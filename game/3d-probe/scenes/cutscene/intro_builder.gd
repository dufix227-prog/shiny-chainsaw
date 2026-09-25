@tool
extends Node3D

## Сборщик стартовой катсцены. Ставит улицу, лес, фонари, машины и табличку,
## а постановку (путь кота, камеры, затемнение) записывает в анимацию «intro»
## узла AnimationPlayer. Всё сохраняется в intro.tscn и правится в редакторе:
## ключи анимации можно двигать руками во вкладке «Анимация».
##
## ВНИМАНИЕ: пересборка перезаписывает анимацию. Если правили ключи руками —
## перенесите правки сюда (в SHOTS / CAT_PATH), иначе они пропадут.
##
## Пересобрать: узел Builder → «Пересобрать катсцену» → Ctrl+S, или
## godot --path game/3d-probe -s res://tools/build_intro.gd (с окном — трава MultiMesh).

const Terrain = preload("res://scenes/cutscene/intro_terrain.gd")
const StreetRecipes = preload("res://scenes/cutscene/street_recipes.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")
const TRAFFIC_SCRIPT = preload("res://scenes/cutscene/traffic_car.gd")

const PROBE_KINDS := "res://scenes/style_probe/kinds/"
const PROBE_GENERATED := "res://scenes/style_probe/generated/"
const KINDS_DIR := "res://scenes/cutscene/kinds/"
const GENERATED_DIR := "res://scenes/cutscene/generated/"
const GENERATED_GROUPS := ["Terrain", "Forest", "Bushes", "GroundCover", "Lamps", "Traffic", "Sign"]

## Скорость кота в катсцене (единиц в секунду) — как обычный шаг в игре.
const CAT_SPEED := 2.2
## Табличка: где стоит и куда повёрнута (лицом к подходящему коту).
const SIGN_POSITION := Vector3(3.4, 0.25, -11.5)
const SIGN_YAW := -0.4
## Сколько держится крупный план таблички — канон автора: 3 секунды.
const SIGN_CLOSEUP_SECONDS := 3.0

const CAR_COLORS := [
	["#8e2a24", "#a8332b", "#c24034"], ["#24466e", "#2d5585", "#38669b"],
	["#c9a032", "#dab240", "#e8c552"], ["#d9d6cf", "#e6e3dc", "#f1eee8"], ["#2e5a3a", "#386b45", "#447d52"],
]

@export var layout_seed := 5
@export_tool_button("Пересобрать катсцену", "Reload") var rebuild_button := _rebuild_in_editor

var terrain := Terrain.new()
var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _camera_spots: Array[Vector3] = []


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
	var timeline := _build_animation(scene_root)
	_camera_spots = timeline
	_build_terrain(scene_root)
	_build_sign(scene_root)
	_build_lamps(scene_root)
	_build_traffic(scene_root)
	_plant_forest(scene_root)
	_scatter_ground_cover(scene_root)
	var sun := scene_root.get_node_or_null("Sun")
	if sun:
		# Низкое закатное солнце, как в пробе графики.
		sun.basis = Basis.looking_at(-Vector3(0.75, 0.3, 0.55).normalized())


# --- Объекты -------------------------------------------------------------------

func _build_kinds() -> void:
	for i in CAR_COLORS.size():
		var mesh_path := KINDS_DIR + "car_%d_mesh.res" % i
		ResourceSaver.save(StreetRecipes.car(40 + i, CAR_COLORS[i]), mesh_path, ResourceSaver.FLAG_COMPRESS)
		var car := Node3D.new()
		car.name = "Car"
		car.set_script(TRAFFIC_SCRIPT)
		var visual := MeshInstance3D.new()
		visual.name = "Mesh"
		visual.mesh = ResourceLoader.load(mesh_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		car.add_child(visual)
		visual.owner = car
		_pack(car, "car_%d" % i)
	# Табличка: меш + надпись Label3D (текст — формулировка автора).
	var sign_mesh := KINDS_DIR + "sign_mesh.res"
	ResourceSaver.save(StreetRecipes.sign(50), sign_mesh, ResourceSaver.FLAG_COMPRESS)
	var sign := Node3D.new()
	sign.name = "StrawberrySign"
	var board := MeshInstance3D.new()
	board.name = "Mesh"
	board.mesh = ResourceLoader.load(sign_mesh, "", ResourceLoader.CACHE_MODE_REPLACE)
	sign.add_child(board)
	board.owner = sign
	var text := Label3D.new()
	text.name = "Text"
	text.text = "через 500 метров\nклубничные запасы"
	text.font = load("res://assets/fonts/tiny5/Tiny5-Regular.ttf")
	text.font_size = 64
	text.pixel_size = 0.0031
	text.modulate = Color("#3a2414")
	text.outline_size = 0
	text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	text.position = Vector3(0, 2.05, 0.215)
	sign.add_child(text)
	text.owner = sign
	_pack(sign, "sign")


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


func _new_group(group_name: String, scene_root: Node) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
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


func _build_terrain(scene_root: Node) -> void:
	var group := _new_group("Terrain", scene_root)
	var path := GENERATED_DIR + "ground_mesh.res"
	ResourceSaver.save(terrain.build_ground(), path, ResourceSaver.FLAG_COMPRESS)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	group.add_child(ground)
	ground.owner = scene_root


func _build_sign(scene_root: Node) -> void:
	var group := _new_group("Sign", scene_root)
	_place(_scenes.sign, group, scene_root, SIGN_POSITION, SIGN_YAW)


## Фонари вдоль южного тротуара.
func _build_lamps(scene_root: Node) -> void:
	var group := _new_group("Lamps", scene_root)
	var lantern := _scene(PROBE_KINDS + "lantern.tscn")
	var x := Terrain.X_MIN + 8.0
	while x < Terrain.X_MAX - 4.0:
		if not _near_camera(Vector3(x, 0, 7.3)):
			_place(lantern, group, scene_root, Vector3(x, 0.25, 7.3), PI)
		x += 13.0


## Поток машин в обе стороны (канон: «по улице в обе стороны едут машины»).
func _build_traffic(scene_root: Node) -> void:
	var group := _new_group("Traffic", scene_root)
	var lanes := [[-2.5, 0.0, 11.0], [2.5, PI, 12.5]]  # [z полосы, поворот, скорость]
	var index := 0
	for lane in lanes:
		var x := Terrain.X_MIN + _rng.randf_range(0.0, 10.0)
		while x < Terrain.X_MAX:
			var car := _place(_scenes["car_%d" % (index % CAR_COLORS.size())], group, scene_root,
				Vector3(x, 0.0, lane[0]), lane[1])
			car.speed = lane[2] + _rng.randf_range(-1.5, 1.5)
			# Машины исчезают и появляются за краем кадра, а не на виду.
			car.x_min = Terrain.X_MIN - 5.0
			car.x_max = Terrain.X_MAX + 5.0
			index += 1
			x += _rng.randf_range(18.0, 30.0)


## Лес по обе стороны улицы, коридор тропы свободен, у камер свободно.
func _plant_forest(scene_root: Node) -> void:
	var forest := _new_group("Forest", scene_root)
	var bushes := _new_group("Bushes", scene_root)
	var kinds := ["spruce", "spruce", "spruce_tall", "small_spruce", "pine", "birch", "broadleaf"]
	var spacing := 3.2
	var z := Terrain.Z_MAX - 1.0
	while z > Terrain.Z_MIN + 1.0:
		var x := Terrain.X_MIN + 1.0
		while x < Terrain.X_MAX - 1.0:
			# Дальше от тропы лес нужен только у улицы — его видно в общем плане.
			if z < -30.0 and absf(x) > 45.0:
				x += spacing
				continue
			var tree_x := x + _rng.randf_range(-1.2, 1.2)
			var tree_z := z + _rng.randf_range(-1.2, 1.2)
			x += spacing
			if absf(tree_z) < Terrain.SIDEWALK_OUTER + 1.5:
				continue
			var from_trail := absf(tree_x - terrain.trail_center_x(tree_z)) - terrain.trail_half_width(tree_z)
			if tree_z < 0.0 and from_trail < 2.2:
				continue
			if tree_x > 0.0 and tree_x < 7.0 and tree_z > -16.0 and tree_z < -8.0:
				continue  # место вокруг таблички
			if _near_camera(Vector3(tree_x, 0, tree_z)):
				continue
			var chance := 0.75 if tree_z < 0.0 else 0.55
			if _rng.randf() > chance:
				continue
			var kind: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
			if kind == "broadleaf" and from_trail < 5.0:
				kind = "birch"
			_place(_scene(PROBE_KINDS + kind + ".tscn"), forest, scene_root,
				Vector3(tree_x, terrain.height(tree_x, tree_z) - 0.1, tree_z), _rng.randf() * TAU, _rng.randf_range(0.85, 1.2))
			if _rng.randf() < 0.2:
				var bush_x := tree_x + _rng.randf_range(-2.0, 2.0)
				var bush_z := tree_z + _rng.randf_range(-2.0, 2.0)
				if absf(bush_z) > Terrain.SIDEWALK_OUTER + 0.5 and not terrain.is_trail(bush_x, bush_z):
					_place(_scene(PROBE_KINDS + "bush.tscn"), bushes, scene_root,
						Vector3(bush_x, terrain.height(bush_x, bush_z), bush_z), _rng.randf() * TAU)
		z -= spacing


func _near_camera(point: Vector3) -> bool:
	for spot in _camera_spots:
		if Vector2(point.x - spot.x, point.z - spot.z).length() < 4.5:
			return true
	return false


func _scatter_ground_cover(scene_root: Node) -> void:
	var group := _new_group("GroundCover", scene_root)
	var variants := 6
	var spots := []
	for i in variants:
		spots.append([])
	for attempt in 3000:
		var x := _rng.randf_range(-40.0, 30.0)
		var z := _rng.randf_range(-80.0, 30.0)
		if terrain.is_street(z) or terrain.is_trail(x, z) or _near_camera(Vector3(x, 0, z)):
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


# --- Постановка ------------------------------------------------------------------

## Путь кота: точки [позиция, «стоит ли здесь»]. Время считается по скорости.
func _cat_path() -> Array:
	var points: Array = [
		[Vector3(-40.0, 0.25, -6.5), false],
		[Vector3(-3.4, 0.25, -6.5), false],
		[Vector3(0.0, 0.25, -8.2), false],
		[Vector3(0.6, 0.25, -10.6), true],  # остановка у таблички
	]
	var z := -14.0
	while z > -76.0:
		points.append([Vector3(terrain.trail_center_x(z), 0.25, z), false])
		z -= 5.0
	return points


## Строит анимацию и возвращает точки, где стоит камера (чтобы там не росли деревья).
func _build_animation(scene_root: Node) -> Array[Vector3]:
	var player: AnimationPlayer = scene_root.get_node("AnimationPlayer")
	var animation := Animation.new()
	# Длина задаётся с запасом сразу: иначе (по умолчанию 1 с) position_track_interpolate
	# обрезает время, и камера «следит» за котом из первой секунды.
	animation.length = 600.0
	var cat_position := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(cat_position, "CatModel")
	var cat_rotation := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(cat_rotation, "CatModel")
	var cat_speed := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(cat_speed, "CatModel:move_speed")
	animation.value_track_set_update_mode(cat_speed, Animation.UPDATE_DISCRETE)
	var camera_position := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(camera_position, "ShotCamera")
	var camera_rotation := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(camera_rotation, "ShotCamera")
	var fade := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(fade, "Overlay/Fade:color")

	# Кот: идёт по точкам, у таблички стоит, поворачивается к ней и обратно.
	var path := _cat_path()
	var time := 0.0
	var yaw := -PI / 2.0
	var times := []
	var sign_look_start := 0.0
	for i in path.size():
		var point: Vector3 = path[i][0]
		if i > 0:
			var previous: Vector3 = path[i - 1][0]
			var step := point - previous
			yaw = atan2(-step.x, -step.z)
			time += step.length() / CAT_SPEED
		times.append(time)
		animation.position_track_insert_key(cat_position, time, point)
		animation.rotation_track_insert_key(cat_rotation, time, Quaternion(Vector3.UP, yaw))
		if i == 0:
			animation.track_insert_key(cat_speed, 0.0, CAT_SPEED)
		if path[i][1]:
			# Остановка: повернуться к табличке, постоять, пока идёт крупный план, развернуться.
			animation.track_insert_key(cat_speed, time, 0.0)
			var to_sign := SIGN_POSITION - point
			var sign_yaw := atan2(-to_sign.x, -to_sign.z)
			animation.rotation_track_insert_key(cat_rotation, time + 0.6, Quaternion(Vector3.UP, sign_yaw))
			sign_look_start = time + 0.8
			var wait := 0.8 + SIGN_CLOSEUP_SECONDS + 0.8
			animation.rotation_track_insert_key(cat_rotation, time + wait - 0.4, Quaternion(Vector3.UP, sign_yaw))
			var next: Vector3 = path[i + 1][0]
			var onward := next - point
			animation.rotation_track_insert_key(cat_rotation, time + wait, Quaternion(Vector3.UP, atan2(-onward.x, -onward.z)))
			animation.position_track_insert_key(cat_position, time + wait, point)
			time += wait
			times[i] = time
			animation.track_insert_key(cat_speed, time, CAT_SPEED)
	var walk_end := time
	animation.track_insert_key(cat_speed, walk_end, 0.0)

	# Камеры: список планов [начало, откуда, куда смотрит]. Смена плана — резкая (кадр).
	var corner_time: float = times[2]
	var sign_normal := Vector3(sin(SIGN_YAW), 0, cos(SIGN_YAW))
	var sign_center := SIGN_POSITION + Vector3(0, 2.05, 0)
	var shots: Array = []
	# 1. Общий план улицы: камера на южном тротуаре, панорама за котом.
	shots.append([[0.0, Vector3(-14.0, 5.5, 6.8), _cat_at(animation, cat_position, 0.0) + Vector3(0, 1.4, 0)],
		[7.0, Vector3(-14.0, 5.5, 6.8), _cat_at(animation, cat_position, 7.0) + Vector3(0, 1.4, 0)]])
	# 2. Кот идёт навстречу камере, за ним — поток машин.
	# Камера на тротуаре впереди кота и отъезжает перед ним.
	shots.append([[7.0, _cat_at(animation, cat_position, 7.0) + Vector3(6.5, 2.0, -1.0), _cat_at(animation, cat_position, 7.0) + Vector3(0, 1.6, 0)],
		[corner_time - 1.0, _cat_at(animation, cat_position, corner_time - 1.0) + Vector3(6.0, 2.2, -1.0),
			_cat_at(animation, cat_position, corner_time - 1.0) + Vector3(0, 1.6, 0)]])
	# 3. Со спины: кот сворачивает на бетонную тропу, впереди табличка.
	# Камера сзади справа, со стороны таблички: кот и табличка не заслоняют друг друга.
	shots.append([[corner_time - 1.0, Vector3(5.0, 4.2, -4.4), Vector3(1.2, 1.5, -11.0)],
		[sign_look_start, Vector3(4.5, 3.8, -5.2), Vector3(2.0, 1.8, -11.0)]])
	# 4. Крупный план таблички — ровно SIGN_CLOSEUP_SECONDS.
	shots.append([[sign_look_start, sign_center + sign_normal * 2.6 + Vector3(0, 0.15, 0), sign_center],
		[sign_look_start + SIGN_CLOSEUP_SECONDS, sign_center + sign_normal * 2.1 + Vector3(0, 0.1, 0), sign_center]])
	# 5. Камера за спиной кота: он уходит по плитам в лес.
	var follow: Array = []
	var t := sign_look_start + SIGN_CLOSEUP_SECONDS
	while t < walk_end - 6.0:
		var cat := _cat_at(animation, cat_position, t)
		follow.append([t, cat + Vector3(0.6, 3.6, 7.5), cat + Vector3(0, 1.6, -4.0)])
		t += 2.5
	shots.append(follow)
	# 6. Камера останавливается и поднимается, кот уходит вглубь леса.
	var last_cat := _cat_at(animation, cat_position, walk_end - 6.0)
	shots.append([[walk_end - 6.0, last_cat + Vector3(0.6, 3.6, 7.5), last_cat + Vector3(0, 1.6, -4.0)],
		[walk_end + 1.0, last_cat + Vector3(1.5, 7.5, 12.0), _cat_at(animation, cat_position, walk_end) + Vector3(0, 1.0, 0)]])

	var spots: Array[Vector3] = []
	for shot in shots:
		for i in shot.size():
			var key: Array = shot[i]
			# Первый ключ плана сдвинут на миг — так смена плана выглядит как склейка.
			var key_time: float = key[0] + (0.001 if i == 0 and key[0] > 0.0 else 0.0)
			animation.position_track_insert_key(camera_position, key_time, key[1])
			animation.rotation_track_insert_key(camera_rotation, key_time, _look_rotation(key[1], key[2]))
			spots.append(key[1])

	# Затемнение: из чёрного в начале, в чёрное в конце.
	var length := walk_end + 3.0
	animation.track_insert_key(fade, 0.0, Color(0, 0, 0, 1))
	animation.track_insert_key(fade, 1.5, Color(0, 0, 0, 0))
	animation.track_insert_key(fade, length - 2.2, Color(0, 0, 0, 0))
	animation.track_insert_key(fade, length, Color(0, 0, 0, 1))
	animation.length = length

	var library := AnimationLibrary.new()
	library.add_animation("intro", animation)
	for old in player.get_animation_library_list():
		player.remove_animation_library(old)
	player.add_animation_library("", library)
	return spots


func _cat_at(animation: Animation, track: int, time: float) -> Vector3:
	return animation.position_track_interpolate(track, time)


func _look_rotation(from: Vector3, to: Vector3) -> Quaternion:
	return Basis.looking_at(to - from, Vector3.UP).get_rotation_quaternion()
