#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std140) uniform Params {
	float planet_radius;
	float atmosphere_radius;
	float scale_height;
	int num_optical_depth_points;
	int lut_width;
	int lut_height;
	float pad0;
	float pad1;
} params;

layout(r32f, set = 0, binding = 1) uniform restrict writeonly image2D out_lut;

const float PI = 3.14159265358979323846;

float ray_sphere_exit_distance(vec3 ray_origin, vec3 ray_dir, float sphere_radius) {
	float a = dot(ray_dir, ray_dir);
	float b = 2.0 * dot(ray_origin, ray_dir);
	float c = dot(ray_origin, ray_origin) - sphere_radius * sphere_radius;
	float discriminant = b * b - 4.0 * a * c;

	if (discriminant < 0.0) {
		return 0.0;
	}

	float sqrt_discriminant = sqrt(discriminant);
	float t0 = (-b - sqrt_discriminant) / (2.0 * a);
	float t1 = (-b + sqrt_discriminant) / (2.0 * a);
	return max(max(t0, t1), 0.0);
}

float compute_local_density(vec3 point) {
	float dist_from_surface = length(point) - params.planet_radius;
	float thickness = max(params.atmosphere_radius - params.planet_radius, 0.0001);
	float scaled_dist = dist_from_surface / thickness;
	return exp(-scaled_dist / max(params.scale_height, 0.0001));
}

float compute_optical_depth(vec3 ray_start, vec3 ray_dir, float ray_length) {
	if (ray_length <= 0.0) {
		return 0.0;
	}

	vec3 ray_pos = ray_start;
	float step_size = ray_length / float(max(params.num_optical_depth_points - 1, 1));
	float optical_depth = 0.0;

	for (int i = 0; i < params.num_optical_depth_points; i++) {
		optical_depth += compute_local_density(ray_pos) * step_size;
		ray_pos += ray_dir * step_size;
	}

	return optical_depth;
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (coord.x >= params.lut_width || coord.y >= params.lut_height) {
		return;
	}

	float height01 = (float(coord.x) + 0.5) / float(max(params.lut_width, 1));
	float vertical_angle01 = (float(coord.y) + 0.5) / float(max(params.lut_height, 1));
	float radius = mix(params.planet_radius, params.atmosphere_radius, clamp(height01, 0.0, 1.0));
	vec3 ray_origin = vec3(radius, 0.0, 0.0);
	vec3 up = normalize(ray_origin);
	vec3 tangent = vec3(0.0, 0.0, 1.0);
	float vertical_angle = mix(0.0, PI, clamp(vertical_angle01, 0.0, 1.0));
	vec3 ray_dir = normalize(up * cos(vertical_angle) + tangent * sin(vertical_angle));
	float ray_length = ray_sphere_exit_distance(ray_origin, ray_dir, params.atmosphere_radius);
	float optical_depth = compute_optical_depth(ray_origin, ray_dir, ray_length);

	imageStore(out_lut, coord, vec4(optical_depth, 0.0, 0.0, 1.0));
}
