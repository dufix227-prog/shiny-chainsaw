class_name EndingScreen
extends Control

signal quit_requested

const CREDITS_DURATION := 4.0

var opened := false
var showing_credits := false
var credits_elapsed := 0.0
var title_label: Label
var detail_label: Label
var continue_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("11131c")
	add_child(backdrop)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-300, -120)
	center.size = Vector2(600, 240)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	add_child(center)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	center.add_child(title_label)
	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 20)
	center.add_child(detail_label)
	continue_button = Button.new()
	continue_button.text = "Титры"
	continue_button.custom_minimum_size = Vector2(220, 48)
	continue_button.pressed.connect(show_credits)
	center.add_child(continue_button)

func begin_moderator() -> void:
	opened = true
	showing_credits = false
	credits_elapsed = 0.0
	visible = true
	title_label.text = "КОНЕЦ ПРОЛОГА"
	detail_label.text = "Остался модерировать витуберш"
	continue_button.text = "Титры"
	continue_button.visible = true
	continue_button.grab_focus()

func show_credits() -> void:
	if not opened:
		return
	showing_credits = true
	credits_elapsed = 0.0
	title_label.text = "10 000 МЕТРОВ"
	detail_label.text = "Пролог\n\nСпасибо за игру"
	continue_button.visible = false

func _process(delta: float) -> void:
	if not showing_credits:
		return
	credits_elapsed += delta
	if credits_elapsed >= CREDITS_DURATION:
		showing_credits = false
		quit_requested.emit()

func reset() -> void:
	opened = false
	showing_credits = false
	credits_elapsed = 0.0
	visible = false
