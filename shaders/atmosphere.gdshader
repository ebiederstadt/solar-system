shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix;

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform vec3 planet_center_world = vec3(0.0, 0.0, 0.0);
uniform vec3 sun_pos_world = vec3(0.0, 0.0, 0.0);
uniform float atmosphere_radius = 1.2;
uniform float planet_radius = 1.0;

uniform int num_in_scattering_points = 50;
uniform int num_optical_depth_points = 20;
uniform float atmosphere_blend_value = 0.5;
uniform float scale_height = 0.25; // H_0

// Evaluates r(t) = O + tD
vec3 ray(vec3 ray_origin, vec3 ray_direction, float t) {
	return ray_origin + ray_direction * t;
}

bool solve_quadratic(float a, float b, float c, out float x0, out float x1) {
	float discr = b * b - 4.0 * a * c;
 	if (discr < 0.0) return false;

	else if (discr == 0.0) x0 = x1 = -0.5 * b / a;
	else {
        float q = (b > 0.0) ?
            -0.5 * (b + sqrt(discr)) :
            -0.5 * (b - sqrt(discr));
        x0 = q / a;
        x1 = c / q;
    }

		if (x1 < x0) {
			float tmp = x0;
			x0 = x1;
			x1 = tmp;
		}

		// If the first intersection is small than 1 it is behind the camera
		return x0 >= 0.0;
}

bool ray_sphere_intersection(vec3 ray_origin, vec3 ray_direction, float radius, out float x0, out float x1) {
	vec3 oc = ray_origin - planet_center_world;
	float a = dot(ray_direction, ray_direction);
	float b = 2.0 * dot(ray_direction, oc);
	float c = dot(oc, oc) - radius * radius;

	if (solve_quadratic(a, b, c, x0, x1)) {
		return true;
	}
	return false;
}

float compute_local_density(vec3 point) {
	float dist_from_surface = length(point - planet_center_world) - planet_radius;
	float scaled_dist = dist_from_surface / (atmosphere_radius - planet_radius);

	return exp(-scaled_dist / scale_height);
}

float optical_depth(vec3 ray_start, vec3 target) {
	return 0.0;
}

vec3 calculate_scattering(vec3 ray_entrance, vec3 ray_exit, vec3 ray_dir) {
	float ray_len = length(ray_exit - ray_entrance);
	vec3 in_scatter_point = ray_entrance;
	float in_scattered_light = 0.0;
	float step_size = ray_len / float(num_in_scattering_points - 1);

	for (int i = 0; i < num_in_scattering_points; i++) {
		// exp(-h - H_0)
		float density = compute_local_density(in_scatter_point);
		float optical_depth_sun = optical_depth(in_scatter_point, sun_pos_world);
		float optical_depth_view = optical_depth(in_scatter_point, ray_entrance);

		in_scattered_light += density;
		in_scatter_point += ray_dir * step_size;
	}

	return vec3(in_scattered_light);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);

	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;

	// Reconstruct a point on the far clip plane, then shoot a ray from the camera through it.
	vec4 far_view = INV_PROJECTION_MATRIX * vec4(ndc_xy, 1.0, 1.0);
	far_view.xyz /= far_view.w;

	vec3 ray_origin = INV_VIEW_MATRIX[3].xyz;
	vec3 ray_target_world = (INV_VIEW_MATRIX * vec4(far_view.xyz, 1.0)).xyz;
	vec3 ray_dir = normalize(ray_target_world - ray_origin);

	float dist_to_atmosphere = 0.0;
	float dist_through_atmosphere = 0.0;
	bool hit_atmosphere = ray_sphere_intersection(
		ray_origin,
		ray_dir,
		atmosphere_radius,
		dist_to_atmosphere,
		dist_through_atmosphere
	);

	float dist_to_planet = 0.0;
	float dist_through_planet = 0.0;
	bool hit_planet = ray_sphere_intersection(
		ray_origin,
		ray_dir,
		atmosphere_radius,
		dist_to_planet,
		dist_through_planet
	);

	if (hit_planet) {
		dist_through_atmosphere = min(dist_through_atmosphere, dist_to_planet);
	}

	vec3 original_color = screen.rgb;

	if (hit_atmosphere) {
		vec3 ray_start_atmosphere = ray(ray_origin, ray_dir, dist_to_atmosphere);
		vec3 ray_end_atmosphere = ray(ray_origin, ray_dir, dist_through_atmosphere);
		vec3 in_scattered_light = calculate_scattering(ray_start_atmosphere, ray_end_atmosphere, ray_dir);
		ALBEDO = mix(original_color, in_scattered_light, atmosphere_blend_value);
	} else {
		ALBEDO = screen.rgb;
	}
}
