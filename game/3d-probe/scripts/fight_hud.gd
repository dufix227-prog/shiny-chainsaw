class_name FightHUD
extends Control

var encounters: RoadEncounters
var panel: PanelContainer
var title: Label
var health: Label
var tell: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-350, 24)
	size = Vector2(326, 142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	title = _label(box, "ДРАКА", 20)
	health = _label(box, "", 17)
	tell = _label(box, "", 16)
	visible = false

func setup(value: RoadEncounters) -> void:
	encounters = value

func _process(_delta: float) -> void:
	if not is_instance_valid(encounters):
		visible = false
		return
	visible = encounters.fight.active or encounters.message_seconds > 0.0
	if not visible:
		return
	if encounters.fight.active and is_instance_valid(encounters.active_enemy):
		title.text = encounters.active_enemy.display_name
		health.text = "Кот: %d / 10   Противник: %d / %d" % [encounters.fight.player_hp,
			encounters.fight.enemy_hp, encounters.fight.enemy_max_hp]
		if encounters.fight.enemy_attacking:
			tell.text = "ЗАМАХ · %.1f с · держи ПКМ / L1" % maxf(0.0, encounters.fight.telegraph_time)
		elif encounters.fight.enemy_slow_seconds > 0.0:
			tell.text = "Враг замедлен · %.1f с" % encounters.fight.enemy_slow_seconds
		else:
			tell.text = "ЛКМ/R1 — палка · ПКМ/L1 — блок\nДвойное направление — уворот"
	else:
		title.text = encounters.last_message
		health.text = ""
		tell.text = ""

func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
