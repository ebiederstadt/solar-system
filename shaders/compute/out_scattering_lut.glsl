#[compute]
#version 450

#include "res://shaders/atmosphere_common.gdshaderinc"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std140) uniform Params {
	float planet_radius;
	float atmosphere_radius;
	float scale_height;
	int num_optical_depth_points;
	int lut_width;
	int lut_height;
} params;

layout(r32f, set = 0, binding = 1) uniform restrict writeonly image2D out_lut;

const float PI = 3.14159265358979323846;

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
	if (coord.x >= params.lut_width || coord.y >= params.lut_height) {
		return;
	}

	// Calculate the UV coordinates
	float scaled_height = (float(coord.x) + 0.5) / float(max(params.lut_width, 1));
	float scaled_angle = (float(coord.y) + 0.5) / float(max(params.lut_height, 1));

	// Calculate the "world space" coordinates
	float radius = mix(params.planet_radius, params.atmosphere_radius, clamp(scaled_height, 0.0, 1.0));
	float vertical_angle = mix(0.0, PI, clamp(scaled_angle, 0.0, 1.0));

	vec3 ray_origin = vec3(radius, 0.0, 0.0);
	vec3 up = normalize(ray_origin);
	vec3 tangent = vec3(0.0, 0.0, 1.0);
	Ray ray = make_ray(ray_origin, up * cos(vertical_angle) + tangent * sin(vertical_angle));

	float ray_length = atmosphere_ray_sphere_intersections(ray, vec3(0.0), params.atmosphere_radius).x1;
	float optical_depth = compute_optical_depth(
		ray,
		ray_length,
		params.num_optical_depth_points,
		vec3(0.0),
		params.planet_radius,
		params.atmosphere_radius,
		max(params.scale_height, 0.0001)
	);

	imageStore(out_lut, coord, vec4(optical_depth, 0.0, 0.0, 1.0));
}
