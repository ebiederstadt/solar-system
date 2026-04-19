struct Ray {
	vec3 origin;
	vec3 direction;
};

struct HitInfo {
	bool hit;
	float x0;
	float x1;
};

Ray make_ray(vec3 origin, vec3 direction) {
	Ray ray;
	ray.origin = origin;
	ray.direction = normalize(direction);
	return ray;
}

vec3 point_on_ray(Ray ray, float t) {
	return ray.origin + ray.direction * t;
}

bool solve_quadratic(float a, float b, float c, out float x0, out float x1) {
	float discriminant = b * b - 4.0 * a * c;
	if (discriminant < 0.0) {
		return false;
	}

	if (discriminant == 0.0) {
		x0 = -0.5 * b / a;
		x1 = x0;
		return true;
	}

	float q = (b > 0.0) ? -0.5 * (b + sqrt(discriminant)) : -0.5 * (b - sqrt(discriminant));
	x0 = q / a;
	x1 = c / q;

	if (x1 < x0) {
		float tmp = x0;
		x0 = x1;
		x1 = tmp;
	}

	return true;
}

HitInfo atmosphere_ray_sphere_intersections(Ray ray, vec3 sphere_center, float sphere_radius) {
	HitInfo hit_info = HitInfo(false, 0.0, 0.0);
	vec3 offset = ray.origin - sphere_center;
	float a = 1.0;
	float b = 2.0 * dot(offset, ray.direction);
	float c = dot(offset, offset) - sphere_radius * sphere_radius;
	float t0;
	float t1;
	if (!solve_quadratic(a, b, c, t0, t1)) {
		return hit_info;
	}

	hit_info.hit = true;
	hit_info.x0 = t0;
	hit_info.x1 = t1;
	return hit_info;
}

float surface_distance(vec3 point, vec3 planet_center_world, float planet_radius) {
	return length(point - planet_center_world) - planet_radius;
}

float scaled_height(vec3 point, vec3 planet_center_world, float planet_radius, float atmosphere_radius) {
	float dist_from_surface = surface_distance(point, planet_center_world, planet_radius);
	float scaled_dist = dist_from_surface / (atmosphere_radius - planet_radius);
	return scaled_dist;
}

float compute_local_density(
	vec3 point,
	vec3 planet_center_world,
	float planet_radius,
	float atmosphere_radius,
	float scale_height
) {
	float scaled_dist = scaled_height(point, planet_center_world, planet_radius, atmosphere_radius);
	return exp(-scaled_dist / scale_height);
}

float compute_optical_depth(
	Ray ray,
	float ray_length,
	int num_optical_depth_points,
	vec3 planet_center_world,
	float planet_radius,
	float atmosphere_radius,
	float scale_height
) {
	if (ray_length <= 0.0) {
		return 0.0;
	}

	vec3 ray_pos = ray.origin;
	float step_size = ray_length / float(max(num_optical_depth_points - 1, 1));
	float optical_depth = 0.0;

	for (int i = 0; i < num_optical_depth_points; i++) {
		optical_depth += compute_local_density(
			ray_pos,
			planet_center_world,
			planet_radius,
			atmosphere_radius,
			scale_height
		) * step_size;
		ray_pos += ray.direction * step_size;
	}

	return optical_depth;
}
