class_name DroppedInventoryItem
extends Node3D

const Art = preload("res://scripts/geometry.gd")
const Icons = preload("res://scripts/inventory_art.gd")
const REACH := 1.6
var item: Dictionary
var collected := false

func setup(value: Dictionary, world_position: Vector3) -> void:
	item = value.duplicate(true)
	position = world_position

func _ready() -> void:
	var material := Art.material(Color("f2ede2"))
	# Иконка предмета как текстура на ящике: проба вместо финальных моделей.
	material.albedo_texture = Icons.item_texture(item.get("id", ""))
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.5
	Art.box(self, Vector3(0, 0.16, 0), Vector3(0.38, 0.32, 0.38), material)
	var label := Label3D.new()
	label.text = item.get("name", "Предмет")
	label.position.y = 0.6
	label.font_size = 36
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func can_collect(player_position: Vector3) -> bool:
	return not collected and global_position.distance_to(player_position) <= REACH

func collect(player_position: Vector3, inventory: ProbeInventory) -> bool:
	if not can_collect(player_position) or not inventory.add_to_first_free(item):
		return false
	collected = true
	queue_free()
	return true
