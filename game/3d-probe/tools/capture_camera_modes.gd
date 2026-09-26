extends SceneTree

## Кадры видов камеры и сценки у завала на стартовом месте.
## godot --fixed-fps 60 --path game/3d-probe -s res://tools/capture_camera_modes.gd -- <папка>


func _initialize() -> void:
	_capture.call_deferred()


func _shot(folder: String, file_name: String, wait: int = 25) -> void:
	for i in wait:
		await process_frame
	root.get_texture().get_image().save_jpg(folder + "/" + file_name, 0.88)
	print("Кадр: ", file_name)


func _capture() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var settings: Node = root.get_node("GameSettings")
	settings.settings_path = "user://capture_settings.cfg"
	root.get_node("SaveGame").start_new_game("Кот", "a")
	change_scene_to_file("res://scenes/world/start_area.tscn")
	for i in 3:
		await process_frame
	var scene := current_scene
	var player: CharacterBody3D = scene.get_node("CatPlayer")
	var builder = scene.get_node("World/Builder")
	var z: float = builder.SPAWN_Z - 3.0 * builder.WORLD_UNITS_PER_METRE
	player.global_position = Vector3(builder.terrain.trail_center_x(z), 0.35, z)
	player.camera_pivot.rotation = Vector3(-0.3, 0.3, 0)
	player.visual.rotation.y = 0.3
	await _shot(folder, "01-third-person.jpg")
	player.set_camera_mode(settings.CameraMode.FIRST_PERSON)
	player.camera_pivot.rotation.x = -0.05
	await _shot(folder, "02-first-person.jpg")
	settings.set_value("camera_side", 1.6)
	settings.set_value("camera_height", 2.8)
	settings.set_value("camera_distance", 5.0)
	settings.set_value("camera_pitch", -8.0)
	player.set_camera_mode(settings.CameraMode.CUSTOM)
	await _shot(folder, "03-custom-shoulder.jpg")
	settings.reset_to_defaults()
	settings.set_value("camera_distance", 15.0)
	player.set_camera_mode(settings.CameraMode.THIRD_PERSON)
	settings.apply()
	player.camera_pivot.rotation = Vector3(-0.5, 0.3, 0)
	await _shot(folder, "04-zoomed-out.jpg")
	settings.reset_to_defaults()
	settings.apply()
	player.global_position = scene.get_node("EndZone").global_position - Vector3(0, 2.2, 0)
	await _shot(folder, "05-barrier-reaction.jpg", 50)
	if FileAccess.file_exists("user://capture_settings.cfg"):
		DirAccess.remove_absolute("user://capture_settings.cfg")
	quit()
