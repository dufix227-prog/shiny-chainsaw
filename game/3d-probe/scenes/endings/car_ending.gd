extends CanvasLayer

## Ранняя концовка С9-машина «глупый суицидник» (канон автора 09.09.2026,
## ideas/prologue/car-ending.md): после столкновения кот летит в небо →
## камера отдаляется → «Конец» → титры → игра закрывается сама.
## Без крови, травм, реплик и объяснений — так решил автор.
## Пропуск — сразу к титрам (канон). Кнопка пропуска — ЗАГЛУШКА (Esc / Start / Enter / A),
## текст титров — ЗАГЛУШКА: автор его ещё не дал.

signal started
signal finished

const FLIGHT_SECONDS := 3.5
const PULL_BACK_SECONDS := 4.5
const THE_END_SECONDS := 3.5
const CREDITS_SECONDS := 10.0

## В проверках игру закрывать не нужно — только сообщить, что концовка кончилась.
@export var quit_on_finish := true

var running := false
var _in_credits := false
var _player: Node3D
var _camera: Camera3D
var _flying: Node3D

@onready var fade: ColorRect = $Fade
@onready var the_end: Label = $TheEnd
@onready var credits: Label = $Credits


func _ready() -> void:
	visible = false
	fade.color.a = 0.0
	the_end.modulate.a = 0.0
	credits.visible = false


func start(player: Node3D) -> void:
	if running:
		return
	running = true
	visible = true
	started.emit()
	_player = player
	player.controls_enabled = false
	player.set_physics_process(false)
	_flying = player.get_node("Visual")
	$Whoosh.play()
	# Камера переходит из «пружины» за котом прямо в мир — иначе пружина
	# каждый кадр возвращала бы её за спину кота и отдаления не было бы.
	_camera = player.camera
	_camera.reparent(player.get_parent(), true)
	var start_position := _camera.global_position
	var away := (start_position - player.global_position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var sequence := create_tween()
	sequence.set_parallel(true)
	sequence.tween_property(_flying, "position:y", 70.0, FLIGHT_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	sequence.tween_property(_flying, "rotation:x", TAU * 4.0, FLIGHT_SECONDS)
	sequence.tween_method(_pull_camera.bind(start_position, away), 0.0, 1.0, PULL_BACK_SECONDS)
	sequence.chain().tween_callback(_show_the_end)


## Камера отъезжает назад и вверх, всё время глядя на улетающего кота.
func _pull_camera(amount: float, start_position: Vector3, away: Vector3) -> void:
	_camera.global_position = start_position + away * 18.0 * amount + Vector3.UP * 12.0 * amount
	var target := _flying.global_position + Vector3.UP * 1.5
	if _camera.global_position.distance_to(target) > 0.1:
		_camera.look_at(target, Vector3.UP)


func _show_the_end() -> void:
	if _in_credits:
		return
	var sequence := create_tween()
	sequence.tween_property(fade, "color:a", 0.85, 1.0)
	sequence.parallel().tween_property(the_end, "modulate:a", 1.0, 1.0)
	sequence.tween_interval(THE_END_SECONDS - 1.0)
	sequence.tween_callback(_show_credits)


func _show_credits() -> void:
	if _in_credits:
		return
	_in_credits = true
	the_end.modulate.a = 0.0
	fade.color.a = 1.0
	credits.visible = true
	var screen_height := get_viewport().get_visible_rect().size.y
	credits.position.y = screen_height
	var sequence := create_tween()
	sequence.tween_property(credits, "position:y", -credits.size.y, CREDITS_SECONDS)
	sequence.tween_callback(_finish)


func _unhandled_input(event: InputEvent) -> void:
	if not running or _in_credits:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		skip_to_credits()


func skip_to_credits() -> void:
	_show_credits()


func _finish() -> void:
	finished.emit()
	if quit_on_finish:
		get_tree().quit()
