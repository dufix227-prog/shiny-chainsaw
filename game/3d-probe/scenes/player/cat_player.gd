extends CharacterBody3D

## Кот под управлением игрока: ходьба, бег с выносливостью, прыжок, камера
## (четыре вида, приближение), замедление в кустах и реакции лица на события.
##
## Виды камеры (просьба автора 25.09.2026 «от 1 лица, третьего и кастомное»;
## канон 09.09.2026 — свободная камера, «прямо за котом» и первое лицо):
## - третье лицо: свободно вращается мышью/стиком;
## - за спиной: камера держится за котом, влево/вправо поворачивают кота;
## - первое лицо: камера в глазах кота, сам кот не виден (только тень);
## - своя: высота, сдвиг вбок, расстояние и наклон — из настроек.

const CatModel = preload("res://scenes/player/cat_model.gd")

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
const TURN_SPEED := 2.8  # поворот кота в виде «за спиной», радиан в секунду
const PITCH_MIN := -1.1
const PITCH_MAX := 0.35
const FIRST_PERSON_PITCH_MIN := -1.35
const FIRST_PERSON_PITCH_MAX := 1.25
const ZOOM_MIN := 2.5
const ZOOM_MAX := 16.0
const ZOOM_STEP := 1.0
## Когда препятствие прижимает камеру ближе этого расстояния, кот начинает
## становиться прозрачным, а на FADE_GONE_DISTANCE исчезает совсем: иначе
## камера упирается в его голову и закрывает весь экран.
const FADE_START_DISTANCE := 3.0
const FADE_GONE_DISTANCE := 1.3
const MODE_NAMES := ["Третье лицо", "За спиной", "Первое лицо", "Своя камера"]

signal struck_by_car(car: Node3D)
signal camera_mode_changed(title: String)
signal reaction_started(closeup: bool)
signal reaction_finished

var stamina := STAMINA_MAX
var is_running := false
var controls_enabled := true
var camera_mode: int = GameSettings.CameraMode.THIRD_PERSON

var _out_of_breath := false
var _bushes_touching := 0
var _visual_parts: Array[GeometryInstance3D] = []
var _current_fade := 0.0
## Вид камеры до перехода в первое лицо приближением — чтобы вернуться отдалением.
var _mode_before_first_person: int = GameSettings.CameraMode.THIRD_PERSON
var _reaction_tween: Tween
var _in_closeup := false

@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/CatModel
@onready var face_camera: Camera3D = $Visual/FaceCamera
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	model = CatModel.replace(model, SaveGame.cat_variant)
	for part in visual.find_children("*", "GeometryInstance3D", true, false):
		_visual_parts.append(part)
	GameSettings.changed.connect(_apply_camera_settings)
	camera_mode = GameSettings.get_value("camera_mode")
	_apply_camera_settings()
	camera_pivot.rotation.x = deg_to_rad(GameSettings.get_value("camera_pitch"))


func _process(_delta: float) -> void:
	if camera_mode == GameSettings.CameraMode.FIRST_PERSON:
		return
	var distance := spring_arm.get_hit_length()
	var fade := 1.0 - clampf((distance - FADE_GONE_DISTANCE) / (FADE_START_DISTANCE - FADE_GONE_DISTANCE), 0.0, 1.0)
	if _in_closeup:
		fade = 0.0
	if absf(fade - _current_fade) > 0.01:
		_current_fade = fade
		for part in _visual_parts:
			part.transparency = fade


func _unhandled_input(event: InputEvent) -> void:
	if _in_closeup and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		end_reaction()
		return
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = GameSettings.mouse_sensitivity * 0.01
		var vertical_sign := -1.0 if GameSettings.invert_camera_y else 1.0
		turn_camera(-event.relative.x * sensitivity, -event.relative.y * sensitivity * vertical_sign)
	elif event.is_action_pressed("camera_zoom_in"):
		zoom(-ZOOM_STEP)
	elif event.is_action_pressed("camera_zoom_out"):
		zoom(ZOOM_STEP)
	elif event.is_action_pressed("camera_mode"):
		set_camera_mode((camera_mode + 1) % MODE_NAMES.size())


func turn_camera(yaw_change: float, pitch_change: float) -> void:
	if camera_mode == GameSettings.CameraMode.BEHIND:
		# «За спиной» мышь по горизонтали поворачивает кота, камера следует за ним.
		visual.rotation.y += yaw_change
	else:
		camera_pivot.rotation.y += yaw_change
	var first := camera_mode == GameSettings.CameraMode.FIRST_PERSON
	camera_pivot.rotation.x = clampf(camera_pivot.rotation.x + pitch_change,
		FIRST_PERSON_PITCH_MIN if first else PITCH_MIN, FIRST_PERSON_PITCH_MAX if first else PITCH_MAX)


## Приближение/отдаление. Ближе минимума — первое лицо; отдаление из него — назад.
func zoom(step: float) -> void:
	if camera_mode == GameSettings.CameraMode.FIRST_PERSON:
		if step > 0.0:
			set_camera_mode(_mode_before_first_person)
		return
	var distance: float = GameSettings.get_value("camera_distance") + step
	if distance < ZOOM_MIN:
		_mode_before_first_person = camera_mode
		set_camera_mode(GameSettings.CameraMode.FIRST_PERSON)
		return
	GameSettings.set_value("camera_distance", clampf(distance, ZOOM_MIN, ZOOM_MAX))
	GameSettings.save_settings()
	_apply_camera_settings()


func set_camera_mode(mode: int) -> void:
	if mode == camera_mode:
		return
	if camera_mode != GameSettings.CameraMode.FIRST_PERSON and mode == GameSettings.CameraMode.FIRST_PERSON:
		_mode_before_first_person = camera_mode
	camera_mode = mode
	GameSettings.set_value("camera_mode", mode)
	GameSettings.save_settings()
	_apply_camera_settings()
	camera_mode_changed.emit(MODE_NAMES[mode])


## Реакция лица на событие («маленькая катсцена», просьба автора 25.09.2026).
## closeup — камера на пару секунд показывает мордочку, управление ждёт.
## Пропуск — прыжок / подтверждение.
func play_reaction(mood: String, seconds: float, closeup: bool = false) -> void:
	if _reaction_tween:
		_reaction_tween.kill()
	model.emotion = mood
	if closeup:
		_in_closeup = true
		controls_enabled = false
		velocity = Vector3.ZERO
		# Камера напротив мордочки, чуть сбоку — с учётом роста выбранной модели.
		var eye: float = model.eye_height
		face_camera.position = Vector3(1.2, eye + 0.45, -5.0)
		face_camera.look_at(visual.to_global(Vector3(0, eye - 0.15, 0)), Vector3.UP)
		face_camera.current = true
	reaction_started.emit(closeup)
	_reaction_tween = create_tween()
	_reaction_tween.tween_interval(seconds)
	_reaction_tween.tween_callback(end_reaction)


func end_reaction() -> void:
	if _reaction_tween:
		_reaction_tween.kill()
		_reaction_tween = null
	model.emotion = "neutral"
	if _in_closeup:
		_in_closeup = false
		camera.current = true
		controls_enabled = true
	reaction_finished.emit()


func is_in_closeup() -> bool:
	return _in_closeup


## Вызывает машина, в чью зону попал кот (traffic_car.gd).
func hit_by_car(car: Node3D) -> void:
	if controls_enabled:
		model.emotion = "surprised"
		struck_by_car.emit(car)


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
		var stick: float = GameSettings.get_value("stick_sensitivity")
		turn_camera(-look.x * STICK_LOOK_SPEED * stick * delta, -look.y * STICK_LOOK_SPEED * stick * delta)

	var direction := Vector3.ZERO
	if camera_mode == GameSettings.CameraMode.BEHIND:
		# Как «танк»: влево/вправо поворачивают кота, вперёд/назад — вдоль взгляда.
		visual.rotation.y -= move_input.x * TURN_SPEED * delta
		var facing := visual.global_basis * Vector3.FORWARD
		direction = Vector3(facing.x, 0, facing.z).normalized() * -move_input.y
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, visual.rotation.y, minf(1.0, 8.0 * delta))
	else:
		direction = _direction_from_camera(move_input)
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
			# Выдохся — грустная мордочка на пару секунд (предложение, не канон).
			if is_inside_tree() and not _in_closeup:
				play_reaction("sad", 2.0)
	else:
		stamina = minf(stamina + STAMINA_RECOVERY * delta, STAMINA_MAX)


## Поворот по ходу движения; сама анимация шага — в модели (cat_model.gd).
func _animate(direction: Vector3, delta: float) -> void:
	if camera_mode == GameSettings.CameraMode.FIRST_PERSON:
		# В первом лице кот смотрит туда же, куда камера.
		visual.rotation.y = camera_pivot.rotation.y
	elif direction != Vector3.ZERO and camera_mode != GameSettings.CameraMode.BEHIND:
		# Модель смотрит вдоль −Z, поэтому угол считается от −direction.
		var target_yaw := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 12.0 * delta)
	# Реальная скорость, а не желаемая: упёрся в дерево — стоит неподвижно.
	var real := get_real_velocity()
	var ground_speed := Vector2(real.x, real.z).length()
	model.move_speed = ground_speed
	model.running = is_running
	model.airborne = not is_on_floor()
	if ground_speed > 0.05 and controls_enabled:
		SaveGame.has_unsaved_progress = true


func _apply_camera_settings() -> void:
	camera_mode = GameSettings.get_value("camera_mode")
	camera.fov = GameSettings.get_value("field_of_view")
	camera.far = GameSettings.get_value("draw_distance")
	var first := camera_mode == GameSettings.CameraMode.FIRST_PERSON
	var custom := camera_mode == GameSettings.CameraMode.CUSTOM
	var eye: float = model.eye_height if model else 2.4
	camera_pivot.position = Vector3(0, eye if first else (GameSettings.get_value("camera_height") if custom else 3.2), 0)
	spring_arm.spring_length = 0.0 if first else GameSettings.get_value("camera_distance")
	spring_arm.position.x = GameSettings.get_value("camera_side") if custom else 0.0
	if custom:
		camera_pivot.rotation.x = deg_to_rad(GameSettings.get_value("camera_pitch"))
	# В первом лице кот не заслоняет обзор, но его тень остаётся.
	var shadow_only := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for part in _visual_parts:
		part.cast_shadow = shadow_only if first else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if first:
			part.transparency = 0.0
	_current_fade = 0.0
