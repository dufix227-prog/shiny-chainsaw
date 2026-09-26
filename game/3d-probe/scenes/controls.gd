extends Node

## Управление: список действий, раскладка по умолчанию и перебинд.
## Автозагрузка Controls. У каждого действия три места: две клавиши
## (клавиатура или мышь) и одна кнопка геймпада (Steam Deck).
## Изменения игрока хранятся в user://controls.cfg; «По умолчанию» их стирает.

signal changed

const SLOT_COUNT := 3
const GAMEPAD_SLOT := 2
const CONTROLS_PATH := "user://controls.cfg"
## Путь можно подменить (тесты пишут в отдельный файл, не трогая раскладку игрока).
var controls_path := CONTROLS_PATH

## [действие, название в настройках, место 1, место 2, геймпад].
## Место — словарь-описание события (см. _make_event), {} — пусто.
const ACTIONS := [
	["move_up", "Вперёд", {"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1.0}],
	["move_down", "Назад", {"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1.0}],
	["move_left", "Влево", {"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1.0}],
	["move_right", "Вправо", {"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1.0}],
	["run", "Бег", {"key": KEY_SHIFT}, {}, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1.0}],
	["jump", "Прыжок", {"key": KEY_SPACE}, {}, {"button": JOY_BUTTON_A}],
	["look_up", "Камера вверх", {}, {}, {"axis": JOY_AXIS_RIGHT_Y, "dir": -1.0}],
	["look_down", "Камера вниз", {}, {}, {"axis": JOY_AXIS_RIGHT_Y, "dir": 1.0}],
	["look_left", "Камера влево", {}, {}, {"axis": JOY_AXIS_RIGHT_X, "dir": -1.0}],
	["look_right", "Камера вправо", {}, {}, {"axis": JOY_AXIS_RIGHT_X, "dir": 1.0}],
	["camera_zoom_in", "Камера ближе", {"mouse": MOUSE_BUTTON_WHEEL_UP}, {"key": KEY_EQUAL}, {"button": JOY_BUTTON_DPAD_UP}],
	["camera_zoom_out", "Камера дальше", {"mouse": MOUSE_BUTTON_WHEEL_DOWN}, {"key": KEY_MINUS}, {"button": JOY_BUTTON_DPAD_DOWN}],
	["camera_mode", "Вид камеры", {"key": KEY_V}, {}, {"button": JOY_BUTTON_BACK}],
	["pause", "Пауза", {"key": KEY_ESCAPE}, {}, {"button": JOY_BUTTON_START}],
]

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_GUIDE: "Steam",
	JOY_BUTTON_DPAD_UP: "Крест. вверх", JOY_BUTTON_DPAD_DOWN: "Крест. вниз",
	JOY_BUTTON_DPAD_LEFT: "Крест. влево", JOY_BUTTON_DPAD_RIGHT: "Крест. вправо",
}
## Названия клавиш по-русски (в пиксельном шрифте нет стрелок-символов).
const KEY_NAMES := {
	KEY_UP: "Стр. вверх", KEY_DOWN: "Стр. вниз", KEY_LEFT: "Стр. влево", KEY_RIGHT: "Стр. вправо",
	KEY_SPACE: "Пробел", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_BACKSPACE: "Backspace", KEY_TAB: "Tab",
	KEY_EQUAL: "=", KEY_MINUS: "-",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "Колесо (нажатие)",
	MOUSE_BUTTON_WHEEL_UP: "Колесо вверх", MOUSE_BUTTON_WHEEL_DOWN: "Колесо вниз",
	MOUSE_BUTTON_XBUTTON1: "Мышь 4", MOUSE_BUTTON_XBUTTON2: "Мышь 5",
}

## Текущая раскладка: действие → [место 1, место 2, геймпад].
var bindings := {}


func _ready() -> void:
	reset_to_defaults()
	load_bindings()
	apply()


func action_label(action: String) -> String:
	for entry in ACTIONS:
		if entry[0] == action:
			return entry[1]
	return action


func reset_to_defaults() -> void:
	bindings.clear()
	for entry in ACTIONS:
		bindings[entry[0]] = [entry[2].duplicate(), entry[3].duplicate(), entry[4].duplicate()]


## Назначить место slot действия action. Если это же событие уже стоит у
## другого действия — там оно снимается (одна кнопка — одно действие).
## Возвращает название действия, у которого кнопку сняли, или "".
func rebind(action: String, slot: int, description: Dictionary) -> String:
	var taken_from := ""
	if not description.is_empty():
		for other in bindings:
			for other_slot in SLOT_COUNT:
				if (other != action or other_slot != slot) and bindings[other][other_slot] == description:
					bindings[other][other_slot] = {}
					taken_from = action_label(other)
	bindings[action][slot] = description
	apply()
	save_bindings()
	return taken_from


## Описание события для перебинда или {} (если это событие не подходит к месту).
func describe(event: InputEvent, slot: int) -> Dictionary:
	if slot == GAMEPAD_SLOT:
		if event is InputEventJoypadButton and event.pressed:
			return {"button": event.button_index}
		if event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
			return {"axis": event.axis, "dir": signf(event.axis_value)}
		return {}
	if event is InputEventKey and event.pressed and not event.echo:
		return {"key": event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode}
	if event is InputEventMouseButton and event.pressed:
		return {"mouse": event.button_index}
	return {}


func describe_text(description: Dictionary) -> String:
	if description.is_empty():
		return "—"
	if description.has("key"):
		return KEY_NAMES.get(description.key, OS.get_keycode_string(description.key))
	if description.has("mouse"):
		return MOUSE_NAMES.get(description.mouse, "Мышь %d" % description.mouse)
	if description.has("button"):
		return BUTTON_NAMES.get(description.button, "Кнопка %d" % description.button)
	var sign_text := "+" if description.dir > 0.0 else "−"
	match int(description.axis):
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
			return "Л. стик " + _axis_arrow(description)
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			return "П. стик " + _axis_arrow(description)
		JOY_AXIS_TRIGGER_LEFT:
			return "L2"
		JOY_AXIS_TRIGGER_RIGHT:
			return "R2"
	return "Ось %d %s" % [description.axis, sign_text]


func _axis_arrow(description: Dictionary) -> String:
	var horizontal: bool = int(description.axis) in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]
	if horizontal:
		return "вправо" if description.dir > 0.0 else "влево"
	return "вниз" if description.dir > 0.0 else "вверх"


## Переписать InputMap по текущей раскладке.
func apply() -> void:
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for description in bindings[action]:
			var event := _make_event(description)
			if event:
				InputMap.action_add_event(action, event)
	changed.emit()


func _make_event(description: Dictionary) -> InputEvent:
	if description.has("key"):
		var key := InputEventKey.new()
		key.physical_keycode = description.key
		return key
	if description.has("mouse"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = description.mouse
		return mouse
	if description.has("button"):
		var button := InputEventJoypadButton.new()
		button.button_index = description.button
		return button
	if description.has("axis"):
		var motion := InputEventJoypadMotion.new()
		motion.axis = description.axis
		motion.axis_value = description.dir
		return motion
	return null


func load_bindings() -> void:
	var file := ConfigFile.new()
	if file.load(controls_path) != OK:
		return
	for action in bindings:
		if file.has_section_key("bindings", action):
			var saved: Array = file.get_value("bindings", action)
			if saved.size() == SLOT_COUNT:
				bindings[action] = saved


func save_bindings() -> void:
	var file := ConfigFile.new()
	for action in bindings:
		file.set_value("bindings", action, bindings[action])
	file.save(controls_path)


func clear_saved() -> void:
	if FileAccess.file_exists(controls_path):
		DirAccess.remove_absolute(controls_path)
