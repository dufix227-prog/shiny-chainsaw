extends RefCounted

## Земля пробы графики: короткий кусок тропы (~7 м маршрута), справа обрыв
## в долину с рекой, вдали горы. Земля — мелкие воксельные столбики 0,5×0,25,
## у каждого свой оттенок; горы и долина — из кубиков крупнее (их видно издалека).

const Mesher = preload("res://scenes/style_probe/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const COLUMN := 0.5
const LAYER := 0.25
const X_MIN := -44.0
const X_MAX := 18.0
const Z_MIN := -100.0
const Z_MAX := 22.0
const VALLEY_Y := -16.0
## Позади старта и за завалом земля круто поднимается — туда не пройти.
const START_RISE_Z := 12.0
const END_RISE_Z := -84.0
const BARRIER_Z := -74.0
## Крутизна подъёма у краёв: 1,3 вверх на единицу — круче, чем может идти кот.
const EDGE_STEEPNESS := 1.3

const DIRT := ["#6e4526", "#7d5130", "#8d5d37", "#9c6a40", "#a9774a"]
const PATH_STONE := ["#7a746c", "#8a837a", "#978f85"]
const CLIFF_ROCK := ["#5b4a42", "#6a574c", "#786357", "#877063", "#94806f"]
const VALLEY_GRASS := ["#26401f", "#2e4a23", "#375628", "#43632d"]
const MOUNTAIN_LOW := ["#2c3d2a", "#344731", "#3d5236"]
const MOUNTAIN_HIGH := ["#5a4852", "#66525b", "#735d64", "#826a6c", "#957a74"]

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init(seed: int = 7) -> void:
	_noise.seed = seed
	_noise.frequency = 0.08
	_rng.seed = seed


func path_center_x(z: float) -> float:
	return -2.0 + sin(z * 0.045) * 2.5 + sin(z * 0.11 + 1.0) * 0.8


func path_width(z: float) -> float:
	return 5.2 + 1.4 * sin(z * 0.07 + 0.5)


func cliff_x(z: float) -> float:
	return 12.0 + sin(z * 0.08) * 1.5


func fence_x(z: float) -> float:
	return cliff_x(z) - 1.6


func is_path(x: float, z: float) -> bool:
	return z < START_RISE_Z - 1.0 and z > BARRIER_Z - 6.0 and absf(x - path_center_x(z)) < path_width(z) / 2.0


## Высота верха земли в точке, кратная LAYER.
func ground_height(x: float, z: float) -> float:
	if x > cliff_x(z):
		return snappedf(VALLEY_Y + maxf(_noise.get_noise_2d(x, z), 0.0) * 1.5, LAYER)
	var height := 0.0
	if not is_path(x, z):
		var from_edge := absf(x - path_center_x(z)) - path_width(z) / 2.0
		height = LAYER + maxf(_noise.get_noise_2d(x, z), 0.0) * 1.2 * smoothstep(0.0, 4.0, from_edge)
	var rise := maxf(path_center_x(z) - 15.0 - x, 0.0) + maxf(z - START_RISE_Z, 0.0) + maxf(END_RISE_Z - z, 0.0)
	return snappedf(height + rise * EDGE_STEEPNESS, LAYER)


## Возвращает [меш земли, форма коллизии].
func build_ground() -> Array:
	var columns := int((X_MAX - X_MIN) / COLUMN) + 1
	var rows := int((Z_MAX - Z_MIN) / COLUMN) + 1
	var levels := PackedInt32Array()
	levels.resize(columns * rows)
	for j in rows:
		for i in columns:
			levels[i + j * columns] = roundi(ground_height(X_MIN + i * COLUMN, Z_MIN + j * COLUMN) / LAYER)
	var mesher := Mesher.new(Vector3(COLUMN, LAYER, COLUMN), Vector3(X_MIN - COLUMN / 2.0, 0, Z_MIN - COLUMN / 2.0))
	for j in rows:
		for i in columns:
			var x := X_MIN + i * COLUMN
			var z := Z_MIN + j * COLUMN
			var top := levels[i + j * columns]
			var lowest := top
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = i + offset.x
				var nj: int = j + offset.y
				if ni >= 0 and ni < columns and nj >= 0 and nj < rows:
					lowest = mini(lowest, levels[ni + nj * columns])
			for k in range(lowest - 1, top):
				mesher.set_cell(Vector3i(i, k, j), _ground_color(x, z, top - 1 - k, top))
	var mesh := ArrayMesh.new()
	mesher.commit(mesh, Recipes.VOXEL)
	return [mesh, _grid_collision(levels, columns, rows)]


## depth — сколько слоёв от верха (0 — верхний кубик).
func _ground_color(x: float, z: float, depth: int, top: int) -> Color:
	var in_valley := x > cliff_x(z)
	if depth == 0:
		if is_path(x, z):
			# Изредка — плоский камень в тропе, как на картинке меню.
			var slab := hash(Vector2i(floori(x), floori(z))) % 100 < 7
			return Recipes._pick(PATH_STONE if slab else DIRT, _rng, 0.3 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5)
		var palette: Array = VALLEY_GRASS if in_valley else Recipes.GRASS
		return Recipes._pick(palette, _rng, 0.45 + _noise.get_noise_2d(x * 0.6, z * 0.6) * 0.6)
	if depth <= 2 and top > VALLEY_Y / LAYER + 4:
		return Recipes._pick(DIRT, _rng, 0.3)
	return Recipes._pick(CLIFF_ROCK, _rng, 0.5 + sin(float(top - depth) * 0.9) * 0.3)


func _grid_collision(levels: PackedInt32Array, columns: int, rows: int) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	for j in rows - 1:
		for i in columns - 1:
			var a := Vector3(X_MIN + i * COLUMN, levels[i + j * columns] * LAYER, Z_MIN + j * COLUMN)
			var b := Vector3(a.x + COLUMN, levels[i + 1 + j * columns] * LAYER, a.z)
			var c := Vector3(a.x, levels[i + (j + 1) * columns] * LAYER, a.z + COLUMN)
			var d := Vector3(a.x + COLUMN, levels[i + 1 + (j + 1) * columns] * LAYER, a.z + COLUMN)
			faces.append_array([a, b, c, b, d, c])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


# --- Даль: долина с рекой и горы ------------------------------------------------

func river_x(z: float) -> float:
	return 70.0 + sin(z * 0.012) * 30.0


func valley_height(x: float, z: float) -> float:
	if absf(x - river_x(z)) < 7.0:
		return VALLEY_Y - 1.0
	return snappedf(VALLEY_Y + maxf(_noise.get_noise_2d(x * 0.3, z * 0.3), 0.0) * 2.5, 0.5)


func build_valley() -> ArrayMesh:
	return _height_field(18.0, 260.0, -460.0, 60.0, 1.5, 0.5, valley_height, _valley_color)


func _valley_color(x: float, z: float, height: float) -> Color:
	if height < VALLEY_Y - 0.5:
		return Color("#2b2a24")
	return Recipes._pick(VALLEY_GRASS, _rng, 0.4 + _noise.get_noise_2d(x * 0.2, z * 0.2) * 0.6)


func mountain_height(x: float, z: float) -> float:
	var distance := Vector2(x - 40.0, z + 110.0).length()
	var ridge := 1.0 - absf(_noise.get_noise_2d(x * 0.05, z * 0.05))
	var tall := clampf(distance / 380.0, 0.0, 1.0)
	return snappedf(VALLEY_Y + ridge * ridge * lerpf(20.0, 110.0, tall), 3.0)


func build_mountains() -> ArrayMesh:
	return _height_field(40.0, 700.0, -800.0, -110.0, 6.0, 3.0, mountain_height, _mountain_color)


func _mountain_color(x: float, z: float, height: float) -> Color:
	var above_valley := height - VALLEY_Y
	if above_valley < 25.0:
		return Recipes._pick(MOUNTAIN_LOW, _rng, 0.5)
	return Recipes._pick(MOUNTAIN_HIGH, _rng, clampf(above_valley / 110.0, 0.0, 1.0))


## Поле столбиков для дали: столбик от соседа пониже до своей высоты.
func _height_field(x_min: float, x_max: float, z_min: float, z_max: float, column: float, layer: float,
		height_at: Callable, color_at: Callable) -> ArrayMesh:
	var columns := int((x_max - x_min) / column) + 1
	var rows := int((z_max - z_min) / column) + 1
	var levels := PackedInt32Array()
	levels.resize(columns * rows)
	for j in rows:
		for i in columns:
			levels[i + j * columns] = roundi(height_at.call(x_min + i * column, z_min + j * column) / layer)
	var mesher := Mesher.new(Vector3(column, layer, column), Vector3(x_min - column / 2.0, 0, z_min - column / 2.0))
	for j in rows:
		for i in columns:
			var top := levels[i + j * columns]
			var lowest := top
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = i + offset.x
				var nj: int = j + offset.y
				if ni >= 0 and ni < columns and nj >= 0 and nj < rows:
					lowest = mini(lowest, levels[ni + nj * columns])
			var x := x_min + i * column
			var z := z_min + j * column
			for k in range(lowest - 1, top):
				mesher.set_cell(Vector3i(i, k, j), color_at.call(x, z, k * layer))
	var mesh := ArrayMesh.new()
	mesher.commit(mesh, Recipes.VOXEL)
	return mesh


## Лента воды вдоль реки.
func build_water() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var y := VALLEY_Y - 0.35
	var z := 60.0
	while z > -460.0:
		var next_z := z - 6.0
		var a := Vector3(river_x(z) - 7.5, y, z)
		var b := Vector3(river_x(z) + 7.5, y, z)
		var c := Vector3(river_x(next_z) - 7.5, y, next_z)
		var d := Vector3(river_x(next_z) + 7.5, y, next_z)
		for point in [a, c, b, b, c, d]:
			tool.add_vertex(point)
		z = next_z
	var mesh := tool.commit()
	mesh.surface_set_material(0, load("res://scenes/style_probe/materials/water.tres"))
	return mesh
