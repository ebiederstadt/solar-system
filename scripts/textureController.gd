extends Node

@export var texture_rect: TextureRect

@export var planet_radius = 1.0:
	set(value):
		planet_radius = value
		_update_texture()

@export var atmosphere_radius = 1.2:
	set(value):
		atmosphere_radius = value
		_update_texture()

@export var scale_height = 0.25:
	set(value):
		scale_height = value
		_update_texture()

@export var num_optical_depth_points = 50:
	set(value):
		num_optical_depth_points = value
		_update_texture()

var out_scattering_texture: OutScatteringTexture

func _update_texture():
	if not out_scattering_texture:
		return

	out_scattering_texture.planet_radius = planet_radius
	out_scattering_texture.atmosphere_radius = atmosphere_radius
	out_scattering_texture.scale_height = scale_height
	out_scattering_texture.num_optical_depth_points = num_optical_depth_points

	var window_size = get_window().size
	texture_rect.texture = out_scattering_texture.build_texture(window_size.x, window_size.y)
	print(texture_rect.texture.get_width())
	print(texture_rect.texture.get_height())

func _ready() -> void:
	assert(texture_rect != null, "The texture rect must be assigned")

	out_scattering_texture = OutScatteringTexture.new(
		planet_radius,
		atmosphere_radius,
		scale_height,
		num_optical_depth_points
	)
	_update_texture()
