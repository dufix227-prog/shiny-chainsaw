class_name MimeTutorial
extends CharacterBody3D

signal objective_changed(text: String)
signal completed

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const SPAWN_METRES := 8.0
const WALK_END_METRES := 12.0
const CHURCH_METRES := 40.0
const REACH := 2.2
const WALK_SPEED := 2.4
const RUN_SPEED := 4.6

enum Stage { WAITING, WALK, RUN, INVENTORY, DONE }

var stage := Stage.WAITING
var paused := false

func _ready() -> void:
	_build_figure()
	reset()

func _build_figure() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	collision.shape = capsule
	collision.position.y = 0.7
	add_child(collision)
	var white := Art.material(Color("e7e2d3"), true)
	var black := Art.material(Color("282a2b"), true)
	Art.box(self, Vector3(0, 0.95, 0), Vector3(0.52, 0.7, 0.36), black)
	Art.box(self, Vector3(0, 1.5, 0), Vector3(0.68, 0.58, 0.54), white)
	for side in [-1.0, 1.0]:
		Art.box(self, Vector3(side * 0.34, 1.05, 0), Vector3(0.16, 0.62, 0.2), black)
		Art.box(self, Vector3(side * 0.36, 0.72, 0), Vector3(0.25, 0.2, 0.25), white)
		Art.box(self, Vector3(side * 0.14, 0.34, 0), Vector3(0.2, 0.68, 0.2), black)
	Art.box(self, Vector3(-0.18, 1.53, 0.28), Vector3(0.1, 0.14, 0.04), black)
	Art.box(self, Vector3(0.18, 1.53, 0.28), Vector3(0.1, 0.14, 0.04), black)

func begin() -> bool:
	if stage != Stage.WAITING:
		return false
	stage = Stage.WALK
	objective_changed.emit("Иди за мимом")
	return true

func update_player(player_position: Vector3) -> void:
	if stage == Stage.RUN and Route.metres(position) >= CHURCH_METRES \
			and Route.metres(player_position) >= CHURCH_METRES - 1.0:
		stage = Stage.INVENTORY
		objective_changed.emit("B · открой инвентарь")

func inventory_opened() -> void:
	if stage != Stage.INVENTORY:
		return
	stage = Stage.DONE
	objective_changed.emit("View · карта уже у тебя")
	completed.emit()

func is_player_in_reach(player_position: Vector3) -> bool:
	return stage == Stage.WAITING and global_position.distance_to(player_position) <= REACH

func _physics_process(_delta: float) -> void:
	velocity = Vector3.ZERO
	if paused:
		return
	if stage == Stage.WALK:
		velocity.z = -WALK_SPEED
		if Route.metres(position) >= WALK_END_METRES:
			stage = Stage.RUN
			objective_changed.emit("R2 · беги за мимом до церкви")
	elif stage == Stage.RUN and Route.metres(position) < CHURCH_METRES:
		velocity.z = -RUN_SPEED
	move_and_slide()

func reset() -> void:
	stage = Stage.WAITING
	position = Vector3(1.8, 0.08, Route.world_z(SPAWN_METRES))
	velocity = Vector3.ZERO
	objective_changed.emit("E / A · мим показывает дорогу")
