extends RefCounted

## Рецепты блочных деревьев, кустов, камней и брёвен.
## Всё собирается из блоков на сетке 1×1×1 (как в воксельной игре)
## с пиксельными текстурами 16×16: один блок = одна текстура.
## Сетка: стороны блоков лежат на полуцелых координатах, ствол 1×1 стоит
## в центре начала координат. Поэтому деревья ставятся в целые точки мира
## и совпадают с блоками земли.
##
## Кот ≈ 2,5 блока ростом: ель 10 блоков — это 4 кота.
## Вид временный: заменить модель можно в одной сцене scenes/trees/<вид>.tscn.

const MATERIALS := "res://scenes/trees/materials/"
const MESHES := "res://scenes/trees/meshes/"


static func build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES))
	var recipes := {
		"spruce": spruce(), "small_spruce": small_spruce(), "pine": pine(), "birch": birch(),
		"oak": oak(), "big_oak": big_oak(), "dead_tree": dead_tree(),
		"bush": bush(), "big_rock": big_rock(), "small_rock": small_rock(), "fallen_log": fallen_log(),
	}
	for file_name in recipes:
		ResourceSaver.save(recipes[file_name], MESHES + file_name + ".res")


## Ель: тёмные ярусы «5-3-5-3», острая макушка.
static func spruce() -> ArrayMesh:
	var bark := _begin()
	var needles := _begin()
	_column(bark, 0, 9)
	for tier in [[3, 5], [4, 3], [5, 5], [6, 3], [7, 3], [8, 1], [9, 1]]:
		_layer(needles, tier[0], tier[1])
	return _finish([[bark, "bark_spruce"], [needles, "leaves_spruce"]])


## Ёлочка: молодая низкая ель.
static func small_spruce() -> ArrayMesh:
	var bark := _begin()
	var needles := _begin()
	_column(bark, 0, 4)
	for tier in [[2, 3], [3, 3], [4, 1], [5, 1]]:
		_layer(needles, tier[0], tier[1])
	return _finish([[bark, "bark_spruce"], [needles, "leaves_spruce"]])


## Сосна: высокий голый рыжий ствол, плоская шапка и боковой пучок.
static func pine() -> ArrayMesh:
	var bark := _begin()
	var needles := _begin()
	_column(bark, 0, 10)
	_block(bark, Vector3i(1, 6, 0))
	_layer(needles, 9, 5)
	_layer(needles, 10, 5)
	_layer(needles, 11, 3)
	_box(needles, Vector3i(1, 7, -1), Vector3i(3, 1, 3))
	return _finish([[bark, "bark_pine"], [needles, "leaves_pine"]])


## Берёза: белый ствол в чёрных чёрточках, узкая светлая крона.
static func birch() -> ArrayMesh:
	var bark := _begin()
	var crown := _begin()
	_column(bark, 0, 7)
	_box(crown, Vector3i(-1, 4, -1), Vector3i(3, 4, 3))
	for side in [Vector3i(2, 5, 0), Vector3i(-2, 6, 0), Vector3i(0, 5, -2), Vector3i(0, 6, 2)]:
		_box(crown, side, Vector3i(1, 2, 1))
	_block(crown, Vector3i(0, 8, 0))
	return _finish([[bark, "bark_birch"], [crown, "leaves_birch"]])


## Дуб: ствол с корнями и широкая крона, нижний край выше кота.
static func oak() -> ArrayMesh:
	var bark := _begin()
	var crown := _begin()
	_column(bark, 0, 5)
	for root in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		_block(bark, root)
	_layer(crown, 4, 7, 2)
	_layer(crown, 6, 5)
	_layer(crown, 7, 3)
	return _finish([[bark, "bark_oak"], [crown, "leaves_oak"]])


## Большой дуб: толстый ствол 3×3 и огромная крона.
static func big_oak() -> ArrayMesh:
	var bark := _begin()
	var crown := _begin()
	_box(bark, Vector3i(-1, 0, -1), Vector3i(3, 6, 3))
	_block(bark, Vector3i(2, 0, 0))
	_block(bark, Vector3i(0, 0, -2))
	_layer(crown, 5, 9, 3)
	_layer(crown, 8, 7, 2)
	_layer(crown, 10, 3)
	return _finish([[bark, "bark_oak"], [crown, "leaves_oak"]])


## Сухостой: серый ствол без листвы, сучья лесенкой в стороны.
static func dead_tree() -> ArrayMesh:
	var bark := _begin()
	_column(bark, 0, 7)
	for branch in [Vector3i(1, 4, 0), Vector3i(2, 5, 0), Vector3i(-1, 5, 0), Vector3i(-2, 6, 0),
			Vector3i(-3, 6, 0), Vector3i(0, 3, 1), Vector3i(0, 3, 2), Vector3i(0, 4, 2), Vector3i(0, 6, -1)]:
		_block(bark, branch)
	return _finish([[bark, "bark_dead"]])


## Куст: невысокий крест из листвы — коту по пояс.
static func bush() -> ArrayMesh:
	var leaves := _begin()
	_layer(leaves, 0, 3)
	_block(leaves, Vector3i(0, 1, 0))
	return _finish([[leaves, "leaves_bush"]])


## Большой камень: ступенчатая глыба (коллизия в сцене — те же блоки).
static func big_rock() -> ArrayMesh:
	var stone := _begin()
	_box(stone, Vector3i(-1, 0, -1), Vector3i(3, 2, 3))
	_box(stone, Vector3i(-1, 2, 0), Vector3i(2, 1, 2))
	_block(stone, Vector3i(2, 0, 0))
	return _finish([[stone, "stone"]])


## Мелкий камень: не мешает ходьбе.
static func small_rock() -> ArrayMesh:
	var stone := _begin()
	stone.append_from(_cube(Vector3(0.5, 0.35, 0.5)), 0, Transform3D(Basis(), Vector3(0, 0.175, 0)))
	stone.append_from(_cube(Vector3(0.3, 0.2, 0.3)), 0, Transform3D(Basis(), Vector3(0.3, 0.1, 0.2)))
	return _finish([[stone, "stone"]])


## Бревно 8 блоков вдоль оси X.
static func fallen_log() -> ArrayMesh:
	var wood := _begin()
	_box(wood, Vector3i(-4, 0, 0), Vector3i(8, 1, 1))
	return _finish([[wood, "bark_oak"]])


# --- Блоки -------------------------------------------------------------------

## Столб 1×1 от высоты from до to (не включая to).
static func _column(tool: SurfaceTool, from: int, to: int) -> void:
	_box(tool, Vector3i(0, from, 0), Vector3i(1, to - from, 1))


## Квадратный слой size×size с отрезанными углами — крона не выглядит ящиком.
static func _layer(tool: SurfaceTool, y: int, size: int, height: int = 1) -> void:
	var half := size / 2
	if size < 5:
		_box(tool, Vector3i(-half, y, -half), Vector3i(size, height, size))
		return
	_box(tool, Vector3i(-half, y, -half + 1), Vector3i(size, height, size - 2))
	_box(tool, Vector3i(-half + 1, y, -half), Vector3i(size - 2, height, 1))
	_box(tool, Vector3i(-half + 1, y, half), Vector3i(size - 2, height, 1))


static func _block(tool: SurfaceTool, cell: Vector3i) -> void:
	_box(tool, cell, Vector3i.ONE)


## Прямоугольник блоков: first — блок с наименьшими координатами, size — сколько блоков.
static func _box(tool: SurfaceTool, first: Vector3i, size: Vector3i) -> void:
	var size_f := Vector3(size)
	var min_corner := Vector3(first.x - 0.5, first.y, first.z - 0.5)
	tool.append_from(_cube(size_f), 0, Transform3D(Basis(), min_corner + size_f / 2.0))


static func _cube(size: Vector3) -> BoxMesh:
	var cube := BoxMesh.new()
	cube.size = size
	return cube


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## surfaces — список пар [SurfaceTool, имя материала из MATERIALS].
static func _finish(surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		var tool: SurfaceTool = surface[0]
		tool.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, load(MATERIALS + surface[1] + ".tres"))
	return mesh
