extends Node3D

## Модель кота: анимация шага, эмоции лица, моргание и звук шагов.
## Используется игроком (cat_player), катсценами и превью выбора модели.
## Снаружи задают move_speed / running / airborne и emotion — остальное
## модель делает сама. В катсцене move_speed и emotion ключуются в AnimationPlayer.
##
## Канон автора: стоящий кот не двигается — ни шага на месте, ни покачивания
## тела (ideas/prologue/animation/plan.md). Моргание — движение век, не тела;
## его можно выключить (blink_enabled).

## Варианты модели (сцены — scenes/player/cat_variants/cat_<id>.tscn).
const VARIANT_NAMES := {"a": "Рыжик", "b": "Чиби", "c": "Стройный", "d": "Пушистый"}
const DEFAULT_VARIANT := "a"
## Эмоции — канон автора 19.09.2026 (плюс спокойное лицо).
const EMOTION_NAMES := {"neutral": "спокойствие", "joy": "радость", "sad": "грусть", "angry": "злость",
	"surprised": "удивление"}

const STRIDE_LENGTH := 1.1
const LEG_SWING := 0.55
const RUN_LEG_SWING := 0.8
const FOOTSTEPS := [preload("res://audio/footstep_1.wav"), preload("res://audio/footstep_2.wav"),
	preload("res://audio/footstep_3.wav")]
## Шаги по разным поверхностям звучат по-разному (решение автора 19.09.2026).
## Пока это один набор шагов с разной высотой и громкостью — временно,
## до настоящих записей: [высота тона, громкость дБ].
const SURFACE_SOUND := {"asphalt": [1.25, -6.0], "concrete": [1.12, -7.0], "dirt": [0.95, -9.0], "grass": [0.8, -13.0]}

@export var variant_id := DEFAULT_VARIANT
## Высота глаз над ступнями — для камеры от первого лица.
@export var eye_height := 2.4
@export var move_speed := 0.0
@export var running := false
@export var airborne := false
@export var blink_enabled := true
@export var footsteps_enabled := true
@export var emotion := "neutral":
	set(value):
		emotion = value if EMOTION_NAMES.has(value) else "neutral"
		if is_node_ready():
			_show_face()

var _walk_phase := 0.0
var _blink_left := 0.0
var _next_blink := 3.0
var _eyes := {}
var _mouths := {}

@onready var leg_left: Node3D = $LegLeft
@onready var leg_right: Node3D = $LegRight
@onready var arm_left: Node3D = $ArmLeft
@onready var arm_right: Node3D = $ArmRight
@onready var head: Node3D = $Head
@onready var tail: Node3D = $Tail
@onready var body: Node3D = $Body
@onready var eyes_mesh: MeshInstance3D = $Head/Eyes
@onready var mouth_mesh: MeshInstance3D = $Head/Mouth
@onready var footsteps: AudioStreamPlayer3D = $Footsteps


static func scene_path(id: String) -> String:
	return "res://scenes/player/cat_variants/cat_%s.tscn" % id


## Заменить модель old на вариант id; возвращает новую модель (с тем же именем узла,
## чтобы анимации катсцен продолжали её находить).
static func replace(old: Node3D, id: String) -> Node3D:
	if not VARIANT_NAMES.has(id) or old.get("variant_id") == id:
		return old
	var fresh: Node3D = load(scene_path(id)).instantiate()
	fresh.name = old.name
	fresh.transform = old.transform
	var parent := old.get_parent()
	var index := old.get_index()
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(fresh)
	parent.move_child(fresh, index)
	if old.owner:
		fresh.owner = old.owner
	return fresh


func _ready() -> void:
	var folder := "res://scenes/player/cat_parts/%s/" % variant_id
	for state in ["neutral", "joy", "sad", "angry", "surprised", "closed"]:
		_eyes[state] = load(folder + "eyes_%s.res" % state)
	for mood in EMOTION_NAMES:
		_mouths[mood] = load(folder + "mouth_%s.res" % mood)
	_next_blink = randf_range(2.5, 6.0)
	_show_face()


func _process(delta: float) -> void:
	_animate_walk(delta)
	_blink(delta)


func _animate_walk(delta: float) -> void:
	var walking := move_speed > 0.05 and not airborne
	var swing := 0.0
	var bob := 0.0
	if walking:
		var before := _walk_phase
		_walk_phase += delta * move_speed / STRIDE_LENGTH * PI
		# Каждые пол-оборота фазы — лапа касается земли.
		if floori(_walk_phase / PI) != floori(before / PI):
			_play_footstep()
		swing = sin(_walk_phase) * (RUN_LEG_SWING if running else LEG_SWING)
		bob = absf(sin(_walk_phase)) * 0.05
	else:
		_walk_phase = 0.0
	var blend := minf(1.0, 14.0 * delta)
	if airborne:
		_pose(blend, -0.45, -0.45, 0.6, 0.6, 0.0)
	else:
		_pose(blend, swing, -swing, -swing * 0.8, swing * 0.8, bob)
	tail.rotation.y = lerpf(tail.rotation.y, sin(_walk_phase * 0.5) * 0.25 if walking else 0.0, blend)
	head.rotation.z = lerpf(head.rotation.z, sin(_walk_phase) * 0.04 if walking else 0.0, blend)


func _blink(delta: float) -> void:
	if not blink_enabled or emotion == "joy":
		return
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_show_face()
		return
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = randf_range(2.5, 6.0)
		_blink_left = 0.12
		eyes_mesh.mesh = _eyes.closed


func _show_face() -> void:
	eyes_mesh.mesh = _eyes[emotion]
	mouth_mesh.mesh = _mouths[emotion]


func _play_footstep() -> void:
	if not footsteps_enabled:
		return
	var surface := "grass"
	var scene := get_tree().current_scene
	if scene and scene.has_method("surface_at"):
		surface = scene.surface_at(global_position)
	var sound: Array = SURFACE_SOUND.get(surface, SURFACE_SOUND.grass)
	footsteps.stream = FOOTSTEPS[randi() % FOOTSTEPS.size()]
	footsteps.pitch_scale = sound[0] * randf_range(0.93, 1.07)
	footsteps.volume_db = sound[1] + (2.0 if running else 0.0)
	footsteps.play()


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
