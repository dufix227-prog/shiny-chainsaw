extends SceneTree

## Проверки настроек, сохранений, паузы и главного меню.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/menus_and_saves.gd
## Пишет в отдельные user://test_*, настройки и снимки игрока не трогает.

const TEST_SAVE_DIR := "user://test_saves/"
const TEST_SETTINGS := "user://test_settings.cfg"
const GAME_SCENE := "res://scenes/style_probe/style_probe.tscn"

var checks := 0
var failures := 0
var settings: Node
var saves: Node


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("НЕ ПРОШЛО: ", message)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	settings = root.get_node("GameSettings")
	saves = root.get_node("SaveGame")
	settings.settings_path = TEST_SETTINGS
	saves.save_dir = TEST_SAVE_DIR
	_clear_test_files()
	_check_settings_menu_keys()
	_check_settings_round_trip()
	await _check_main_menu()
	await _check_save_and_load()
	await _check_pause_menu()
	_clear_test_files()
	print("Меню и сохранения: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)


func _clear_test_files() -> void:
	for slot in range(1, saves.SLOT_COUNT + 1):
		saves.delete_slot(slot)
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)


## Каждый элемент экрана настроек указывает на существующую настройку.
func _check_settings_menu_keys() -> void:
	var menu: Node = load("res://scenes/ui/settings_menu.tscn").instantiate()
	var keys := {}
	for control in menu.find_children("*", "Control", true, false):
		if not control.has_meta("setting_key"):
			continue
		var key: String = control.get_meta("setting_key")
		keys[key] = true
		check(settings.DEFAULTS.has(key), "настройка «%s» из экрана существует" % key)
		if control is OptionButton:
			var values: Array = control.get_meta("option_values")
			check(values.size() == control.item_count, "у «%s» на каждый пункт своё значение" % key)
			check(values.has(settings.DEFAULTS[key]), "значение по умолчанию «%s» есть в списке" % key)
	for key in settings.DEFAULTS:
		check(keys.has(key), "настройку «%s» можно изменить на экране" % key)
	check(keys.size() >= 14, "на экране настроек не меньше 14 настроек (%d)" % keys.size())
	menu.free()


func _check_settings_round_trip() -> void:
	settings.reset_to_defaults()
	settings.set_value("shadow_quality", settings.Quality.LOW)
	settings.set_value("field_of_view", 85.0)
	settings.set_value("fog", false)
	settings.set_value("pixel_size", 3)
	settings.save_settings()
	settings.reset_to_defaults()
	settings.load_settings()
	check(settings.get_value("shadow_quality") == settings.Quality.LOW, "тени сохраняются")
	check(is_equal_approx(settings.get_value("field_of_view"), 85.0), "угол обзора сохраняется")
	check(settings.get_value("fog") == false, "туман сохраняется")
	check(settings.get_value("pixel_size") == 3, "пиксельность сохраняется")
	settings.reset_to_defaults()


func _check_main_menu() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await frames(3)
	var menu := current_scene
	check(menu.get_node("%ContinueButton").disabled, "без снимков «Продолжить» неактивна")
	menu.get_node("%SettingsButton").pressed.emit()
	check(menu.get_node("%SettingsMenu").visible, "из меню открываются настройки")
	menu.get_node("%SettingsMenu").close()
	check(menu.get_node("%MainButtons").visible, "после настроек возвращается меню")
	menu.get_node("%NewGameButton").pressed.emit()
	check(menu.get_node("%NamePanel").visible, "«Новая игра» спрашивает имя")
	menu.get_node("%StartButton").pressed.emit()
	await frames(3)
	check(current_scene.scene_file_path == "res://scenes/cutscene/intro.tscn", "после имени начинается катсцена")
	check(saves.hero_name == "Кот", "пустое имя — техническое имя по умолчанию")


func _check_save_and_load() -> void:
	change_scene_to_file(GAME_SCENE)
	await frames(3)
	saves.start_new_game("Тест")
	var player: Node3D = current_scene.get_node("CatPlayer")
	var spot := Vector3(-1.0, 0.6, -20.0)
	player.global_position = spot
	player.stamina = 42.0
	check(saves.save_to_slot(3), "снимок записывается")
	var data: Dictionary = saves.read_slot(3)
	check(data.version == saves.FORMAT_VERSION, "в снимке есть версия формата")
	check(data.title == "Сохранение 3", "имя снимка по умолчанию")
	check(data.hero_name == "Тест", "в снимке есть имя героя")
	check(not saves.has_unsaved_progress, "после записи нет несохранённого прогресса")
	check(saves.latest_slot() == 3, "последний снимок находится")
	saves.rename_slot(3, "У таблички")
	check(saves.read_slot(3).title == "У таблички", "снимок переименовывается")

	player.global_position = Vector3(0, 1, 0)
	check(saves.load_slot(3), "снимок загружается")
	await frames(4)
	var loaded: Node3D = current_scene.get_node("CatPlayer")
	check(loaded.global_position.distance_to(spot) < 0.3, "после загрузки кот там же (%s)" % loaded.global_position)
	# За кадры после загрузки выносливость успевает чуть восстановиться.
	check(absf(loaded.stamina - 42.0) < 1.5, "выносливость восстановлена (%.1f)" % loaded.stamina)

	# Старый снимок без поля версии читается (перевод формата).
	var file := FileAccess.open(saves.slot_path(4), FileAccess.WRITE)
	var old := data.duplicate()
	old.erase("version")
	file.store_string(JSON.stringify(old))
	file.close()
	check(saves.read_slot(4).version == saves.FORMAT_VERSION, "снимок без версии переводится в текущий формат")
	saves.delete_slot(4)
	check(not saves.has_slot(4), "снимок удаляется")


func _check_pause_menu() -> void:
	var pause: Node = current_scene.get_node("PauseMenu")
	pause.open()
	check(paused, "пауза останавливает игру")
	pause.get_node("%SettingsButton").pressed.emit()
	check(pause.get_node("SettingsMenu").visible, "из паузы открываются настройки")
	pause.get_node("SettingsMenu").close()
	pause.get_node("%SaveButton").pressed.emit()
	var save_menu: Node = pause.get_node("SaveMenu")
	check(save_menu.visible and save_menu.get_node("%List").get_child_count() == 20, "из паузы открываются 20 слотов")
	save_menu.close()
	saves.has_unsaved_progress = true
	pause.get_node("%MainMenuButton").pressed.emit()
	check(pause.get_node("UnsavedDialog").visible, "при выходе без сохранения — напоминание")
	pause.get_node("UnsavedDialog").get_node("%CancelButton").pressed.emit()
	pause.close()
	check(not paused, "пауза снимается")
