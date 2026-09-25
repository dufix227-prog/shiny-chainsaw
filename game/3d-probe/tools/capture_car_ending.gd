extends SceneTree

## Кадры концовки С9-машина: кот выходит на дорогу, машина сбивает, полёт,
## отдаление камеры, «Конец», титры.
## godot --fixed-fps 60 --path game/3d-probe -s res://tools/capture_car_ending.gd -- <папка>
## --fixed-fps 60 обязателен: иначе при медленной отрисовке анимация пролетает за кадр.


func _initialize() -> void:
	_capture.call_deferred()


func _shot(folder: String, file_name: String) -> void:
	root.get_texture().get_image().save_jpg(folder + "/" + file_name, 0.88)
	print("Кадр: ", file_name)


func _capture() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/start_area.tscn")
	for i in 3:
		await process_frame
	var scene := current_scene
	scene.get_node("CarEnding").quit_on_finish = false
	var player: CharacterBody3D = scene.get_node("CatPlayer")
	# Кот стоит на ближней полосе, камера смотрит вдоль дороги на встречную машину.
	# Кот выходит с тротуара на дорогу; камера смотрит вдоль улицы на встречный поток.
	player.global_position = Vector3(-30.0, 0.35, -6.0)
	player.get_node("CameraPivot").rotation = Vector3(-0.3, deg_to_rad(-70.0), 0)
	for i in 20:
		await process_frame
	player.global_position = Vector3(-30.0, 0.1, -2.5)
	var times := {0.05: "01-on-road.jpg", 1.6: "02-flight.jpg", 3.6: "03-pull-back.jpg", 6.2: "04-the-end.jpg", 11.0: "05-credits.jpg"}
	var ending: Node = scene.get_node("CarEnding")
	var hit_time := -1.0
	var elapsed := 0.0
	var pending := times.keys()
	pending.sort()
	while elapsed < 40.0 and not pending.is_empty():
		await process_frame
		elapsed += 1.0 / 60.0
		if hit_time < 0.0 and ending.running:
			hit_time = elapsed
		if hit_time >= 0.0 and elapsed - hit_time >= pending[0]:
			_shot(folder, times[pending[0]])
			pending.pop_front()
	print("Машина сбила через %.1f с" % hit_time)
	quit()
