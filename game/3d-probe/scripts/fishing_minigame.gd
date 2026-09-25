class_name FishingMinigame
extends Control

signal caught(result: Dictionary)
signal closed

const FishingData = preload("res://scripts/fishing_data.gd")
const HOOK_WINDOW := 4.0
const MIN_BITE_DELAY := 1.5
const MAX_BITE_DELAY := 4.0

enum Phase { READY, WAITING, HOOK }

var opened := false
var paused := false
var phase := Phase.READY
var phase_time := 0.0
var attempts := 0
var successes := 0
var rng := RandomNumberGenerator.new()
var status_label: Label
var timer_bar: ProgressBar
var action_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	rng.seed = 8260
	_build_ui()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("102634dd")
	add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -150)
	panel.size = Vector2(560, 300)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	add_child(panel)
	var title := Label.new()
	title.text = "РЫБАЛКА · ОЗЕРО 260 М"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	panel.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(status_label)
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(520, 34)
	timer_bar.max_value = HOOK_WINDOW
	timer_bar.show_percentage = false
	panel.add_child(timer_bar)
	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(260, 50)
	action_button.pressed.connect(act)
	panel.add_child(action_button)
	var close := Button.new()
	close.text = "B · Уйти от озера"
	close.pressed.connect(close_game)
	panel.add_child(close)

func begin() -> void:
	opened = true
	paused = false
	visible = true
	phase = Phase.READY
	phase_time = 0.0
	_refresh("Удочка готова.")
	action_button.grab_focus()

func act() -> void:
	if not opened or paused:
		return
	match phase:
		Phase.READY:
			attempts += 1
			phase = Phase.WAITING
			phase_time = rng.randf_range(MIN_BITE_DELAY, MAX_BITE_DELAY)
			_refresh("Заброс выполнен. Жди поклёвку…")
		Phase.WAITING:
			phase = Phase.READY
			phase_time = 0.0
			_refresh("Слишком рано. Улов сорвался.")
		Phase.HOOK:
			successes += 1
			var result := FishingData.catch_for_roll(rng.randi_range(0, 99), rng.randi_range(1, 3))
			phase = Phase.READY
			phase_time = 0.0
			_refresh("Поймано: %s" % _result_name(result))
			caught.emit(result)

func _process(delta: float) -> void:
	if not opened or paused or phase == Phase.READY:
		return
	phase_time -= delta
	if phase == Phase.WAITING and phase_time <= 0.0:
		phase = Phase.HOOK
		phase_time = HOOK_WINDOW
		_refresh("КЛЮЁТ! Подсекай сейчас!")
	elif phase == Phase.HOOK and phase_time <= 0.0:
		phase = Phase.READY
		phase_time = 0.0
		_refresh("Поздно. Улов сорвался.")
	elif phase == Phase.HOOK:
		timer_bar.value = phase_time

func _result_name(result: Dictionary) -> String:
	if result.kind == "coins":
		return "%d мон." % int(result.count)
	return String(result.name)

func _refresh(text: String) -> void:
	status_label.text = text
	timer_bar.visible = phase == Phase.HOOK
	timer_bar.value = phase_time
	action_button.text = "A / E · Подсечь" if phase == Phase.HOOK else "A / E · Забросить"

func set_paused(value: bool) -> void:
	paused = value

func close_game(notify := true) -> void:
	opened = false
	paused = false
	visible = false
	phase = Phase.READY
	phase_time = 0.0
	if notify:
		closed.emit()

func reset() -> void:
	close_game(false)
	attempts = 0
	successes = 0
	rng.seed = 8260
