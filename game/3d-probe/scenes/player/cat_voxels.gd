extends RefCounted

## Рецепт модели героя-кота из мелких вокселей (0,1 единицы), в стиле
## гайда «как в меню». Каждая подвижная часть — отдельный меш со своей точкой
## вращения: ноги, лапы, голова, хвост. Модель смотрит вдоль −Z.
##
## Что из этого канон автора: антропоморфный кот на двух лапах, милые
## треугольные ушки, мордочка с деталями для эмоций, красный браслетик
## (ideas/common/design/appearance/plan.md). Рыжий полосатый окрас — прежний
## вид кота из пробы; окрас меняется в палитрах ниже.
##
## Пересобрать: godot --headless --path game/3d-probe -s res://tools/build_cat_model.gd

const Mesher = preload("res://scenes/voxel/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const VOXEL := 0.1
const PARTS_DIR := "res://scenes/player/cat_parts/"

const FUR := ["#b8652a", "#c97634", "#d8863e", "#e3964b", "#eba65c"]
const FUR_STRIPE := "#9e4f1d"
const CREAM := ["#ecd2a4", "#f3dfb8", "#f9ebcf"]
const EAR_INNER := "#e8a3a0"
const NOSE := "#d9767a"
const BLUSH := "#f0a08c"
const EYE := "#241a16"
const EYE_SHINE := "#ffffff"
const WHISKER := "#fbf6ee"
const BRACELET := "#d23a30"
const BRACELET_BEAD := "#fff4ec"

## Точки вращения частей (в единицах мира, от ступней).
const PIVOTS := {
	"leg_left": Vector3(-0.3, 0.75, 0.0), "leg_right": Vector3(0.3, 0.75, 0.0),
	"arm_left": Vector3(-0.75, 1.65, -0.05), "arm_right": Vector3(0.75, 1.65, -0.05),
	"body": Vector3.ZERO, "head": Vector3(0.0, 1.75, -0.1), "tail": Vector3(0.0, 0.95, 0.4),
}

var _rng := RandomNumberGenerator.new()
var _parts := {}


func _init() -> void:
	_rng.seed = 2026
	for part in PIVOTS:
		_parts[part] = Mesher.new(Vector3.ONE * VOXEL, -PIVOTS[part])


func build_all() -> void:
	_legs()
	_body()
	_arms()
	_head()
	_tail()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARTS_DIR))
	for part in _parts:
		var mesh := ArrayMesh.new()
		_parts[part].commit(mesh, Recipes.VOXEL)
		ResourceSaver.save(mesh, PARTS_DIR + part + ".res", ResourceSaver.FLAG_COMPRESS)


# --- Части -------------------------------------------------------------------

func _legs() -> void:
	for side in ["left", "right"]:
		var x0 := -5 if side == "left" else 1
		var part: String = "leg_" + side
		_box(part, Vector3i(x0, 1, -2), Vector3i(4, 7, 4), func(c: Vector3i): return _fur(c.y, 0, 34))
		# Стопа светлая и чуть вытянута вперёд.
		_box(part, Vector3i(x0, 0, -3), Vector3i(4, 1, 5), func(_c: Vector3i): return _pick(CREAM, 0.3))


func _body() -> void:
	_box("body", Vector3i(-6, 7, -4), Vector3i(12, 11, 8), func(c: Vector3i):
		var on_front := c.z == -4
		if on_front and c.x >= -3 and c.x <= 2 and c.y >= 10 and c.y <= 16:
			return _pick(CREAM, 0.5)
		var on_side_or_back := c.x == -6 or c.x == 5 or c.z == 3
		if on_side_or_back and c.y in [9, 12, 15]:
			return Color(FUR_STRIPE)
		return _fur(c.y, 0, 34))


func _arms() -> void:
	for side in ["left", "right"]:
		var x0 := -9 if side == "left" else 6
		var part: String = "arm_" + side
		_box(part, Vector3i(x0, 9, -2), Vector3i(3, 8, 3), func(c: Vector3i):
			if c.y <= 10:
				return _pick(CREAM, 0.4)
			# Красный браслетик на левой лапе (канон), бусина спереди.
			if side == "left" and c.y == 11:
				return Color(BRACELET_BEAD) if c.z == -2 and c.x == x0 + 1 else Color(BRACELET)
			return _fur(c.y, 0, 34))
	# Браслет чуть толще лапы — чтобы читался издалека.
	for x in range(-10, -5):
		for z in range(-3, 2):
			var on_ring := x == -10 or x == -6 or z == -3 or z == 1
			if on_ring and not ((x == -10 or x == -6) and (z == -3 or z == 1)):
				_parts.arm_left.set_cell(Vector3i(x, 11, z), Color(BRACELET_BEAD) if z == -3 and x == -8 else Color(BRACELET))


func _head() -> void:
	var size := Vector3i(16, 13, 13)
	var first := Vector3i(-8, 17, -7)
	_box("head", first, size, func(c: Vector3i): return _fur(c.y, 0, 34), true)
	var head: Object = _parts.head
	var face_z := -7
	# Мордочка: светлая, выступает на один воксель.
	for x in range(-3, 3):
		for y in range(18, 22):
			head.set_cell(Vector3i(x, y, face_z - 1), _pick(CREAM, 0.6))
	for x in range(-1, 1):
		head.set_cell(Vector3i(x, 21, face_z - 1), Color(NOSE))
		head.set_cell(Vector3i(x, 19, face_z - 1), Color(EYE))
	head.set_cell(Vector3i(-2, 20, face_z - 1), Color(EYE))
	head.set_cell(Vector3i(1, 20, face_z - 1), Color(EYE))
	# Глаза 3×4 с бликом; румянец под ними.
	for eye_x in [-6, 3]:
		for x in range(eye_x, eye_x + 3):
			for y in range(22, 26):
				head.set_cell(Vector3i(x, y, face_z), Color(EYE))
		head.set_cell(Vector3i(eye_x + 1, 25, face_z), Color(EYE_SHINE))
		head.set_cell(Vector3i(eye_x + 2, 24, face_z), Color(EYE_SHINE))
	for x in [-7, -6, 5, 6]:
		head.set_cell(Vector3i(x, 20, face_z), Color(BLUSH))
	# Полоски на лбу — «буква М» рыжего кота.
	for stripe in [[-1, 26, 3], [0, 26, 3], [-4, 27, 2], [3, 27, 2], [-7, 26, 2], [6, 26, 2]]:
		for y in range(stripe[1], stripe[1] + stripe[2]):
			head.set_cell(Vector3i(stripe[0], y, face_z), Color(FUR_STRIPE))
	# Усы — белые штрихи по бокам мордочки.
	for y in [19, 21]:
		for x in [-9, -10, 8, 9]:
			head.set_cell(Vector3i(x, y, -6), Color(WHISKER))
	_ears()


## Треугольные ушки: снизу 5 вокселей, сверху 1, внутри розовые.
func _ears() -> void:
	var head: Object = _parts.head
	var rows := [[-8, -4], [-8, -5], [-8, -6], [-8, -7], [-8, -8]]
	for i in rows.size():
		var y := 30 + i
		for x in range(rows[i][0], rows[i][1] + 1):
			for z in range(-3, 0):
				var inner: bool = z == -3 and x > rows[i][0] and x < rows[i][1] and i < 3
				var color := Color(EAR_INNER) if inner else _fur(y, 0, 34)
				head.set_cell(Vector3i(x, y, z), color)
				head.set_cell(Vector3i(-1 - x, y, z), color)


func _tail() -> void:
	var steps := 18
	for i in steps:
		var t := float(i) / (steps - 1)
		var y := 9 + roundi(15.0 * pow(t, 1.2))
		var z := 4 + roundi(4.5 * sin(PI * t * 0.85))
		var color := Color(FUR_STRIPE) if i % 4 == 3 or i >= steps - 2 else _fur(y, 0, 34)
		for x in range(-1, 1):
			for dz in range(0, 2):
				_parts.tail.set_cell(Vector3i(x, y, z + dz), color)
				_parts.tail.set_cell(Vector3i(x, y + 1, z + dz), color)


# --- Помощники ---------------------------------------------------------------

## Прямоугольник вокселей в части part. color_for(cell) даёт цвет.
## rounded — срезать рёбра, чтобы голова не была кубом.
func _box(part: String, first: Vector3i, size: Vector3i, color_for: Callable, rounded: bool = false) -> void:
	for x in range(first.x, first.x + size.x):
		for y in range(first.y, first.y + size.y):
			for z in range(first.z, first.z + size.z):
				if rounded:
					var edges := int(x == first.x or x == first.x + size.x - 1) \
						+ int(y == first.y or y == first.y + size.y - 1) \
						+ int(z == first.z or z == first.z + size.z - 1)
					if edges >= 2:
						continue
				var cell := Vector3i(x, y, z)
				_parts[part].set_cell(cell, color_for.call(cell))


## Мех светлее к макушке, с разбросом оттенка по вокселям.
func _fur(y: int, low: int, high: int) -> Color:
	return _pick(FUR, clampf(float(y - low) / (high - low), 0.0, 1.0))


func _pick(palette: Array, light: float) -> Color:
	return Recipes._pick(palette, _rng, light)
