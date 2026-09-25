class_name FullMapHUD
extends Control

signal close_requested

## Полная карта 500-метрового маршрута: открытые зоны растут по посещению,
## метки сцен — по факту встречи (без спойлеров), текущие метры в подписи.

const Route = preload("res://scripts/route.gd")
const World = preload("res://scripts/world.gd")
var route: Route
var player_position := Vector3.ZERO
var opened := false
var close_button := Button.new()
var info := Label.new()
var map_canvas: MapCanvas
var _total_cells := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.08, 0.07, 0.78)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243c35")
	style.border_color = Color("c5ae7a")
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "КАРТА МАРШРУТА · 500 М"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	column.add_child(info)
	map_canvas = MapCanvas.new()
	map_canvas.custom_minimum_size = Vector2(650, 410)
	map_canvas.route = route
	map_canvas.owner_hud = self
	column.add_child(map_canvas)
	close_button.text = "M / B · Закрыть карту"
	close_button.custom_minimum_size.y = 42
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(func(): close_requested.emit())
	column.add_child(close_button)
	visible = false

func set_open(value: bool) -> void:
	opened = value
	visible = value
	if value:
		call_deferred("_focus_close")

func _focus_close() -> void:
	close_button.grab_focus()

func refresh() -> void:
	if route == null:
		return
	# Открытия существуют только в проходимых клетках, так что счётчик — размер словаря;
	# полный перебор 24 тысяч клеток на каждый кадр не нужен.
	if _total_cells < 0:
		_total_cells = MapCanvas.walkable_cells().size()
	var found := route.discovered.size()
	info.text = "Открыто: %d из %d клеток · осталось: %d · метры: %.0f" % [found, _total_cells, _total_cells - found, Route.metres(player_position)]
	if is_instance_valid(map_canvas):
		map_canvas.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if opened and (event.is_action_pressed("full_map") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()

class MapCanvas extends Control:
	var route: Route
	var owner_hud: FullMapHUD
	const MARKERS := [
		{"id": "tree", "pos": Vector3(-3.25, 0, World.TREE_Z), "color": Color("6e9a55")},
	]

	static func walkable_cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for x in range(-2, 6):
			for z in range(floori(World.FRONT_Z / Route.CELL), ceili(World.BACK_Z / Route.CELL) + 1):
				result.append(Vector2i(x, z))
		return result

	static func world_bounds() -> Rect2:
		return Rect2(Vector2(-5.0, World.FRONT_Z), Vector2(17.0, World.BACK_Z - World.FRONT_Z))

	func content_rect() -> Rect2:
		var bounds := world_bounds()
		var scale_factor := minf((size.x - 24) / bounds.size.x, (size.y - 24) / bounds.size.y)
		var content_size := bounds.size * scale_factor
		return Rect2((size - content_size) / 2, content_size)

	func world_to_map(world: Vector2) -> Vector2:
		var bounds := world_bounds()
		var content := content_rect()
		return content.position + (world - bounds.position) * content.size / bounds.size

	static func cell_tint(cell: Vector2i, discovered: bool) -> Color:
		if not discovered:
			return Color("3e4a45")
		var world := Vector2(cell.x, cell.y) * Route.CELL
		if world.x < -4:
			return Color("567c86")
		if absf(world.x) < 1.9:
			return Color("c7ad76")
		return Color("81905a")

	static func marker_tint(discovered: bool, landmark: Color) -> Color:
		return landmark if discovered else Color("718076")

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, Color("101a19"))
		if route == null:
			return
		var content := content_rect()
		var scale_factor := content.size.x / world_bounds().size.x
		# Вся карта — вытянутая полоса маршрута; рисуем только колонку вокруг кота.
		var player_cell_z := floori(owner_hud.player_position.z / Route.CELL)
		for x in range(-2, 6):
			for z in range(player_cell_z - 6, player_cell_z + 7):
				var cell := Vector2i(x, z)
				var world := Vector2(cell.x, cell.y) * Route.CELL
				var patch := Rect2(world_to_map(world), Vector2.ONE * Route.CELL * scale_factor).intersection(content)
				var discovered := route.discovered.has(cell)
				draw_rect(patch, cell_tint(cell, discovered))
				draw_rect(patch, Color("67706555"), false, 1)
		for marker in MARKERS:
			var pos: Vector3 = marker.pos
			var cell := Vector2i(floori(pos.x / Route.CELL), floori(pos.z / Route.CELL))
			var tint: Color = marker_tint(route.discovered.has(cell), marker.color)
			draw_circle(world_to_map(Vector2(pos.x, pos.z)), 8, tint)
		for id in route.visible_scene_ids():
			var scene: Dictionary = {}
			for candidate in Route.SCENES:
				if candidate.id == id:
					scene = candidate
			if scene.is_empty():
				continue
			var pos := Route.scene_position(scene)
			var marker := world_to_map(Vector2(pos.x, pos.z))
			if not content.has_point(marker):
				continue
			draw_circle(marker, 7, Color("e8c86a"))
			draw_circle(marker, 3, Color("8a6a2a"))
		var player := world_to_map(Vector2(owner_hud.player_position.x, owner_hud.player_position.z))
		draw_circle(player, 7, Color("f7dfad"))
		draw_circle(player, 3, Color("b87837"))
		draw_rect(area, Color("b3a37b"), false, 2)
