extends MeshInstance3D

@export var camera: Camera3D
@export var quad_mesh_instance: MeshInstance3D
@export var planet_instance: MeshInstance3D
@export_range(1.0, 5.0, 0.05) var atmosphere_radius: float = 1.2

@export var num_in_scattering_points = 50;
@export var num_optical_depth_points = 20;
@export_range(0.0, 1.0, 0.005) var atmosphere_blend_value = 0.5;
@export_range(0.0, 1.0, 0.005) var scale_height = 0.25;

var material: ShaderMaterial
var sphere_mesh: SphereMesh

func _ready() -> void:
	material = quad_mesh_instance.get_active_material(0) as ShaderMaterial
	assert(material != null, "Could not find the shader material")

	assert(planet_instance != null, "planet_instance must be assigned in the Inspector")

	sphere_mesh = planet_instance.mesh as SphereMesh
	assert(sphere_mesh != null, "The planet object must be a sphere")

func _process(_delta: float) -> void:
	var sphere_center = planet_instance.global_position
	var scale_vec = planet_instance.global_basis.get_scale()
	var planet_radius = sphere_mesh.radius * scale_vec.x

	material.set_shader_parameter("planet_center_world", sphere_center)
	material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
	material.set_shader_parameter("planet_radius", planet_radius)
	material.set_shader_parameter("num_in_scattering_points", num_in_scattering_points);
	material.set_shader_parameter("num_optical_depth_points", num_optical_depth_points);
	material.set_shader_parameter("atmosphere_blend_value", atmosphere_blend_value);
	material.set_shader_parameter("scale_height", scale_height);
