extends MeshInstance3D

@export var camera: Camera3D
@export var quad_mesh_instance: MeshInstance3D
@export var sphere_center: Vector3 = Vector3.ZERO
@export var sphere_radius: float = 10.0

var material: ShaderMaterial

func _ready() -> void:
	material = quad_mesh_instance.get_active_material(0) as ShaderMaterial

func _process(_delta: float) -> void:
	if material == null:
		return

	material.set_shader_parameter("sphere_center_world", sphere_center)
	material.set_shader_parameter("sphere_radius", sphere_radius)
