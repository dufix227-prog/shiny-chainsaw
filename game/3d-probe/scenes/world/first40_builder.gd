@tool
extends Node3D

## Сборщик участка «первые 40 м». Ставит землю, тропу, лес, кусты, камни,
## брёвна и завал в конце — и всё это сохраняется в first40.tscn как узлы.
## Во время игры сборщик ничего не создаёт: мир — готовые данные сцены.
##
## Как пересобрать:
## - в редакторе: выбрать узел Builder → кнопка «Пересобрать участок»
##   в инспекторе → сохранить сцену (Ctrl+S);
## - из консоли: godot --headless --path game/3d-probe -s res://tools/build_first40.gd
##
## Одинаковый layout_seed всегда даёт одинаковый участок. Понравившийся вид
## можно закрепить, запомнив seed; поменять — ввести другое число.

const TreeShapes = preload("res://scenes/trees/tree_shapes.gd")

const WORLD_UNITS_PER_METRE := 12.24  # темп К1: 500 м ≈ 30 минут ходьбы
const SECTION_METRES := 40.0
const SECTION_END_Z := -SECTION_METRES * WORLD_UNITS_PER_METRE

# Долина закрыта склонами со всех сторон: позади старта и за завалом.
const START_SLOPE_Z := 22.0
const END_SLOPE_Z := SECTION_END_Z - 18.0
const SLOPE_STEEPNESS := 1.8  # подъём на единицу — около 60°, коту не забраться

const TERRAIN_X_MIN := -96.0
const TERRAIN_X_MAX := 96.0
const TERRAIN_Z_MAX := 70.0
const TERRAIN_Z_MIN := SECTION_END_Z - 70.0
const VISUAL_GRID_STEP := 2.0
const COLLISION_GRID_STEP := 3.0

const TERRAIN_MESH_PATH := "res://scenes/world/generated/first40_terrain_mesh.res"
const TERRAIN_SHAPE_PATH := "res://scenes/world/generated/first40_terrain_shape.res"
const TERRAIN_MATERIAL := "res://scenes/world/terrain_material.tres"

## Доля каждого вида в лесу (веса, не проценты).
const TREE_KINDS := [
	{"scene": "res://scenes/trees/spruce.tscn", "weight": 30},
	{"scene": "res://scenes/trees/pine.tscn", "weight": 25},
	{"scene": "res://scenes/trees/birch.tscn", "weight": 18},
	{"scene": "res://scenes/trees/oak.tscn", "weight": 15},
	{"scene": "res://scenes/trees/dead_tree.tscn", "weight": 7},
]
const BUSH_SCENE := "res://scenes/props/bush.tscn"
const SMALL_ROCK_SCENE := "res://scenes/props/small_rock.tscn"
const BIG_ROCK_SCENE := "res://scenes/props/big_rock.tscn"
const LOG_SCENE := "res://scenes/props/fallen_log.tscn"

const GENERATED_GROUPS := ["Terrain", "Forest", "Bushes", "Rocks", "FallenLogs", "Barrier"]

@export var layout_seed := 2026
@export_range(2.0, 20.0, 0.5) var path_min_width := 5.0
@export_range(2.0, 20.0, 0.5) var path_max_width := 11.0
## Насколько далеко тропа уходит вбок от прямой линии.
@export_range(0.0, 20.0, 0.5) var path_meander := 7.0
## От середины тропы до начала непроходимого склона.
@export_range(15.0, 60.0, 1.0) var valley_half_width := 34.0
## Среднее расстояние между деревьями у тропы.
@export_range(2.0, 8.0, 0.1) var tree_spacing := 3.4
@export_tool_button("Пересобрать участок", "Reload") var rebuild_button := _rebuild_in_editor

var _rng := RandomNumberGenerator.new()
var _center_noise := FastNoiseLite.new()
var _width_noise := FastNoiseLite.new()
var _ground_noise := FastNoiseLite.new()
var _scenes := {}


# --- Форма участка: тропа и рельеф -------------------------------------------

func setup_noise() -> void:
	_center_noise.seed = layout_seed
	_center_noise.frequency = 0.004
	_width_noise.seed = layout_seed + 1
	_width_noise.frequency = 0.012
	_ground_noise.seed = layout_seed + 2
	_ground_noise.frequency = 0.045


## Середина тропы по X на глубине z. Тропа плавно петляет.
func path_center_x(z: float) -> float:
	return _center_noise.get_noise_1d(z) * path_meander * 1.6


## Ширина тропы на глубине z: плавно сужается и расширяется между min и max.
func path_width(z: float) -> float:
	var amount := clampf(0.5 + _width_noise.get_noise_1d(z) * 1.2, 0.0, 1.0)
	return lerpf(path_min_width, path_max_width, amount)


func distance_from_path(x: float, z: float) -> float:
	return absf(x - path_center_x(z))


## 1 — на тропе, 0 — на траве, между ними мягкий край.
## На склонах позади старта и за завалом тропы нет.
func path_amount(x: float, z: float) -> float:
	var half_width := path_width(z) / 2.0
	var across := 1.0 - smoothstep(half_width - 0.8, half_width + 0.8, distance_from_path(x, z))
	var inside_valley := smoothstep(START_SLOPE_Z + 2.0, START_SLOPE_Z - 4.0, z) \
		* smoothstep(SECTION_END_Z - 6.0, SECTION_END_Z - 1.0, z)
	return across * inside_valley


func ground_height(x: float, z: float) -> float:
	var from_path := distance_from_path(x, z)
	var half_width := path_width(z) / 2.0
	# Тропа ровная, по сторонам — мягкие проходимые бугры.
	var bumps := _ground_noise.get_noise_2d(x, z) * 1.4 * smoothstep(half_width, half_width + 6.0, from_path)
	var past_side := maxf(from_path - valley_half_width, 0.0)
	var past_start := maxf(z - START_SLOPE_Z, 0.0)
	var past_end := maxf(END_SLOPE_Z - z, 0.0)
	var past_edge := maxf(past_side, maxf(past_start, past_end))
	return bumps + past_edge * SLOPE_STEEPNESS + past_edge * past_edge * 0.015


func spawn_position() -> Vector3:
	return Vector3(path_center_x(0.0), ground_height(path_center_x(0.0), 0.0) + 0.1, 0.0)


# --- Сборка --------------------------------------------------------------------

func _rebuild_in_editor() -> void:
	rebuild(get_tree().edited_scene_root)


## scene_root — корень сцены, которой будут принадлежать новые узлы
## (без этого они не сохранятся в файл).
func rebuild(scene_root: Node) -> void:
	setup_noise()
	_rng.seed = layout_seed
	_clear_generated()
	_build_terrain(scene_root)
	_plant_forest(scene_root)
	_plant_path_edges(scene_root)
	_scatter_big_rocks(scene_root)
	_scatter_fallen_logs(scene_root)
	_build_barrier(scene_root)
	_place_player_and_end_zone(scene_root)


func _clear_generated() -> void:
	for group_name in GENERATED_GROUPS:
		var old := get_node_or_null(NodePath(group_name))
		if old:
			remove_child(old)
			old.free()


func _new_group(group_name: String, scene_root: Node) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	group.owner = scene_root
	return group


func _place(scene_path: String, parent: Node3D, scene_root: Node, position: Vector3,
		yaw: float = 0.0, scale_factor: float = 1.0) -> Node3D:
	if not _scenes.has(scene_path):
		_scenes[scene_path] = load(scene_path)
	var instance: Node3D = _scenes[scene_path].instantiate()
	instance.position = position
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * scale_factor
	parent.add_child(instance, true)
	instance.owner = scene_root
	return instance


func _build_terrain(scene_root: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TERRAIN_MESH_PATH.get_base_dir()))
	var mesh := _terrain_mesh()
	ResourceSaver.save(mesh, TERRAIN_MESH_PATH)
	var shape := _terrain_collision()
	ResourceSaver.save(shape, TERRAIN_SHAPE_PATH)

	var group := _new_group("Terrain", scene_root)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = load(TERRAIN_MESH_PATH)
	ground.material_override = load(TERRAIN_MATERIAL)
	group.add_child(ground)
	ground.owner = scene_root
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	group.add_child(body)
	body.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	collision.shape = load(TERRAIN_SHAPE_PATH)
	body.add_child(collision)
	collision.owner = scene_root


func _terrain_mesh() -> ArrayMesh:
	var columns := int((TERRAIN_X_MAX - TERRAIN_X_MIN) / VISUAL_GRID_STEP) + 1
	var rows := int((TERRAIN_Z_MAX - TERRAIN_Z_MIN) / VISUAL_GRID_STEP) + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in rows:
		var z := TERRAIN_Z_MAX - row * VISUAL_GRID_STEP
		for column in columns:
			var x := TERRAIN_X_MIN + column * VISUAL_GRID_STEP
			vertices.append(Vector3(x, ground_height(x, z), z))
			normals.append(_ground_normal(x, z))
			colors.append(Color(path_amount(x, z), 0, 0))
	for row in rows - 1:
		for column in columns - 1:
			var top_left := row * columns + column
			var bottom_left := top_left + columns
			indices.append_array([top_left, bottom_left, top_left + 1, top_left + 1, bottom_left, bottom_left + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ground_normal(x: float, z: float) -> Vector3:
	var step := 0.5
	var slope_x := ground_height(x + step, z) - ground_height(x - step, z)
	var slope_z := ground_height(x, z + step) - ground_height(x, z - step)
	return Vector3(-slope_x, 2.0 * step, -slope_z).normalized()


## Коллизия земли — та же форма на более редкой сетке (файл меньше, ходьба та же).
func _terrain_collision() -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	var z := TERRAIN_Z_MAX
	while z - COLLISION_GRID_STEP >= TERRAIN_Z_MIN - 0.01:
		var x := TERRAIN_X_MIN
		while x + COLLISION_GRID_STEP <= TERRAIN_X_MAX + 0.01:
			var a := Vector3(x, ground_height(x, z), z)
			var b := Vector3(x + COLLISION_GRID_STEP, ground_height(x + COLLISION_GRID_STEP, z), z)
			var c := Vector3(x, ground_height(x, z - COLLISION_GRID_STEP), z - COLLISION_GRID_STEP)
			var d := Vector3(x + COLLISION_GRID_STEP, ground_height(x + COLLISION_GRID_STEP, z - COLLISION_GRID_STEP), z - COLLISION_GRID_STEP)
			faces.append_array([a, c, b, b, c, d])
			x += COLLISION_GRID_STEP
		z -= COLLISION_GRID_STEP
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _pick_tree_scene() -> String:
	var total := 0
	for kind in TREE_KINDS:
		total += kind.weight
	var roll := _rng.randi_range(1, total)
	for kind in TREE_KINDS:
		roll -= kind.weight
		if roll <= 0:
			return kind.scene
	return TREE_KINDS[0].scene


## Лес: густо у тропы, реже вглубь, редкие деревья на склонах.
## У каждого дерева своя коллизия ствола — никаких невидимых стен.
func _plant_forest(scene_root: Node) -> void:
	var forest := _new_group("Forest", scene_root)
	var bushes := _new_group("Bushes", scene_root)
	var z := TERRAIN_Z_MAX - 8.0
	while z > TERRAIN_Z_MIN + 8.0:
		var x := TERRAIN_X_MIN + 6.0
		while x < TERRAIN_X_MAX - 6.0:
			var tree_x := x + _rng.randf_range(-0.45, 0.45) * tree_spacing
			var tree_z := z + _rng.randf_range(-0.45, 0.45) * tree_spacing
			var from_path := distance_from_path(tree_x, tree_z)
			var half_width := path_width(tree_z) / 2.0
			var chance := _forest_density(from_path - half_width, from_path)
			if _rng.randf() < chance:
				var y := ground_height(tree_x, tree_z) - 0.3
				_place(_pick_tree_scene(), forest, scene_root, Vector3(tree_x, y, tree_z),
					_rng.randf() * TAU, _rng.randf_range(0.8, 1.3))
				# Подлесок рядом с частью деревьев.
				if _rng.randf() < 0.22:
					var bush_x := tree_x + _rng.randf_range(-2.0, 2.0)
					var bush_z := tree_z + _rng.randf_range(-2.0, 2.0)
					if distance_from_path(bush_x, bush_z) > path_width(bush_z) / 2.0:
						_place(BUSH_SCENE, bushes, scene_root, Vector3(bush_x, ground_height(bush_x, bush_z), bush_z),
							_rng.randf() * TAU, _rng.randf_range(0.8, 1.4))
			x += tree_spacing
		z -= tree_spacing


## Вероятность дерева в точке. from_edge — расстояние от края тропы.
func _forest_density(from_edge: float, from_path: float) -> float:
	if from_edge < 1.6:
		return 0.0  # сама тропа и полоса у края свободны
	if from_edge < 14.0:
		return 0.95
	if from_path < valley_half_width + 10.0:
		return 0.5
	if from_path < valley_half_width + 28.0:
		return 0.25
	return 0.0


## Кусты и мелкие камни вдоль краёв тропы.
func _plant_path_edges(scene_root: Node) -> void:
	var bushes: Node3D = get_node("Bushes")
	var rocks := _new_group("Rocks", scene_root)
	var z := START_SLOPE_Z
	while z > SECTION_END_Z - 10.0:
		for side: float in [-1.0, 1.0]:
			var half_width := path_width(z) / 2.0
			if _rng.randf() < 0.5:
				var bush_x := path_center_x(z) + side * (half_width + _rng.randf_range(-0.2, 2.5))
				_place(BUSH_SCENE, bushes, scene_root, Vector3(bush_x, ground_height(bush_x, z), z),
					_rng.randf() * TAU, _rng.randf_range(0.7, 1.3))
			if _rng.randf() < 0.3:
				var rock_x := path_center_x(z) + side * (half_width + _rng.randf_range(-1.5, 1.5))
				_place(SMALL_ROCK_SCENE, rocks, scene_root, Vector3(rock_x, ground_height(rock_x, z), z),
					_rng.randf() * TAU, _rng.randf_range(1.5, 3.2))
		z -= 2.4


## Крупные камни — непроходимые, у каждого коллизия по форме.
func _scatter_big_rocks(scene_root: Node) -> void:
	var rocks: Node3D = get_node("Rocks")
	var z := START_SLOPE_Z - 6.0
	while z > SECTION_END_Z:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var from_edge := _rng.randf_range(2.5, 16.0)
		var x := path_center_x(z) + side * (path_width(z) / 2.0 + from_edge)
		_place(BIG_ROCK_SCENE, rocks, scene_root, Vector3(x, ground_height(x, z) - 0.2, z),
			_rng.randf() * TAU, _rng.randf_range(0.3, 0.6))
		z -= _rng.randf_range(14.0, 30.0)


## Поваленные деревья в лесу — ещё одна преграда между стволами.
func _scatter_fallen_logs(scene_root: Node) -> void:
	var logs := _new_group("FallenLogs", scene_root)
	var z := START_SLOPE_Z - 4.0
	while z > SECTION_END_Z + 10.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		# Бревно длиной 10 не должно доставать до тропы при любом повороте.
		var from_edge := _rng.randf_range(7.0, valley_half_width - 12.0)
		var x := path_center_x(z) + side * (path_width(z) / 2.0 + from_edge)
		_place(LOG_SCENE, logs, scene_root, Vector3(x, ground_height(x, z) + 0.4, z), _rng.randf() * TAU)
		z -= _rng.randf_range(8.0, 18.0)


## Завал на 40 м: стена из брёвен поперёк всей долины, края уходят в склоны.
## Пять рядов выше прыжка кота, без наклонных брёвен — по ним нельзя забраться.
func _build_barrier(scene_root: Node) -> void:
	var barrier := _new_group("Barrier", scene_root)
	var center := path_center_x(SECTION_END_Z)
	var reach := valley_half_width + 4.0
	for layer in 5:
		var x := center - reach + _rng.randf_range(0.0, 3.0)
		while x < center + reach:
			var z := SECTION_END_Z + _rng.randf_range(-0.35, 0.35)
			var y := ground_height(x, SECTION_END_Z) + 0.5 + layer * 1.0
			var barrier_log := _place(LOG_SCENE, barrier, scene_root, Vector3(x, y, z), _rng.randf_range(-0.06, 0.06))
			barrier_log.rotation.x = _rng.randf_range(0.0, TAU)  # сук торчит в разные стороны
			x += _rng.randf_range(6.5, 8.0)
	for i in 4:
		var rock_x := center + _rng.randf_range(-12.0, 12.0)
		var rock_z := SECTION_END_Z + _rng.randf_range(2.5, 4.5)
		_place(BIG_ROCK_SCENE, barrier, scene_root, Vector3(rock_x, ground_height(rock_x, rock_z) - 0.3, rock_z),
			_rng.randf() * TAU, _rng.randf_range(0.3, 0.45))


func _place_player_and_end_zone(scene_root: Node) -> void:
	var player := scene_root.get_node_or_null("CatPlayer")
	if player:
		player.position = spawn_position()
	var end_zone := scene_root.get_node_or_null("EndZone")
	if end_zone:
		var zone_z := SECTION_END_Z + 9.0
		end_zone.position = Vector3(path_center_x(zone_z), ground_height(path_center_x(zone_z), zone_z) + 2.0, zone_z)
