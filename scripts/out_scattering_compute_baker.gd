class_name OutScatteringComputeBaker
extends RefCounted


const SHADER_PATH := "res://shaders/out_scattering_lut.glsl"
const PARAMS_BUFFER_SIZE := 32
const WORKGROUP_SIZE_X := 8
const WORKGROUP_SIZE_Y := 8

var rd: RenderingDevice
var shader_rid: RID
var pipeline_rid: RID
var params_buffer_rid: RID
var output_texture_rid: RID
var uniform_set_rid: RID
var output_texture: Texture2DRD
var _current_width := -1
var _current_height := -1
var _initialization_failed := false
var _logged_failure := false


func build_texture(
	width: int,
	height: int,
	planet_radius: float,
	atmosphere_radius: float,
	scale_height: float,
	num_optical_depth_points: int
) -> Texture2D:
	if width <= 0 or height <= 0 or num_optical_depth_points < 2:
		return null

	if not _ensure_initialized():
		return null

	if not _ensure_output_texture(width, height):
		return null

	var params_bytes := _pack_params(
		planet_radius,
		atmosphere_radius,
		scale_height,
		num_optical_depth_points,
		width,
		height
	)
	var update_error := rd.buffer_update(params_buffer_rid, 0, params_bytes.size(), params_bytes)
	if update_error != OK:
		_log_failure("Failed to update compute params buffer: %s" % error_string(update_error))
		return null

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)

	var groups_x := int(ceil(float(width) / float(WORKGROUP_SIZE_X)))
	var groups_y := int(ceil(float(height) / float(WORKGROUP_SIZE_Y)))
	rd.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	rd.compute_list_end()

	return output_texture


func _ensure_initialized() -> bool:
	if _initialization_failed:
		return false

	if rd != null and pipeline_rid.is_valid() and params_buffer_rid.is_valid():
		return true

	rd = RenderingServer.get_rendering_device()
	if rd == null:
		_initialization_failed = true
		_log_failure("RenderingDevice compute is unavailable on this renderer/device.")
		return false

	var shader_file := load(SHADER_PATH) as RDShaderFile
	if shader_file == null:
		_initialization_failed = true
		_log_failure("Failed to load compute shader at %s." % SHADER_PATH)
		return false

	var shader_spirv := shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if not shader_rid.is_valid():
		_initialization_failed = true
		_log_failure("Failed to compile the out-scattering compute shader.")
		return false

	pipeline_rid = rd.compute_pipeline_create(shader_rid)
	if not pipeline_rid.is_valid():
		_initialization_failed = true
		_log_failure("Failed to create the out-scattering compute pipeline.")
		return false

	params_buffer_rid = rd.uniform_buffer_create(PARAMS_BUFFER_SIZE)
	if not params_buffer_rid.is_valid():
		_initialization_failed = true
		_log_failure("Failed to create the out-scattering params buffer.")
		return false

	output_texture = Texture2DRD.new()
	return true


func _ensure_output_texture(width: int, height: int) -> bool:
	if width == _current_width and height == _current_height and output_texture_rid.is_valid() and uniform_set_rid.is_valid():
		return true

	_free_output_resources()

	var usage_bits := RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	if not rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_R32_SFLOAT, usage_bits):
		_log_failure("The current RenderingDevice does not support R32_SFLOAT storage textures.")
		return false

	var texture_format := RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = width
	texture_format.height = height
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	texture_format.usage_bits = usage_bits

	var texture_view := RDTextureView.new()
	output_texture_rid = rd.texture_create(texture_format, texture_view)
	if not output_texture_rid.is_valid():
		_log_failure("Failed to create the out-scattering storage texture.")
		return false

	output_texture.texture_rd_rid = output_texture_rid
	uniform_set_rid = _create_uniform_set()
	if not uniform_set_rid.is_valid():
		_free_output_resources()
		_log_failure("Failed to create the out-scattering uniform set.")
		return false

	_current_width = width
	_current_height = height
	return true


func _create_uniform_set() -> RID:
	var params_uniform := RDUniform.new()
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	params_uniform.binding = 0
	params_uniform.add_id(params_buffer_rid)

	var texture_uniform := RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 1
	texture_uniform.add_id(output_texture_rid)

	return rd.uniform_set_create([params_uniform, texture_uniform], shader_rid, 0)


func _pack_params(
	planet_radius: float,
	atmosphere_radius: float,
	scale_height: float,
	num_optical_depth_points: int,
	width: int,
	height: int
) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_float(planet_radius)
	buffer.put_float(atmosphere_radius)
	buffer.put_float(scale_height)
	buffer.put_32(num_optical_depth_points)
	buffer.put_32(width)
	buffer.put_32(height)
	return buffer.data_array


func _free_output_resources() -> void:
	if rd == null:
		return

	if uniform_set_rid.is_valid():
		rd.free_rid(uniform_set_rid)
		uniform_set_rid = RID()

	if output_texture_rid.is_valid():
		rd.free_rid(output_texture_rid)
		output_texture_rid = RID()

	_current_width = -1
	_current_height = -1


func _cleanup() -> void:
	if rd == null:
		return

	_free_output_resources()

	if params_buffer_rid.is_valid():
		rd.free_rid(params_buffer_rid)
		params_buffer_rid = RID()

	if pipeline_rid.is_valid():
		rd.free_rid(pipeline_rid)
		pipeline_rid = RID()

	if shader_rid.is_valid():
		rd.free_rid(shader_rid)
		shader_rid = RID()

	rd = null
	output_texture = null


func _log_failure(message: String) -> void:
	if _logged_failure:
		return

	_logged_failure = true
	push_warning(message)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()
