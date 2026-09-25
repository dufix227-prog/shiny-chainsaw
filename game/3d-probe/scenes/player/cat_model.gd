extends Node3D

## Модель кота и её анимация. Используется и игроком (cat_player), и катсценами.
## Снаружи задают только три вещи: move_speed, running, airborne — остальное
## модель делает сама. В катсцене move_speed ключуется в AnimationPlayer.
##
## Канон автора: стоящий кот не двигается совсем — ни шага на месте, ни
## покачивания (ideas/prologue/animation/plan.md).

## Скорость, с которой кот сейчас идёт (единиц в секунду). 0 — стоит.
@export var move_speed := 0.0
@export var running := false
@export var airborne := false

## Длина шага: за один шаг кот проходит столько единиц. Частота шагов
## считается от скорости — поэтому ноги не «скользят» по земле.
const STRIDE_LENGTH := 1.1
const LEG_SWING := 0.55
const RUN_LEG_SWING := 0.8

var _walk_phase := 0.0

@onready var leg_left: Node3D = $LegLeft
@onready var leg_right: Node3D = $LegRight
@onready var arm_left: Node3D = $ArmLeft
@onready var arm_right: Node3D = $ArmRight
@onready var head: Node3D = $Head
@onready var tail: Node3D = $Tail
@onready var body: Node3D = $Body


func _process(delta: float) -> void:
	var walking := move_speed > 0.05 and not airborne
	var swing := 0.0
	var bob := 0.0
	if walking:
		_walk_phase += delta * move_speed / STRIDE_LENGTH * PI
		swing = sin(_walk_phase) * (RUN_LEG_SWING if running else LEG_SWING)
		bob = absf(sin(_walk_phase)) * 0.05
	else:
		_walk_phase = 0.0
	var blend := minf(1.0, 14.0 * delta)
	if airborne:
		_pose(blend, -0.45, -0.45, 0.6, 0.6, 0.0)
	else:
		_pose(blend, swing, -swing, -swing * 0.8, swing * 0.8, bob)
	# Хвост и голова покачиваются только при ходьбе.
	tail.rotation.y = lerpf(tail.rotation.y, sin(_walk_phase * 0.5) * 0.25 if walking else 0.0, blend)
	head.rotation.z = lerpf(head.rotation.z, sin(_walk_phase) * 0.04 if walking else 0.0, blend)


func _pose(blend: float, leg_l: float, leg_r: float, arm_l: float, arm_r: float, bob: float) -> void:
	leg_left.rotation.x = lerpf(leg_left.rotation.x, leg_l, blend)
	leg_right.rotation.x = lerpf(leg_right.rotation.x, leg_r, blend)
	arm_left.rotation.x = lerpf(arm_left.rotation.x, arm_l, blend)
	arm_right.rotation.x = lerpf(arm_right.rotation.x, arm_r, blend)
	for part in [body, head, arm_left, arm_right, tail]:
		part.position.y = lerpf(part.position.y, _rest_y(part) + bob, blend)


func _rest_y(part: Node3D) -> float:
	if not part.has_meta("rest_y"):
		part.set_meta("rest_y", part.position.y)
	return part.get_meta("rest_y")
