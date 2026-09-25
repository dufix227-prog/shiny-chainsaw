extends SceneTree

## Кадры интерфейса: главное меню, ввод имени, настройки, пауза, снимки.
## godot --path game/3d-probe -s res://tools/capture_menus.gd -- <папка>
## Снимки пишутся в отдельную папку user://capture_saves/, игровые не трогаются.


func _initialize() -> void:
	_capture.call_deferred()


func _shot(folder: String, file_name: String) -> void:
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_jpg(folder + "/" + file_name, 0.88)
	print("Кадр: ", file_name)


func _capture() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var saves: Node = root.get_node("SaveGame")
	saves.save_dir = "user://capture_saves/"
	change_scene_to_file("res://scenes/style_probe/style_probe.tscn")
	await _shot(folder, "00-game.jpg")
	saves.start_new_game("Кот")
	saves.save_to_slot(1)
	saves.rename_slot(1, "У старта")
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _shot(folder, "01-main-menu.jpg")
	var menu := current_scene
	menu.get_node("%NewGameButton").pressed.emit()
	await _shot(folder, "02-name.jpg")
	menu.get_node("%NameBackButton").pressed.emit()
	menu.get_node("%SettingsButton").pressed.emit()
	await _shot(folder, "03-settings-graphics.jpg")
	menu.get_node("%SettingsMenu").close()
	change_scene_to_file("res://scenes/style_probe/style_probe.tscn")
	await _shot(folder, "04-game.jpg")
	var pause: Node = current_scene.get_node("PauseMenu")
	pause.open()
	await _shot(folder, "05-pause.jpg")
	pause.get_node("%SaveButton").pressed.emit()
	await _shot(folder, "06-saves.jpg")
	for slot in range(1, 21):
		saves.delete_slot(slot)
	quit()
