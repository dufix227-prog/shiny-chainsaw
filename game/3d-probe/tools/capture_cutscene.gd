extends SceneTree

## Кадры катсцены в заданные секунды (для проверки постановки без просмотра целиком).
## godot --path game/3d-probe -s res://tools/capture_cutscene.gd -- <сцена> <папка> <секунды...>


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	change_scene_to_file(args[0])
	for i in 3:
		await process_frame
	var player: AnimationPlayer = current_scene.get_node("AnimationPlayer")
	for time_text in args.slice(2):
		player.seek(float(time_text), true)
		player.pause()
		for i in 25:
			await process_frame
		var path := "%s/cutscene-%05.1fs.jpg" % [args[1], float(time_text)]
		root.get_texture().get_image().save_jpg(path, 0.88)
		print("Кадр: ", path)
	quit()
