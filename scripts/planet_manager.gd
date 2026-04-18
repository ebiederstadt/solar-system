extends MeshInstance3D

@export var sun: DirectionalLight3D
@onready var material := get_active_material(0) as ShaderMaterial

func _process(_delta: float) -> void:
	if sun == null or material == null:
		return

	# In Godot, the light shines along its local -basis.z direction.
	var sun_dir = -sun.global_transform.basis.z.normalized()
	material.set_shader_parameter("sun_direction_world", sun_dir)
