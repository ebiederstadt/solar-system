extends MeshInstance3D

@export var sun: DirectionalLight3D
@onready var material := get_active_material(0) as ShaderMaterial

var _last_sun_dir := Vector3.INF

func _ready() -> void:
	_sync_shader_params()

func _process(_delta: float) -> void:
	if sun == null or material == null:
		return

	# In Godot, the light shines along its local -basis.z direction.
	var sun_dir = -sun.global_transform.basis.z.normalized()
	if not sun_dir.is_equal_approx(_last_sun_dir):
		_last_sun_dir = sun_dir
		material.set_shader_parameter("sun_direction_world", sun_dir)

func _sync_shader_params() -> void:
	if sun == null or material == null:
		return

	_last_sun_dir = -sun.global_transform.basis.z.normalized()
	material.set_shader_parameter("sun_direction_world", _last_sun_dir)
