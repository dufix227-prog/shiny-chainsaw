extends Node3D

## Этап 1A-v2: проба масштаба на детальных CC0-моделях Quaternius.
## Отзыв автора 11.09.2026: примитивы-«квадратики» отклонены, каждая модель
## должна быть проработанной. Кандидаты CC0 подгоняются под технические
## высоты; дверь и табличка пока честные заглушки (кандидат не найден).
## Клавиши: C — ортография, H — превью коллизий, Q/E — облёт, +/- — зум.
## STAGE1_CAPTURE=/путь.png — сохранить кадр и выйти; STAGE1_COLLISIONS=1,
## STAGE1_ORTHO=1 — предустановки кадра.

const ProbeInput = preload("res://scripts/probe_input.gd")
const Cat = preload("res://scripts/cat.gd")
const Art = preload("res://scripts/geometry.gd")

const PLATFORM_SIZE := Vector3(60, 0.2, 18)
const SPACING := 3.6
const CAPTURE_FRAMES := 12

## Технические целевые высоты в единицах мира (кот текущей пробы — 2,47 ед.).
## Кот остаётся «текущим» — кодовая модель cat.gd; автор: CC0-кот ужасен,
## текущий вроде норм (11.09.2026).
const TARGETS := {
	"cat": {"title": "Кот (текущий)", "height": 2.75, "own_cat": true},
	"cat_blender": {"title": "Кот-кандидат (Blender)", "asset": "res://assets/own/cat_hoplite_v1.glb", "height": 2.75, "own_label": "собственная модель (Blender), кандидат"},
	"man": {"title": "НПС человекоподобный", "asset": "res://assets/cc0/man_quaternius.glb", "height": 2.75},
	"farmer": {"title": "НПС фермер", "asset": "res://assets/cc0/farmer_quaternius.glb", "height": 2.75},
	"pig": {"title": "Свинка", "asset": "res://assets/cc0/pig_quaternius.glb", "height": 1.25},
	"super_pig": {"title": "Суперсвинка", "asset": "res://assets/cc0/pig_quaternius.glb", "height": 1.65, "dark": true},
	"car": {"title": "Машина (полицейская — кандидат)", "asset": "res://assets/cc0/police_car_quaternius.glb", "height": 2.45},
	"tree": {"title": "Дерево", "asset": "res://assets/cc0/tree_quaternius.glb", "height": 5.8},
	"bush": {"title": "Куст", "asset": "res://assets/cc0/bush_quaternius.glb", "height": 1.1},
	"rocks": {"title": "Камни (набор)", "asset": "res://assets/cc0/rocks_quaternius.glb", "height": 1.25},
	"door": {"title": "Дверь", "height": 2.75, "stub": true},
	"sign": {"title": "Табличка", "height": 2.85, "stub": true},
}

var entries: Array[Dictionary] = []
var preview_shapes: Array[MeshInstance3D] = []
var camera: Camera3D
var orbit_angle := 0.0
var orbit_distance := 14.5
var focus_point := Vector3(0, 1.2, 0)
var capture_path := ""

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	_build_platform()
	_build_light()
	_build_lineup()
	_build_camera()
	if not OS.get_environment("STAGE1_COLLISIONS").is_empty():
		set_collision_preview(true)
	if not OS.get_environment("STAGE1_ORTHO").is_empty():
		toggle_projection()
	if not OS.get_environment("STAGE1_ANGLE").is_empty():
		orbit_angle = deg_to_rad(float(OS.get_environment("STAGE1_ANGLE")))
	if not OS.get_environment("STAGE1_DIST").is_empty():
		orbit_distance = float(OS.get_environment("STAGE1_DIST"))
	if not OS.get_environment("STAGE1_ANGLE").is_empty() or not OS.get_environment("STAGE1_DIST").is_empty():
		_look_at_lineup()
	if not OS.get_environment("STAGE1_FOCUS_X").is_empty():
		focus_point.x = float(OS.get_environment("STAGE1_FOCUS_X"))
		_look_at_lineup()

func _build_platform() -> void:
	var body := StaticBody3D.new()
	body.name = "Platform"
	body.position = Vector3(0, -PLATFORM_SIZE.y / 2, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = PLATFORM_SIZE
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	Art.box(body, Vector3.ZERO, PLATFORM_SIZE, Art.material(Color("8d8d86")))

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c8d2c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9c0b4")
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)

func _build_lineup() -> void:
	var x := -SPACING * 5.0
	for id in TARGETS:
		var spec: Dictionary = TARGETS[id]
		var node: Node3D
		if spec.get("own_cat", false):
			node = Cat.new()
			node.name = "ProbeCat"
		elif spec.has("asset"):
			node = _load_fitted(spec.asset, spec.height, bool(spec.get("dark", false)))
		else:
			node = _make_door() if id == "door" else _make_sign()
		_add_entry(id, spec, node, x, spec.height)
		# Глаза ставим уже в дереве сцены: нужны корректные глобальные трансформы.
		if id == "pig" or id == "super_pig":
			_add_pig_eyes(node)
		x += SPACING

func _preview_material() -> StandardMaterial3D:
	# Полупрозрачный красный оверлей: виден меш коллизии, модель под ним читается.
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 0.25, 0.2, 0.3)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

## Коллизия должна совпадать с объектом точь-в-точь (автор 11.09.2026):
## строим trimesh по каждому меши модели, а не охватывающий бокс.
func _add_exact_collision(node: Node3D) -> void:
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).create_trimesh_collision()

## Превью коллизий — копии мешей с полупрозрачным красным материалом:
## силуэт оверлея совпадает с объектом точно.
func _add_preview_meshes(node: Node3D) -> void:
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var source := mesh_instance as MeshInstance3D
		var clone := MeshInstance3D.new()
		clone.mesh = source.mesh
		clone.transform = source.transform
		clone.material_override = _preview_material()
		clone.visible = false
		source.add_sibling(clone)
		preview_shapes.append(clone)

func _add_entry(id: String, spec: Dictionary, node: Node3D, x: float, label_height: float) -> void:
	add_child(node)
	node.position = Vector3(x, 0, 0)
	var is_stub: bool = spec.get("stub", false)
	var origin_note: String
	if is_stub:
		origin_note = "техническая заглушка"
	elif spec.get("own_cat", false):
		origin_note = "текущий кодовый кот"
	elif spec.has("own_label"):
		origin_note = spec.own_label
	else:
		origin_note = "CC0 Quaternius, кандидат"
	_add_exact_collision(node)
	_add_preview_meshes(node)
	var label := Label3D.new()
	label.name = "Label_" + id
	label.text = "%s — техническое, высота…" % spec.title
	label.position = Vector3(x, spec.height + 1.0, 0)
	label.font_size = 30
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	entries.append({"id": id, "title": spec.title, "origin": origin_note, "node": node, "label": label, "offset": 0.0})

func _load_fitted(path: String, target_height: float, dark: bool) -> Node3D:
	var packed: PackedScene = load(path)
	var instance: Node3D = packed.instantiate()
	instance.set_meta("cc0_scene", true)
	add_child(instance)
	_fix_materials(instance)
	var height := _measured_height(instance)
	# Подгонка по высоте и выравнивание по земле.
	var factor := target_height / maxf(height, 0.01)
	instance.scale = Vector3.ONE * factor
	instance.position = Vector3.ZERO
	if dark:
		var paint := Art.material(Color("1d1e24"), true)
		_paint(instance, paint)
	# Переносим в обёртку: add_child внутри _add_entry добавит копию узла.
	remove_child(instance)
	return instance

func _paint(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_paint(child, material)

## Модель свинки Quaternius идёт без глаз (отзыв автора 11.09.2026) — добавляем
## собственные тёмные глаза на морду. Модель смотрит в +Z (проверено по
## геометрии glTF: голова в верхней трети тянется к максимальному Z).
func _add_pig_eyes(pig: Node3D) -> void:
	var size := _local_size(pig)
	var eye := SphereMesh.new()
	eye.radius = 0.035
	eye.height = 0.07
	var eye_material := Art.material(Color("241d18"))
	for side in [-1, 1]:
		var holder := Node3D.new()
		holder.name = "ProbeEyeL" if side < 0 else "ProbeEyeR"
		holder.position = Vector3(side * size.x * 0.16, size.y * 0.72, size.z * 0.5)
		var mesh := MeshInstance3D.new()
		mesh.mesh = eye
		mesh.material_override = eye_material
		holder.add_child(mesh)
		pig.add_child(holder)

## Габариты узла в его локальном пространстве (без учёта собственного scale).
func _local_size(node: Node3D) -> Vector3:
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			var bounds := mesh_instance.get_aabb()
			var to_local := node.global_transform.affine_inverse() * mesh_instance.global_transform
			for corner_index in 8:
				var point := to_local * bounds.get_endpoint(corner_index)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
		for child in current.get_children():
			stack.append(child)
	return maximum - minimum

func _make_door() -> Node3D:
	var root := Node3D.new()
	var frame := Color("6e5233")
	Art.box(root, Vector3(0, 1.38, 0), Vector3(1.05, 2.7, 0.1), Art.material(Color("7a5c3a"), true))
	Art.box(root, Vector3(0, 2.76, 0), Vector3(1.18, 0.14, 0.14), Art.material(frame))
	Art.box(root, Vector3(0.4, 1.4, 0.08), Vector3(0.1, 0.36, 0.05), Art.material(Color("c9a54e"), true))
	return root

func _make_sign() -> Node3D:
	var root := Node3D.new()
	var wood := Art.material(Color("8a6b45"), true)
	Art.box(root, Vector3(0, 1.35, 0), Vector3(0.13, 2.7, 0.13), wood)
	Art.box(root, Vector3(0, 2.45, 0), Vector3(1.35, 0.8, 0.08), wood)
	var text := Label3D.new()
	text.text = "техническая табличка"
	text.font_size = 30
	text.pixel_size = 0.005
	text.position = Vector3(0, 2.48, 0.05)
	root.add_child(text)
	return root

func _build_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)
	_look_at_lineup()

func _look_at_lineup() -> void:
	camera.position = Vector3(sin(orbit_angle) * orbit_distance, 3.4, cos(orbit_angle) * orbit_distance)
	camera.look_at(focus_point)

func _measured_height(node: Node3D) -> float:
	var top := 0.0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			var bounds := mesh_instance.get_aabb()
			var to_world := mesh_instance.global_transform
			for corner_index in 8:
				var corner := bounds.get_endpoint(corner_index)
				var world_point := to_world * corner
				top = maxf(top, world_point.y)
		for child in current.get_children():
			stack.append(child)
	return top

func measure_heights() -> void:
	for entry in entries:
		var height := _measured_height(entry.node)
		entry.offset = height
		entry.label.text = "%s — %0.2f ед. — %s" % [entry.title, height, entry.origin]
		print("STAGE1_HEIGHT %s %s %.2f" % [entry.id, entry.title, height])

func set_collision_preview(value: bool) -> void:
	for shape in preview_shapes:
		shape.visible = value

func toggle_projection() -> bool:
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 15.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	return camera.projection == Camera3D.PROJECTION_ORTHOGONAL

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_C:
			toggle_projection()
		KEY_H:
			set_collision_preview(not preview_shapes[0].visible)
		KEY_Q:
			orbit_angle -= 0.28
			_look_at_lineup()
		KEY_E:
			orbit_angle += 0.28
			_look_at_lineup()
		KEY_EQUAL:
			orbit_distance = maxf(6.0, orbit_distance - 1.2)
			_look_at_lineup()
		KEY_MINUS:
			orbit_distance = minf(24.0, orbit_distance + 1.2)
			_look_at_lineup()

func _process(_delta: float) -> void:
	if capture_path.is_empty():
		return
	set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	measure_heights()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var samples := [Vector2i(640, 400), Vector2i(300, 400), Vector2i(500, 300), Vector2i(960, 450)]
	for point in samples:
		var pixel := image.get_pixelv(point)
		print("STAGE1_PIXEL %s %.2f %.2f %.2f" % [point, pixel.r, pixel.g, pixel.b])
	image.save_png(capture_path)
	print("STAGE1_CAPTURE saved: ", capture_path)
	get_tree().quit()

## Фикс чёрных текстур у импортных GLB: glTF по умолчанию metallic=1 —
## металл отражает пустое окружение и выглядит чёрным. Гасим металличность.
func _fix_materials(node: Node) -> void:
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D:
				var fixed := mat.duplicate() as StandardMaterial3D
				fixed.metallic = 0.0
				fixed.roughness = 0.85
				mesh.mesh.surface_set_material(surface, fixed)
