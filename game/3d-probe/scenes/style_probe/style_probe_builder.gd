@tool
extends Node3D

## Сборщик пробы графики «как в меню». Делает воксельные модели (деревья,
## кусты, камни, забор, фонарь), сохраняет их как сцены в kinds/ и расставляет
## в style_probe.tscn. Результат — обычные узлы сцены, видимые в редакторе.
##
## Пересобрать: узел Builder → «Пересобрать пробу» → Ctrl+S, или
## godot --headless --path game/3d-probe -s res://tools/build_style_probe.gd

const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")
const Terrain = preload("res://scenes/style_probe/probe_terrain.gd")
const BUSH_SCRIPT = preload("res://scenes/props/bush.gd")

const WORLD_UNITS_PER_METRE := 12.24
const KINDS_DIR := "res://scenes/style_probe/kinds/"
const GENERATED_DIR := "res://scenes/style_probe/generated/"
const GENERATED_GROUPS := ["Terrain", "Distance", "Forest", "Bushes", "Rocks", "GroundCover", "Fence", "Barrier", "Props"]

## Деревья леса и их доля (веса).
const TREE_KINDS := {
	"spruce": 26, "spruce_tall": 14, "small_spruce": 12, "pine": 12,
	"broadleaf": 16, "broadleaf_wide": 8, "birch": 12,
}

## Варианты пятен травы: цвета цветов в каждом (пусто — только трава).
const COVER_FLOWERS := [["#f2c14e"], ["#f4efe2"], ["#f2c14e", "#f08a5d"], [], [], ["#b58ae0", "#f4efe2"]]

@export var layout_seed := 11
@export_tool_button("Пересобрать пробу", "Reload") var rebuild_button := _rebuild_in_editor

var terrain := Terrain.new()
var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _occupied := {}


func path_center_x(z: float) -> float:
	return terrain.path_center_x(z)


## Для инструмента снимков: высота земли в точке.
func block_height(x: float, z: float) -> float:
	return terrain.ground_height(x, z)


func setup_noise() -> void:
	pass  # форма пробы не зависит от шума сборщика; метод нужен инструменту снимков


func _rebuild_in_editor() -> void:
	rebuild(get_tree().edited_scene_root)


func rebuild(scene_root: Node) -> void:
	_rng.seed = layout_seed
	_occupied.clear()
	_scenes.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KINDS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENERATED_DIR))
	_build_kinds()
	for group_name in GENERATED_GROUPS:
		var old := get_node_or_null(NodePath(group_name))
		if old:
			remove_child(old)
			old.free()
	_build_terrain(scene_root)
	_build_distance(scene_root)
	_build_fence(scene_root)
	_build_barrier(scene_root)
	_plant_forest(scene_root)
	_plant_path_edges(scene_root)
	_scatter_ground_cover(scene_root)
	_place_props(scene_root)
	var player := scene_root.get_node_or_null("CatPlayer")
	if player:
		player.position = Vector3(path_center_x(4.0), block_height(path_center_x(4.0), 4.0) + 0.1, 4.0)
	var sun := scene_root.get_node_or_null("Sun")
	if sun:
		# Низкое закатное солнце справа-впереди, как на картинке меню.
		sun.basis = Basis.looking_at(-Vector3(0.8, 0.33, -0.5).normalized())


# --- Виды объектов: воксельная модель + коллизия, сохраняются как сцены -------

func _build_kinds() -> void:
	_save_tree("spruce", Recipes.spruce(1), 0.35)
	_save_tree("spruce_tall", Recipes.spruce(2, 54), 0.35)
	_save_tree("small_spruce", Recipes.spruce(3, 24), 0.3)
	_save_tree("pine", Recipes.pine(4), 0.35)
	_save_tree("broadleaf", Recipes.broadleaf(5), 0.75)
	_save_tree("broadleaf_wide", Recipes.broadleaf(6), 0.75)
	_save_tree("birch", Recipes.birch(7), 0.3)
	var rock_shape := BoxShape3D.new()
	rock_shape.size = Vector3(2.8, 1.9, 2.4)
	_save_kind("rock", Recipes.rock(8), rock_shape, Transform3D(Basis(), Vector3(0.2, 0.9, 0.1)))
	var log_shape := CylinderShape3D.new()
	log_shape.radius = 0.62
	log_shape.height = 7.8
	_save_kind("log", Recipes.log(9), log_shape, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3.ZERO))
	var fence_shape := BoxShape3D.new()
	fence_shape.size = Vector3(3.0, 1.6, 0.4)
	_save_kind("fence", Recipes.fence_segment(10), fence_shape, Transform3D(Basis(), Vector3(1.5, 0.8, 0)))
	var post_shape := CylinderShape3D.new()
	post_shape.radius = 0.25
	post_shape.height = 3.0
	_save_kind("lantern", Recipes.lantern(11), post_shape, Transform3D(Basis(), Vector3(0, 1.5, 0)), true)
	_save_bush()
	for i in COVER_FLOWERS.size():
		ResourceSaver.save(Recipes.ground_cover(20 + i, COVER_FLOWERS[i]), GENERATED_DIR + "ground_cover_%d.res" % i,
			ResourceSaver.FLAG_COMPRESS)
	ResourceSaver.save(Recipes.cloud(13), GENERATED_DIR + "cloud.res", ResourceSaver.FLAG_COMPRESS)


func _save_tree(kind: String, mesh: ArrayMesh, trunk_radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = trunk_radius
	shape.height = 4.0
	_save_kind(kind, mesh, shape, Transform3D(Basis(), Vector3(0, 2, 0)), false, true)


## Сцена вида: StaticBody3D → Mesh + коллизия (+ свет у фонаря).
func _save_kind(kind: String, mesh: ArrayMesh, shape: Shape3D, shape_transform: Transform3D,
		with_light: bool = false, blocks_camera: bool = false) -> void:
	var mesh_path := KINDS_DIR + kind + "_mesh.res"
	ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
	var body := StaticBody3D.new()
	body.name = kind.to_pascal_case()
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	body.add_child(visual)
	visual.owner = body
	var collision := CollisionShape3D.new()
	collision.name = "TrunkCollision"
	collision.shape = shape
	collision.transform = shape_transform
	body.add_child(collision)
	collision.owner = body
	if with_light:
		var light := OmniLight3D.new()
		light.name = "Light"
		light.position = Vector3(0.8, 2.2, -0.3)
		light.light_color = Color(1, 0.72, 0.4)
		light.light_energy = 2.0
		light.omni_range = 7.0
		body.add_child(light)
		light.owner = body
	if blocks_camera:
		_add_camera_blocker(body, mesh)
	_pack(body, kind)


## Крона и куст для кота проходимы (упирается он только в ствол), а для
## камеры — нет: иначе она влетает внутрь листвы. Поэтому у них отдельное
## тело на слое 3 «только камера» — его видит лишь SpringArm3D кота.
## Форма — выпуклая оболочка каждой поверхности меша (ствол, крона).
const CAMERA_ONLY_LAYER := 4  # бит слоя 3

func _add_camera_blocker(owner_node: Node3D, mesh: ArrayMesh) -> void:
	var blocker := StaticBody3D.new()
	blocker.name = "CameraBlocker"
	blocker.collision_layer = CAMERA_ONLY_LAYER
	blocker.collision_mask = 0
	owner_node.add_child(blocker)
	blocker.owner = owner_node
	for i in mesh.get_surface_count():
		var single := ArrayMesh.new()
		single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))
		var hull := CollisionShape3D.new()
		hull.name = "Hull%d" % i
		hull.shape = single.create_convex_shape(true, false)
		blocker.add_child(hull)
		hull.owner = owner_node


## Куст проходим и замедляет кота вдвое (скрипт bush.gd).
func _save_bush() -> void:
	var mesh_path := KINDS_DIR + "bush_mesh.res"
	ResourceSaver.save(Recipes.bush(14), mesh_path, ResourceSaver.FLAG_COMPRESS)
	var root := Node3D.new()
	root.name = "Bush"
	root.set_script(BUSH_SCRIPT)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	root.add_child(visual)
	visual.owner = root
	var zone := Area3D.new()
	zone.name = "SlowZone"
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	root.add_child(zone)
	zone.owner = root
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.6, 2.6)
	shape.shape = box
	shape.position = Vector3(0.3, 0.8, 0.2)
	zone.add_child(shape)
	shape.owner = root
	_add_camera_blocker(root, visual.mesh)
	_pack(root, "bush")


func _pack(root: Node, kind: String) -> void:
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, KINDS_DIR + kind + ".tscn")
	root.free()
	_scenes[kind] = ResourceLoader.load(KINDS_DIR + kind + ".tscn", "", ResourceLoader.CACHE_MODE_REPLACE)


# --- Расстановка ------------------------------------------------------------------

func _new_group(group_name: String, scene_root: Node) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	group.owner = scene_root
	return group


func _place(kind: String, parent: Node3D, scene_root: Node, position: Vector3, yaw: float = 0.0,
		size: float = 1.0) -> Node3D:
	var instance: Node3D = _scenes[kind].instantiate()
	instance.position = position
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * size
	parent.add_child(instance, true)
	instance.owner = scene_root
	return instance


func _on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, block_height(x, z), z)


func _claim(x: float, z: float, radius: int) -> bool:
	var cx := roundi(x)
	var cz := roundi(z)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if _occupied.has(Vector2i(cx + dx, cz + dz)):
				return false
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			_occupied[Vector2i(cx + dx, cz + dz)] = true
	return true


func _add_mesh(parent: Node3D, scene_root: Node, node_name: String, mesh: Mesh, path: String) -> MeshInstance3D:
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	parent.add_child(instance)
	instance.owner = scene_root
	return instance


func _build_terrain(scene_root: Node) -> void:
	var group := _new_group("Terrain", scene_root)
	var ground: Array = terrain.build_ground()
	_add_mesh(group, scene_root, "Ground", ground[0], GENERATED_DIR + "ground_mesh.res")
	ResourceSaver.save(ground[1], GENERATED_DIR + "ground_shape.res", ResourceSaver.FLAG_COMPRESS)
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	group.add_child(body)
	body.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "GroundCollision"
	collision.shape = ResourceLoader.load(GENERATED_DIR + "ground_shape.res", "", ResourceLoader.CACHE_MODE_REPLACE)
	body.add_child(collision)
	collision.owner = scene_root


## Долина, река, горы, облака и далёкий лес (без коллизий — туда не дойти).
func _build_distance(scene_root: Node) -> void:
	var group := _new_group("Distance", scene_root)
	_add_mesh(group, scene_root, "Valley", terrain.build_valley(), GENERATED_DIR + "valley_mesh.res")
	_add_mesh(group, scene_root, "River", terrain.build_water(), GENERATED_DIR + "river_mesh.res")
	_add_mesh(group, scene_root, "Mountains", terrain.build_mountains(), GENERATED_DIR + "mountains_mesh.res")
	var cloud_mesh: Mesh = load(GENERATED_DIR + "cloud.res")
	for i in 10:
		var cloud := MeshInstance3D.new()
		cloud.name = "Cloud%d" % i
		cloud.mesh = cloud_mesh
		cloud.position = Vector3(_rng.randf_range(-200, 420), _rng.randf_range(80, 140), _rng.randf_range(-320, -620))
		cloud.scale = Vector3.ONE * _rng.randf_range(0.8, 1.6)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(cloud)
		cloud.owner = scene_root
	# Далёкие ели: один MultiMesh, иначе тысячи узлов.
	var far_trees := MultiMesh.new()
	far_trees.transform_format = MultiMesh.TRANSFORM_3D
	far_trees.mesh = load(KINDS_DIR + "spruce_mesh.res")
	var spots: Array[Transform3D] = []
	while spots.size() < 900:
		var x := _rng.randf_range(20, 420)
		var z := _rng.randf_range(-600, 40)
		var y: float
		if x < 260 and z > -460:
			y = terrain.valley_height(x, z)
			if y < Terrain.VALLEY_Y - 0.5:
				continue
		else:
			y = terrain.mountain_height(x, z)
			if y > Terrain.VALLEY_Y + 45.0:
				continue
		var size := _rng.randf_range(0.8, 1.6)
		spots.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, y, z)))
	far_trees.instance_count = spots.size()
	for i in spots.size():
		far_trees.set_instance_transform(i, spots[i])
	var far_forest := MultiMeshInstance3D.new()
	far_forest.name = "FarForest"
	far_forest.multimesh = far_trees
	far_forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(far_forest)
	far_forest.owner = scene_root


## Забор вдоль обрыва — видимая граница справа.
func _build_fence(scene_root: Node) -> void:
	var group := _new_group("Fence", scene_root)
	var z := 18.0
	while z > Terrain.END_RISE_Z + 2.0:
		var start := Vector3(terrain.fence_x(z), 0, z)
		var finish := Vector3(terrain.fence_x(z - 3.0), 0, z - 3.0)
		var direction := finish - start
		var ground := maxf(block_height(start.x, start.z), block_height(finish.x, finish.z))
		var segment := _place("fence", group, scene_root, Vector3(start.x, ground, start.z), atan2(-direction.z, direction.x))
		segment.scale.x = direction.length() / 3.0
		for step in range(0, 4):
			_occupied[Vector2i(roundi(start.x), roundi(z - step))] = true
		z -= 3.0


## Завал поперёк тропы: три ряда брёвен от подъёма слева до забора, камни впереди.
func _build_barrier(scene_root: Node) -> void:
	var group := _new_group("Barrier", scene_root)
	var z := Terrain.BARRIER_Z
	var left := path_center_x(z) - 20.0
	var right := terrain.fence_x(z) + 0.5
	for layer in 3:
		var x := left + 3.9 + (3.8 if layer % 2 == 1 else 0.0)
		while x - 3.9 < right:
			var barrier_log := _place("log", group, scene_root, Vector3(x, 0.62 + layer * 1.24 + 0.25, z + _rng.randf_range(-0.15, 0.15)),
				_rng.randf_range(-0.04, 0.04))
			barrier_log.rotation.x = _rng.randf() * TAU
			x += 7.6
	for x in range(floori(left), ceili(right)):
		for dz in range(-2, 3):
			_occupied[Vector2i(x, roundi(z) + dz)] = true
	for i in 4:
		var rock_x := path_center_x(z) + _rng.randf_range(-6, 6)
		_place("rock", group, scene_root, _on_ground(rock_x, z + 3.2), _rng.randf() * TAU, _rng.randf_range(0.8, 1.1))


func _pick_tree(prefer_broadleaf: bool) -> String:
	if prefer_broadleaf:
		return ["broadleaf", "broadleaf_wide", "birch", "birch"][_rng.randi_range(0, 3)]
	var total := 0
	for kind in TREE_KINDS:
		total += TREE_KINDS[kind]
	var roll := _rng.randi_range(1, total)
	for kind in TREE_KINDS:
		roll -= TREE_KINDS[kind]
		if roll <= 0:
			return kind
	return "spruce"


## Лес: густо слева и на подъёмах, редкие большие деревья между тропой и забором.
func _plant_forest(scene_root: Node) -> void:
	var group := _new_group("Forest", scene_root)
	var spacing := 2.8
	var z := Terrain.Z_MAX - 1.0
	while z > Terrain.Z_MIN + 1.0:
		var x := Terrain.X_MIN + 1.0
		while x < terrain.fence_x(z) - 1.0:
			var tree_x := x + _rng.randf_range(-1.1, 1.1)
			var tree_z := z + _rng.randf_range(-1.1, 1.1)
			var from_edge := absf(tree_x - path_center_x(tree_z)) - terrain.path_width(tree_z) / 2.0
			var right_side := tree_x > path_center_x(tree_z)
			var chance := 0.0
			if from_edge > 2.5:
				chance = 0.16 if right_side else 0.8
			# За стартом лес начинается подальше: камера за котом не должна
			# оказываться внутри крон.
			if tree_z > Terrain.START_RISE_Z + 5.0 or tree_z < Terrain.BARRIER_Z - 2.0:
				chance = 0.85
			if tree_x > terrain.fence_x(tree_z) - 2.5:
				chance = 0.0
			if _rng.randf() < chance:
				var kind := _pick_tree(right_side and tree_z < Terrain.START_RISE_Z - 3.0)
				var radius := 2 if kind.begins_with("broadleaf") else 1
				# Широкие кроны не нависают над самой тропой.
				if kind.begins_with("broadleaf") and from_edge < 4.5:
					kind = "birch"
					radius = 1
				if _claim(tree_x, tree_z, radius):
					_place(kind, group, scene_root, _on_ground(tree_x, tree_z) - Vector3(0, 0.1, 0),
						_rng.randf() * TAU, _rng.randf_range(0.85, 1.2))
			x += spacing
		z -= spacing


func _plant_path_edges(scene_root: Node) -> void:
	var bushes := _new_group("Bushes", scene_root)
	var rocks := _new_group("Rocks", scene_root)
	var z := Terrain.START_RISE_Z - 2.0
	while z > Terrain.BARRIER_Z + 3.0:
		for side: float in [-1.0, 1.0]:
			var edge := path_center_x(z) + side * terrain.path_width(z) / 2.0
			if _rng.randf() < 0.45:
				var bush_x := edge + side * _rng.randf_range(0.8, 2.5)
				if _claim(bush_x, z, 0):
					_place("bush", bushes, scene_root, _on_ground(bush_x, z), _rng.randf() * TAU, _rng.randf_range(0.7, 1.2))
			if _rng.randf() < 0.08:
				var rock_x := edge + side * _rng.randf_range(2.0, 4.0)
				if _claim(rock_x, z, 1):
					_place("rock", rocks, scene_root, _on_ground(rock_x, z) - Vector3(0, 0.2, 0), _rng.randf() * TAU,
						_rng.randf_range(0.6, 1.0))
		z -= 1.6


## Трава и цветы вокруг тропы — по MultiMesh на вариант пятна, без коллизии.
func _scatter_ground_cover(scene_root: Node) -> void:
	var group := _new_group("GroundCover", scene_root)
	var spots_by_variant := []
	for i in COVER_FLOWERS.size():
		spots_by_variant.append([])
	for attempt in 2600:
		var z := _rng.randf_range(Terrain.BARRIER_Z - 4.0, Terrain.START_RISE_Z + 2.0)
		var x := _rng.randf_range(path_center_x(z) - 19.0, terrain.fence_x(z) + 1.2)
		if terrain.is_path(x, z):
			continue
		var variant := _rng.randi_range(0, COVER_FLOWERS.size() - 1)
		spots_by_variant[variant].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _on_ground(x, z)))
	for i in COVER_FLOWERS.size():
		var spots: Array = spots_by_variant[i]
		var cover := MultiMesh.new()
		cover.transform_format = MultiMesh.TRANSFORM_3D
		cover.mesh = load(GENERATED_DIR + "ground_cover_%d.res" % i)
		cover.instance_count = spots.size()
		for j in spots.size():
			cover.set_instance_transform(j, spots[j])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Patches%d" % i
		instance.multimesh = cover
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(instance)
		instance.owner = scene_root


func _place_props(scene_root: Node) -> void:
	var group := _new_group("Props", scene_root)
	var z := -2.0
	var x := path_center_x(z) - terrain.path_width(z) / 2.0 - 1.0
	_claim(x, z, 1)
	_place("lantern", group, scene_root, _on_ground(x, z), 0.0)
