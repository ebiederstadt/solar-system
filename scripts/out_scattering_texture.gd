class_name OutScatteringTexture
extends RefCounted


var planet_radius: float
var atmosphere_radius: float
var scale_height: float
var num_optical_depth_points: int


func _init(
	p_planet_radius: float,
	p_atmosphere_radius: float,
	p_scale_height: float,
	p_num_optical_depth_points: int
) -> void:
	planet_radius = p_planet_radius
	atmosphere_radius = p_atmosphere_radius
	scale_height = p_scale_height
	num_optical_depth_points = max(p_num_optical_depth_points, 2)


func build_texture(width: int, height: int) -> ImageTexture:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RF)

	for y in height:
		var vertical_angle_scaled := float(y) / float(max(height - 1, 1))
		for x in width:
			var height_scaled := float(x) / float(max(width - 1, 1))
			var optical_depth := _compute_optical_depth_to_atmosphere_edge(height_scaled, vertical_angle_scaled)
			image.set_pixel(x, y, Color(optical_depth, 0.0, 0.0, 1.0))

	return ImageTexture.create_from_image(image)


func _compute_optical_depth_to_atmosphere_edge(height01: float, vertical_angle01: float) -> float:
	var radius = lerp(planet_radius, atmosphere_radius, clampf(height01, 0.0, 1.0))
	var ray_origin := Vector3(radius, 0.0, 0.0)
	var up := ray_origin.normalized()
	var tangent := Vector3.FORWARD
	var vertical_angle = lerp(0.0, PI, clampf(vertical_angle01, 0.0, 1.0))
	var ray_dir := (up * cos(vertical_angle) + tangent * sin(vertical_angle)).normalized()
	var ray_length := _ray_sphere_exit_distance(ray_origin, ray_dir, atmosphere_radius)
	return _compute_optical_depth(ray_origin, ray_dir, ray_length)


func _ray_sphere_exit_distance(ray_origin: Vector3, ray_dir: Vector3, sphere_radius: float) -> float:
	var a := ray_dir.dot(ray_dir)
	var b := 2.0 * ray_origin.dot(ray_dir)
	var c := ray_origin.dot(ray_origin) - sphere_radius * sphere_radius
	var discriminant := b * b - 4.0 * a * c

	if discriminant < 0.0:
		return 0.0

	var sqrt_discriminant := sqrt(discriminant)
	var t0 := (-b - sqrt_discriminant) / (2.0 * a)
	var t1 := (-b + sqrt_discriminant) / (2.0 * a)
	return max(max(t0, t1), 0.0)


func _compute_local_density(point: Vector3) -> float:
	var dist_from_surface := point.length() - planet_radius
	var scaled_dist = dist_from_surface / max(atmosphere_radius - planet_radius, 0.0001)
	return exp(-scaled_dist / max(scale_height, 0.0001))


func _compute_optical_depth(ray_start: Vector3, ray_dir: Vector3, ray_length: float) -> float:
	if ray_length <= 0.0:
		return 0.0

	var ray_pos := ray_start
	var step_size := ray_length / float(num_optical_depth_points - 1)
	var optical_depth := 0.0

	for i in num_optical_depth_points:
		optical_depth += _compute_local_density(ray_pos) * step_size
		ray_pos += ray_dir * step_size

	return optical_depth
