class_name RoadNPC
extends CharacterBody3D

const Art = preload("res://scripts/geometry.gd")
const REACH := 2.5
const CHASE_SPEED := 2.8

var encounter_id := ""
var display_name := "НПС"
var species := "cat"
var max_hp := 10
var accessory := ""
var defeated := false
var interaction_completed := false
var spawn_position := Vector3.ZERO
var label: Label3D

func setup(data: Dictionary, spot: Vector3) -> void:
	encounter_id = String(data.id)
	display_name = String(data.name)
	species = String(data.get("species", "cat"))
	max_hp = int(data.get("hp", 10))
	accessory = String(data.get("accessory", ""))
	position = spot
	spawn_position = spot
	_build_body()
	var visual_scale := float(data.get("visual_scale", 1.0))
	scale = Vector3.ONE * visual_scale

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.35
	collision.shape = capsule
	collision.position.y = 0.68
	add_child(collision)
	var fur := Art.material(_species_color(), true)
	var dark := Art.material(Color("332f2c"), true)
	var body_size := Vector3(0.62, 0.72, 0.48)
	if species == "chicken":
		body_size = Vector3(0.62, 0.55, 0.72)
	Art.box(self, Vector3(0, 0.72, 0), body_size, fur)
	Art.box(self, Vector3(0, 1.25, 0.05), Vector3(0.65, 0.55, 0.55), fur)
	for side in [-1, 1]:
		if species == "cat":
			Art.ear(self, Vector3(side * 0.22, 1.55, 0.03), Vector3(0.28, 0.3, 0.3), fur)
		elif species == "dog":
			Art.box(self, Vector3(side * 0.33, 1.34, 0.02), Vector3(0.18, 0.42, 0.2), fur)
		elif species == "goose" or species == "chicken":
			Art.box(self, Vector3(side * 0.22, 0.76, 0), Vector3(0.16, 0.5, 0.45), fur)
		Art.box(self, Vector3(side * 0.18, 1.28, 0.34), Vector3(0.08, 0.1, 0.04), dark)
	if species == "goose" or species == "chicken":
		Art.box(self, Vector3(0, 1.16, 0.42), Vector3(0.28, 0.12, 0.38), Art.material(Color("d99342"), true))
	if species == "hedgehog":
		for side in [-1, 0, 1]:
			var spike := Art.box(self, Vector3(side * 0.22, 1.0, -0.3), Vector3(0.09, 0.65, 0.09), dark)
			spike.rotation.x = -0.5
	match accessory:
		"herb_bag":
			Art.box(self, Vector3(-0.38, 0.74, 0), Vector3(0.28, 0.5, 0.38), Art.material(Color("607249"), true))
		"lantern":
			Art.box(self, Vector3(0.42, 0.65, 0.08), Vector3(0.25, 0.38, 0.25), Art.material(Color("d6a54b"), true))
		"scar":
			var scar := Art.box(self, Vector3(0.17, 1.34, 0.34), Vector3(0.04, 0.3, 0.025), dark)
			scar.rotation.z = -0.35
	label = Label3D.new()
	label.text = display_name
	label.position = Vector3(0, 1.95, 0)
	label.font_size = 34
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _species_color() -> Color:
	match species:
		"dog": return Color("9b734f")
		"goose": return Color("e4e1d2")
		"chicken": return Color("ba7852")
		"hedgehog": return Color("746151")
	return Color("a8907e")

func distance_to_player(player_position: Vector3) -> float:
	return global_position.distance_to(player_position)

func chase(player_position: Vector3, speed_multiplier := 1.0) -> void:
	if defeated:
		return
	var offset := player_position - global_position
	offset.y = 0
	if offset.length() > 1.45:
		velocity = offset.normalized() * CHASE_SPEED * speed_multiplier
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func mark_defeated() -> void:
	defeated = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

func reset_to(spot: Vector3) -> void:
	position = spot
	spawn_position = spot
	velocity = Vector3.ZERO
	defeated = false
	interaction_completed = false
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
