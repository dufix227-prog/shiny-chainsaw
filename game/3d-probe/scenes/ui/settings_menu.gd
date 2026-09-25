extends Control

## Экран настроек — один на всю игру: открывается из главного меню и из паузы.
## Каждый элемент в сцене помечен metadata/setting_key — имя настройки в
## GameSettings. Поэтому новую настройку можно добавить в редакторе: скопировать
## строку, поменять ключ — код трогать не нужно.
## Изменения применяются сразу (видно на экране), сохраняются в файл при «Назад».

signal closed

@onready var tabs: TabContainer = %Tabs
@onready var back_button: Button = %BackButton
@onready var defaults_button: Button = %DefaultsButton

var _controls: Array[Control] = []


func _ready() -> void:
	visible = false
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, tabs.get_tab_control(i).get_meta("tab_title", tabs.get_tab_control(i).name))
	for control in find_children("*", "Control", true, false):
		if control.has_meta("setting_key"):
			_controls.append(control)
			_connect(control)
	back_button.pressed.connect(close)
	defaults_button.pressed.connect(_reset)


func open() -> void:
	_refresh()
	visible = true
	tabs.current_tab = 0
	back_button.grab_focus()


func close() -> void:
	GameSettings.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
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
		_: label.text = "%d" % roundi(slider.value)
