class_name SuperPig
extends Node3D

const Art = preload("res://scripts/geometry.gd")
const SPEED_MULTIPLIER := 2.2
const SEAT_CAPACITY := 2

var summoned := false
var mounted := false
var exhausted := false
var passenger_count := 0

func _ready() -> void:
	visible = false
	_build_model()

func _build_model() -> void:
	var black := Art.material(Color("18191e"), true)
	var grey := Art.material(Color("3c3e45"), true)
	var tusk := Art.material(Color("eee1bf"), true)
	Art.box(self, Vector3(0, 0.72, 0), Vector3(1.65, 0.95, 0.9), black)
	Art.box(self, Vector3(0, 0.83, 0.64), Vector3(0.92, 0.8, 0.68), black)
	Art.box(self, Vector3(0, 0.7, 1.02), Vector3(0.58, 0.32, 0.22), grey)
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 0.52, 0.3, -0.3), Vector3(0.25, 0.58, 0.3), grey)
		Art.box(self, Vector3(side * 0.52, 0.3, 0.36), Vector3(0.25, 0.58, 0.3), grey)
		Art.box(self, Vector3(side * 0.38, 0.58, 1.17), Vector3(0.12, 0.12, 0.28), tusk)

func summon(player_position: Vector3) -> void:
	if summoned or exhausted:
		return
	summoned = true
	visible = true
	global_position = player_position + Vector3(1.4, 0, 0)

func is_player_in_reach(player_position: Vector3) -> bool:
	return summoned and not exhausted and not mounted and global_position.distance_to(player_position) <= 2.4

func mount(player_position: Vector3, with_companion: bool) -> void:
	mounted = true
	passenger_count = 2 if with_companion else 1
	global_position = player_position

func dismount(player_position: Vector3) -> void:
	mounted = false
	passenger_count = 0
	global_position = player_position + Vector3(1.4, 0, 0)

func follow(player_position: Vector3) -> void:
	if mounted:
		global_position = player_position

func finish_trip(player_position: Vector3) -> void:
	summoned = true
	mounted = false
	exhausted = true
	passenger_count = 0
	visible = true
	global_position = player_position + Vector3(1.4, 0, 0)

func reset() -> void:
	summoned = false
	mounted = false
	exhausted = false
	passenger_count = 0
	visible = false
