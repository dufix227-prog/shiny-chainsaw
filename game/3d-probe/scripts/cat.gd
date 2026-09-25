extends CharacterBody3D

signal stepped(delta: float, distance: float)

const Art = preload("res://scripts/geometry.gd")
const SPEED := 3.4
const RUN_MULTIPLIER := 1.75
const COFFEE_SPEED_MULTIPLIER := 3.0
const COFFEE_DURATION_SECONDS := 240.0
const APPLE_SPEED_BONUS := 5.0
const APPLE_DURATION_SECONDS := 180.0
const DODGE_SPEED := 11.0
const DODGE_DURATION := 0.22
const JUMP_VELOCITY := 6.8
## К2: кот начинает в лесу (С1); X/Z синхронизированы с location_forest.SPAWN.
const SPAWN := Vector3(0, 0.08, 9.5)

var visual := Node3D.new()
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var camera_basis := Basis.IDENTITY
var walk_time := 0.0
var movement_enabled := true
var sitting := false
var running := false
var scripted_direction := Vector3.ZERO
var scripted_speed := SPEED
var scripted_walk := false
var speed_multiplier := 1.0
var mount_speed_multiplier := 1.0
var coffee_seconds_remaining := 0.0
var apple_seconds_remaining := 0.0
var dodge_seconds_remaining := 0.0
var dodge_direction := Vector3.ZERO

func _ready() -> void:
	position = SPAWN
	floor_snap_length = 0.3
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	collision.shape = capsule
	collision.position.y = 0.7
	add_child(collision)
	add_child(visual)
	visual.scale = Vector3.ONE * 1.15
	_build_model()

func _build_model() -> void:
	var fur := Art.material(Color("d8913b"), true)
	var cream := Art.material(Color("f5dca7"))
	var stripe := Art.material(Color("915129"))
	var dark := Art.material(Color("302a26"))
	var coat := Art.material(Color("416878"), true)
	var pink := Art.material(Color("d9a08c"))
	var leather := Art.material(Color("70543b"), true)
	Art.box(visual, Vector3(0, 0.94, 0), Vector3(0.57, 0.68, 0.4), coat)
	Art.box(visual, Vector3(0, 1.5, 0), Vector3(0.87, 0.64, 0.65), fur)
	for side in [-1, 1]:
		Art.ear(visual, Vector3(side * 0.29, 1.77, 0), Vector3(0.35, 0.38, 0.42), fur)
		Art.ear(visual, Vector3(side * 0.29, 1.79, 0.22), Vector3(0.2, 0.24, 0.035), pink)
		Art.box(visual, Vector3(side * 0.23, 1.52, 0.34), Vector3(0.1, 0.13, 0.04), dark)
		Art.box(visual, Vector3(side * 0.25, 1.56, 0.367), Vector3(0.027, 0.035, 0.015), cream)
		Art.box(visual, Vector3(side * 0.25, 1.7, 0.328), Vector3(0.08, 0.16, 0.025), stripe)
		Art.box(visual, Vector3(side * 0.38, 1.37, 0.32), Vector3(0.14, 0.045, 0.03), stripe)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.17, 0.6, 0)
		visual.add_child(leg)
		Art.box(leg, Vector3(0, -0.23, 0), Vector3(0.23, 0.44, 0.23), fur)
		Art.box(leg, Vector3(0, -0.47, 0.055), Vector3(0.27, 0.15, 0.35), leather)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.39, 1.15, 0)
		visual.add_child(arm)
		Art.box(arm, Vector3(0, -0.18, 0), Vector3(0.2, 0.4, 0.25), coat)
		Art.box(arm, Vector3(0, -0.43, 0), Vector3(0.2, 0.17, 0.24), fur)
		arms.append(arm)
	var stick := Art.box(arms[1], Vector3(0.06, -0.48, 0.2), Vector3(0.09, 0.92, 0.09), leather)
	stick.rotation.x = -0.55
	Art.box(visual, Vector3(0, 1.33, 0.36), Vector3(0.44, 0.2, 0.13), cream)
	Art.box(visual, Vector3(0, 1.42, 0.435), Vector3(0.1, 0.075, 0.06), dark)
	Art.box(visual, Vector3(0, 0.99, -0.31), Vector3(0.45, 0.49, 0.28), leather)
	Art.box(visual, Vector3(0, 1.14, -0.47), Vector3(0.43, 0.06, 0.04), cream)
	for side in [-1, 1]:
		Art.box(visual, Vector3(side * 0.19, 0.99, 0.22), Vector3(0.06, 0.5, 0.04), leather)
	Art.box(visual, Vector3(0.24, 0.56, -0.42), Vector3(0.2, 0.19, 0.65), fur)
	Art.box(visual, Vector3(0.24, 0.69, -0.72), Vector3(0.2, 0.39, 0.18), cream)

static func direction_for(input: Vector2, basis: Basis) -> Vector3:
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var back := Vector3(basis.z.x, 0, basis.z.z).normalized()
	return (right * input.x + back * input.y).limit_length(1.0)

func _physics_process(delta: float) -> void:
	if coffee_seconds_remaining > 0.0 and movement_enabled:
		coffee_seconds_remaining = maxf(0.0, coffee_seconds_remaining - delta)
		if coffee_seconds_remaining == 0.0:
			speed_multiplier = 1.0
	if apple_seconds_remaining > 0.0 and movement_enabled:
		apple_seconds_remaining = maxf(0.0, apple_seconds_remaining - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := direction_for(input, camera_basis)
	if scripted_walk:
		direction = scripted_direction
	elif InputMap.has_action("route_forward") and Input.is_action_pressed("route_forward"):
		direction = Vector3.FORWARD
	if not movement_enabled and not scripted_walk:
		direction = Vector3.ZERO
	if dodge_seconds_remaining > 0.0 and movement_enabled and not scripted_walk:
		dodge_seconds_remaining = maxf(0.0, dodge_seconds_remaining - delta)
		direction = dodge_direction
	var route_forward := InputMap.has_action("route_forward") and Input.is_action_pressed("route_forward")
	running = not scripted_walk and movement_enabled and direction.length() > 0.001 and not route_forward and InputMap.has_action("run") and Input.is_action_pressed("run")
	var apple_bonus := APPLE_SPEED_BONUS if apple_seconds_remaining > 0.0 else 0.0
	var regular_speed := (SPEED * (RUN_MULTIPLIER if running else 1.0) * speed_multiplier + apple_bonus) * mount_speed_multiplier
	var speed := scripted_speed if scripted_walk else (DODGE_SPEED if dodge_seconds_remaining > 0.0 else regular_speed)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0
		if movement_enabled and not scripted_walk and not sitting and InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	var before := position
	move_and_slide()
	var distance := Vector2(position.x - before.x, position.z - before.z).length()
	if position.y < -4:
		reset()
		distance = 0
	stepped.emit(delta, distance)
	var moving := distance > 0.05 * delta
	var airborne := not is_on_floor()
	if moving:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 12 * delta)
		walk_time += delta * (15 if running else 10)
	if sitting:
		visual.position.y = lerpf(visual.position.y, -0.34, 10 * delta)
		_set_limb_pose(-1.24, 0.55, 10 * delta)
	elif airborne:
		visual.position.y = lerpf(visual.position.y, 0.06, 10 * delta)
		_set_limb_pose(-0.72, 0.42, 12 * delta)
	else:
		visual.position.y = lerpf(visual.position.y, 0.0, 10 * delta)
		var amplitude := 0.70 if running else 0.45
		for i in legs.size():
			var swing := sin(walk_time + i * PI) * amplitude if moving else 0.0
			legs[i].rotation.x = swing
			arms[i].rotation.x = -swing * 0.7

func _set_limb_pose(leg_angle: float, arm_angle: float, blend: float) -> void:
	for i in legs.size():
		legs[i].rotation.x = lerpf(legs[i].rotation.x, leg_angle, blend)
		arms[i].rotation.x = lerpf(arms[i].rotation.x, arm_angle, blend)

func set_sitting(value: bool) -> void:
	sitting = value

func start_scripted_walk(direction: Vector3, speed: float = SPEED) -> void:
	scripted_direction = direction.normalized()
	scripted_speed = maxf(speed, 0.0)
	scripted_walk = true

func stop_scripted_walk() -> void:
	scripted_walk = false
	scripted_direction = Vector3.ZERO
	velocity.x = 0
	velocity.z = 0

func drink_coffee() -> void:
	speed_multiplier = COFFEE_SPEED_MULTIPLIER
	coffee_seconds_remaining = COFFEE_DURATION_SECONDS

func eat_speed_apple() -> void:
	apple_seconds_remaining = APPLE_DURATION_SECONDS

func begin_dodge(direction: Vector3) -> bool:
	if not movement_enabled or sitting or scripted_walk or direction.length_squared() < 0.01:
		return false
	dodge_direction = direction.normalized()
	dodge_seconds_remaining = DODGE_DURATION
	return true

func set_mount_speed_multiplier(value: float) -> void:
	mount_speed_multiplier = maxf(1.0, value)

func reset() -> void:
	stop_scripted_walk()
	position = SPAWN
	velocity = Vector3.ZERO
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	walk_time = 0
	sitting = false
	speed_multiplier = 1.0
	mount_speed_multiplier = 1.0
	coffee_seconds_remaining = 0.0
	apple_seconds_remaining = 0.0
	dodge_seconds_remaining = 0.0
	dodge_direction = Vector3.ZERO
