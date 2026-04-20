shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix;

#include "res://shaders/atmosphere_common.gdshaderinc"

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;
uniform vec3 planet_center_world = vec3(0.0, 0.0, 0.0);
uniform vec3 sun_pos_world = vec3(0.0, 0.0, 0.0);
uniform float sun_radius = 1.0;
uniform float atmosphere_radius = 1.2;
uniform float planet_radius = 1.0;

uniform int num_in_scattering_points = 50;
uniform int num_optical_depth_points = 20;
uniform float atmosphere_blend_value = 0.5;
uniform float scale_height = 0.25; // H_0

uniform vec3 scattering_coefficients;
uniform sampler2D out_scattering_lut : filter_linear, repeat_disable;

HitInfo ray_sphere_intersect(Ray ray, float radius) {
	HitInfo hit_info = atmosphere_ray_sphere_intersections(ray, planet_center_world, radius);
	if (!hit_info.hit) {
		return hit_info;
	}

	if (hit_info.x1 < 0.0) {
		return HitInfo(false, 0.0, 0.0);
	}

	hit_info.x0 = max(hit_info.x0, 0.0);
	return hit_info;
}

float surface_distance(vec3 point) {
	return surface_distance(point, planet_center_world, planet_radius);
}

// Computes the distance betwen the planet and the top of atmosphere in range (0, 1)
float scaled_atmosphere_dist(vec3 point) {
	return scaled_height(point, planet_center_world, planet_radius, atmosphere_radius);
}

bool inside_atmosphere(vec3 point) {
	float dist_from_surface = surface_distance(point);
	return dist_from_surface <= atmosphere_radius;
}

/// Numerically integrate out-scattering (optical depth) within a boundary
float compute_optical_depth(vec3 ray_start, vec3 target_dir, float ray_length) {
	return compute_optical_depth(
		make_ray(ray_start, target_dir),
		ray_length,
		num_optical_depth_points,
		planet_center_world,
		planet_radius,
		atmosphere_radius,
		scale_height
	);
}

float compute_optical_depth_baked(vec3 ray_start, vec3 target_dir) {
	float scaled_height = scaled_atmosphere_dist(ray_start);

	vec3 up = normalize(ray_start - planet_center_world);
	float cos_theta = clamp(dot(up, target_dir), -1.0, 1.0);
	float angle = acos(cos_theta) / PI;

	vec2 uv = vec2(scaled_height, angle);
	return texture(out_scattering_lut, uv).r;
}

float compute_optical_depth_to_camera_baked(vec3 ray_start, vec3 ray_dir, vec3 camera_pos) {
	bool point_in_atmosphere = inside_atmosphere(camera_pos);

	if (point_in_atmosphere && surface_distance(ray_start) > surface_distance(camera_pos)) {
		ray_dir = -ray_dir;
	}
	float optical_depth_to_camera = compute_optical_depth_baked(ray_start, ray_dir);

	if (point_in_atmosphere) {
		float camera_to_boundary = compute_optical_depth_baked(camera_pos, ray_dir);
		optical_depth_to_camera = max(optical_depth_to_camera - camera_to_boundary, 0.0);
	}

	return optical_depth_to_camera;
}

vec3 calculate_scattering(vec3 ray_entrance, vec3 ray_exit, vec3 ray_dir, vec3 original_col, vec3 camera_pos) {
	float ray_len = length(ray_exit - ray_entrance);
	vec3 in_scatter_point = ray_entrance;
	vec3 in_scattered_light = vec3(0.0);
	float optical_depth_view;
	float step_size = ray_len / float(num_in_scattering_points - 1);

	for (int i = 0; i < num_in_scattering_points; i++) {
		// exp(-h - H_0)
		float density = compute_local_density(
			in_scatter_point,
			planet_center_world,
			planet_radius,
			atmosphere_radius,
			scale_height
		);

		vec3 dir_to_sun = normalize(sun_pos_world - in_scatter_point);
		float optical_depth_sun = compute_optical_depth_baked(in_scatter_point, dir_to_sun);

		float view_ray_length = step_size * float(i);
		optical_depth_view = compute_optical_depth_to_camera_baked(in_scatter_point, -ray_dir, camera_pos);

		vec3 transmittance = exp(-(optical_depth_sun + optical_depth_view) * scattering_coefficients);

		in_scattered_light += density * transmittance * scattering_coefficients * step_size;
		in_scatter_point += ray_dir * step_size;
	}

	float original_col_transmittance = exp(-optical_depth_view);
	return original_col * original_col_transmittance + in_scattered_light;
}

float scene_depth_distance(vec2 screen_uv, Ray view_ray, mat4 inv_projection_matrix, mat4 inv_view_matrix) {
	float depth_raw = texture(depth_texture, screen_uv).x;
	if (depth_raw >= 1.0) {
		return 1e20;
	}

	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_raw);
	vec4 world = inv_view_matrix * inv_projection_matrix * vec4(ndc, 1.0);
	vec3 position_world = world.xyz / world.w;
	return max(dot(position_world - view_ray.origin, view_ray.direction), 0.0);
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
	float scene_depth_t = scene_depth_distance(SCREEN_UV, view_ray, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

	if (planet_hit.hit) {
		atmosphere_hit.x1 = min(atmosphere_hit.x1, planet_hit.x0);
	}

	if (atmosphere_hit.hit) {
		atmosphere_hit.x1 = min(atmosphere_hit.x1, scene_depth_t);
		if (scene_depth_t <= atmosphere_hit.x0 || atmosphere_hit.x1 <= atmosphere_hit.x0) {
			atmosphere_hit.hit = false;
		}
	}

	vec3 original_color = screen.rgb;

	if (atmosphere_hit.hit) {
		vec3 ray_start_atmosphere = point_on_ray(view_ray, atmosphere_hit.x0);
		vec3 ray_end_atmosphere = point_on_ray(view_ray, atmosphere_hit.x1);
		vec3 light = calculate_scattering(ray_start_atmosphere, ray_end_atmosphere, view_ray.direction, original_color, view_ray.origin);
		ALBEDO = light;
	} else {
		ALBEDO = screen.rgb;
	}
}
