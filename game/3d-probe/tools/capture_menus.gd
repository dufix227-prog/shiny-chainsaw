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
	var settings: Node = root.get_node("GameSettings")
	saves.save_dir = "user://capture_saves/"
	settings.settings_path = "user://capture_settings.cfg"
	change_scene_to_file("res://scenes/world/start_area.tscn")
	await _shot(folder, "00-game.jpg")
	saves.start_new_game("Кот")
	saves.save_to_slot(1)
	saves.rename_slot(1, "У старта")
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _shot(folder, "01-main-menu.jpg")
	var menu := current_scene
	menu.get_node("%ContinueButton").pressed.emit()
	await _shot(folder, "02-continue.jpg")
	menu.get_node("%ContinueBackButton").pressed.emit()
	menu.get_node("%NewGameButton").pressed.emit()
	menu.get_node("%NextModel").pressed.emit()
	menu.get_node("%EmotionButton").pressed.emit()
	await _shot(folder, "03-new-game-model.jpg")
	menu.get_node("%NameBackButton").pressed.emit()
	menu.get_node("%SettingsButton").pressed.emit()
	var tabs: TabContainer = menu.get_node("%SettingsMenu").get_node("%Tabs")
	var names := ["04-settings-graphics.jpg", "05-settings-interface.jpg", "06-settings-camera.jpg",
		"07-settings-controls.jpg", "08-settings-sound.jpg"]
	for i in names.size():
		tabs.current_tab = i
		await _shot(folder, names[i])
	# Тот же экран «Интерфейс», но с читаемым шрифтом.
	settings.set_value("ui_font", settings.UiFont.READABLE)
	settings.apply()
	menu.get_node("%SettingsMenu")._refresh()
	tabs.current_tab = 1
	await _shot(folder, "09-readable-font.jpg")
	settings.reset_to_defaults()
	settings.apply()
	menu.get_node("%SettingsMenu").close()
	for slot in range(1, 21):
		saves.delete_slot(slot)
	if FileAccess.file_exists("user://capture_settings.cfg"):
		DirAccess.remove_absolute("user://capture_settings.cfg")
	quit()
