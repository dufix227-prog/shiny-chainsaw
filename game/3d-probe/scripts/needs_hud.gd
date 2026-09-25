extends PanelContainer

signal mode_requested
signal eat_requested
signal rest_requested
signal pause_requested

const Needs = preload("res://scripts/needs.gd")
var mode_button: Button
var eat_button: Button
var rest_button: Button
var pause_button: Button
var food_bar: ProgressBar
var stamina_bar: ProgressBar
var status_label: Label
var values: VBoxContainer

func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var heading := Label.new()
	heading.text = "ПРОБА ТЕМПА И НУЖД"
	heading.add_theme_font_size_override("font_size", 14)
	column.add_child(heading)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	mode_button = _button(controls, "", func(): mode_requested.emit())
	pause_button = _button(controls, "", func(): pause_requested.emit())
	values = VBoxContainer.new()
	column.add_child(values)
	food_bar = _bar(values, "Сытость")
	stamina_bar = _bar(values, "Выносливость")
	var actions := HBoxContainer.new()
	values.add_child(actions)
	eat_button = _button(actions, "", func(): eat_requested.emit())
	rest_button = _button(actions, "", func(): rest_requested.emit())
	var note := Label.new()
	note.text = "Временный баланс · не режим «хард»"
	note.add_theme_font_size_override("font_size", 12)
	values.add_child(note)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	column.add_child(status_label)

func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _bar(parent: Control, title: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 115
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.step = 0.1
	row.add_child(bar)
	return bar

func refresh(needs: Needs, paused: bool, pickup_mode: bool = false) -> void:
	values.visible = needs.enabled
	# Let the container shrink again when the optional controls are hidden.
	size = get_combined_minimum_size()
	mode_button.text = "N · Нужды: вкл" if needs.enabled else "N · Нужды: выкл"
	pause_button.text = "P · Продолжить" if paused else "P · Пауза"
	mode_button.disabled = paused
	eat_button.text = "E · Поесть (%d)" % needs.portions
	eat_button.visible = not pickup_mode
	eat_button.disabled = paused or not needs.can_eat()
	rest_button.text = "L1 / Space · Встать" if needs.resting else "L1 / Space · Сесть"
	rest_button.disabled = paused
	food_bar.value = needs.food
	stamina_bar.value = needs.stamina
	status_label.text = "Пауза · движение и нужды остановлены" if paused else needs.status()
	if not needs.enabled and not paused:
		status_label.text = "Нужды выключены · сначала нажми Y/N, затем L1/Space для отдыха"
	if pickup_mode:
		status_label.text = status_label.text.replace("E — поесть", "B — открыть инвентарь")
