extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and Input.is_action_just_pressed("screenshot"):
		print("Taking screenshot!")
		var img = get_viewport().get_texture().get_image()

		DirAccess.make_dir_recursive_absolute("user://screenshots")

		var datetime_string = Time.get_datetime_string_from_system()
		var safe_datetime_string = datetime_string.replace(":", "-")
		var save_path = "user://screenshots/{0}.png".format([safe_datetime_string])
		var absolute_save_path = ProjectSettings.globalize_path(save_path)
		print("Saving screenshot to %s" % absolute_save_path)
		var err = img.save_png(save_path)

		if err != OK:
			push_error("Failed to save screenshot to %s (error %d)" % [save_path, err])
		else:
			print("Saved screenshot to %s" % save_path)
