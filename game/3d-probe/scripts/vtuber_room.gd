class_name VtuberRoom
extends Control

signal chosen(id: String, display_name: String)

const VtuberData = preload("res://scripts/vtuber_data.gd")

var opened := false
var roster := ItemList.new()
var introduction := Label.new()
var choose_button := Button.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("151221f5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-390, -300)
	panel.size = Vector2(780, 600)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title := Label.new()
	title.text = "ПОДВАЛ · ВЫБЕРИ ВИТУБЕРШУ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)
	roster.custom_minimum_size = Vector2(780, 390)
	for entry in VtuberData.ENTRIES:
		roster.add_item(String(entry.name))
	roster.item_selected.connect(_show_entry)
	roster.item_activated.connect(func(_index: int): _choose())
	panel.add_child(roster)
	introduction.custom_minimum_size = Vector2(780, 90)
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	introduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	introduction.add_theme_font_size_override("font_size", 18)
	panel.add_child(introduction)
	choose_button.text = "Выбрать"
	choose_button.pressed.connect(_choose)
	panel.add_child(choose_button)
	visible = false

func begin() -> void:
	opened = true
	visible = true
	roster.select(0)
	_show_entry(0)
	roster.grab_focus()

func _show_entry(index: int) -> void:
	var entry: Dictionary = VtuberData.ENTRIES[index]
	introduction.text = "%s: %s" % [entry.name, entry.intro]
	choose_button.disabled = false

func _choose() -> void:
	var selected := roster.get_selected_items()
	if selected.is_empty():
		return
	var entry: Dictionary = VtuberData.ENTRIES[selected[0]]
	opened = false
	visible = false
	chosen.emit(String(entry.id), String(entry.name))

func reset() -> void:
	opened = false
	visible = false
	roster.deselect_all()
	introduction.text = ""
