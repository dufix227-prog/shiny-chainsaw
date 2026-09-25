extends RefCounted

## Рецепты воксельных деревьев, кустов, камней и мелочей для пробы графики.
## Каждый объект — сотни мелких кубиков (0,1–0,35 единицы) с разными оттенками,
## как на картинке главного меню. Кот ≈ 2,5 единицы ростом.
##
## Палитры идут от тёмного к светлому: верх кроны светлее, низ темнее.

const Mesher = preload("res://scenes/style_probe/voxel_mesher.gd")

const VOXEL := preload("res://scenes/style_probe/materials/voxel.tres")
const FOLIAGE := preload("res://scenes/style_probe/materials/foliage.tres")
const GLOW := preload("res://scenes/style_probe/materials/glow.tres")
const CLOUD := preload("res://scenes/style_probe/materials/cloud.tres")

const LEAVES := ["#1c3519", "#24421d", "#2d5022", "#385e27", "#46702c", "#587f30", "#6d8f34", "#86a23c"]
const SPRUCE := ["#1d3a25", "#24452b", "#2c5131", "#355d37", "#436c3f", "#557d47"]
const PINE_NEEDLES := ["#1b3a20", "#234726", "#2d552b", "#3a6532", "#4b763a"]
const BIRCH_LEAVES := ["#4f7a26", "#5f8c2d", "#719f35", "#86b140", "#9cc050"]
const BARK := ["#3a2416", "#462c1b", "#533520", "#603e25", "#6e482b"]
const PINE_BARK := ["#6a3419", "#7d4020", "#924d28", "#a65b31", "#b86b3b"]
const BIRCH_BARK := ["#d3cdbd", "#e0dbcd", "#ece8dd"]
const STONE := ["#5a5552", "#67615d", "#746e68", "#827b74", "#908980"]
const MOSS := ["#3f5f24", "#4c6e2a", "#5b7d31"]
const GRASS := ["#2f5a1f", "#3b6a24", "#4a7a2a", "#5d8c30", "#77a03a"]
const WOOD := ["#4d311e", "#5c3b24", "#6b462b", "#7a5132"]
const CLOUD_COLORS := ["#e48c78", "#ee9f84", "#f5b490", "#fac9a0", "#fcdcb4"]


## Ель: ярусы-конусы, каждый ярус — усечённый конус, низ шире; верх ярусов светлее.
## Крона начинается выше кота, чтобы нижние ярусы не висели плитами перед камерой.
static func spruce(seed: int, height_voxels: int = 42) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.25)
	var wood := Mesher.new()
	var leaves := Mesher.new()
	_trunk(wood, rng, 2, 0, height_voxels - 4, BARK)
	var crown_start := maxi(int(height_voxels * 0.25), 9)
	var tier := 7
	for y in range(crown_start, height_voxels + 2):
		var along := float(y - crown_start) / (height_voxels + 2 - crown_start)
		var in_tier := float((y - crown_start) % tier) / tier  # 0 — низ яруса, 1 — верх
		var tier_radius := lerpf(height_voxels * 0.2, 1.0, along)
		var radius := tier_radius * lerpf(1.0, 0.45, in_tier)
		var light := clampf(0.2 + in_tier * 0.4 + along * 0.35, 0.0, 1.0)
		_disc(leaves, rng, noise, y, radius, SPRUCE, light)
	wood.hidden_by = leaves.cells
	return _finish([[wood, VOXEL], [leaves, FOLIAGE]])


## Сосна: высокий рыжий ствол, пучки хвои только наверху.
static func pine(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.3)
	var wood := Mesher.new()
	var needles := Mesher.new()
	_trunk(wood, rng, 2, 0, 46, PINE_BARK)
	_line(wood, rng, Vector3i(0, 34, 0), Vector3i(5, 39, 2), PINE_BARK)
	_line(wood, rng, Vector3i(0, 38, 0), Vector3i(-4, 42, -3), PINE_BARK)
	_blob(needles, rng, noise, Vector3(0, 46, 0), Vector3(8, 3.5, 8), PINE_NEEDLES)
	_blob(needles, rng, noise, Vector3(5, 40, 2), Vector3(5, 2.5, 5), PINE_NEEDLES)
	_blob(needles, rng, noise, Vector3(-4, 43, -3), Vector3(5, 2.5, 5), PINE_NEEDLES)
	_blob(needles, rng, noise, Vector3(1, 49, 1), Vector3(5, 2.2, 5), PINE_NEEDLES)
	wood.hidden_by = needles.cells
	return _finish([[wood, VOXEL], [needles, FOLIAGE]])


## Широколиственное дерево (как большие деревья слева на картинке меню):
## толстый ствол с корнями, ветви и кучевая крона с просветами.
static func broadleaf(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.22)
	var wood := Mesher.new(Vector3.ONE * 0.35)
	var leaves := Mesher.new(Vector3.ONE * 0.35)
	# Крона начинается выше камеры (≈ 9 единиц), чтобы камера не ныряла под листву.
	_trunk(wood, rng, 4, 0, 30, BARK)
	for x in range(-3, 3):
		for z in range(-3, 3):
			if absi(x * 2 + 1) + absi(z * 2 + 1) <= 8:
				for y in 2:
					wood.set_cell(Vector3i(x, y, z), _pick(BARK, rng, 0.3))
	_line(wood, rng, Vector3i(0, 22, 0), Vector3i(7, 30, 3), BARK, 2)
	_line(wood, rng, Vector3i(0, 23, 0), Vector3i(-6, 31, -2), BARK, 2)
	for blob in [[Vector3(0, 34, 0), Vector3(9, 6, 9)], [Vector3(7, 31, 3), Vector3(6, 5, 6)],
			[Vector3(-6, 32, -2), Vector3(6, 5, 6)], [Vector3(2, 38, -3), Vector3(6, 4, 6)],
			[Vector3(-3, 30, 5), Vector3(5, 4, 5)]]:
		_blob(leaves, rng, noise, blob[0], blob[1], LEAVES)
	wood.hidden_by = leaves.cells
	return _finish([[wood, VOXEL], [leaves, FOLIAGE]])


## Берёза: белый ствол в чёрных чёрточках, узкая светлая крона.
static func birch(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.3)
	var wood := Mesher.new(Vector3.ONE * 0.25)
	var leaves := Mesher.new(Vector3.ONE * 0.25)
	for y in 34:
		for x in [-1, 0]:
			for z in [-1, 0]:
				var dark := rng.randf() < 0.13
				wood.set_cell(Vector3i(x, y, z), Color("#2a2522") if dark else _pick(BIRCH_BARK, rng, rng.randf()))
	_blob(leaves, rng, noise, Vector3(0, 33, 0), Vector3(6, 11, 6), BIRCH_LEAVES)
	_blob(leaves, rng, noise, Vector3(4, 28, 1), Vector3(3.5, 5, 3.5), BIRCH_LEAVES)
	_blob(leaves, rng, noise, Vector3(-3, 30, -2), Vector3(3.5, 5, 3.5), BIRCH_LEAVES)
	wood.hidden_by = leaves.cells
	return _finish([[wood, VOXEL], [leaves, FOLIAGE]])


static func bush(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.35)
	var leaves := Mesher.new(Vector3.ONE * 0.25)
	_blob(leaves, rng, noise, Vector3(0, 2, 0), Vector3(5, 3.5, 5), LEAVES)
	_blob(leaves, rng, noise, Vector3(3, 1, 2), Vector3(3, 2.5, 3), LEAVES)
	return _finish([[leaves, FOLIAGE]])


## Камень: неровная глыба, сверху мох.
static func rock(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var noise := _noise(seed, 0.3)
	var stone := Mesher.new()
	_blob(stone, rng, noise, Vector3(0, 1, 0), Vector3(5, 3.5, 4), STONE)
	_blob(stone, rng, noise, Vector3(3, 0, 2), Vector3(3, 2, 3), STONE)
	for cell: Vector3i in stone.cells.keys():
		if not stone.cells.has(cell + Vector3i.UP) and cell.y >= 2 and rng.randf() < 0.55:
			stone.cells[cell] = _pick(MOSS, rng, rng.randf())
	return _finish([[stone, VOXEL]])


## Бревно длиной 7,8 вдоль оси X, торцы светлые.
static func log(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var wood := Mesher.new()
	for x in range(-13, 13):
		for y in range(-2, 2):
			for z in range(-2, 2):
				if Vector2(y + 0.5, z + 0.5).length() < 2.1:
					var is_end := x == -13 or x == 12
					var color := Color("#b08a5a") if is_end else _pick(BARK, rng, rng.randf())
					if not is_end and y == 1 and rng.randf() < 0.3:
						color = _pick(MOSS, rng, rng.randf())
					wood.set_cell(Vector3i(x, y, z), color)
	return _finish([[wood, VOXEL]])


## Пятно травы и цветов 2×2 единицы (кубики 0,1). Без коллизии.
## flower_colors — цвета лепестков этого варианта (пусто — только трава).
static func ground_cover(seed: int, flower_colors: Array = []) -> ArrayMesh:
	var rng := _rng(seed)
	var plants := Mesher.new(Vector3.ONE * 0.1, Vector3(-1, 0, -1))
	for i in 30:
		var x := rng.randi_range(0, 19)
		var z := rng.randi_range(0, 19)
		var height := rng.randi_range(2, 6)
		for y in height:
			plants.set_cell(Vector3i(x, y, z), _pick(GRASS, rng, float(y) / height))
	for i in (rng.randi_range(1, 3) if not flower_colors.is_empty() else 0):
		var x := rng.randi_range(1, 18)
		var z := rng.randi_range(1, 18)
		var stem := rng.randi_range(3, 6)
		for y in stem:
			plants.set_cell(Vector3i(x, y, z), Color(GRASS[1]))
		var petal := Color(flower_colors[rng.randi_range(0, flower_colors.size() - 1)])
		for offset in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			plants.set_cell(Vector3i(x, stem, z) + offset, petal)
		plants.set_cell(Vector3i(x, stem, z), Color("#e0902f"))
	return _finish([[plants, FOLIAGE]])


## Звено забора 3 единицы вдоль оси X: столб в начале и две жерди.
static func fence_segment(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var wood := Mesher.new(Vector3.ONE * 0.2, Vector3(0, 0, -0.2))
	for y in 8:
		for x in 2:
			for z in 2:
				wood.set_cell(Vector3i(x, y, z), _pick(WOOD, rng, rng.randf()))
	for rail_y in [3, 6]:
		for x in range(2, 15):
			wood.set_cell(Vector3i(x, rail_y, 0), _pick(WOOD, rng, rng.randf()))
			wood.set_cell(Vector3i(x, rail_y, 1), _pick(WOOD, rng, rng.randf()))
	return _finish([[wood, VOXEL]])


## Фонарь на столбе (предложение, как на картинке меню): светящийся кубик.
static func lantern(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	var wood := Mesher.new(Vector3.ONE * 0.2)
	var light := Mesher.new(Vector3.ONE * 0.2)
	for y in 15:
		for x in [-1, 0]:
			for z in [-1, 0]:
				wood.set_cell(Vector3i(x, y, z), _pick(WOOD, rng, rng.randf()))
	for x in range(1, 5):
		wood.set_cell(Vector3i(x, 14, -1), _pick(WOOD, rng, rng.randf()))
	for x in range(3, 6):
		for z in range(-2, 1):
			wood.set_cell(Vector3i(x, 13, z), Color("#2a211a"))
			wood.set_cell(Vector3i(x, 9, z), Color("#2a211a"))
			for y in range(10, 13):
				light.set_cell(Vector3i(x, y, z), Color.WHITE)
	return _finish([[wood, VOXEL], [light, GLOW]])


## Плоское закатное облако из крупных кубиков, без теней и тумана.
static func cloud(seed: int) -> ArrayMesh:
	var rng := _rng(seed)
	# Облака на картинке меню — плоские плотные «лепёшки», шум почти не нужен.
	var noise := _noise(seed, 0.08)
	var puffs := Mesher.new(Vector3.ONE * 2.0)
	_blob(puffs, rng, noise, Vector3.ZERO, Vector3(9, 1.2, 4), CLOUD_COLORS)
	_blob(puffs, rng, noise, Vector3(-4, 1, 0), Vector3(4, 1.2, 3), CLOUD_COLORS)
	_blob(puffs, rng, noise, Vector3(4, 1, -1), Vector3(5, 1.2, 3), CLOUD_COLORS)
	return _finish([[puffs, CLOUD]])


# --- Кирпичики рецептов -----------------------------------------------------------

## Ствол width×width кубиков по центру от from до to.
static func _trunk(mesher, rng: RandomNumberGenerator, width: int, from: int, to: int, palette: Array) -> void:
	var half := width / 2
	for y in range(from, to):
		for x in range(-half, width - half):
			for z in range(-half, width - half):
				mesher.set_cell(Vector3i(x, y, z), _pick(palette, rng, rng.randf()))


## Ветка толщиной thickness от a до b.
static func _line(mesher, rng: RandomNumberGenerator, a: Vector3i, b: Vector3i, palette: Array, thickness: int = 1) -> void:
	var steps := maxi(maxi(absi(b.x - a.x), absi(b.y - a.y)), absi(b.z - a.z))
	for i in steps + 1:
		var point := Vector3i(Vector3(a).lerp(Vector3(b), float(i) / steps).round())
		for dx in thickness:
			for dz in thickness:
				mesher.set_cell(point + Vector3i(dx, 0, dz), _pick(palette, rng, rng.randf()))


## Эллипсоид с рваным краем (шум), верх светлее.
static func _blob(mesher, rng: RandomNumberGenerator, noise: FastNoiseLite, center: Vector3,
		radii: Vector3, palette: Array) -> void:
	var reach := Vector3i(radii.ceil()) + Vector3i.ONE
	var middle := Vector3i(center.round())
	for x in range(-reach.x, reach.x + 1):
		for y in range(-reach.y, reach.y + 1):
			for z in range(-reach.z, reach.z + 1):
				var cell := middle + Vector3i(x, y, z)
				var distance := (Vector3(x, y, z) / radii).length()
				if distance < 1.0 + noise.get_noise_3dv(Vector3(cell)) * 0.45:
					var light := clampf((y + radii.y) / (2.0 * radii.y), 0.0, 1.0)
					mesher.set_cell(cell, _pick(palette, rng, light))


## Горизонтальный слой-диск радиусом radius с рваным краем.
static func _disc(mesher, rng: RandomNumberGenerator, noise: FastNoiseLite, y: int, radius: float,
		palette: Array, light: float) -> void:
	var reach := ceili(radius) + 2
	for x in range(-reach, reach):
		for z in range(-reach, reach):
			var distance := Vector2(x + 0.5, z + 0.5).length()
			if distance < radius + noise.get_noise_3d(x, y, z) * 1.6:
				var edge_light := light + (distance / maxf(radius, 1.0)) * 0.2
				mesher.set_cell(Vector3i(x, y, z), _pick(palette, rng, edge_light))


## Цвет из палитры: light 0 — тёмный конец, 1 — светлый, плюс случайный разброс.
static func _pick(palette: Array, rng: RandomNumberGenerator, light: float) -> Color:
	var index := roundi(light * (palette.size() - 1) + rng.randf_range(-1.2, 1.2))
	return Color(palette[clampi(index, 0, palette.size() - 1)])


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	return noise


static func _finish(surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		surface[0].commit(mesh, surface[1])
	return mesh
