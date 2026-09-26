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
		var player: Node3D = scene.get_node("CatPlayer")
		player.global_position = _spot(scene, float(args[2]))
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


## Точка на середине тропы через metres метров от начала управления.
func _spot(scene: Node, metres: float) -> Vector3:
	if scene.has_node("World/Builder"):  # стартовое место (улица + тропа)
		var builder = scene.get_node("World/Builder")
		var z: float = builder.SPAWN_Z - metres * builder.WORLD_UNITS_PER_METRE
		var x: float = builder.terrain.trail_center_x(z)
		return Vector3(x, builder.terrain.height(x, z) + 0.1, z)
	var old_builder = scene.get_node("Builder")
	old_builder.setup_noise()
	var old_z := roundi(-metres * old_builder.WORLD_UNITS_PER_METRE)
	var old_x := roundi(old_builder.path_center_x(old_z))
	return Vector3(old_x, old_builder.block_height(old_x, old_z) + 0.1, old_z)
