class_name ProbeInput
extends RefCounted

const LEFT_STICK_X := 0
const LEFT_STICK_Y := 1
const BUTTON_A := 0
const BUTTON_B := 1
const BUTTON_X := 2
const BUTTON_Y := 3
const BUTTON_BACK := 4
const BUTTON_START := 6
const BUTTON_LEFT_STICK := 7
const BUTTON_RIGHT_STICK := 8
const BUTTON_LEFT_SHOULDER := 9
const BUTTON_RIGHT_SHOULDER := 10
const RIGHT_TRIGGER := 5
const DPAD_UP := 11
const DPAD_DOWN := 12
const DPAD_LEFT := 13
const DPAD_RIGHT := 14

static func install() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("camera", [KEY_C])
	_add_keys("reset", [KEY_R])
	_add_keys("quality", [KEY_Q])
	_add_keys("route_forward", [KEY_F])
	_add_keys("needs", [KEY_N])
	_add_keys("eat", [KEY_E])
	_add_keys("interact", [KEY_E])
	_add_keys("rest", [KEY_SPACE])
	_add_keys("pause_probe", [KEY_P])
	_add_keys("inventory", [KEY_B])
	_add_keys("inventory_close", [KEY_ESCAPE])
	_add_keys("inventory_use", [KEY_ENTER, KEY_KP_ENTER])
	_add_keys("inventory_context", [KEY_V])
	_add_keys("full_map", [KEY_M])
	_add_keys("run", [KEY_SHIFT])
	_add_keys("jump", [KEY_J])
	_add_mouse("attack", MOUSE_BUTTON_LEFT)
	_add_mouse("block", MOUSE_BUTTON_RIGHT)
	_add_button("attack", BUTTON_RIGHT_SHOULDER)
	_add_button("block", BUTTON_LEFT_SHOULDER)
	_add_button("interact", BUTTON_A)
	_add_button("jump", BUTTON_A)
	# A inside the inventory activates the focused control through ui_accept;
	# binding it also to inventory_use made one press both select and eat.
	_add_button("inventory_context", BUTTON_Y)
	_add_motion("run", RIGHT_TRIGGER, 1.0)
	_add_button("inventory_close", BUTTON_B)
	_add_button("inventory", BUTTON_X)
	_add_button("needs", BUTTON_Y)
	_add_button("rest", BUTTON_LEFT_SHOULDER)
	_add_button("quality", BUTTON_RIGHT_SHOULDER)
	_add_button("camera", BUTTON_BACK)
	_add_button("full_map", BUTTON_LEFT_STICK)
	_add_button("pause_probe", BUTTON_START)
	_add_button("reset", BUTTON_RIGHT_STICK)
	_add_motion("move_left", LEFT_STICK_X, -1.0)
	_add_motion("move_right", LEFT_STICK_X, 1.0)
	_add_motion("move_up", LEFT_STICK_Y, -1.0)
	_add_motion("move_down", LEFT_STICK_Y, 1.0)
	_add_button("move_up", DPAD_UP)
	_add_button("move_down", DPAD_DOWN)
	_add_button("move_left", DPAD_LEFT)
	_add_button("move_right", DPAD_RIGHT)
	_add_button("ui_accept", BUTTON_A)
	_add_button("ui_cancel", BUTTON_B)
	_add_button("ui_up", DPAD_UP)
	_add_button("ui_down", DPAD_DOWN)
	_add_button("ui_left", DPAD_LEFT)
	_add_button("ui_right", DPAD_RIGHT)

## Отдельная раскладка витрины пачки (probes/pack_viewer.tscn). Автор смотрит
## её на Steam Deck, где нет клавиатуры, поэтому всё нужное лежит на геймпаде:
## левый стик и крестовина — облёт/зум, A и L1 — следующий/предыдущий объект,
## B — вся пачка, X — автоповорот, Y — ортография, R1 — сброс, Menu — выход.
## Клавиши продублированы для запуска за столом.
static func install_viewer() -> void:
	_add_keys("viewer_orbit_left", [KEY_LEFT])
	_add_keys("viewer_orbit_right", [KEY_RIGHT])
	_add_keys("viewer_zoom_in", [KEY_UP])
	_add_keys("viewer_zoom_out", [KEY_DOWN])
	_add_motion("viewer_orbit_left", LEFT_STICK_X, -1.0)
	_add_motion("viewer_orbit_right", LEFT_STICK_X, 1.0)
	_add_motion("viewer_zoom_in", LEFT_STICK_Y, -1.0)
	_add_motion("viewer_zoom_out", LEFT_STICK_Y, 1.0)
	_add_button("viewer_orbit_left", DPAD_LEFT)
	_add_button("viewer_orbit_right", DPAD_RIGHT)
	_add_button("viewer_zoom_in", DPAD_UP)
	_add_button("viewer_zoom_out", DPAD_DOWN)

	_add_keys("viewer_next", [KEY_E])
	_add_button("viewer_next", BUTTON_A)
	_add_button("viewer_next", BUTTON_RIGHT_SHOULDER)
	_add_keys("viewer_prev", [KEY_Q])
	_add_button("viewer_prev", BUTTON_LEFT_SHOULDER)

	_add_keys("viewer_all", [KEY_0])
	_add_button("viewer_all", BUTTON_B)
	_add_keys("viewer_spin", [KEY_SPACE])
	_add_button("viewer_spin", BUTTON_X)
	_add_keys("viewer_ortho", [KEY_C])
	_add_button("viewer_ortho", BUTTON_Y)
	_add_keys("viewer_reset", [KEY_R])
	_add_button("viewer_reset", BUTTON_RIGHT_STICK)
	_add_keys("viewer_quit", [KEY_ESCAPE])
	_add_button("viewer_quit", BUTTON_START)

static func _add_keys(action: StringName, keys: Array) -> void:
	_ensure(action)
	for code: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = code
		_add_unique(action, event)

static func _add_button(action: StringName, button: int) -> void:
	_ensure(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_unique(action, event)

static func _add_motion(action: StringName, axis: int, axis_value: float) -> void:
	_ensure(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_unique(action, event)

static func _add_mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_unique(action, event)

static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

static func _add_unique(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == event.as_text():
			return
	InputMap.action_add_event(action, event)
