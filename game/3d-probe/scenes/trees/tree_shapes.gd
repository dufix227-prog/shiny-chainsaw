extends RefCounted

## Рецепты пяти видов деревьев: каждое собирается из простых фигур
## (цилиндры, конусы, шары) в один меш с 2–3 поверхностями — кора, листва,
## пометки. Один меш на дерево = мало вызовов отрисовки в густом лесу.
##
## Это временная замена настоящим моделям: когда будут Blender-модели,
## в сценах scenes/trees/*.tscn достаточно заменить меш, коллизия останется.
##
## Масштаб: кот ≈ 2,5 единицы ростом. Деревья 8–14 единиц — 3–6 котов.

const MATERIALS := "res://scenes/trees/materials/"
const MESHES := "res://scenes/trees/meshes/"


static func build_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES))
	_save(spruce(), "spruce")
	_save(pine(), "pine")
	_save(birch(), "birch")
	_save(oak(), "oak")
	_save(dead_tree(), "dead_tree")
	_save(fallen_log(), "fallen_log")


## Ель: тёмный ярусный конус почти до земли.
static func spruce() -> ArrayMesh:
	var bark := _begin()
	var needles := _begin()
	_add(bark, _cylinder(0.38, 0.12, 5.0), Vector3(0, 2.2, 0))
	var tiers := 5
	for i in tiers:
		var radius := 3.0 - i * 0.5
		var tier_height := 3.4 - i * 0.25
		_add(needles, _cone(radius, tier_height), Vector3(0, 2.6 + i * 1.75 + tier_height / 2.0, 0),
			Vector3(0, i * 0.7, 0))
	return _finish([[bark, "bark_brown"], [needles, "leaves_spruce"]])


## Сосна: высокий голый рыжий ствол и плоская «шапка» наверху.
static func pine() -> ArrayMesh:
	var bark := _begin()
	var crown := _begin()
	_add(bark, _cylinder(0.36, 0.2, 12.0), Vector3(0, 5.7, 0))
	_add(bark, _cylinder(0.1, 0.05, 2.4), Vector3(0.9, 10.6, 0), Vector3(0, 0, -0.9))
	_add(crown, _blob(2.7, 2.2), Vector3(0, 12.2, 0))
	_add(crown, _blob(1.8, 1.6), Vector3(1.6, 11.1, 0.4))
	_add(crown, _blob(1.9, 1.7), Vector3(-1.3, 11.6, -0.7))
	_add(crown, _blob(1.6, 1.4), Vector3(0.3, 13.4, -0.2))
	return _finish([[bark, "bark_pine"], [crown, "leaves_pine"]])


## Берёза: тонкий белый ствол с чёрными пометками и вытянутая светлая крона.
static func birch() -> ArrayMesh:
	var bark := _begin()
	var marks := _begin()
	var crown := _begin()
	var trunk_height := 9.0
	_add(bark, _cylinder(0.22, 0.11, trunk_height), Vector3(0, trunk_height / 2.0 - 0.3, 0))
	for mark_y in [0.8, 1.9, 2.7, 3.9, 5.1, 6.2]:
		var radius_here := lerpf(0.22, 0.11, (mark_y + 0.3) / trunk_height) + 0.012
		_add(marks, _cylinder(radius_here, radius_here, 0.14, 8), Vector3(0, mark_y, 0))
	_add(crown, _blob(1.9, 5.8), Vector3(0, 8.0, 0))
	_add(crown, _blob(1.2, 3.0), Vector3(0.9, 6.4, 0.4))
	_add(crown, _blob(1.1, 2.6), Vector3(-0.8, 7.1, -0.5))
	return _finish([[bark, "bark_birch"], [marks, "birch_marks"], [crown, "leaves_birch"]])


## Дуб: толстый короткий ствол, две ветви и широкая кучевая крона.
static func oak() -> ArrayMesh:
	var bark := _begin()
	var crown := _begin()
	_add(bark, _cylinder(0.7, 0.42, 5.0), Vector3(0, 2.2, 0))
	_add(bark, _cylinder(0.3, 0.15, 3.2), Vector3(1.2, 4.9, 0.2), Vector3(0.1, 0, -0.8))
	_add(bark, _cylinder(0.28, 0.14, 3.0), Vector3(-1.1, 5.0, -0.3), Vector3(-0.1, 0, 0.75))
	_add(crown, _blob(3.3, 4.8), Vector3(0, 6.8, 0))
	_add(crown, _blob(2.3, 3.6), Vector3(2.4, 5.9, 0.8))
	_add(crown, _blob(2.4, 3.8), Vector3(-2.3, 6.1, -0.7))
	_add(crown, _blob(2.1, 3.2), Vector3(0.4, 8.2, -1.3))
	_add(crown, _blob(2.0, 3.0), Vector3(-0.6, 5.7, 2.1))
	return _finish([[bark, "bark_brown"], [crown, "leaves_oak"]])


## Сухостой: серый ствол без листвы, торчащие в стороны сучья.
static func dead_tree() -> ArrayMesh:
	var bark := _begin()
	_add(bark, _cylinder(0.34, 0.1, 8.0), Vector3(0, 3.7, 0))
	# [высота, поворот вокруг ствола, наклон от вертикали]
	var branches := [
		[3.4, 0.0, 0.9], [4.5, 2.1, 1.0], [5.4, 4.0, 0.8], [6.3, 1.2, 1.1], [2.6, 5.0, 1.2],
	]
	for branch in branches:
		var height: float = branch[0]
		var yaw: float = branch[1]
		var tilt: float = branch[2]
		var length := 2.6
		var along := Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_euler(Vector3(0, 0, -tilt))
		# Сук растёт от ствола наружу: центр цилиндра сдвинут на половину длины.
		var center := Vector3(0, height, 0) + along.y * length / 2.0
		bark.append_from(_cylinder(0.1, 0.03, length), 0, Transform3D(along, center))
	return _finish([[bark, "bark_grey"]])


## Поваленное бревно: лежит вдоль оси X, длина 10 единиц.
static func fallen_log() -> ArrayMesh:
	var wood := _begin()
	_add(wood, _cylinder(0.55, 0.5, 10.0, 10), Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	_add(wood, _cylinder(0.12, 0.05, 1.6), Vector3(1.5, 0.9, 0.1), Vector3(0.3, 0, -0.4))
	return _finish([[wood, "log_wood"]])


static func _cylinder(bottom_radius: float, top_radius: float, height: float, segments: int = 9) -> CylinderMesh:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom_radius
	shape.top_radius = top_radius
	shape.height = height
	shape.radial_segments = segments
	shape.rings = 1
	return shape


static func _cone(radius: float, height: float) -> CylinderMesh:
	var shape := _cylinder(radius, 0.0, height, 10)
	shape.cap_top = false
	return shape


static func _blob(radius: float, height: float) -> SphereMesh:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 10
	shape.rings = 6
	return shape


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _add(tool: SurfaceTool, shape: PrimitiveMesh, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	tool.append_from(shape, 0, Transform3D(Basis.from_euler(rotation), position))


## surfaces — список пар [SurfaceTool, имя материала из MATERIALS].
static func _finish(surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		var tool: SurfaceTool = surface[0]
		tool.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, load(MATERIALS + surface[1] + ".tres"))
	return mesh


static func _save(mesh: ArrayMesh, file_name: String) -> void:
	ResourceSaver.save(mesh, MESHES + file_name + ".res")
