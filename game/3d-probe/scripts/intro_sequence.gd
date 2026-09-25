extends Node

signal finished

const IntroLocation = preload("res://scripts/location_intro.gd")
const WALK_SPEED := 3.4
const SIGN_PAUSE_SECONDS := 1.4

enum Phase { IDLE, STONE_TRAIL, SIGN, FOREST_TRAIL, DONE }

var phase := Phase.IDLE
var cat: CharacterBody3D
var paused := false
var sign_seconds := 0.0
var finish_count := 0

func begin(value: CharacterBody3D) -> void:
	reset()
	cat = value
	cat.position = IntroLocation.CUTSCENE_SPAWN
	cat.velocity = Vector3.ZERO
	cat.start_scripted_walk(Vector3.FORWARD, WALK_SPEED)
	phase = Phase.STONE_TRAIL

func is_active() -> bool:
	return phase == Phase.STONE_TRAIL or phase == Phase.SIGN or phase == Phase.FOREST_TRAIL

func set_paused(value: bool) -> void:
	paused = value
	if not is_instance_valid(cat):
		return
	if value:
		cat.stop_scripted_walk()
	elif phase == Phase.STONE_TRAIL or phase == Phase.FOREST_TRAIL:
		cat.start_scripted_walk(Vector3.FORWARD, WALK_SPEED)

func reset() -> void:
	if is_instance_valid(cat):
		cat.stop_scripted_walk()
	cat = null
	phase = Phase.IDLE
	paused = false
	sign_seconds = 0.0
	finish_count = 0

func _physics_process(delta: float) -> void:
	if paused or not is_instance_valid(cat):
		return
	match phase:
		Phase.STONE_TRAIL:
			if cat.position.z <= IntroLocation.SIGN_STOP.z:
				cat.stop_scripted_walk()
				phase = Phase.SIGN
		Phase.SIGN:
			sign_seconds += delta
			if sign_seconds >= SIGN_PAUSE_SECONDS:
				cat.start_scripted_walk(Vector3.FORWARD, WALK_SPEED)
				phase = Phase.FOREST_TRAIL
		Phase.FOREST_TRAIL:
			if cat.position.z <= IntroLocation.RELEASE_SPAWN.z:
				_complete()

func _complete() -> void:
	cat.stop_scripted_walk()
	cat.position = IntroLocation.RELEASE_SPAWN
	cat.velocity = Vector3.ZERO
	phase = Phase.DONE
	finish_count += 1
	finished.emit()
