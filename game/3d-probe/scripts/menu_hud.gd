class_name MenuHUD
extends Control

signal start_requested
signal resume_requested
signal settings_requested
signal main_menu_requested
signal quit_requested
signal quality_requested
signal name_confirmed(cat_name: String)

const START := "start"
const PAUSE := "pause"
const SETTINGS := "settings"
const NAME := "name"

var shade := ColorRect.new()
var panel := PanelContainer.new()
var column := VBoxContainer.new()
var title := Label.new()
var subtitle := Label.new()
var actions := VBoxContainer.new()
var name_row := HBoxContainer.new()
var name_field := LineEdit.new()
var name_confirm := Button.new()
var back_target := START
var mode := START
var primary_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.08, 0.07, 0.76)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243c35")
	style.border_color = Color("c5ae7a")
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("d2ddc0"))
	column.add_child(subtitle)
	var separator := HSeparator.new()
	column.add_child(separator)
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	# К2 (С1): игрок называет кота перед первой вылазкой. Имя вводит игрок —
	# текстов сюжета здесь нет. На Steam Deck фокус на LineEdit открывает
	# экранную клавиатуру; это нужно проверить на устройстве.
	name_row.add_theme_constant_override("separation", 10)
	column.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Имя кота:"
	name_row.add_child(name_label)
	name_field.max_length = 16
	name_field.placeholder_text = "Кот"
	name_field.custom_minimum_size = Vector2(220, 44)
	name_field.focus_mode = Control.FOCUS_ALL
	name_row.add_child(name_field)
	name_confirm.text = "Отправиться в лес"
	name_confirm.custom_minimum_size = Vector2(0, 44)
	name_confirm.focus_mode = Control.FOCUS_ALL
	name_confirm.pressed.connect(func(): _confirm_name())
	name_row.add_child(name_confirm)
	name_field.text_submitted.connect(func(_text: String): _confirm_name())
	name_row.visible = false
	show_start()

func is_open() -> bool:
	return visible

func name_entry() -> void:
	mode = NAME
	visible = true
	name_row.visible = true
	name_field.text = ""
	_build("ЛЕСНАЯ ДОРОГА", "Как зовут кота?", [])
	call_deferred("_focus_name_field")

func _focus_name_field() -> void:
	if visible:
		name_field.grab_focus()

func _confirm_name() -> void:
	var value := name_field.text.strip_edges()
	if value.is_empty():
		value = name_field.placeholder_text
	name_row.visible = false
	name_confirmed.emit(value)

func show_start() -> void:
	mode = START
	back_target = START
	visible = true
	name_row.visible = false
	_build("ЛЕСНАЯ ДОРОГА", "Техническая проба маршрута · 500 м", [
		["Начать пробу", func(): start_requested.emit()],
		["Настройки", func(): _open_settings(START)],
		["Выйти из игры", func(): quit_requested.emit()],
	])

func show_pause() -> void:
	mode = PAUSE
	back_target = PAUSE
	visible = true
	_build("ПАУЗА", "Проба остановлена", [
		["Продолжить", func(): resume_requested.emit()],
		["Настройки", func(): _open_settings(PAUSE)],
		["Выйти в главное меню", func(): main_menu_requested.emit()],
		["Выйти из игры", func(): quit_requested.emit()],
	])

func _open_settings(return_to: String) -> void:
	mode = SETTINGS
	back_target = return_to
	visible = true
	_build("НАСТРОЙКИ", "Фиксированная раскладка Steam Deck для этой пробы", [
		["Качество 3D: изменить", func(): quality_requested.emit()],
		["A · действие / подтвердить    B · назад / закрыть", Callable()],
		["X · инвентарь    Y · нужды    L1 · отдых", Callable()],
		["R1 · качество    View · камера    Menu · пауза", Callable()],
		["R3 · новая попытка    Стик / крестовина · ходьба", Callable()],
		["Назад", _back],
	])

func _back() -> void:
	if back_target == PAUSE:
		show_pause()
	else:
		show_start()

func close() -> void:
	visible = false
	get_viewport().gui_release_focus()

func _build(next_title: String, next_subtitle: String, entries: Array) -> void:
	title.text = next_title
	subtitle.text = next_subtitle
	for child in actions.get_children():
		child.queue_free()
	primary_button = null
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 48
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_ALL
		var callback: Callable = entry[1]
		if callback.is_valid():
			button.pressed.connect(callback)
		else:
			button.disabled = true
		actions.add_child(button)
		if primary_button == null and not button.disabled:
			primary_button = button
	call_deferred("_focus_primary")

func _focus_primary() -> void:
	if is_instance_valid(primary_button) and visible:
		primary_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if mode == SETTINGS or mode == NAME:
			_back()
		elif mode == PAUSE:
			resume_requested.emit()
		get_viewport().set_input_as_handled()
