class_name PigFollow
extends Node3D

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const SEAT_CAPACITY := 2
const SPEED_MULTIPLIER := 1.6
const MAX_HUNGER_SECONDS := 240.0

var stolen := false
var mounted := false
var passenger_count := 0
var hungry_seconds := MAX_HUNGER_SECONDS
var bratishkin_shouted := false
var hunger_warned := false

func _ready() -> void:
	position = home_position()
	_build_model()

static func home_position() -> Vector3:
	return Vector3(7.0, 0.05, Route.world_z(205.0))

func _build_model() -> void:
	var pink := Art.material(Color("d98587"), true)
	var light := Art.material(Color("edb0a8"), true)
	var dark := Art.material(Color("493939"), true)
	Art.box(self, Vector3(0, 0.55, 0), Vector3(1.25, 0.72, 0.7), pink)
	Art.box(self, Vector3(0, 0.68, 0.52), Vector3(0.72, 0.62, 0.55), pink)
	Art.box(self, Vector3(0, 0.61, 0.83), Vector3(0.46, 0.28, 0.18), light)
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 0.39, 0.26, -0.18), Vector3(0.2, 0.48, 0.22), dark)
		Art.box(self, Vector3(side * 0.39, 0.26, 0.28), Vector3(0.2, 0.48, 0.22), dark)
		Art.box(self, Vector3(side * 0.19, 0.72, 0.83), Vector3(0.05, 0.07, 0.04), dark)

func is_player_in_reach(player_position: Vector3) -> bool:
	return not mounted and global_position.distance_to(player_position) <= 2.2

func mount(player_position: Vector3) -> bool:
	if hungry_seconds <= 0.0:
		return false
	stolen = true
	mounted = true
	passenger_count = 1
	global_position = player_position
	return true

func dismount(player_position: Vector3) -> void:
	mounted = false
	passenger_count = 0
	global_position = player_position + Vector3(1.2, 0, 0)

func feed() -> void:
	hungry_seconds = minf(MAX_HUNGER_SECONDS, hungry_seconds + MAX_HUNGER_SECONDS * 0.5)
	hunger_warned = false

func advance(delta: float, player_position: Vector3) -> void:
	if not stolen:
		return
	hungry_seconds = maxf(0.0, hungry_seconds - delta)
	if mounted:
		global_position = player_position
	if hungry_seconds == 0.0:
		mounted = false
		passenger_count = 0
		stolen = false
		global_position = home_position()

func is_hungry() -> bool:
	return hungry_seconds <= MAX_HUNGER_SECONDS * 0.25

func reset() -> void:
	stolen = false
	mounted = false
	passenger_count = 0
	hungry_seconds = MAX_HUNGER_SECONDS
	bratishkin_shouted = false
	hunger_warned = false
	global_position = home_position()
