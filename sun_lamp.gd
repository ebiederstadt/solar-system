extends DirectionalLight3D

@export var target: MeshInstance3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	look_at(target.global_transform.origin, Vector3.UP)
