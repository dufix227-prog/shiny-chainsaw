extends Control

## Экран настроек — один на всю игру: открывается из главного меню и из паузы.
## Каждый элемент в сцене помечен metadata/setting_key — имя настройки в
## GameSettings. Поэтому новую настройку можно добавить в редакторе: скопировать
## строку, поменять ключ — код трогать не нужно.
## Изменения применяются сразу (видно на экране), сохраняются в файл при «Назад».
## Кнопки перебинда помечены metadata/rebind_action и rebind_slot (Controls):
## нажать — затем нужную клавишу/кнопку; Backspace очищает место, Esc — отмена.

signal closed

@onready var tabs: TabContainer = %Tabs
@onready var back_button: Button = %BackButton
@onready var defaults_button: Button = %DefaultsButton

var _controls: Array[Control] = []
var _rebind_buttons: Array[Button] = []
## Кнопка перебинда, которая сейчас ждёт нажатия, или null.
var _waiting: Button

@onready var rebind_message: Label = %RebindMessage
@onready var reset_controls: Button = %ResetControls


func _ready() -> void:
	visible = false
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, tabs.get_tab_control(i).get_meta("tab_title", tabs.get_tab_control(i).name))
	for control in find_children("*", "Control", true, false):
		if control.has_meta("setting_key"):
			_controls.append(control)
			_connect(control)
		elif control.has_meta("rebind_action"):
			_rebind_buttons.append(control)
			control.pressed.connect(_start_rebind.bind(control))
	reset_controls.pressed.connect(func():
		Controls.reset_to_defaults()
		Controls.apply()
		Controls.clear_saved()
		rebind_message.text = "Кнопки сброшены."
		_refresh_rebind())
	back_button.pressed.connect(close)
	defaults_button.pressed.connect(_reset)


func open() -> void:
	_refresh()
	_refresh_rebind()
	rebind_message.text = ""
	visible = true
	tabs.current_tab = 0
	back_button.grab_focus()


func close() -> void:
	_waiting = null
	GameSettings.save_settings()
	visible = false
	closed.emit()


## Перебинд ловит нажатие раньше интерфейса (_input), чтобы клавиша не
## нажала заодно кнопку меню.
func _input(event: InputEvent) -> void:
	if _waiting == null or not visible:
		return
	var slot: int = _waiting.get_meta("rebind_slot")
	var action: String = _waiting.get_meta("rebind_action")
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and slot != Controls.GAMEPAD_SLOT:
		_finish_rebind("Отменено.")
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_BACKSPACE:
		Controls.rebind(action, slot, {})
		_finish_rebind("Место очищено.")
	else:
		var description := Controls.describe(event, slot)
		if description.is_empty():
			return
		var taken_from := Controls.rebind(action, slot, description)
		_finish_rebind("Снято с «%s»." % taken_from if taken_from else "")
	get_viewport().set_input_as_handled()


func _start_rebind(button: Button) -> void:
	_waiting = button
	button.text = "нажмите…"
	var pad: bool = button.get_meta("rebind_slot") == Controls.GAMEPAD_SLOT
	rebind_message.text = "Нажмите кнопку геймпада или наклоните стик." if pad else "Нажмите клавишу или кнопку мыши."


func _finish_rebind(message: String) -> void:
	_waiting = null
	rebind_message.text = message
	_refresh_rebind()


func _refresh_rebind() -> void:
	for button in _rebind_buttons:
		var description: Dictionary = Controls.bindings[button.get_meta("rebind_action")][button.get_meta("rebind_slot")]
		button.text = Controls.describe_text(description)


func _unhandled_input(event: InputEvent) -> void:
	if _waiting != null:
		return
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _reset() -> void:
	GameSettings.reset_to_defaults()
	GameSettings.apply()
	_refresh()


func _connect(control: Control) -> void:
	var key: String = control.get_meta("setting_key")
	if control is CheckBox:
		control.toggled.connect(func(on: bool): _changed(key, on))
	elif control is OptionButton:
		control.item_selected.connect(func(index: int): _changed(key, control.get_meta("option_values")[index]))
	elif control is HSlider:
		control.value_changed.connect(func(value: float):
			_show_value(control)
			_changed(key, int(value) if typeof(GameSettings.DEFAULTS[key]) == TYPE_INT else value))


func _changed(key: String, value: Variant) -> void:
	if GameSettings.get_value(key) == value:
		return
	GameSettings.set_value(key, value)
	GameSettings.apply()


## Показать в элементах текущие значения, не вызывая их сигналы.
func _refresh() -> void:
	for control in _controls:
		var value: Variant = GameSettings.get_value(control.get_meta("setting_key"))
		if control is CheckBox:
			control.set_pressed_no_signal(value)
		elif control is OptionButton:
			var index: int = control.get_meta("option_values").find(value)
			control.select(maxi(index, 0))
		elif control is HSlider:
			control.set_value_no_signal(value)
			_show_value(control)


func _show_value(slider: HSlider) -> void:
	var label: Label = slider.get_parent().get_node_or_null("Value")
	if label == null:
		return
	match slider.get_meta("value_format", "number"):
		"percent": label.text = "%d%%" % roundi(slider.value * 100.0)
		"degrees": label.text = "%d°" % roundi(slider.value)
		"number1": label.text = "%.1f" % slider.value
		_: label.text = "%d" % roundi(slider.value)
