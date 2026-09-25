extends Control

## Локальная карта: следует за котом, показывает только открытое.
## Дальняя часть маршрута — нейтральные зоны (вода/дорога/поляна) без
## конкретных мест; метки сцен появляются только по факту встречи.

const Route = preload("res://scripts/route.gd")
const World = preload("res://scripts/world.gd")

var route: RefCounted
var player_position := Vector3.ZERO


func world_to_map(world: Vector2) -> Vector2:
	var scale_factor := minf((size.x - 16) / 20.0, (size.y - 16) / 34.0)
	return size / 2 + (world - Vector2(player_position.x, player_position.z)) * scale_factor


func _world_rect(corner_a: Vector2, corner_b: Vector2) -> Rect2:
	var a := world_to_map(corner_a)
	var b := world_to_map(corner_b)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(a.x - b.x), absf(a.y - b.y)))


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("273b38"))
	if route == null:
		return
	var scale_factor := minf((size.x - 16) / 20.0, (size.y - 16) / 34.0)
	# Полоса маршрута на всю длину: берег слева, дорога в центре, поляна справа.
	var strip := _world_rect(Vector2(-5.0, World.BACK_Z), Vector2(12.0, World.FRONT_Z)).intersection(area)
	if strip.has_area():
		draw_rect(strip, Color("4a5a43"))
		var water := _world_rect(Vector2(-30.0, World.BACK_Z), Vector2(-5.2, World.FRONT_Z)).intersection(strip)
		if water.has_area():
			draw_rect(water, Color("40616d"))
		var road := _world_rect(Vector2(-1.8, World.BACK_Z), Vector2(1.8, World.FRONT_Z)).intersection(strip)
		if road.has_area():
			draw_rect(road, Color("6b5f45"))
			var stripe := _world_rect(Vector2(-1.4, World.BACK_Z), Vector2(1.4, World.FRONT_Z)).intersection(road)
			if stripe.has_area():
				draw_rect(stripe, Color("c7ad76"))
	# Открытые клетки сканируем окном вокруг кота: словарь открытий на 500 м
	# слишком велик для покадрового полного перебора.
	var center_cell := Vector2i(floori(player_position.x / Route.CELL), floori(player_position.z / Route.CELL))
	var visible_rows := ceili(size.y / scale_factor / Route.CELL / 2.0) + 2
	for x in range(-3, 6):
		for z in range(center_cell.y - visible_rows, center_cell.y + visible_rows + 1):
			var cell := Vector2i(x, z)
			if not route.discovered.has(cell):
				continue
			var world := Vector2(cell.x, cell.y) * Route.CELL
			var pixel := world_to_map(world)
			var tint := Color("81905a")
			if world.x < -4:
				tint = Color("567c86")
			elif absf(world.x) < 1.9:
				tint = Color("c7ad76")
			var patch := Rect2(pixel, Vector2.ONE * Route.CELL * scale_factor).intersection(area)
			if patch.has_area():
				draw_rect(patch, tint)
	# Метки сцен — только встреченные, без будущих мест.
	for id in route.visible_scene_ids():
		var scene: Dictionary = {}
		for candidate in Route.SCENES:
			if candidate.id == id:
				scene = candidate
		if scene.is_empty():
			continue
		var pos := Route.scene_position(scene)
		var marker := world_to_map(Vector2(pos.x, pos.z))
		if not area.has_point(marker):
			continue
		draw_circle(marker, 6, Color("e8c86a"))
		draw_circle(marker, 3, Color("8a6a2a"))
	var marker := world_to_map(Vector2(player_position.x, player_position.z))
	draw_circle(marker, 6, Color("f7dfad"))
	draw_circle(marker, 3, Color("b87837"))
	draw_rect(area, Color("b3a37b"), false, 2)
