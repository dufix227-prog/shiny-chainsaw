extends RefCounted

## Блочная земля: из высот столбиков 1×1 строит меш (верх + боковые стенки)
## и такую же по форме коллизию. Соседние одинаковые грани сливаются в одну
## длинную — иначе файл земли весил бы десятки мегабайт.
##
## heights[column + row * width] — высота верха столбика в блоках,
## is_path — тот же индекс, 1 для блока тропы.

var width: int
var depth: int
var first_x: int  # X центра первого столбика
var first_z: int  # Z центра первого ряда; ряды идут в сторону −Z
var heights := PackedInt32Array()
var is_path := PackedByteArray()

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _faces := PackedVector3Array()


func height(column: int, row: int) -> int:
	return heights[column + row * width]


func build_mesh() -> ArrayMesh:
	_build_tops()
	_build_sides_facing_x()
	_build_sides_facing_z()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Вызывать после build_mesh(): коллизия собирается из тех же граней.
func build_collision() -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces)
	return shape


## Верх: подряд идущие по X столбики одной высоты и типа — одна грань.
func _build_tops() -> void:
	for row in depth:
		var column := 0
		while column < width:
			var run_end := column + 1
			while run_end < width and height(run_end, row) == height(column, row) \
					and is_path[run_end + row * width] == is_path[column + row * width]:
				run_end += 1
			var y := float(height(column, row))
			var x0 := first_x + column - 0.5
			var x1 := first_x + run_end - 0.5
			var z0 := first_z - row + 0.5
			var z1 := first_z - row - 0.5
			var color := Color(is_path[column + row * width], 0, 0)
			_quad(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, color)
			column = run_end


## Стенки между соседями по X (смотрят в +X или −X), сливаются вдоль рядов.
func _build_sides_facing_x() -> void:
	for column in width - 1:
		var row := 0
		while row < depth:
			var left := height(column, row)
			var right := height(column + 1, row)
			if left == right:
				row += 1
				continue
			var run_end := row + 1
			while run_end < depth and height(column, run_end) == left and height(column + 1, run_end) == right:
				run_end += 1
			var x := first_x + column + 0.5
			var z0 := first_z - row + 0.5
			var z1 := first_z - run_end + 0.5
			var high_is_left := left > right
			var owner_column := column if high_is_left else column + 1
			var normal := Vector3.RIGHT if high_is_left else Vector3.LEFT
			_wall(Vector3(x, 0, z0), Vector3(x, 0, z1), mini(left, right), maxi(left, right), normal,
				is_path[owner_column + row * width])
			row = run_end


## Стенки между соседними рядами (смотрят в +Z или −Z), сливаются вдоль X.
func _build_sides_facing_z() -> void:
	for row in depth - 1:
		var column := 0
		while column < width:
			var near := height(column, row)  # ряд ближе к +Z
			var far := height(column, row + 1)
			if near == far:
				column += 1
				continue
			var run_end := column + 1
			while run_end < width and height(run_end, row) == near and height(run_end, row + 1) == far:
				run_end += 1
			var z := first_z - row - 0.5
			var x0 := first_x + column - 0.5
			var x1 := first_x + run_end - 0.5
			var high_is_near := near > far
			var owner_row := row if high_is_near else row + 1
			var normal := Vector3.FORWARD if high_is_near else Vector3.BACK
			_wall(Vector3(x0, 0, z), Vector3(x1, 0, z), mini(near, far), maxi(near, far), normal,
				is_path[column + owner_row * width])
			column = run_end


## Стенка от low до high. Верхний слой отдельно — у него травяная бахрома.
func _wall(a: Vector3, b: Vector3, low: int, high: int, normal: Vector3, path: int) -> void:
	var top_color := Color(path, 1, 0)
	var lower_color := Color(path, 0, 0)
	_wall_part(a, b, high - 1, high, normal, top_color)
	if high - 1 > low:
		_wall_part(a, b, low, high - 1, normal, lower_color)


func _wall_part(a: Vector3, b: Vector3, low: int, high: int, normal: Vector3, color: Color) -> void:
	var a_low := Vector3(a.x, low, a.z)
	var b_low := Vector3(b.x, low, b.z)
	var a_high := Vector3(a.x, high, a.z)
	var b_high := Vector3(b.x, high, b.z)
	# Порядок обхода выбирается так, чтобы лицевая сторона смотрела по normal.
	if (b_low - a_low).cross(a_high - a_low).dot(normal) > 0.0:
		_quad(a_low, a_high, b_high, b_low, normal, color)
	else:
		_quad(a_low, b_low, b_high, a_high, normal, color)


## Четырёхугольник p0-p1-p2-p3; при нужде порядок переворачивается, чтобы
## лицевая сторона смотрела по normal (Godot рисует треугольники по часовой).
func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3, color: Color) -> void:
	if (p1 - p0).cross(p2 - p0).dot(normal) > 0.0:
		var swap := p1
		p1 = p3
		p3 = swap
	var start := _vertices.size()
	for point in [p0, p1, p2, p3]:
		_vertices.append(point)
		_normals.append(normal)
		_colors.append(color)
	_indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	_faces.append_array([p0, p1, p2, p0, p2, p3])
