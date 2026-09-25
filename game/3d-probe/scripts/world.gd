extends Node3D

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const ForestStart = preload("res://scripts/location_forest.gd")
const PrologueIntro = preload("res://scripts/location_intro.gd")
const Church = preload("res://scripts/location_church.gd")
const BratishkinHouse = preload("res://scripts/location_bratishkin.gd")
const TREE_Z := Route.ORIGIN_Z - 8.5 * Route.WORLD_UNITS_PER_METRE
const BACK_Z := Route.ORIGIN_Z + 4.8
const FRONT_Z := Route.END_Z - 0.8
var rng := RandomNumberGenerator.new()
## Вода хранится ссылкой: её шейдер unshaded, поэтому сутки и дождь передаются
## ей параметрами через set_daylight() — иначе ночью вода остаётся дневной.
var water: MeshInstance3D
var water_material: ShaderMaterial

func _ready() -> void:
	rng.seed = 421
	var grass := Art.material(Color("8a9b50"), true)
	var earth := Art.material(Color("806447"), true)
	var sand := Art.material(Color("c6ae76"), true)
	var rock := Art.material(Color("9f9d84"), true)
	var wood := Art.material(Color("715036"), true)
	var leaves := Art.material(Color("506d35"), true)
	# 500 м дороги: тот же состав, один батч на чанк 32 ед., чтобы дальние
	# секции не попадали в список отрисовки камеры.
	# Полоса земли заходит и за старт (там улица и роща С1) и тянется назад дальше
	# камеры: иначе за началом маршрута просвечивало небо — автор 19.09.2026
	# спросил про «пустоту». Обрезка внутри чанка должна совпадать с концом
	# цикла, иначе последние чанки выходят пустыми.
	var ground_back_z := ceili(BACK_Z) + 240
	for start in range(floori(FRONT_Z) - 1, ground_back_z, 32):
		var chunk := Node3D.new()
		add_child(chunk)
		_ground(chunk, start, mini(start + 32, ground_back_z), grass, earth, sand, leaves, rock)
		Art.batch_static(chunk)
	_tree(Vector3(-3.25, 0, TREE_Z), wood, leaves)
	_tree_line(wood, leaves)
	_water()
	PrologueIntro.build(self)
	ForestStart.build(self)
	Church.build(self)
	BratishkinHouse.build(self)
	# Water and physical boundaries are independent.
	var physical_back_z := PrologueIntro.CUTSCENE_SPAWN.z + 3.0
	var center := (FRONT_Z + physical_back_z) / 2
	var depth := physical_back_z - FRONT_Z + 2
	for data in [Vector4(-5, center, 0.4, depth), Vector4(11.5, center, 0.4, depth),
			Vector4(3, FRONT_Z, 18, 0.4), Vector4(3, physical_back_z, 18, 0.4)]:
		var boundary := Art.box(self, Vector3(data.x, 1.5, data.y), Vector3(data.z, 4, data.w), earth, true)
		boundary.visible = false
	# Ground is already batched; only merge the landmarks together here.
	for child in get_children():
		if child is Node3D and child.get_meta("landmark", false):
			Art.batch_static(child)

func _ground(chunk: Node3D, start: int, end: int, grass: Material, earth: Material,
		sand: Material, leaves: Material, rock: Material) -> void:
	# Тропа идёт по лесу: земля и трава по обе стороны от неё, сама тропа —
	# утоптанная полоса 3 м со светлой серединой. Моря вдоль маршрута больше
	# нет: вода осталась только озером у рыбалки (канон 260 м). До 19.09.2026
	# вода тянулась вдоль всего маршрута, и половину кадра занимало море —
	# автор сказал, что дорога должна быть дорогой.
	for z in range(start, end, 2):
		# У озера левый край земли обрывается за песчаной полосой — иначе трава
		# торчала бы над водой. Ширина земли — 90 единиц: при 24 за деревьями
		# сразу начиналась пустота, и лес читался островом в небе.
		var left_x := -5.4 if near_lake(z) else -240.0
		var width := 240.0 - left_x
		var center_x := (left_x + 240.0) / 2.0
		Art.box(chunk, Vector3(center_x, -0.53, z), Vector3(width, 1, 2.02), earth, true)
		Art.box(chunk, Vector3(center_x, -0.06, z), Vector3(width, 0.16, 2.02), grass, true)
		# Тропа шире (замечание автора 19.09.2026: «тропа побольше»): тело 6 м,
		# светлая утоптанная середина 4 м.
		Art.box(chunk, Vector3(0, 0.02, z), Vector3(6.0, 0.06, 2.03), earth)
		Art.box(chunk, Vector3(0, 0.05, z),
			Vector3(4.0 + rng.randf_range(-0.3, 0.3), 0.03, 2.03), sand)
		if near_lake(z):
			# Песчаный берег и невидимая граница появляются только у озера.
			Art.box(chunk, Vector3(-5.2 + sin(z * 0.35) * 0.9, -0.16, z),
				Vector3(0.6, 0.18, 2.02), sand)
			var shore_limit := Art.box(chunk, Vector3(-5.6, 1, z), Vector3(0.3, 3, 2.05),
				earth, true)
			shore_limit.visible = false
	for i in (end - start) * 3:
		var z := rng.randf_range(start, end - 1)
		var x := rng.randf_range(-40.0 if not near_lake(z) else -5.4, 40.0)
		if absf(x) < 3.4:
			continue
		Art.box(chunk, Vector3(x, 0.1, z), Vector3(0.3, 0.15, 0.25), leaves)
		Art.box(chunk, Vector3(x + 0.1, 0.21, z), Vector3(0.08, 0.32, 0.07), grass)
	for i in (end - start) * 2:
		Art.box(chunk, Vector3(rng.randf_range(-1.4, 1.4), 0.065, rng.randf_range(start, end - 1)),
			Vector3(0.13, 0.018, 0.08), earth)
	for z in range(start, end, 3):
		for side in [-1.0, 1.0]:
			Art.box(chunk, Vector3(side * 4.6 + rng.randf_range(-0.4, 0.4), 0.1, z),
				Vector3(0.6, 0.35, 0.5), rock)
	for i in 4:
		var bush := Vector3(8.5, 0.35, start + 2 + i * 6)
		if bush.z >= end:
			continue
		Art.box(chunk, bush, Vector3(1.3, 0.7, 1.1), leaves)
		Art.box(chunk, bush + Vector3(0.1, 0.45, 0), Vector3(0.9, 0.3, 0.8), grass)
	# Подлесок: кусты между стволами. Без него стволы стоят рядами на газоне,
	# а лес должен читаться густым (замечание автора 19.09.2026).
	for z in range(start, end, 2):
		for side in [-1.0, 1.0]:
			for k in 2:
				var bx: float = side * rng.randf_range(5.5, 34.0)
				var bz := z + rng.randf_range(-1.0, 1.0)
				if near_lake(bz) and bx < -5.4:
					continue
				var size := rng.randf_range(0.9, 1.7)
				Art.box(chunk, Vector3(bx, 0.35, bz), Vector3(size, 0.7, size),
					leaves)
				Art.box(chunk, Vector3(bx + 0.1, 0.75, bz), Vector3(size * 0.7, 0.3,
					size * 0.7), grass)


static func lake_z() -> float:
	return Route.world_z(260.0)


static func near_lake(z: float) -> bool:
	# Озеро стоит там, где по канону рыбалка: 260 м, слева от тропы.
	return absf(z - lake_z()) < 440.0


func _tree_line(wood: Material, leaves: Material) -> void:
	# Густая стена леса вдоль маршрута. По замечанию автора 19.09.2026 («лес прям
	# густой») деревья стоят тесно в три ряда у самой тропы, дальше — реже.
	# Единицы мира: 12,24 на метр маршрута, поэтому 240 единиц — это первые 20 м,
	# а 640 — первые 52 м. Дальше маршрут пока без леса, это следующий шаг.
	var near_rows := [-6.5, -12.5, -21.0, -32.0, 12.5, 18.5, 27.0, 38.0]
	var z := BACK_Z - 2.0
	while z > BACK_Z - 2.0 - 400.0:
		for row in near_rows:
			if rng.randf() < 0.12:
				continue
			_tree(Vector3(row + rng.randf_range(-2.2, 2.2), 0,
				z + rng.randf_range(-3.5, 3.5)), wood, leaves)
		z -= 9.0
	while z > BACK_Z - 2.0 - 900.0:
		for row in [-6.5, -14.0, 12.5, 20.0]:
			if rng.randf() < 0.35:
				continue
			_tree(Vector3(row + rng.randf_range(-1.5, 1.5), 0,
				z + rng.randf_range(-3.0, 3.0)), wood, leaves)
		z -= 14.0

func _tree(pos: Vector3, wood: Material, leaves: Material) -> void:
	var tree := Node3D.new()
	tree.set_meta("landmark", true)
	add_child(tree)
	tree.position = pos
	Art.box(tree, Vector3(0, 1.45, 0), Vector3(0.65, 2.9, 0.65), wood, true)
	Art.box(tree, Vector3(0, 0.12, 0), Vector3(1.1, 0.25, 0.9), wood)
	var branch := Art.box(tree, Vector3(-0.45, 2.3, 0), Vector3(0.35, 1.5, 0.35), wood)
	branch.rotation.z = -0.7
	for offset in [Vector3(-1, 3.15, 0.2), Vector3(1, 3.3, 0), Vector3(0, 3.6, -1), Vector3(0, 4.05, 0)]:
		Art.box(tree, offset, Vector3(1.8, 1.5, 1.7), leaves)
		var highlight := Art.material(Color("738644"), true)
		Art.box(tree, offset + Vector3(-0.08, 0.76, 0), Vector3(1.6, 0.08, 1.5), highlight)
		for i in 4:
			Art.box(tree, offset + Vector3(rng.randf_range(-0.75, 0.75), 0.2, 0.88),
				Vector3(0.24, 0.22, 0.09), highlight)

func _water() -> void:
	# Вода — только озеро у рыбалки (260 м), слева от тропы. Раньше это была
	# плоскость во всю длину маршрута, и дорога читалась полоской суши в море.
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(180, 900)
	water = MeshInstance3D.new()
	water.mesh = mesh
	water.position = Vector3(-96.0, -0.33, lake_z())
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water.material_override = water_material
	add_child(water)


func set_daylight(night: float, wet: float) -> void:
	# Вода рисуется без расчёта света, поэтому сутки и дождь приходят сюда
	# параметрами шейдера, а не через солнце и ambient.
	if water_material == null:
		return
	water_material.set_shader_parameter("night", clampf(night, 0.0, 1.0))
	water_material.set_shader_parameter("wet", clampf(wet, 0.0, 1.0))
