extends SceneTree

## Проверки настроек, сохранений, паузы и главного меню.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/menus_and_saves.gd
## Пишет в отдельные user://test_*, настройки и снимки игрока не трогает.

const TEST_SAVE_DIR := "user://test_saves/"
const TEST_SETTINGS := "user://test_settings.cfg"
const TEST_CONTROLS := "user://test_controls.cfg"
const GAME_SCENE := "res://scenes/world/start_area.tscn"

var checks := 0
var failures := 0
var settings: Node
var saves: Node
var controls: Node


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
	controls = root.get_node("Controls")
	settings.settings_path = TEST_SETTINGS
	saves.save_dir = TEST_SAVE_DIR
	controls.controls_path = TEST_CONTROLS
	_clear_test_files()
	_check_settings_menu_keys()
	_check_settings_round_trip()
	_check_fonts_and_sound()
	_check_rebind()
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
	controls.clear_saved()


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
	check(keys.size() >= 30, "на экране настроек не меньше 30 настроек (%d)" % keys.size())
	var rebind_buttons := 0
	for control in menu.find_children("*", "Button", true, false):
		if control.has_meta("rebind_action"):
			rebind_buttons += 1
			check(controls.bindings.has(control.get_meta("rebind_action")), "перебинд: действие %s существует" % control.get_meta("rebind_action"))
	check(rebind_buttons == controls.ACTIONS.size() * controls.SLOT_COUNT, "перебинд: у каждого действия три места (%d)" % rebind_buttons)
	menu.free()


func _check_fonts_and_sound() -> void:
	var theme: Theme = load(settings.UI_THEME)
	settings.set_value("ui_font", settings.UiFont.READABLE)
	settings.set_value("ui_scale", 1.25)
	settings.set_value("music_volume", 0.5)
	settings.apply()
	check(theme.default_font.resource_path.contains("PT_Sans"), "шрифт «обычный» меняет текст на читаемый")
	check(theme.get_font("font", "TitleLabel").resource_path.contains("PT_Sans"), "и заголовки тоже")
	check(is_equal_approx(root.content_scale_factor, 1.25), "размер интерфейса меняется")
	for bus in ["Music", "Effects", "Ambient", "Interface", "Voice"]:
		check(AudioServer.get_bus_index(bus) > 0, "есть аудиошина %s" % bus)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.5),
		"громкость музыки применяется к шине")
	settings.reset_to_defaults()
	settings.apply()
	check(theme.default_font.resource_path.contains("Tiny5"), "по умолчанию — пиксельный шрифт")


func _check_rebind() -> void:
	controls.reset_to_defaults()
	controls.apply()
	var key_i := InputEventKey.new()
	key_i.physical_keycode = KEY_I
	key_i.pressed = true
	var description: Dictionary = controls.describe(key_i, 0)
	check(controls.describe(key_i, controls.GAMEPAD_SLOT).is_empty(), "клавиатуру нельзя поставить в место геймпада")
	controls.rebind("move_up", 0, description)
	check(InputMap.action_has_event("move_up", key_i), "перебинд: «Вперёд» на I")
	var taken: String = controls.rebind("jump", 1, description)
	check(taken == "Вперёд" and controls.bindings.move_up[0].is_empty(), "та же клавиша снимается с другого действия")
	var pad_button := InputEventJoypadButton.new()
	pad_button.button_index = JOY_BUTTON_Y
	pad_button.pressed = true
	controls.rebind("camera_mode", controls.GAMEPAD_SLOT, controls.describe(pad_button, controls.GAMEPAD_SLOT))
	check(controls.describe_text(controls.bindings.camera_mode[2]) == "Y", "название кнопки геймпада")
	controls.reset_to_defaults()
	controls.load_bindings()
	check(controls.bindings.jump[1] == description, "раскладка сохраняется в файл")
	controls.reset_to_defaults()
	controls.apply()
	controls.clear_saved()
	check(controls.describe_text(controls.bindings.camera_zoom_in[0]) == "Колесо вверх", "приближение — колесо мыши")


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
	menu.get_node("%NextModel").pressed.emit()
	menu.get_node("%NextModel").pressed.emit()
	check(menu.get_node("%CatPreview").model.variant_id == "c", "стрелки меняют модель в превью")
	menu.get_node("%EmotionButton").pressed.emit()
	check(menu.get_node("%CatPreview").model.emotion == "joy", "кнопка мимики меняет эмоцию в превью")
	menu.get_node("%StartButton").pressed.emit()
	await frames(3)
	check(current_scene.scene_file_path == "res://scenes/cutscene/intro.tscn", "после имени начинается катсцена")
	check(saves.hero_name == "Кот", "пустое имя — техническое имя по умолчанию")
	check(saves.cat_variant == "c", "выбранная модель уходит в игру")


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
	check(data.cat_variant == "a" and data.has("flags"), "в снимке есть модель кота и флаги")
	check(not saves.has_unsaved_progress, "после записи нет несохранённого прогресса")
	check(saves.latest_slot() == 3, "последний снимок находится")
	saves.cat_variant = "c"
	saves.set_flag("barrier_reaction_seen")
	saves.save_to_slot(3)
	saves.cat_variant = "a"
	saves.flags = {}
	saves.rename_slot(3, "У таблички")
	check(saves.read_slot(3).title == "У таблички", "снимок переименовывается")

	player.global_position = Vector3(0, 1, 0)
	check(saves.load_slot(3), "снимок загружается")
	await frames(4)
	var loaded: Node3D = current_scene.get_node("CatPlayer")
	check(loaded.global_position.distance_to(spot) < 0.3, "после загрузки кот там же (%s)" % loaded.global_position)
	# За кадры после загрузки выносливость успевает чуть восстановиться.
	check(absf(loaded.stamina - 42.0) < 1.5, "выносливость восстановлена (%.1f)" % loaded.stamina)
	check(saves.cat_variant == "c" and loaded.model.variant_id == "c", "после загрузки та же модель кота")
	check(saves.has_flag("barrier_reaction_seen"), "флаги событий восстанавливаются")
	# «Продолжить» в меню: одна кнопка → последний снимок или выбор другого.
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await frames(3)
	var menu := current_scene
	check(not menu.has_node("%LoadButton"), "отдельной кнопки «Загрузить» больше нет")
	check(not menu.get_node("%ContinueButton").disabled, "со снимками «Продолжить» активна")
	menu.get_node("%ContinueButton").pressed.emit()
	check(menu.get_node("%ContinuePanel").visible, "«Продолжить» открывает выбор")
	check(menu.get_node("%LatestButton").text.contains("У таблички"), "в выборе — последний снимок с именем")
	menu.get_node("%OtherSavesButton").pressed.emit()
	check(menu.get_node("%SaveMenu").visible, "«Выбрать другое» открывает список снимков")
	menu.get_node("%SaveMenu").close()
	change_scene_to_file(GAME_SCENE)
	await frames(3)

	# Старый снимок без поля версии читается (перевод формата).
	var file := FileAccess.open(saves.slot_path(4), FileAccess.WRITE)
	var old := data.duplicate()
	old.erase("version")
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated: Dictionary = saves.read_slot(4)
	check(migrated.version == saves.FORMAT_VERSION, "снимок без версии переводится в текущий формат")
	check(migrated.cat_variant == "a" and migrated.flags.is_empty(), "старый снимок получает модель и флаги по умолчанию")
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
