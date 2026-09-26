@tool
extends Node3D

## Сборщик стартового места (улица + первые 10 м тропы). Это общий мир
## катсцены С1 и игры: оба включают сцену start_area_world.tscn.
## Ставит землю, машины, фонари, тоннели, табличку, лес, кусты, траву и завал
## в конце куска — всё сохраняется в сцену как узлы.
##
## Пересобрать: узел Builder → «Пересобрать мир» → Ctrl+S, или
## godot --path game/3d-probe -s res://tools/build_start_area.gd (с окном: трава — MultiMesh).

const Terrain = preload("res://scenes/world/start_area_terrain.gd")
const StreetRecipes = preload("res://scenes/cutscene/street_recipes.gd")
const TRAFFIC_SCRIPT = preload("res://scenes/cutscene/traffic_car.gd")

const WORLD_UNITS_PER_METRE := 12.24
## Где кот получает управление — там, где кончается катсцена. Это 0 м.
const SPAWN_Z := -74.0
## Длина этого куска маршрута (правило автора: маленькими шагами).
const PIECE_METRES := 10.0
const BARRIER_Z := SPAWN_Z - PIECE_METRES * WORLD_UNITS_PER_METRE - 1.0

const PROBE_KINDS := "res://scenes/style_probe/kinds/"
const PROBE_GENERATED := "res://scenes/style_probe/generated/"
const KINDS_DIR := "res://scenes/world/start_kinds/"
const GENERATED_DIR := "res://scenes/world/start_generated/"
const GENERATED_GROUPS := ["Terrain", "Street", "Sign", "Forest", "Bushes", "GroundCover", "Barrier"]

## Места, где в катсцене стоят неподвижные камеры: там ничего не ставить.
const CLEAR_SPOTS := [Vector3(-14.0, 0, 6.8)]

const CAR_COLORS := [
	["#8e2a24", "#a8332b", "#c24034"], ["#24466e", "#2d5585", "#38669b"],
	["#c9a032", "#dab240", "#e8c552"], ["#d9d6cf", "#e6e3dc", "#f1eee8"], ["#2e5a3a", "#386b45", "#447d52"],
]
const TREE_KINDS := ["spruce", "spruce", "spruce_tall", "small_spruce", "pine", "birch", "broadleaf", "broadleaf_wide"]

@export var layout_seed := 5
@export_tool_button("Пересобрать мир", "Reload") var rebuild_button := _rebuild_in_editor

var terrain := Terrain.new()
var _rng := RandomNumberGenerator.new()
var _scenes := {}


func spawn_position() -> Vector3:
	return spawn_position_static()


static func spawn_position_static() -> Vector3:
	var shape := Terrain.new()
	var x := shape.trail_center_x(SPAWN_Z)
	return Vector3(x, shape.height(x, SPAWN_Z), SPAWN_Z)


func _rebuild_in_editor() -> void:
	rebuild(get_tree().edited_scene_root)


func rebuild(scene_root: Node) -> void:
	_rng.seed = layout_seed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KINDS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIR))
	for group_name in GENERATED_GROUPS:
		var old := get_node_or_null(NodePath(group_name))
		if old:
			remove_child(old)
			old.free()
	_build_kinds()
	_build_terrain(scene_root)
	_build_street(scene_root)
	_build_sign(scene_root)
	_build_barrier(scene_root)
	_plant_forest(scene_root)
	_scatter_ground_cover(scene_root)
	var sun := scene_root.get_node_or_null("Sun")
	if sun:
		# Низкое закатное солнце, как в пробе графики.
		sun.basis = Basis.looking_at(-Vector3(0.75, 0.3, 0.55).normalized())


# --- Виды объектов -------------------------------------------------------------

func _build_kinds() -> void:
	for i in CAR_COLORS.size():
		_save_car(i)
	_save_sign()
	_save_tunnel()


## Машина: меш + зона, в которую если попадёт кот — концовка С9-машина.
## Твёрдой коллизии у машины нет: она не толкает кота, а сразу запускает концовку.
func _save_car(index: int) -> void:
	var mesh_path := KINDS_DIR + "car_%d_mesh.res" % index
	ResourceSaver.save(StreetRecipes.car(40 + index, CAR_COLORS[index]), mesh_path, ResourceSaver.FLAG_COMPRESS)
	var car := Node3D.new()
	car.name = "Car"
	car.set_script(TRAFFIC_SCRIPT)
	_add_mesh_child(car, mesh_path)
	var zone := Area3D.new()
	zone.name = "HitZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	car.add_child(zone)
	zone.owner = car
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 1.8, 2.0)
	shape.shape = box
	shape.position = Vector3(0, 0.9, 0)
	zone.add_child(shape)
	shape.owner = car
	# Гул мотора (собственная синтезированная заглушка, tools/make_sounds.py).
	var engine := AudioStreamPlayer3D.new()
	engine.name = "Engine"
	engine.stream = load("res://audio/engine_loop.wav")
	engine.bus = &"Effects"
	engine.autoplay = true
	engine.volume_db = -4.0
	engine.unit_size = 5.0
	engine.max_distance = 45.0
	engine.position = Vector3(1.4, 0.6, 0)
	car.add_child(engine)
	engine.owner = car
	_pack(car, "car_%d" % index)


## Табличка: меш, надпись Label3D (текст — формулировка автора 25.09.2026) и коллизия столбиков и доски.
func _save_sign() -> void:
	var mesh_path := KINDS_DIR + "sign_mesh.res"
	ResourceSaver.save(StreetRecipes.sign(50), mesh_path, ResourceSaver.FLAG_COMPRESS)
	var sign := StaticBody3D.new()
	sign.name = "StrawberrySign"
	_add_mesh_child(sign, mesh_path)
	var text := Label3D.new()
	text.name = "Text"
	text.text = "халявная клубника\nчерез 500 метров"
	text.font = load("res://assets/fonts/tiny5/Tiny5-Regular.ttf")
	text.font_size = 64
	text.pixel_size = 0.0031
	text.modulate = Color("#3a2414")
	text.outline_size = 0
	text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	text.position = Vector3(0, 2.05, 0.215)
	sign.add_child(text)
	text.owner = sign
	for part in [[Vector3(0.2, 2.7, 0.2), Vector3(-1.2, 1.35, 0.0)], [Vector3(0.2, 2.7, 0.2), Vector3(1.2, 1.35, 0.0)],
			[Vector3(3.2, 1.3, 0.1), Vector3(0.0, 2.05, 0.15)]]:
		_add_box_collision(sign, part[0], part[1])
	_pack(sign, "sign")


## Тоннель: каменный портал и тёмное нутро. Кот может зайти в темноту,
## но через 6 единиц упирается в конец (там же исчезают и появляются машины).
func _save_tunnel() -> void:
	var mesh_path := KINDS_DIR + "tunnel_mesh.res"
	ResourceSaver.save(StreetRecipes.tunnel_portal(60), mesh_path, ResourceSaver.FLAG_COMPRESS)
	var tunnel := StaticBody3D.new()
	tunnel.name = "Tunnel"
	_add_mesh_child(tunnel, mesh_path)
	var darkness := MeshInstance3D.new()
	darkness.name = "Darkness"
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 5.5, 11.0)
	darkness.mesh = box
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color("#07060a")
	black.cull_mode = BaseMaterial3D.CULL_FRONT  # видно изнутри: тёмный зев
	darkness.material_override = black
	darkness.position = Vector3(4.0, 2.75, 0.0)
	tunnel.add_child(darkness)
	darkness.owner = tunnel
	_add_box_collision(tunnel, Vector3(0.5, 5.5, 11.0), Vector3(7.75, 2.75, 0.0))
	_pack(tunnel, "tunnel")


func _add_mesh_child(parent: Node3D, mesh_path: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	parent.add_child(visual)
	visual.owner = parent


func _add_box_collision(body: Node3D, size: Vector3, position: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Collision%d" % body.get_child_count()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	body.add_child(shape)
	shape.owner = body


func _pack(root: Node, kind: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, KINDS_DIR + kind + ".tscn")
	root.free()
	_scenes[kind] = ResourceLoader.load(KINDS_DIR + kind + ".tscn", "", ResourceLoader.CACHE_MODE_REPLACE)


func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


# --- Расстановка -----------------------------------------------------------------

func _new_group(group_name: String, parent: Node, scene_root: Node) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	parent.add_child(group)
	group.owner = scene_root
	return group


func _place(scene: PackedScene, parent: Node3D, scene_root: Node, position: Vector3, yaw: float = 0.0,
		size: float = 1.0) -> Node3D:
	var instance: Node3D = scene.instantiate()
	instance.position = position
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * size
	parent.add_child(instance, true)
	instance.owner = scene_root
	return instance


func _near_clear_spot(point: Vector3) -> bool:
	for spot in CLEAR_SPOTS:
		if Vector2(point.x - spot.x, point.z - spot.z).length() < 4.5:
			return true
	return false


func _build_terrain(scene_root: Node) -> void:
	var group := _new_group("Terrain", self, scene_root)
	for part in terrain.build_meshes():
		var path: String = GENERATED_DIR + part[0].to_snake_case() + "_mesh.res"
		ResourceSaver.save(part[1], path, ResourceSaver.FLAG_COMPRESS)
		var ground := MeshInstance3D.new()
		ground.name = part[0]
		ground.mesh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		group.add_child(ground)
		ground.owner = scene_root
	var shape_path := GENERATED_DIR + "ground_shape.res"
	ResourceSaver.save(terrain.build_collision(), shape_path, ResourceSaver.FLAG_COMPRESS)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	group.add_child(body)
	body.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	collision.shape = ResourceLoader.load(shape_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	body.add_child(collision)
	collision.owner = scene_root


## Фонари, машины в обе стороны (канон), тоннели на концах улицы.
func _build_street(scene_root: Node) -> void:
	var street := _new_group("Street", self, scene_root)
	var lamps := _new_group("Lamps", street, scene_root)
	var lantern := _scene(PROBE_KINDS + "lantern.tscn")
	var x := -Terrain.STREET_OPEN_X + 6.0
	while x < Terrain.STREET_OPEN_X - 4.0:
		if not _near_clear_spot(Vector3(x, 0, 7.3)):
			_place(lantern, lamps, scene_root, Vector3(x, Terrain.LAYER, 7.3), PI)
		x += 13.0
	var tunnels := _new_group("Tunnels", street, scene_root)
	_place(_scenes.tunnel, tunnels, scene_root, Vector3(Terrain.TUNNEL_X, 0, 0), 0.0)
	_place(_scenes.tunnel, tunnels, scene_root, Vector3(-Terrain.TUNNEL_X, 0, 0), PI)
	var traffic := _new_group("Traffic", street, scene_root)
	var lanes := [[-2.5, 0.0, 11.0], [2.5, PI, 12.5]]  # [z полосы, поворот, скорость]
	var index := 0
	for lane in lanes:
		var car_x := -Terrain.TUNNEL_X + _rng.randf_range(4.0, 14.0)
		while car_x < Terrain.TUNNEL_X:
			var car := _place(_scenes["car_%d" % (index % CAR_COLORS.size())], traffic, scene_root,
				Vector3(car_x, 0.0, lane[0]), lane[1])
			car.speed = lane[2] + _rng.randf_range(-1.5, 1.5)
			# Разный тон мотора — чтобы поток не гудел одной нотой.
			car.get_node("Engine").pitch_scale = _rng.randf_range(0.8, 1.25)
			# Машины исчезают и появляются в темноте тоннелей.
			car.x_min = -Terrain.TUNNEL_X - 5.0
			car.x_max = Terrain.TUNNEL_X + 5.0
			index += 1
			car_x += _rng.randf_range(18.0, 30.0)


func _build_sign(scene_root: Node) -> void:
	var group := _new_group("Sign", self, scene_root)
	_place(_scenes.sign, group, scene_root, Terrain.SIGN_POSITION, Terrain.SIGN_YAW)


## Завал в конце куска (10 м): три ряда брёвен поперёк тропы, края уходят в склоны.
## Временный конец участка — дальше тропа видна, но будет сделана следующим шагом.
func _build_barrier(scene_root: Node) -> void:
	var group := _new_group("Barrier", self, scene_root)
	var log_scene := _scene(PROBE_KINDS + "log.tscn")
	var rock := _scene(PROBE_KINDS + "rock.tscn")
	var center := terrain.trail_center_x(BARRIER_Z)
	var left := center - Terrain.CORRIDOR_HALF - 4.0
	var right := center + Terrain.CORRIDOR_HALF + 4.0
	for layer in 3:
		var x := left + 3.9 + (3.8 if layer % 2 == 1 else 0.0)
		while x - 3.9 < right:
			var ground := maxf(terrain.height(x - 3.0, BARRIER_Z), terrain.height(x + 3.0, BARRIER_Z))
			var placed := _place(log_scene, group, scene_root, Vector3(x, minf(ground, 2.0) + 0.62 + layer * 1.24,
				BARRIER_Z + _rng.randf_range(-0.15, 0.15)), _rng.randf_range(-0.04, 0.04))
			placed.rotation.x = _rng.randf() * TAU
			x += 7.6
	# Камни у завала — по обочинам, тропа до самих брёвен свободна.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var rock_z := BARRIER_Z + 3.2
		var rock_x := center + side * (terrain.trail_half_width(rock_z) + _rng.randf_range(2.0, 6.0))
		_place(rock, group, scene_root, Vector3(rock_x, terrain.height(rock_x, rock_z), rock_z), _rng.randf() * TAU,
			_rng.randf_range(0.8, 1.1))


## Лес на склонах и полосах у тропы. Коридор тропы и улица свободны.
func _plant_forest(scene_root: Node) -> void:
	var forest := _new_group("Forest", self, scene_root)
	var bushes := _new_group("Bushes", self, scene_root)
	var spacing := 3.1
	var z := 32.0
	while z > -236.0:
		var x := -125.0
		while x < 125.0:
			var tree_x := x + _rng.randf_range(-1.2, 1.2)
			var tree_z := z + _rng.randf_range(-1.2, 1.2)
			x += spacing
			var chance := _tree_chance(tree_x, tree_z)
			if chance <= 0.0 or _rng.randf() > chance:
				continue
			var kind: String = TREE_KINDS[_rng.randi_range(0, TREE_KINDS.size() - 1)]
			var from_trail := absf(tree_x - terrain.trail_center_x(tree_z)) - terrain.trail_half_width(tree_z)
			# Широкие кроны не нависают над тропой.
			if kind.begins_with("broadleaf") and tree_z < -8.0 and from_trail < 5.5:
				kind = "birch"
			_place(_scene(PROBE_KINDS + kind + ".tscn"), forest, scene_root,
				Vector3(tree_x, terrain.height(tree_x, tree_z) - 0.1, tree_z), _rng.randf() * TAU, _rng.randf_range(0.85, 1.2))
			if _rng.randf() < 0.22:
				var bush_x := tree_x + _rng.randf_range(-2.0, 2.0)
				var bush_z := tree_z + _rng.randf_range(-2.0, 2.0)
				if _tree_chance(bush_x, bush_z) > 0.0:
					_place(_scene(PROBE_KINDS + "bush.tscn"), bushes, scene_root,
						Vector3(bush_x, terrain.height(bush_x, bush_z), bush_z), _rng.randf() * TAU)
		z -= spacing


## Вероятность дерева в точке (0 — нельзя).
func _tree_chance(x: float, z: float) -> float:
	if absf(z) < Terrain.SIDEWALK_OUTER + 1.5 or _near_clear_spot(Vector3(x, 0, z)):
		return 0.0
	if x > 0.0 and x < 7.0 and z > -16.0 and z < -8.0:
		return 0.0  # место вокруг таблички
	if absf(z - BARRIER_Z) < 4.5:
		return 0.0  # у завала — только брёвна
	var outside := terrain.distance_outside(x, z)
	if outside > 16.0:
		return 0.0  # высоко на склоне, за гребнем не видно
	if outside > 0.0:
		return 0.6
	if z < -Terrain.SIDEWALK_OUTER:
		var from_trail := absf(x - terrain.trail_center_x(z)) - terrain.trail_half_width(z)
		return 0.0 if from_trail < 2.2 else 0.8
	return 0.35  # полоса травы у южного тротуара


func _scatter_ground_cover(scene_root: Node) -> void:
	var group := _new_group("GroundCover", self, scene_root)
	var variants := 6
	var spots := []
	for i in variants:
		spots.append([])
	for attempt in 5200:
		var x := _rng.randf_range(-60.0, 50.0)
		var z := _rng.randf_range(-225.0, 16.0)
		if terrain.is_street(z) or terrain.is_trail(x, z) or terrain.distance_outside(x, z) > 2.0 \
				or _near_clear_spot(Vector3(x, 0, z)):
			continue
		spots[_rng.randi_range(0, variants - 1)].append(
			Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(x, terrain.height(x, z), z)))
	for i in variants:
		var cover := MultiMesh.new()
		cover.transform_format = MultiMesh.TRANSFORM_3D
		cover.mesh = load(PROBE_GENERATED + "ground_cover_%d.res" % i)
		cover.instance_count = spots[i].size()
		for j in spots[i].size():
			cover.set_instance_transform(j, spots[i][j])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Patches%d" % i
		instance.multimesh = cover
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(instance)
		instance.owner = scene_root
