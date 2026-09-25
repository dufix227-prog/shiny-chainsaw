@tool
extends Node3D

## Сборщик участка «первые 40 м». Ставит блочную землю, тропу, лес, кусты,
## камни, брёвна и завал в конце — и всё это сохраняется в first40.tscn
## как узлы. Во время игры сборщик ничего не создаёт.
##
## Как пересобрать:
## - в редакторе: выбрать узел Builder → кнопка «Пересобрать участок»
##   в инспекторе → сохранить сцену (Ctrl+S);
## - из консоли: godot --headless --path game/3d-probe -s res://tools/build_first40.gd
##
## Одинаковый layout_seed всегда даёт одинаковый участок.
##
## Мир блочный: блок 1×1×1, кот ≈ 2,5 блока ростом и запрыгивает на 1 блок.
## Центры блоков земли — в целых X/Z, поэтому деревья тоже ставятся в целые точки.

const BlockTerrain = preload("res://scenes/world/block_terrain.gd")

const WORLD_UNITS_PER_METRE := 12.24  # темп К1: 500 м ≈ 30 минут ходьбы
const SECTION_METRES := 40.0
const SECTION_END_Z := -SECTION_METRES * WORLD_UNITS_PER_METRE

# Долина закрыта обрывами со всех сторон: позади старта и за завалом.
const START_CLIFF_Z := 22.0
const END_CLIFF_Z := SECTION_END_Z - 18.0
## Обрыв идёт уступами: каждые CLIFF_STEP_WIDTH блоков вглубь — на
## CLIFF_STEP_HEIGHT блоков вверх. Кот прыгает на 1 блок, уступ ему не взять.
const CLIFF_STEP_WIDTH := 3.0
const CLIFF_STEP_HEIGHT := 4
const CLIFF_STEPS := 5

const TERRAIN_X_MIN := -80
const TERRAIN_X_MAX := 80
const TERRAIN_Z_MAX := 50
const TERRAIN_Z_MIN := -550

const TERRAIN_MESH_PATH := "res://scenes/world/generated/first40_terrain_mesh.res"
const TERRAIN_SHAPE_PATH := "res://scenes/world/generated/first40_terrain_shape.res"
const TERRAIN_MATERIAL := "res://scenes/world/terrain_material.tres"

## Доля каждого вида в лесу (веса, не проценты).
const TREE_KINDS := [
	{"scene": "res://scenes/trees/spruce.tscn", "weight": 24},
	{"scene": "res://scenes/trees/small_spruce.tscn", "weight": 10},
	{"scene": "res://scenes/trees/pine.tscn", "weight": 18},
	{"scene": "res://scenes/trees/birch.tscn", "weight": 16},
	{"scene": "res://scenes/trees/oak.tscn", "weight": 16},
	{"scene": "res://scenes/trees/big_oak.tscn", "weight": 5},
	{"scene": "res://scenes/trees/dead_tree.tscn", "weight": 6},
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
## От середины тропы до начала обрыва.
@export_range(15.0, 60.0, 1.0) var valley_half_width := 34.0
## Среднее расстояние между деревьями у тропы.
@export_range(2.0, 8.0, 0.1) var tree_spacing := 3.4
@export_tool_button("Пересобрать участок", "Reload") var rebuild_button := _rebuild_in_editor

var _rng := RandomNumberGenerator.new()
var _center_noise := FastNoiseLite.new()
var _width_noise := FastNoiseLite.new()
var _ground_noise := FastNoiseLite.new()
var _scenes := {}
var _occupied := {}  # занятые столбики земли: Vector2i → true


# --- Форма участка: тропа и рельеф -------------------------------------------

func setup_noise() -> void:
	_center_noise.seed = layout_seed
	_center_noise.frequency = 0.004
	_width_noise.seed = layout_seed + 1
	_width_noise.frequency = 0.012
	_ground_noise.seed = layout_seed + 2
	_ground_noise.frequency = 0.06


## Середина тропы по X на глубине z. Тропа плавно петляет.
func path_center_x(z: float) -> float:
	return _center_noise.get_noise_1d(z) * path_meander * 1.6


## Ширина тропы на глубине z: плавно сужается и расширяется между min и max.
func path_width(z: float) -> float:
	var amount := clampf(0.5 + _width_noise.get_noise_1d(z) * 1.2, 0.0, 1.0)
	return lerpf(path_min_width, path_max_width, amount)


func distance_from_path(x: float, z: float) -> float:
	return absf(x - path_center_x(z))


func inside_valley_z(z: float) -> bool:
	return z < START_CLIFF_Z and z > END_CLIFF_Z


## Блок тропы: центр столбика ближе к середине тропы, чем полширины.
func is_path_block(x: int, z: int) -> bool:
	return z < START_CLIFF_Z - 4.0 and z > SECTION_END_Z - 3.0 \
		and distance_from_path(x, z) < path_width(z) / 2.0


## Высота верха столбика земли в блоках (центр столбика — в целых x, z).
func block_height(x: int, z: int) -> int:
	if is_path_block(x, z):
		return 0
	var from_path := distance_from_path(x, z)
	var half_width := path_width(z) / 2.0
	# У тропы земля ровная, дальше — бугры высотой в блок.
	var bump_strength := smoothstep(half_width + 1.0, half_width + 5.0, from_path)
	# Под завалом тоже ровно, иначе под брёвнами остались бы щели.
	if absf(z - SECTION_END_Z) < 5.0:
		bump_strength = 0.0
	var bumps := roundi(_ground_noise.get_noise_2d(x, z) * 1.6 * bump_strength)
	var past_edge := maxf(from_path - valley_half_width, 0.0)
	past_edge = maxf(past_edge, maxf(z - START_CLIFF_Z, END_CLIFF_Z - z))
	var steps := mini(ceili(past_edge / CLIFF_STEP_WIDTH), CLIFF_STEPS)
	return bumps + steps * CLIFF_STEP_HEIGHT


func spawn_position() -> Vector3:
	var x := roundi(path_center_x(0.0))
	return Vector3(x, block_height(x, 0) + 0.1, 0.0)


# --- Сборка --------------------------------------------------------------------

func _rebuild_in_editor() -> void:
	rebuild(get_tree().edited_scene_root)


## scene_root — корень сцены, которой будут принадлежать новые узлы
## (без этого они не сохранятся в файл).
func rebuild(scene_root: Node) -> void:
	setup_noise()
	_rng.seed = layout_seed
	_occupied.clear()
	_clear_generated()
	_build_terrain(scene_root)
	_build_barrier(scene_root)
	_scatter_big_rocks(scene_root)
	_scatter_fallen_logs(scene_root)
	_plant_forest(scene_root)
	_plant_path_edges(scene_root)
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


## Ставит сцену на верх столбика (x, z). Поворот — только на 90°, чтобы
## блоки дерева совпадали с блоками земли.
func _place(scene_path: String, parent: Node3D, scene_root: Node, x: int, z: int, quarter_turns: int = 0,
		height_offset: float = 0.0) -> Node3D:
	if not _scenes.has(scene_path):
		_scenes[scene_path] = load(scene_path)
	var instance: Node3D = _scenes[scene_path].instantiate()
	instance.position = Vector3(x, block_height(x, z) + height_offset, z)
	instance.rotation.y = quarter_turns * PI / 2.0
	parent.add_child(instance, true)
	instance.owner = scene_root
	return instance


## Занять столбики вокруг (x, z) радиусом radius. false — место уже занято.
func _claim(x: int, z: int, radius: int = 0) -> bool:
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if _occupied.has(Vector2i(x + dx, z + dz)):
				return false
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			_occupied[Vector2i(x + dx, z + dz)] = true
	return true


func _build_terrain(scene_root: Node) -> void:
	var terrain := BlockTerrain.new()
	terrain.first_x = TERRAIN_X_MIN
	terrain.first_z = TERRAIN_Z_MAX
	terrain.width = TERRAIN_X_MAX - TERRAIN_X_MIN + 1
	terrain.depth = TERRAIN_Z_MAX - TERRAIN_Z_MIN + 1
	terrain.heights.resize(terrain.width * terrain.depth)
	terrain.is_path.resize(terrain.width * terrain.depth)
	for row in terrain.depth:
		var z := TERRAIN_Z_MAX - row
		for column in terrain.width:
			var x := TERRAIN_X_MIN + column
			terrain.heights[column + row * terrain.width] = block_height(x, z)
			terrain.is_path[column + row * terrain.width] = 1 if is_path_block(x, z) else 0

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TERRAIN_MESH_PATH.get_base_dir()))
	ResourceSaver.save(terrain.build_mesh(), TERRAIN_MESH_PATH, ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(terrain.build_collision(), TERRAIN_SHAPE_PATH, ResourceSaver.FLAG_COMPRESS)

	var group := _new_group("Terrain", scene_root)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ResourceLoader.load(TERRAIN_MESH_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	ground.material_override = load(TERRAIN_MATERIAL)
	group.add_child(ground)
	ground.owner = scene_root
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	group.add_child(body)
	body.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	collision.shape = ResourceLoader.load(TERRAIN_SHAPE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	body.add_child(collision)
	collision.owner = scene_root


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


## Лес: густо у тропы, реже вглубь, редкие деревья на уступах обрыва.
## У каждого дерева своя коллизия ствола — никаких невидимых стен.
func _plant_forest(scene_root: Node) -> void:
	var forest := _new_group("Forest", scene_root)
	var bushes := _new_group("Bushes", scene_root)
	var z := TERRAIN_Z_MAX - 6.0
	while z > TERRAIN_Z_MIN + 6.0:
		var x := TERRAIN_X_MIN + 5.0
		while x < TERRAIN_X_MAX - 5.0:
			var tree_x := roundi(x + _rng.randf_range(-0.45, 0.45) * tree_spacing)
			var tree_z := roundi(z + _rng.randf_range(-0.45, 0.45) * tree_spacing)
			var from_path := distance_from_path(tree_x, tree_z)
			var chance := _forest_density(from_path - path_width(tree_z) / 2.0, from_path)
			if _rng.randf() < chance and _claim(tree_x, tree_z, 1):
				var scene := _pick_tree_scene()
				_place(scene, forest, scene_root, tree_x, tree_z, _rng.randi_range(0, 3))
				# Подлесок рядом с частью деревьев.
				if _rng.randf() < 0.25:
					var bush_x := tree_x + _rng.randi_range(-3, 3)
					var bush_z := tree_z + _rng.randi_range(-3, 3)
					if not is_path_block(bush_x, bush_z) and _claim(bush_x, bush_z):
						_place(BUSH_SCENE, bushes, scene_root, bush_x, bush_z, _rng.randi_range(0, 3))
			x += tree_spacing
		z -= tree_spacing


## Вероятность дерева в точке. from_edge — расстояние от края тропы.
func _forest_density(from_edge: float, from_path: float) -> float:
	if from_edge < 2.0:
		return 0.0  # сама тропа и полоса у края свободны
	if from_edge < 14.0:
		return 0.95
	if from_path < valley_half_width + 3.0:
		return 0.55
	if from_path < valley_half_width + CLIFF_STEP_WIDTH * CLIFF_STEPS + 8.0:
		return 0.35
	return 0.0


## Кусты и мелкие камни вдоль краёв тропы.
func _plant_path_edges(scene_root: Node) -> void:
	var bushes: Node3D = get_node("Bushes")
	var rocks: Node3D = get_node("Rocks")
	var z := START_CLIFF_Z - 5.0
	while z > SECTION_END_Z - 2.0:
		for side: float in [-1.0, 1.0]:
			var edge := path_center_x(z) + side * path_width(z) / 2.0
			if _rng.randf() < 0.45:
				var bush_x := roundi(edge + side * _rng.randf_range(1.0, 3.0))
				if _claim(bush_x, roundi(z)):
					_place(BUSH_SCENE, bushes, scene_root, bush_x, roundi(z), _rng.randi_range(0, 3))
			if _rng.randf() < 0.35:
				var rock_x := roundi(edge + side * _rng.randf_range(-1.5, 1.5))
				if _claim(rock_x, roundi(z)):
					_place(SMALL_ROCK_SCENE, rocks, scene_root, rock_x, roundi(z), _rng.randi_range(0, 3))
		z -= 2.0


## Крупные камни — непроходимые, у каждого коллизия по его блокам.
func _scatter_big_rocks(scene_root: Node) -> void:
	var rocks := _new_group("Rocks", scene_root)
	var z := START_CLIFF_Z - 8.0
	while z > SECTION_END_Z + 6.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := roundi(path_center_x(z) + side * (path_width(z) / 2.0 + _rng.randf_range(4.0, 16.0)))
		if _claim(x, roundi(z), 2):
			_place(BIG_ROCK_SCENE, rocks, scene_root, x, roundi(z), _rng.randi_range(0, 3))
		z -= _rng.randf_range(14.0, 28.0)


## Поваленные брёвна в лесу — через них можно перепрыгнуть.
func _scatter_fallen_logs(scene_root: Node) -> void:
	var logs := _new_group("FallenLogs", scene_root)
	var z := START_CLIFF_Z - 6.0
	while z > SECTION_END_Z + 12.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		# Бревно длиной 8 не должно доставать до тропы при любом повороте.
		var x := roundi(path_center_x(z) + side * (path_width(z) / 2.0 + _rng.randf_range(7.0, valley_half_width - 12.0)))
		if _claim(x, roundi(z), 4):
			_place(LOG_SCENE, logs, scene_root, x, roundi(z), _rng.randi_range(0, 1))
		z -= _rng.randf_range(9.0, 18.0)


## Завал на 40 м: стена из брёвен поперёк всей долины, края уходят в обрыв.
## Пять рядов — в пять раз выше прыжка кота.
func _build_barrier(scene_root: Node) -> void:
	var barrier := _new_group("Barrier", scene_root)
	var center := roundi(path_center_x(SECTION_END_Z))
	var wall_z := roundi(SECTION_END_Z)
	var reach := roundi(valley_half_width) + 6
	# Земля под завалом ровная: высота берётся с середины тропы.
	var base := block_height(center, wall_z)
	for layer in 5:
		# Ряды сдвинуты на полбревна — как настоящая кладка.
		var x := center - reach + (4 if layer % 2 == 1 else 0)
		while x < center + reach:
			var wall_log := _place(LOG_SCENE, barrier, scene_root, x, wall_z)
			wall_log.position.y = base + layer
			x += 8
		for dx in range(center - reach, center + reach):
			_occupied[Vector2i(dx, wall_z)] = true
	# Второй ряд брёвен позади и камни впереди — чтобы завал читался издалека.
	var x_back := center - reach + 2
	while x_back < center + reach:
		var back_log := _place(LOG_SCENE, barrier, scene_root, x_back, wall_z - 1)
		back_log.position.y = base + _rng.randi_range(0, 2)
		x_back += 8
	for i in 5:
		var rock_x := center + _rng.randi_range(-14, 14)
		var rock_z := wall_z + _rng.randi_range(3, 5)
		if _claim(rock_x, rock_z, 2):
			_place(BIG_ROCK_SCENE, barrier, scene_root, rock_x, rock_z, _rng.randi_range(0, 3))


func _place_player_and_end_zone(scene_root: Node) -> void:
	var player := scene_root.get_node_or_null("CatPlayer")
	if player:
		player.position = spawn_position()
	var end_zone := scene_root.get_node_or_null("EndZone")
	if end_zone:
		var zone_z := roundi(SECTION_END_Z + 9.0)
		var zone_x := roundi(path_center_x(zone_z))
		end_zone.position = Vector3(zone_x, block_height(zone_x, zone_z) + 2.0, zone_z)
