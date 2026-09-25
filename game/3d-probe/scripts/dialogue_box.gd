class_name DialogueBox
extends Control

## К3: диалог-новелла — окно снизу, имя говорящего, портрет-заглушка
## (пиксельная проба кота), варианты ответа канона. Крестовина двигает выбор,
## A/Enter — подтвердить, B/Esc — закрыть (убежать). Время в диалогах идёт:
## окно не ставит симуляцию на паузу, движение кота гасит probe.gd.

signal option_chosen(index: int)
signal closed

const InventoryArt = preload("res://scripts/inventory_art.gd")

var opened := false
var speaker_label := Label.new()
var line_label := Label.new()
var portrait := TextureRect.new()
var options_list := VBoxContainer.new()
var option_buttons: Array[Button] = []
var close_button := Button.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 24
	offset_right = -24
	offset_top = -212
	offset_bottom = -24
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243c35ee")
	style.border_color = Color("a99b73")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	portrait.texture = InventoryArt.cat_texture()
	portrait.custom_minimum_size = Vector2(72, 144)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color("f7dfad"))
	column.add_child(speaker_label)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.add_theme_font_size_override("font_size", 15)
	line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(line_label)
	options_list.add_theme_constant_override("separation", 4)
	column.add_child(options_list)
	close_button.text = "B · Закрыть разговор"
	close_button.custom_minimum_size = Vector2(0, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func(): closed.emit())
	column.add_child(close_button)
	visible = false

func open(speaker: String, line: String, options: Array, show_portrait := true) -> void:
	speaker_label.text = speaker
	line_label.text = line
	portrait.visible = show_portrait
	for child in options_list.get_children():
		child.queue_free()
	option_buttons.clear()
	for i in options.size():
		var option: Dictionary = options[i]
		var button := Button.new()
		button.text = String(option.get("text", "…"))
		button.custom_minimum_size = Vector2(0, 34)
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		button.pressed.connect(func(): _choose(index))
		options_list.add_child(button)
		option_buttons.append(button)
	opened = true
	visible = true
	call_deferred("_focus_first")

func _focus_first() -> void:
	if opened and not option_buttons.is_empty():
		option_buttons[0].grab_focus()

func _process(_delta: float) -> void:
	# Обновления HUD могут сбрасывать фокус; крестовина должна всегда иметь
	# выбор, поэтому возвращаем его на первый вариант, пока окно открыто.
	if opened and is_inside_tree() and get_viewport().gui_get_focus_owner() == null \
			and not option_buttons.is_empty():
		option_buttons[0].grab_focus()

func _choose(index: int) -> void:
	option_chosen.emit(index)

func _unhandled_input(event: InputEvent) -> void:
	if not opened:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		closed.emit()
		get_viewport().set_input_as_handled()
