class_name LocationFishing
extends Node3D

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const METRES := 260.0

var rod_available := true
var rod_model: Node3D

func _ready() -> void:
	position = Vector3(-2.5, 0, Route.world_z(METRES))
	_build()

func _build() -> void:
	var wood := Art.material(Color("6b4b32"), true)
	var dark := Art.material(Color("27282c"), true)
	var line := Art.material(Color("d8d2bd"), true)
	for z in [-1.2, 0.0, 1.2]:
		Art.box(self, Vector3(-1.1, 0.12, z), Vector3(2.5, 0.2, 1.0), wood, true)
	rod_model = Node3D.new()
	rod_model.name = "FishingRod"
	add_child(rod_model)
	var pole := Art.box(rod_model, Vector3(0.2, 0.9, 0), Vector3(0.08, 1.9, 0.08), dark)
	pole.rotation.z = -0.35
	Art.box(rod_model, Vector3(0.57, 1.15, 0), Vector3(0.025, 1.25, 0.025), line)

func is_player_in_reach(player_position: Vector3) -> bool:
	return global_position.distance_to(player_position) <= 2.8

func take_rod() -> void:
	rod_available = false
	rod_model.visible = false

func reset() -> void:
	rod_available = true
	rod_model.visible = true
