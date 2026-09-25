extends RefCounted

## Воксельные рецепты для улицы стартовой катсцены: машины и табличка.
## Стиль и приёмы — те же, что в scenes/style_probe/voxel_recipes.gd.

const Mesher = preload("res://scenes/voxel/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const TIRE := ["#1e1d1f", "#262528", "#2e2d30"]
const GLASS := ["#2d4150", "#35505f", "#3f5d6c"]
const CHROME := "#c9c6be"
const HEADLIGHT := "#fff3c4"
const TAILLIGHT := "#d8322c"
const WOOD := ["#5c3b24", "#6b462b", "#7a5132", "#8a5d3a"]
const BOARD := ["#b98a58", "#c69763", "#d1a46f"]


## Легковушка 4,4 × 2 × 1,8, смотрит вдоль +X. body — палитра кузова.
static func car(seed: int, body: Array) -> ArrayMesh:
	var rng := Recipes._rng(seed)
	var shell := Mesher.new(Vector3.ONE * 0.2, Vector3(-2.2, 0, -1.0))
	for x in 22:
		for z in 10:
			# Кузов: низ y 2..5, скруглённые углы.
			var corner := (x == 0 or x == 21) and (z == 0 or z == 9)
			for y in range(2, 6):
				if corner and y == 5:
					continue
				var color := Recipes._pick(body, rng, float(y - 2) / 4.0)
				if y == 3 and (z == 0 or z == 9):
					color = Color(CHROME) if x % 5 != 0 else color  # молдинг
				if x == 21 and y == 4 and (z <= 2 or z >= 7):
					color = Color(HEADLIGHT)
				if x == 0 and y == 4 and (z <= 1 or z >= 8):
					color = Color(TAILLIGHT)
				shell.set_cell(Vector3i(x, y, z), color)
			# Кабина со стёклами и стойками.
			if x >= 5 and x <= 15 and z >= 1 and z <= 8:
				for y in range(6, 9):
					var pillar := x == 5 or x == 10 or x == 15
					var edge := z == 1 or z == 8 or x == 5 or x == 15
					var glass := edge and not pillar and y < 8
					shell.set_cell(Vector3i(x, y, z), Recipes._pick(GLASS, rng, 0.5) if glass
						else Recipes._pick(body, rng, 0.9))
	# Колёса торчат из-под кузова.
	for wheel_x in [3, 16]:
		for side_z in [-1, 9]:
			for dx in 3:
				for y in 3:
					for dz in 2:
						shell.set_cell(Vector3i(wheel_x + dx, y, side_z + dz), Recipes._pick(TIRE, rng, 0.5))
	return Recipes._finish([[shell, Recipes.VOXEL]])


## Табличка у тропы: два столбика и доска 3,2 × 1,3 лицом к +Z.
## Надпись — отдельный Label3D в сцене таблички (текст правится в редакторе).
static func sign(seed: int) -> ArrayMesh:
	var rng := Recipes._rng(seed)
	var wood := Mesher.new(Vector3.ONE * 0.1, Vector3(-1.6, 0, -0.1))
	for post_x in [3, 27]:
		for y in 27:
			for x in range(post_x, post_x + 2):
				for z in 2:
					wood.set_cell(Vector3i(x, y, z), Recipes._pick(WOOD, rng, rng.randf()))
	for x in 32:
		for y in range(14, 27):
			var frame := x == 0 or x == 31 or y == 14 or y == 26
			wood.set_cell(Vector3i(x, y, 1), Recipes._pick(WOOD, rng, 0.3) if frame
				else Recipes._pick(BOARD, rng, 0.4 + 0.2 * sin(y * 1.3)))
	return Recipes._finish([[wood, Recipes.VOXEL]])
