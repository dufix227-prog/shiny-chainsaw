extends PanelContainer

## Техническая отладочная панель (правило п.1 в game/ПРАВИЛА-ИНСТРУМЕНТОВ-2026-09-15.md).
## Показывает живое состояние пробы и телепортирует кота по метрам, чтобы
## приёмка и проверки агента не требовали повторного прохождения маршрута.
## Панель скрыта по умолчанию (F3), визуально отделена от игрового UI и не
## является частью релизного потока; удаление из probe.gd ничего не ломает.

const Route = preload("res://scripts/route.gd")

## Канонические метры из route.gd — точки приёмки этапов К4–К9.
const ROUTE_POINTS := [
	{"label": "Лес 0", "m": 0.0},
	{"label": "Церковь 40", "m": 40.0},
	{"label": "Стинт 100", "m": 100.0},
	{"label": "Братишкин 189", "m": 189.0},
	{"label": "Рыбалка 260", "m": 260.0},
	{"label": "Ферма 500", "m": 500.0},
]

## Ссылка на probe.gd без типа: обратный preload главного скрипта дал бы
## циклическую зависимость; панели достаточно duck-typing по полям.
var probe: Variant = null

var state_label: Label
var metres_edit: LineEdit


func setup(owner_probe: Variant) -> void:
	probe = owner_probe
	visible = false
	_build()


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	if not visible or probe == null:
		return
	var lines: PackedStringArray = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if is_instance_valid(probe.player):
		lines.append("Метры: %.1f / %d" % [Route.metres(probe.player.position), int(Route.LENGTH)])
		lines.append("Z: %.1f" % probe.player.position.z)
	if probe.needs != null:
		lines.append(probe.needs.status())
	if probe.day_cycle != null:
		lines.append("%s · %s" % [probe.day_cycle.status_text(), probe.weather.status_text()])
	lines.append("Старт: %s · пауза: %s" % [probe.started, probe.paused])
	state_label.text = "\n".join(lines)


func _teleport(metres: float) -> void:
	metres = clampf(metres, 0.0, Route.LENGTH)
	if probe == null or not is_instance_valid(probe.player):
		return
	# Вне активной пробы (катсцена, пауза, титры) телепорт не действует:
	# состояние сцены тогда управляется своими скриптами.
	if not probe.started or probe.paused:
		return
	probe.player.position = Vector3(0, 0.1, Route.world_z(metres))
	probe.player.velocity = Vector3.ZERO
	probe.route.discover(probe.player.position)


func _on_quick_jump(metres: float) -> void:
	_teleport(metres)


func _on_edit_submitted(text: String) -> void:
	if text.is_valid_float():
		_teleport(text.to_float())
		metres_edit.release_focus()


func _build() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	var title := Label.new()
	title.text = "Отладка · F3"
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)

	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 12)
	column.add_child(state_label)

	var quick := HBoxContainer.new()
	for point in ROUTE_POINTS:
		var button := Button.new()
		button.text = point.label
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_quick_jump.bind(point.m))
		button.pressed.connect(button.release_focus)
		quick.add_child(button)
	column.add_child(quick)

	var row := HBoxContainer.new()
	metres_edit = LineEdit.new()
	metres_edit.placeholder_text = "метры"
	metres_edit.custom_minimum_size = Vector2(70, 0)
	metres_edit.text_submitted.connect(_on_edit_submitted)
	row.add_child(metres_edit)
	column.add_child(row)

	# К10: сутки и погода проверяются долго (весь круг — 42 реальные минуты),
	# поэтому в отладке есть быстрые кнопки времени и погоды. Это инструмент
	# приёмки, в релизный поток не входит.
	var clock := HBoxContainer.new()
	for entry in [["Утро", 0.0], ["День", 0.30], ["Вечер", 0.55], ["Ночь", 0.72],
			["Рассвет", 0.92]]:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_set_day.bind(entry[1]))
		button.pressed.connect(button.release_focus)
		clock.add_child(button)
	column.add_child(clock)

	var sky := HBoxContainer.new()
	for entry in [["Ясно", 0], ["Дождь", 1], ["Ливень", 2]]:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_set_weather.bind(entry[1]))
		button.pressed.connect(button.release_focus)
		sky.add_child(button)
	column.add_child(sky)


func _on_set_day(fraction: float) -> void:
	# Доля круга, а не час: так кнопка не зависит от того, где сейчас фаза.
	if probe == null or probe.day_cycle == null or not probe.started or probe.paused:
		return
	probe.day_cycle.seconds = clampf(fraction, 0.0, 0.999) * probe.day_cycle.DAY_SECONDS
	probe.sleeping = false
	probe._sync_sky()


func _on_set_weather(kind: int) -> void:
	if probe == null or probe.weather == null or not probe.started or probe.paused:
		return
	probe.weather.randomness = false
	match kind:
		0:
			probe.weather.clear()
		1:
			probe.weather.target = probe.weather.RAIN
		2:
			probe.weather.start_sudden()
