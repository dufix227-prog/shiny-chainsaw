class_name StreamMinigame
extends Control

signal finished(success: bool)

const STREAM_SECONDS := 300.0
const REACTIONS_REQUIRED := 3
const BOT_COUNT := 8

var opened := false
var elapsed := 0.0
var duration := STREAM_SECONDS
var success := true
var reactions := 0
var reaction_phase := false
var paused := false
var player_position := Vector2(0.5, 0.5)
var bots: Array[Vector2] = []
var status := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	add_child(status)
	visible = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("10131bee"))
	var arena := Rect2(size * Vector2(0.2, 0.2), size * Vector2(0.6, 0.6))
	draw_rect(arena, Color("26344b"), true)
	draw_rect(arena, Color("9bb1d4"), false, 3.0)
	if reaction_phase:
		return
	draw_circle(arena.position + player_position * arena.size, 12.0, Color("f1d674"))
	for bot in bots:
		draw_circle(arena.position + bot * arena.size, 10.0, Color("c45757"))

func begin(seconds := STREAM_SECONDS) -> void:
	duration = seconds
	elapsed = 0.0
	success = true
	reactions = 0
	reaction_phase = false
	paused = false
	player_position = Vector2(0.5, 0.5)
	bots.clear()
	for index in BOT_COUNT:
		var angle := TAU * index / BOT_COUNT
		bots.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.44)
	opened = true
	visible = true
	_refresh_label()

func _process(delta: float) -> void:
	if not opened or reaction_phase or paused:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_position = (player_position + direction * delta * 0.35).clamp(Vector2.ZERO, Vector2.ONE)
	for index in bots.size():
		bots[index] = bots[index].move_toward(player_position, delta * (0.025 + index * 0.006))
		if bots[index].distance_to(player_position) < 0.045:
			success = false
			bots[index] = Vector2(0.05 + index * 0.4, 0.05)
	elapsed += delta
	if elapsed >= duration:
		reaction_phase = true
	_refresh_label()
	queue_redraw()

func react() -> void:
	if not opened or not reaction_phase:
		return
	reactions += 1
	if reactions >= REACTIONS_REQUIRED:
		opened = false
		visible = false
		finished.emit(success)
	else:
		_refresh_label()

func _refresh_label() -> void:
	if reaction_phase:
		status.text = "Реакция на сообщение чата · A\n%d / %d" % [reactions, REACTIONS_REQUIRED]
	else:
		status.text = "СЛИЗАРИО · БОТЫ\nПродержаться: %d с" % ceili(maxf(0.0, duration - elapsed))

func _unhandled_input(event: InputEvent) -> void:
	if opened and reaction_phase and event.is_action_pressed("ui_accept") and not event.is_echo():
		react()
		get_viewport().set_input_as_handled()

func reset() -> void:
	opened = false
	visible = false
	elapsed = 0.0
	reaction_phase = false
	reactions = 0
	paused = false
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value
