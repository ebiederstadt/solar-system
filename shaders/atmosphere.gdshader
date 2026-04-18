shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix;

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D normal_rough_texture : hint_normal_roughness_texture;
uniform vec3 sphere_center_world = vec3(0.0, 0.0, 0.0);
uniform float sphere_radius = 10.0;

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

		// Always return the first intersection, then the second
		if (x1 < x0) {
			float tmp = x0;
			x0 = x1;
			x1 = tmp;
		}

	    return true;
}

bool ray_sphere_intersection(vec3 ray_origin, vec3 ray_direction, vec3 sphere_center, float radius, out float x0, out float x1) {
	vec3 oc = ray_origin - sphere_center;
	float a = dot(ray_direction, ray_direction);
	float b = 2.0 * dot(ray_direction, oc);
	float c = dot(oc, oc) - radius * radius;

	if (solve_quadratic(a, b, c, x0, x1)) {
		return true;
	}
	return false;
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

	vec3 ray_origin_world = INV_VIEW_MATRIX[3].xyz;
	vec3 ray_target_world = (INV_VIEW_MATRIX * vec4(far_view.xyz, 1.0)).xyz;
	vec3 ray_direction_world = normalize(ray_target_world - ray_origin_world);

	float t0 = 0.0;
	float t1 = 0.0;
	bool hit = ray_sphere_intersection(
		ray_origin_world,
		ray_direction_world,
		sphere_center_world,
		sphere_radius,
		t0,
		t1
	);

	// Only count intersections in front of the camera.
	if (hit && t1 >= 0.0) {
		ALBEDO = vec3(1.0, 0.0, 0.0);
		ALPHA = 0.35;
	} else {
		ALBEDO = screen.rgb;
		ALPHA = 1.0;
	}
}
