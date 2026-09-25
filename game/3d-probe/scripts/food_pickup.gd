extends Node3D

const Art = preload("res://scripts/geometry.gd")
const Icons = preload("res://scripts/inventory_art.gd")
const Inventory = preload("res://scripts/food_inventory.gd")
const LOCATION := Vector3(0.9, 0, 3.6)
const REACH := 1.6

var enabled := false
var collected := false

func _ready() -> void:
	position = LOCATION
	var paper := Art.material(Color("f2ede2"))
	# Та же пиксельная проба еды, что и в окне инвентаря, на бумаге пакета.
	paper.albedo_texture = Icons.food_texture()
	paper.uv1_triplanar = true
	paper.uv1_scale = Vector3.ONE * 0.7
	var band := Art.material(Color("537b4b"))
	Art.box(self, Vector3(0, 0.22, 0), Vector3(0.58, 0.42, 0.42), paper)
	Art.box(self, Vector3(0, 0.24, 0), Vector3(0.16, 0.46, 0.45), band)
	var label := Label3D.new()
	label.text = "ЕДА"
	label.position.y = 0.9
	label.font_size = 44
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = enabled and not collected

func can_collect(player_position: Vector3) -> bool:
	return enabled and not collected and global_position.distance_to(player_position) <= REACH

func collect(player_position: Vector3, inventory: Inventory) -> bool:
	if not can_collect(player_position):
		return false
	collected = true
	visible = false
	inventory.add_portion()
	return true

func reset() -> void:
	collected = false
	set_enabled(enabled)
