extends Node3D

@export var camera_ref: Camera3D

@export var target: Node3D
@export var distance: float = 3.0
@export var min_distance: float = 0.5
@export var max_distance: float = 10.0
@export var rotation_speed: float = 0.01
@export var zoom_speed: float = 0.05

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	assert(camera_ref != null, "Camera must be assigned")

	if target:
		global_transform.origin = target.global_transform.origin

	var dir = -transform.basis.z.normalized()
	yaw = atan2(dir.x, dir.z)
	pitch = asin(dir.y)

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.005
		pitch -= event.relative.y * 0.005

		pitch = clamp(pitch, -1.5, 1.5)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= (1.0 - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= (1.0 + zoom_speed)

		distance = clamp(distance, min_distance, max_distance)

func _process(_delta):
	if target:
		global_transform.origin = target.global_transform.origin

	# Apply rotation
	rotation = Vector3(pitch, yaw, 0)

	# Zoom (mouse wheel)
	if Input.is_action_just_pressed("ui_page_up"):
		distance -= zoom_speed
	if Input.is_action_just_pressed("ui_page_down"):
		distance += zoom_speed

	distance = clamp(distance, 1.0, 20.0)

	# Move camera along local Z
	camera_ref.transform.origin = Vector3(0, 0, distance)
