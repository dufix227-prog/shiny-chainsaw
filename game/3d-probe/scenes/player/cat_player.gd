extends CharacterBody3D

## Кот под управлением игрока: ходьба, бег с выносливостью, прыжок,
## камера от третьего лица (мышь или правый стик), замедление в кустах.

const WALK_SPEED := 3.4  # темп К1: 500 м маршрута ≈ 30 минут ходьбы
const RUN_SPEED := 6.0
const BUSH_SPEED_FACTOR := 0.5
const JUMP_VELOCITY := 6.8
const GRAVITY := 18.0

const STAMINA_MAX := 100.0
const STAMINA_RUN_COST := 16.0  # в секунду бега
const STAMINA_RECOVERY := 11.0  # в секунду без бега
const STAMINA_TO_RUN_AGAIN := 25.0  # после полного выдоха бег возвращается не сразу

const STICK_LOOK_SPEED := 2.6  # радиан в секунду при полном отклонении стика
const PITCH_MIN := -1.1
const PITCH_MAX := 0.35

var stamina := STAMINA_MAX
var is_running := false
var controls_enabled := true

var _out_of_breath := false
var _bushes_touching := 0
var _walk_cycle := 0.0

@onready var visual: Node3D = $Visual
@onready var leg_left: Node3D = $Visual/LegLeft
@onready var leg_right: Node3D = $Visual/LegRight
@onready var arm_left: Node3D = $Visual/ArmLeft
@onready var arm_right: Node3D = $Visual/ArmRight
@onready var tail: Node3D = $Visual/Tail
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = GameSettings.mouse_sensitivity * 0.01
		var vertical_sign := -1.0 if GameSettings.invert_camera_y else 1.0
		turn_camera(-event.relative.x * sensitivity, -event.relative.y * sensitivity * vertical_sign)


func turn_camera(yaw_change: float, pitch_change: float) -> void:
	camera_pivot.rotation.y += yaw_change
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x + pitch_change, PITCH_MIN, PITCH_MAX)


func enter_bush() -> void:
	_bushes_touching += 1


func leave_bush() -> void:
	_bushes_touching = maxi(_bushes_touching - 1, 0)


func is_in_bush() -> bool:
	return _bushes_touching > 0


func _physics_process(delta: float) -> void:
	var move_input := Vector2.ZERO
	if controls_enabled:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		turn_camera(-look.x * STICK_LOOK_SPEED * delta, -look.y * STICK_LOOK_SPEED * delta)

	var direction := _direction_from_camera(move_input)
	var wants_to_run := controls_enabled and Input.is_action_pressed("run") and direction != Vector3.ZERO
	_update_stamina(wants_to_run, delta)

	var speed := RUN_SPEED if is_running else WALK_SPEED
	if is_in_bush():
		speed *= BUSH_SPEED_FACTOR
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if is_on_floor():
		velocity.y = 0.0
		if controls_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta

	move_and_slide()
	_animate(direction, delta)


## Направление ходьбы считается от камеры: «вперёд» — туда, куда она смотрит.
func _direction_from_camera(move_input: Vector2) -> Vector3:
	var yaw := camera_pivot.global_rotation.y
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return (right * move_input.x - forward * move_input.y).limit_length(1.0)


func _update_stamina(wants_to_run: bool, delta: float) -> void:
	if _out_of_breath and stamina >= STAMINA_TO_RUN_AGAIN:
		_out_of_breath = false
	is_running = wants_to_run and not _out_of_breath
	if is_running:
		stamina = maxf(stamina - STAMINA_RUN_COST * delta, 0.0)
		if stamina == 0.0:
			_out_of_breath = true
	else:
		stamina = minf(stamina + STAMINA_RECOVERY * delta, STAMINA_MAX)


## Блочная анимация: лапы качаются в такт шагу (частота зависит от скорости,
## чтобы кот не скользил), хвост покачивается всегда.
func _animate(direction: Vector3, delta: float) -> void:
	var moving := direction != Vector3.ZERO and is_on_floor()
	if direction != Vector3.ZERO:
		# Модель смотрит вдоль −Z, поэтому угол считается от −direction.
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 12.0 * delta)
	var swing := 0.0
	if moving:
		var speed := Vector2(velocity.x, velocity.z).length()
		_walk_cycle += delta * speed * 2.6
		swing = sin(_walk_cycle) * (0.9 if is_running else 0.6)
		visual.position.y = absf(sin(_walk_cycle)) * 0.06
	else:
		_walk_cycle = 0.0
		visual.position.y = lerpf(visual.position.y, 0.0, 10.0 * delta)
	if not is_on_floor():
		swing = -0.5  # в прыжке лапы поджаты
	var blend := 14.0 * delta
	leg_left.rotation.x = lerpf(leg_left.rotation.x, swing, blend)
	leg_right.rotation.x = lerpf(leg_right.rotation.x, -swing if is_on_floor() else swing, blend)
	arm_left.rotation.x = lerpf(arm_left.rotation.x, -swing * 0.8, blend)
	arm_right.rotation.x = lerpf(arm_right.rotation.x, swing * 0.8, blend)
	tail.rotation.y = sin(Time.get_ticks_msec() * 0.003) * 0.3
