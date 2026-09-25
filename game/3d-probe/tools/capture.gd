extends SceneTree

## Снимок экрана сцены без ручного запуска игры (для проверки и отчётов).
## godot --path game/3d-probe -s res://tools/capture.gd -- <сцена> <файл.png|.jpg> [метры] [поворот камеры, °] [наклон, °]
## Метры/поворот/наклон нужны только для участка с котом.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var output_path: String = args[1]
	change_scene_to_file(scene_path)
	for i in 3:
		await process_frame
	var scene := current_scene
	if args.size() > 2 and scene.has_node("CatPlayer"):
		var builder = scene.get_node("Builder")
		builder.setup_noise()
		var z := roundi(-float(args[2]) * builder.WORLD_UNITS_PER_METRE)
		var x := roundi(builder.path_center_x(z))
		var player: Node3D = scene.get_node("CatPlayer")
		player.global_position = Vector3(x, builder.block_height(x, z) + 0.1, z)
		var pivot: Node3D = player.get_node("CameraPivot")
		if args.size() > 3:
			pivot.rotation.y = deg_to_rad(float(args[3]))
		if args.size() > 4:
			pivot.rotation.x = deg_to_rad(float(args[4]))
	for i in 40:
		await process_frame
	var image := root.get_texture().get_image()
	if output_path.ends_with(".jpg"):
		image.save_jpg(output_path, 0.88)
	else:
		image.save_png(output_path)
	print("Кадр сохранён: ", output_path)
	quit()
