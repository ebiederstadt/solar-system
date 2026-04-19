extends MeshInstance3D

const OutScatteringTextureBuilder = preload("res://scripts/out_scattering_texture.gd")

@export var camera: Camera3D
@export var quad_mesh_instance: MeshInstance3D
@export var planet_instance: MeshInstance3D
@export var sun_instance: MeshInstance3D
@export_range(16, 1024, 1) var out_scattering_lut_width := 256
@export_range(16, 1024, 1) var out_scattering_lut_height := 64
@export_range(1.001, 5.0, 0.05) var atmosphere_radius: float = 1.2:
	set(value):
		atmosphere_radius = value
		_update_shader_param("atmosphere_radius", atmosphere_radius)
		_rebuild_out_scattering_lut()

@export var num_in_scattering_points := 100:
	set(value):
		num_in_scattering_points = value
		_update_shader_param("num_in_scattering_points", num_in_scattering_points)

@export var num_optical_depth_points := 50:
	set(value):
		num_optical_depth_points = value
		_update_shader_param("num_optical_depth_points", num_optical_depth_points)
		_rebuild_out_scattering_lut()

@export_range(0.001, 1.0, 0.005) var scale_height := 0.25:
	set(value):
		scale_height = value
		_update_shader_param("scale_height", scale_height)
		_rebuild_out_scattering_lut()

@export var scattering_strength := 1.0:
	set(value):
		scattering_strength = value
		_update_scattering_coefficients()

@export var wavelengths := [700, 530, 440]:
	set(value):
		wavelengths = value
		_update_scattering_coefficients()

var material: ShaderMaterial
var planet_mesh: SphereMesh
var sun_mesh: SphereMesh
var _last_planet_center := Vector3.INF
var _last_planet_radius := -1.0
var _last_sun_center := Vector3.INF
var _last_sun_radius := -1.0

func get_radius(sphere_mesh: SphereMesh):
	var scale_vec = planet_instance.global_basis.get_scale()
	return sphere_mesh.radius * scale_vec.x

func _ready() -> void:
	material = quad_mesh_instance.get_active_material(0) as ShaderMaterial
	assert(material != null, "Could not find the shader material")

	assert(planet_instance != null, "planet_instance must be assigned in the Inspector")
	planet_mesh = planet_instance.mesh as SphereMesh
	assert(planet_mesh != null, "The planet object must be a sphere")

	assert(sun_instance != null, "The sun must be assigned")
	sun_mesh = sun_instance.mesh as SphereMesh
	assert(sun_mesh != null, "The sun must be a sphere")

	_sync_static_shader_params()
	_rebuild_out_scattering_lut()

func _process(_delta: float) -> void:
	var sphere_center = planet_instance.global_position
	var planet_radius = get_radius(planet_mesh)

	var sun_center = sun_instance.global_position
	var sun_radius = get_radius(sun_mesh)

	if not sphere_center.is_equal_approx(_last_planet_center):
		_last_planet_center = sphere_center
		material.set_shader_parameter("planet_center_world", sphere_center)

	if not is_equal_approx(planet_radius, _last_planet_radius):
		_last_planet_radius = planet_radius
		material.set_shader_parameter("planet_radius", planet_radius)
		_rebuild_out_scattering_lut()

	if not sun_center.is_equal_approx(_last_sun_center):
		_last_sun_center = sun_center
		material.set_shader_parameter("sun_pos_world", sun_center)

	if not is_equal_approx(sun_radius, _last_sun_radius):
		_last_sun_radius = sun_radius
		material.set_shader_parameter("sun_radius", sun_radius)

func _update_shader_param(param_name: StringName, value) -> void:
	if material != null:
		material.set_shader_parameter(param_name, value)

func _update_scattering_coefficients() -> void:
	if material == null:
		return

	var scatter_red = pow(400.0 / wavelengths[0], 4.0) * scattering_strength
	var scatter_green = pow(400.0 / wavelengths[1], 4.0) * scattering_strength
	var scatter_blue = pow(400.0 / wavelengths[2], 4.0) * scattering_strength
	var scattering_coefficients = Vector3(scatter_red, scatter_green, scatter_blue)
	material.set_shader_parameter("scattering_coefficients", scattering_coefficients)

func _sync_static_shader_params() -> void:
	_update_shader_param("atmosphere_radius", atmosphere_radius)
	_update_shader_param("num_in_scattering_points", num_in_scattering_points)
	_update_shader_param("num_optical_depth_points", num_optical_depth_points)
	_update_shader_param("scale_height", scale_height)
	_update_scattering_coefficients()


func _rebuild_out_scattering_lut() -> void:
	if material == null or planet_mesh == null:
		return

	var builder := OutScatteringTextureBuilder.new(
		get_radius(planet_mesh),
		atmosphere_radius,
		scale_height,
		num_optical_depth_points
	)
	var texture := builder.build_texture(out_scattering_lut_width, out_scattering_lut_height)
	material.set_shader_parameter("out_scattering_lut", texture)
