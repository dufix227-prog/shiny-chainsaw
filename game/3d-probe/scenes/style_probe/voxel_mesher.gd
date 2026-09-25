extends RefCounted

## Воксельный мешер: из набора мелких кубиков с цветами строит меш,
## оставляя только грани, видимые снаружи. У каждого кубика свой цвет
## (цвет вершин, без текстур) — именно пёстрая мозаика мелких кубиков
## даёт вид как на картинке главного меню.

## [нормаль, сосед, 4 угла кубика в долях размера]
const FACES := [
	[Vector3.RIGHT, Vector3i(1, 0, 0), [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]],
	[Vector3.LEFT, Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
	[Vector3.UP, Vector3i(0, 1, 0), [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]],
	[Vector3.DOWN, Vector3i(0, -1, 0), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	[Vector3.BACK, Vector3i(0, 0, 1), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
	[Vector3.FORWARD, Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]],
]

var voxel_size := Vector3.ONE * 0.3
## Где начинается клетка (0, 0, 0).
var origin := Vector3.ZERO
var cells := {}  # Vector3i → Color
## Клетки другого мешера, закрывающие грани этого (например, листва — ствол).
var hidden_by := {}


func _init(size: Vector3 = Vector3.ONE * 0.3, start: Vector3 = Vector3.ZERO) -> void:
	voxel_size = size
	origin = start


func set_cell(cell: Vector3i, color: Color) -> void:
	cells[cell] = color


## Добавляет в mesh одну поверхность из всех кубиков с материалом material.
func commit(mesh: ArrayMesh, material: Material) -> void:
	if cells.is_empty():
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for cell: Vector3i in cells:
		var color: Color = cells[cell]
		var base := origin + Vector3(cell) * voxel_size
		for face in FACES:
			var neighbour: Vector3i = cell + face[1]
			if cells.has(neighbour) or hidden_by.has(neighbour):
				continue
			var normal: Vector3 = face[0]
			var corners: Array[Vector3] = []
			for corner: Vector3 in face[2]:
				corners.append(base + corner * voxel_size)
			# Godot рисует лицевую сторону при обходе по часовой — переворачиваем при нужде.
			if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(normal) > 0.0:
				var swap := corners[1]
				corners[1] = corners[3]
				corners[3] = swap
			var start := vertices.size()
			for corner in corners:
				vertices.append(corner)
				normals.append(normal)
				colors.append(color)
			indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
