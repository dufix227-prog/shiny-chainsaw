class_name RoadEvent
extends Node3D

const Art = preload("res://scripts/geometry.gd")
const REACH := 2.2

var encounter_id := ""
var display_name := "Событие"
var interaction_completed := false

func setup(id: String, title: String) -> void:
	encounter_id = id
	display_name = title
	var cloth := Art.material(Color("7c6247"), true)
	Art.box(self, Vector3(0, 0.28, 0), Vector3(0.75, 0.55, 0.48), cloth)
	Art.box(self, Vector3(0, 0.58, 0), Vector3(0.56, 0.12, 0.38), cloth)
	var label := Label3D.new()
	label.text = title
	label.position.y = 0.95
	label.font_size = 34
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func reset_to(spot: Vector3) -> void:
	position = spot
	interaction_completed = false
	visible = true

func complete() -> void:
	interaction_completed = true
	visible = false

func is_player_in_reach(player_position: Vector3) -> bool:
	return not interaction_completed and global_position.distance_to(player_position) <= REACH
