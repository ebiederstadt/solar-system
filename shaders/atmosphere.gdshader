shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix;

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform vec3 planet_center_world = vec3(0.0, 0.0, 0.0);
uniform vec3 sun_pos_world = vec3(0.0, 0.0, 0.0);
uniform float sun_radius = 1.0;
uniform float atmosphere_radius = 1.2;
uniform float planet_radius = 1.0;

uniform int num_in_scattering_points = 50;
uniform int num_optical_depth_points = 20;
uniform float atmosphere_blend_value = 0.5;
uniform float scale_height = 0.25; // H_0

bool solve_quadratic(float a, float b, float c, out float x0, out float x1) {
	float discr = b * b - 4.0 * a * c;
 	if (discr < 0.0) return false;

	if (discr == 0.0) {
		x0 = -0.5 * b / a;
		x1 = x0;
		return true;
	}

	float q = (b > 0.0) ?
	    -0.5 * (b + sqrt(discr)) :
	    -0.5 * (b - sqrt(discr));
	x0 = q / a;
	x1 = c / q;

	if (x1 < x0) {
		float tmp = x0;
		x0 = x1;
		x1 = tmp;
	}

	return true;
}

struct Ray {
	vec3 origin;
	vec3 direction;
};

Ray make_ray(vec3 origin, vec3 direction) {
	Ray ray;
	ray.origin = origin;
	ray.direction = normalize(direction);
	return ray;
}

struct HitInfo {
	bool hit;
	float x0;
	float x1;
};

// Evaluates r(t) = O + tD
vec3 point_on_ray(Ray ray, float t) {
	return ray.origin + ray.direction * t;
}

HitInfo ray_sphere_intersect(Ray ray, float radius) {
	HitInfo hit_info = HitInfo(false, 0.0, 0.0);

	vec3 oc = ray.origin - planet_center_world;
	float a = dot(ray.direction, ray.direction);
	float b = 2.0 * dot(ray.direction, oc);
	float c = dot(oc, oc) - radius * radius;

	float x0;
	float x1;
	if (!solve_quadratic(a, b, c, x0, x1)) {
		return hit_info;
	}

	if (x1 < 0.0) {
		return hit_info;
	}

	hit_info.hit = true;
	hit_info.x0 = max(x0, 0.0);
	hit_info.x1 = x1;

	return hit_info;
}

float compute_local_density(vec3 point) {
	float dist_from_surface = length(point - planet_center_world) - planet_radius;
	float scaled_dist = dist_from_surface / (atmosphere_radius - planet_radius);

	return exp(-scaled_dist / scale_height);
}

/// Numerically integrate out-scattering (optical depth) within a boundary
float compute_optical_depth(vec3 ray_start, vec3 target_dir, float ray_length) {
	vec3 ray_pos = ray_start;
	float step_size = ray_length / float(num_optical_depth_points - 1);
	float optical_depth = 0.0;

	for (int i = 0; i < num_optical_depth_points; i++) {
		optical_depth += compute_local_density(ray_pos) * step_size;
		ray_pos += target_dir * step_size;
	}

	return optical_depth;
}

vec3 calculate_scattering(vec3 ray_entrance, vec3 ray_exit, vec3 ray_dir) {
	float ray_len = length(ray_exit - ray_entrance);
	vec3 in_scatter_point = ray_entrance;
	float in_scattered_light = 0.0;
	float step_size = ray_len / float(num_in_scattering_points - 1);

	for (int i = 0; i < num_in_scattering_points; i++) {
		// exp(-h - H_0)
		float density = compute_local_density(in_scatter_point);

		vec3 dir_to_sun = normalize(sun_pos_world - in_scatter_point);
		Ray sun_ray = make_ray(in_scatter_point, dir_to_sun);
		float sun_ray_length = ray_sphere_intersect(sun_ray, atmosphere_radius).x1;
		float optical_depth_sun = compute_optical_depth(in_scatter_point, dir_to_sun, sun_ray_length);

		float view_ray_length = step_size * float(i);
		float optical_depth_view = compute_optical_depth(in_scatter_point, -ray_dir, view_ray_length);

		float transmittance = exp(-(optical_depth_sun + optical_depth_view));

		in_scattered_light += density * transmittance * step_size;
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

	vec3 ray_target_world = (INV_VIEW_MATRIX * vec4(far_view.xyz, 1.0)).xyz;
	Ray view_ray = make_ray(INV_VIEW_MATRIX[3].xyz, ray_target_world - INV_VIEW_MATRIX[3].xyz);

	HitInfo atmosphere_hit = ray_sphere_intersect(view_ray, atmosphere_radius);
	HitInfo planet_hit = ray_sphere_intersect(view_ray, planet_radius);

	if (planet_hit.hit) {
		atmosphere_hit.x1 = min(atmosphere_hit.x1, planet_hit.x0);
	}

	vec3 original_color = screen.rgb;

	if (atmosphere_hit.hit) {
		vec3 ray_start_atmosphere = point_on_ray(view_ray, atmosphere_hit.x0);
		vec3 ray_end_atmosphere = point_on_ray(view_ray, atmosphere_hit.x1);
		vec3 in_scattered_light = calculate_scattering(ray_start_atmosphere, ray_end_atmosphere, view_ray.direction);
		ALBEDO = original_color + in_scattered_light * atmosphere_blend_value;
	} else {
		ALBEDO = screen.rgb;
	}
}
