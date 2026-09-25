class_name PigMinigame
extends Control

signal finished

const PIG_COUNT := 3
const FEED := 0
const HERD := 1

var opened := false
var paused := false
var phase := FEED
var player_position := Vector2(0.18, 0.5)
var pigs: Array[Vector2] = []
var fed: Array[bool] = []
var pen := Rect2(0.74, 0.28, 0.2, 0.44)
var status := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 28
	status.offset_bottom = 92
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	add_child(status)
	visible = false

func begin() -> void:
	opened = true
	paused = false
	phase = FEED
	player_position = Vector2(0.18, 0.5)
	pigs = [Vector2(0.35, 0.28), Vector2(0.48, 0.52), Vector2(0.36, 0.76)]
	fed = [false, false, false]
	visible = true
	_refresh_label()
	queue_redraw()

func _process(delta: float) -> void:
	if not opened or paused:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_position = (player_position + direction * delta * 0.38).clamp(Vector2(0.04, 0.08), Vector2(0.96, 0.92))
	queue_redraw()

func act() -> void:
	if not opened or paused:
		return
	var nearest := _nearest_pig()
	if nearest < 0:
		return
	if phase == FEED:
		fed[nearest] = true
		if not fed.has(false):
			phase = HERD
	else:
		var push := (pigs[nearest] - player_position).normalized()
		if push.is_zero_approx():
			push = Vector2.RIGHT
		pigs[nearest] = (pigs[nearest] + push * 0.16).clamp(Vector2(0.04, 0.08), Vector2(0.96, 0.92))
		if _all_in_pen():
			opened = false
			visible = false
			finished.emit()
	_refresh_label()
	queue_redraw()

func _nearest_pig() -> int:
	var result := -1
	var distance := 0.12
	for index in pigs.size():
		if phase == FEED and fed[index]:
			continue
		if phase == HERD and pen.has_point(pigs[index]):
			continue
		var candidate := player_position.distance_to(pigs[index])
		if candidate <= distance:
			distance = candidate
			result = index
	return result

func _all_in_pen() -> bool:
	for pig in pigs:
		if not pen.has_point(pig):
			return false
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("263522ef"))
	var arena := Rect2(size * Vector2(0.08, 0.14), size * Vector2(0.84, 0.76))
	draw_rect(arena, Color("71884b"), true)
	var pen_rect := Rect2(arena.position + pen.position * arena.size, pen.size * arena.size)
	draw_rect(pen_rect, Color("9c8058"), true)
	draw_rect(pen_rect, Color("e2c58d"), false, 4.0)
	draw_circle(arena.position + player_position * arena.size, 12.0, Color("e5a34f"))
	for index in pigs.size():
		var color := Color("f3c0bd") if phase == FEED and not fed[index] else Color("e58e96")
		draw_circle(arena.position + pigs[index] * arena.size, 11.0, color)

func _refresh_label() -> void:
	if phase == FEED:
		status.text = "Подбеги к свинкам и покорми · A / E\n%d / %d" % [fed.count(true), PIG_COUNT]
	else:
		status.text = "Загони свинок палкой в загон · A / E\n%d / %d" % [_pigs_in_pen(), PIG_COUNT]

func _pigs_in_pen() -> int:
	var count := 0
	for pig in pigs:
		if pen.has_point(pig):
			count += 1
	return count

func set_paused(value: bool) -> void:
	paused = value

func reset() -> void:
	opened = false
	paused = false
	visible = false
	phase = FEED
	pigs.clear()
	fed.clear()
