extends RefCounted

## Рецепты моделей героя-кота из мелких вокселей (0,1 единицы) — четыре
## варианта на выбор автора (просьба 25.09.2026: «несколько моделек котика,
## а я выберу лучшую»). Варианты различаются строением, а не цветом: пропорции,
## уши, глаза, хвост, пух. Окрас у всех одинаковый, чтобы сравнивать форму.
##
## Лицо (глаза и рот) — отдельные меши под каждую эмоцию. Эмоции — канон
## автора 19.09.2026: радость, грусть, злость, удивление; плюс спокойное лицо
## и закрытые глаза для моргания.
##
## Что канон: антропоморфный кот на двух лапах, милые треугольные ушки,
## мордочка с деталями для эмоций, красный браслетик.
## Пересобрать: godot --headless --path game/3d-probe -s res://tools/build_cat_model.gd

const Mesher = preload("res://scenes/voxel/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const VOXEL := 0.1

## Размеры — в вокселях. hip — половина расстояния между ногами.
const VARIANTS := {
	"a": {"name": "Рыжик", "leg_w": 4, "leg_h": 7, "hip": 3, "body": Vector3i(12, 11, 8), "arm": Vector2i(3, 8),
		"head": Vector3i(16, 13, 13), "ears": "triangle", "ear_inset": 0, "eye": Vector2i(3, 4), "eye_gap": 6,
		"tail": "curve", "fluffy": false},
	"b": {"name": "Чиби", "leg_w": 4, "leg_h": 4, "hip": 3, "body": Vector3i(11, 8, 8), "arm": Vector2i(3, 6),
		"head": Vector3i(20, 16, 15), "ears": "round", "ear_inset": 2, "eye": Vector2i(4, 5), "eye_gap": 6,
		"tail": "puff", "fluffy": false},
	"c": {"name": "Стройный", "leg_w": 3, "leg_h": 10, "hip": 2, "body": Vector3i(10, 12, 6), "arm": Vector2i(2, 10),
		"head": Vector3i(13, 12, 12), "ears": "tall", "ear_inset": 1, "eye": Vector2i(3, 3), "eye_gap": 5,
		"tail": "long", "fluffy": false},
	"d": {"name": "Пушистый", "leg_w": 5, "leg_h": 6, "hip": 3, "body": Vector3i(14, 11, 10), "arm": Vector2i(3, 7),
		"head": Vector3i(17, 13, 14), "ears": "tufted", "ear_inset": 1, "eye": Vector2i(3, 3), "eye_gap": 7,
		"tail": "fluffy", "fluffy": true},
}
const EMOTIONS := ["neutral", "joy", "sad", "angry", "surprised"]
const EYE_STATES := ["neutral", "joy", "sad", "angry", "surprised", "closed"]

const FUR := ["#b8652a", "#c97634", "#d8863e", "#e3964b", "#eba65c"]
const FUR_STRIPE := "#9e4f1d"
const BROW := "#6b3510"
const CREAM := ["#ecd2a4", "#f3dfb8", "#f9ebcf"]
const EAR_INNER := "#e8a3a0"
const NOSE := "#d9767a"
const BLUSH := "#f0a08c"
const EYE := "#241a16"
const EYE_SHINE := "#ffffff"
const TONGUE := "#e0707a"
const TEAR := "#9fd4f2"
const WHISKER := "#fbf6ee"
const BRACELET := "#d23a30"
const BRACELET_BEAD := "#fff4ec"

var id: String
var v: Dictionary
var pivots := {}
var eye_height := 0.0
var _rng := RandomNumberGenerator.new()
var _parts := {}
var _body_top := 0
var _head_bottom := 0
var _face_z := 0


func _init(variant_id: String) -> void:
	id = variant_id
	v = VARIANTS[variant_id]
	_rng.seed = 2026 + variant_id.unicode_at(0)
	var leg_h: int = v.leg_h
	var body: Vector3i = v.body
	var arm: Vector2i = v.arm
	_body_top = leg_h + body.y
	_head_bottom = _body_top
	_face_z = -(v.head.z + 1) / 2
	pivots = {
		"leg_left": Vector3(-v.hip * VOXEL, (leg_h + 1) * VOXEL, 0.0),
		"leg_right": Vector3(v.hip * VOXEL, (leg_h + 1) * VOXEL, 0.0),
		"arm_left": Vector3(-(body.x / 2 + arm.x / 2.0) * VOXEL, (_body_top - 1) * VOXEL, 0.0),
		"arm_right": Vector3((body.x / 2 + arm.x / 2.0) * VOXEL, (_body_top - 1) * VOXEL, 0.0),
		"body": Vector3.ZERO,
		"head": Vector3(0.0, _head_bottom * VOXEL, -0.1),
		"tail": Vector3(0.0, (leg_h + 2) * VOXEL, body.z / 2 * VOXEL),
	}
	for part in pivots:
		_parts[part] = Mesher.new(Vector3.ONE * VOXEL, -pivots[part])
	eye_height = (_head_bottom + v.head.y * 0.55) * VOXEL


## Все меши варианта: {имя: ArrayMesh}. Части тела + eyes_<состояние> + mouth_<эмоция>.
func build() -> Dictionary:
	_legs()
	_body()
	_arms()
	_head()
	_ears()
	_tail()
	var meshes := {}
	for part in _parts:
		meshes[part] = _commit(_parts[part])
	for state in EYE_STATES:
		meshes["eyes_" + state] = _commit(_eyes(state))
	for emotion in EMOTIONS:
		meshes["mouth_" + emotion] = _commit(_mouth(emotion))
	return meshes


# --- Тело --------------------------------------------------------------------

func _legs() -> void:
	var w: int = v.leg_w
	for side in [-1, 1]:
		var part := "leg_left" if side < 0 else "leg_right"
		var x0: int = side * v.hip - w / 2
		_box(part, Vector3i(x0, 1, -w / 2), Vector3i(w, v.leg_h, w), func(c: Vector3i): return _fur(c.y))
		_box(part, Vector3i(x0, 0, -w / 2 - 1), Vector3i(w, 1, w + 1), func(_c: Vector3i): return _pick(CREAM, 0.3))


func _body() -> void:
	var size: Vector3i = v.body
	var first := Vector3i(-size.x / 2, v.leg_h, -size.z / 2)
	_box("body", first, size, func(c: Vector3i):
		var on_front := c.z == first.z
		if on_front and absi(c.x * 2 + 1) <= size.x / 2 and c.y >= first.y + 3 and c.y <= _body_top - 2:
			return _pick(CREAM, 0.5)
		var on_side_or_back := c.x == first.x or c.x == first.x + size.x - 1 or c.z == first.z + size.z - 1
		if on_side_or_back and (c.y - first.y) % 3 == 2:
			return Color(FUR_STRIPE)
		return _fur(c.y))
	if v.fluffy:
		# Пушистое жабо на груди: неровный светлый край.
		for x in range(-size.x / 2 + 2, size.x / 2 - 2):
			for y in range(_body_top - 5, _body_top):
				if _rng.randf() < 0.75:
					_parts.body.set_cell(Vector3i(x, y, first.z - 1), _pick(CREAM, 0.7))


func _arms() -> void:
	var arm: Vector2i = v.arm
	var body_half: int = v.body.x / 2
	for side in [-1, 1]:
		var part := "arm_left" if side < 0 else "arm_right"
		var x0 := -body_half - arm.x if side < 0 else body_half
		var y0 := _body_top - arm.y
		_box(part, Vector3i(x0, y0, -arm.x / 2), Vector3i(arm.x, arm.y, arm.x), func(c: Vector3i):
			if c.y < y0 + 2:
				return _pick(CREAM, 0.4)
			return _fur(c.y))
		if side < 0:
			# Красный браслетик на левой лапе (канон): кольцо на воксель шире лапы, бусина спереди.
			var ring_y := y0 + 2
			for x in range(x0 - 1, x0 + arm.x + 1):
				for z in range(-arm.x / 2 - 1, -arm.x / 2 + arm.x + 1):
					var on_edge := x == x0 - 1 or x == x0 + arm.x or z == -arm.x / 2 - 1 or z == -arm.x / 2 + arm.x
					var corner := (x == x0 - 1 or x == x0 + arm.x) and (z == -arm.x / 2 - 1 or z == -arm.x / 2 + arm.x)
					if on_edge and not corner:
						var bead := z == -arm.x / 2 - 1 and x == x0 + arm.x / 2
						_parts[part].set_cell(Vector3i(x, ring_y, z), Color(BRACELET_BEAD) if bead else Color(BRACELET))


# --- Голова ------------------------------------------------------------------

func _head() -> void:
	var size: Vector3i = v.head
	var first := Vector3i(-size.x / 2, _head_bottom, _face_z)
	_box("head", first, size, func(c: Vector3i): return _fur(c.y), true)
	var head: Object = _parts.head
	# Мордочка: светлая, на воксель впереди лица; носик сверху.
	for x in range(-3, 3):
		for y in range(_head_bottom + 1, _head_bottom + 5):
			head.set_cell(Vector3i(x, y, _face_z - 1), _pick(CREAM, 0.6))
	for x in range(-1, 1):
		head.set_cell(Vector3i(x, _head_bottom + 4, _face_z - 1), Color(NOSE))
	# Румянец под глазами.
	var eye_rects := _eye_rects()
	for rect in eye_rects:
		var outer_x: int = rect.position.x - 1 if rect.position.x < 0 else rect.end.x
		for x in [outer_x, rect.position.x if rect.position.x < 0 else rect.end.x - 1]:
			head.set_cell(Vector3i(x, _head_bottom + 3, _face_z), Color(BLUSH))
	# Полоски на лбу — «буква М» рыжего кота.
	var brow_top: int = eye_rects[0].end.y + 1
	for stripe in [[-1, 0, 3], [0, 0, 3], [-4, 1, 2], [3, 1, 2], [-size.x / 2 + 1, 0, 2], [size.x / 2 - 2, 0, 2]]:
		for y in range(brow_top + stripe[1], brow_top + stripe[1] + stripe[2]):
			if y < _head_bottom + size.y - 1:
				head.set_cell(Vector3i(stripe[0], y, _face_z), Color(FUR_STRIPE))
	if v.fluffy:
		# Пушистые щёки торчат по бокам мордочки.
		for y in range(_head_bottom + 1, _head_bottom + 5):
			for z in range(_face_z + 1, _face_z + 5):
				if _rng.randf() < 0.7:
					head.set_cell(Vector3i(-size.x / 2 - 1, y, z), _fur(y))
					head.set_cell(Vector3i(size.x - size.x / 2, y, z), _fur(y))
	# Усы — белые штрихи по бокам мордочки.
	var whisker_left := -size.x / 2 - (2 if v.fluffy else 1)
	var whisker_right := size.x - size.x / 2 + (1 if v.fluffy else 0)
	for y in [_head_bottom + 2, _head_bottom + 4]:
		for dx in 2:
			head.set_cell(Vector3i(whisker_left - dx, y, _face_z + 1), Color(WHISKER))
			head.set_cell(Vector3i(whisker_right + dx, y, _face_z + 1), Color(WHISKER))


## Прямоугольники глаз: Rect2i(x, y, ширина, высота) — левый и правый.
func _eye_rects() -> Array:
	var eye: Vector2i = v.eye
	var y0 := _head_bottom + roundi(v.head.y * 0.38)
	var gap: int = v.eye_gap
	return [Rect2i(-gap / 2 - eye.x, y0, eye.x, eye.y), Rect2i(gap - gap / 2, y0, eye.x, eye.y)]


## Глаза и брови для состояния state.
func _eyes(state: String) -> Object:
	var eyes := Mesher.new(Vector3.ONE * VOXEL, -pivots.head)
	var z := _face_z - 1
	for i in 2:
		var rect: Rect2i = _eye_rects()[i]
		var inner_x := rect.end.x - 1 if i == 0 else rect.position.x
		var outer_x := rect.position.x if i == 0 else rect.end.x - 1
		var top := rect.end.y - 1
		match state:
			"closed":
				_fill(eyes, rect.position.x, rect.end.x, rect.position.y + 1, rect.position.y + 2, z, EYE)
			"joy":
				# Глаза-дужки «^ ^».
				for x in range(rect.position.x, rect.end.x):
					var edge := x == rect.position.x or x == rect.end.x - 1
					eyes.set_cell(Vector3i(x, top - 1 if edge else top, z), Color(EYE))
			"sad":
				_fill(eyes, rect.position.x, rect.end.x, rect.position.y, top, z, EYE)
				eyes.set_cell(Vector3i(inner_x, top - 1, z), Color(EYE_SHINE))
				# Бровь «домиком»: внутренний край выше.
				for x in range(rect.position.x, rect.end.x):
					eyes.set_cell(Vector3i(x, top + 2 if x == inner_x else top + 1, z), Color(BROW))
				eyes.set_cell(Vector3i(outer_x, rect.position.y - 1, z), Color(TEAR))
			"angry":
				_fill(eyes, rect.position.x, rect.end.x, rect.position.y, top - 1, z, EYE)
				# Бровь сведена к переносице.
				for x in range(rect.position.x, rect.end.x):
					eyes.set_cell(Vector3i(x, top - 1 if x == inner_x else top, z), Color(BROW))
			"surprised":
				_fill(eyes, rect.position.x, rect.end.x, rect.position.y, top + 2, z, EYE)
				eyes.set_cell(Vector3i(inner_x, top + 1, z), Color(EYE_SHINE))
				eyes.set_cell(Vector3i(outer_x, rect.position.y + 1, z), Color(EYE_SHINE))
				for x in range(rect.position.x, rect.end.x):
					eyes.set_cell(Vector3i(x, top + 3, z), Color(BROW))
			_:
				_fill(eyes, rect.position.x, rect.end.x, rect.position.y, top + 1, z, EYE)
				eyes.set_cell(Vector3i(rect.position.x + 1, top, z), Color(EYE_SHINE))
				if rect.size.x >= 3:
					eyes.set_cell(Vector3i(rect.end.x - 1, top - 1, z), Color(EYE_SHINE))
	return eyes


## Рот для эмоции: на воксель впереди мордочки.
func _mouth(emotion: String) -> Object:
	var mouth := Mesher.new(Vector3.ONE * VOXEL, -pivots.head)
	var z := _face_z - 2
	var row := _head_bottom + 2
	var cells := []
	match emotion:
		"joy":
			cells = [[-3, row + 1], [2, row + 1], [-2, row], [-1, row], [0, row], [1, row]]
			mouth.set_cell(Vector3i(-1, row - 1, z), Color(TONGUE))
			mouth.set_cell(Vector3i(0, row - 1, z), Color(TONGUE))
		"sad":
			cells = [[-1, row], [0, row], [-2, row - 1], [1, row - 1]]
		"angry":
			cells = [[-2, row], [-1, row], [0, row], [1, row]]
		"surprised":
			cells = [[-1, row], [0, row], [-1, row - 1], [0, row - 1]]
		_:
			cells = [[-1, row], [0, row], [-2, row + 1], [1, row + 1]]
	for cell in cells:
		mouth.set_cell(Vector3i(cell[0], cell[1], z), Color(EYE))
	return mouth


## Уши по стилю варианта. Строки — ширина снизу вверх, прижаты к внешнему краю.
func _ears() -> void:
	var rows: Array = {"triangle": [5, 4, 3, 2, 1], "round": [5, 5, 4, 2], "tall": [4, 4, 3, 3, 2, 2, 1],
		"tufted": [5, 4, 3, 2, 1]}[v.ears]
	var head: Object = _parts.head
	var edge: int = -v.head.x / 2 + v.ear_inset
	var y0: int = _head_bottom + v.head.y
	for i in rows.size():
		var width: int = rows[i]
		# У круглых ушей строки по центру, у остальных — прижаты к краю головы.
		var start: int = edge + (rows[0] - width) / 2 if v.ears == "round" else edge
		for x in range(start, start + width):
			for z in range(-3, 0):
				var inner: bool = z == -3 and x > start and x < start + width - 1 and i < rows.size() - 2
				var color := Color(EAR_INNER) if inner else _fur(y0 + i)
				if v.ears == "tufted" and inner:
					color = _pick(CREAM, 0.8)
				head.set_cell(Vector3i(x, y0 + i, z), color)
				head.set_cell(Vector3i(-1 - x, y0 + i, z), color)
	if v.ears == "tufted":
		# Кисточки на кончиках ушей.
		head.set_cell(Vector3i(edge, y0 + rows.size(), -2), Color(FUR_STRIPE))
		head.set_cell(Vector3i(-1 - edge, y0 + rows.size(), -2), Color(FUR_STRIPE))


func _tail() -> void:
	var tail: Object = _parts.tail
	var base_y: int = v.leg_h + 2
	var base_z: int = v.body.z / 2
	match v.tail:
		"puff":
			for i in 5:
				_tail_cell(tail, Vector3i(0, base_y + i, base_z + 1 + i / 2), 1, _fur(base_y + i))
			for x in range(-2, 2):
				for y in range(base_y + 5, base_y + 9):
					for z in range(base_z + 2, base_z + 6):
						if Vector3(x + 0.5, y - base_y - 7, z - base_z - 4).length() < 2.4:
							tail.set_cell(Vector3i(x, y, z), _fur(y))
		"long":
			for i in 26:
				var t := float(i) / 25.0
				var y := base_y + roundi(22.0 * t)
				var z := base_z + 1 + roundi(2.0 * sin(PI * t)) - (roundi(3.0 * (t - 0.8) / 0.2) if t > 0.8 else 0)
				var color := Color(FUR_STRIPE) if i % 5 == 4 or i >= 24 else _fur(y)
				_tail_cell(tail, Vector3i(0, y, z), 1, color)
		"fluffy":
			for i in 18:
				var t := float(i) / 17.0
				var y := base_y + roundi(14.0 * pow(t, 1.1))
				var z := base_z + 1 + roundi(5.0 * sin(PI * t * 0.8))
				var color := _pick(CREAM, 0.8) if i >= 15 else (Color(FUR_STRIPE) if i % 4 == 3 else _fur(y))
				_tail_cell(tail, Vector3i(0, y, z), 2, color)
		_:
			for i in 18:
				var t := float(i) / 17.0
				var y := base_y + roundi(15.0 * pow(t, 1.2))
				var z := base_z + roundi(4.5 * sin(PI * t * 0.85))
				var color := Color(FUR_STRIPE) if i % 4 == 3 or i >= 16 else _fur(y)
				_tail_cell(tail, Vector3i(0, y, z), 1, color)


## Кусок хвоста: квадрат thickness*2 вокселей в поперечнике, два воксела в высоту.
func _tail_cell(tail: Object, center: Vector3i, thickness: int, color: Color) -> void:
	for x in range(-thickness, thickness):
		for dy in 2:
			for dz in range(0, thickness * 2):
				tail.set_cell(Vector3i(x, center.y + dy, center.z + dz), color)


# --- Помощники ---------------------------------------------------------------

## Прямоугольник вокселей в части part. rounded — срезать рёбра (голова не куб).
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


func _fill(mesher: Object, x0: int, x1: int, y0: int, y1: int, z: int, color: String) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			mesher.set_cell(Vector3i(x, y, z), Color(color))


## Мех светлее к макушке, с разбросом оттенка по вокселям.
func _fur(y: int) -> Color:
	var top: float = _head_bottom + v.head.y
	return Recipes._pick(FUR, _rng, clampf(float(y) / top, 0.0, 1.0))


func _pick(palette: Array, light: float) -> Color:
	return Recipes._pick(palette, _rng, light)


func _commit(mesher: Object) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesher.commit(mesh, Recipes.VOXEL)
	return mesh
