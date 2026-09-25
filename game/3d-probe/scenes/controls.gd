extends Node

## Раскладка управления: клавиатура + мышь и геймпад (Steam Deck).
## Подключена как автозагрузка Controls. Действия регистрируются кодом,
## чтобы вся раскладка читалась одним списком.


func _ready() -> void:
	add_keys("move_up", [KEY_W, KEY_UP])
	add_keys("move_down", [KEY_S, KEY_DOWN])
	add_keys("move_left", [KEY_A, KEY_LEFT])
	add_keys("move_right", [KEY_D, KEY_RIGHT])
	add_keys("run", [KEY_SHIFT])
	add_keys("jump", [KEY_SPACE])
	add_keys("pause", [KEY_ESCAPE])

	add_stick("move_up", JOY_AXIS_LEFT_Y, -1.0)
	add_stick("move_down", JOY_AXIS_LEFT_Y, 1.0)
	add_stick("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_stick("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_stick("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	add_stick("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	add_stick("look_left", JOY_AXIS_RIGHT_X, -1.0)
	add_stick("look_right", JOY_AXIS_RIGHT_X, 1.0)
	add_stick("run", JOY_AXIS_TRIGGER_LEFT, 1.0)
	add_button("jump", JOY_BUTTON_A)
	add_button("pause", JOY_BUTTON_START)


func add_keys(action: String, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func add_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func add_stick(action: String, axis: JoyAxis, direction: float) -> void:
	_ensure_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
