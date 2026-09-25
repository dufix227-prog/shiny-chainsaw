extends Node3D

## Этап 1B: три варианта ширины тропы (план исполнения, раздел 8). Одинаковые
## кот, камера-ракурс, деревья и свет; меняется только ширина. Числа —
## технические до выбора автора. Модели: одобренные кандидаты 1A-v3.
## Клавиши: 1/2/3 — перейти к узкой/средней/широкой тропе, C — ортография.
## STAGE1_CAPTURE=/путь.png, STAGE1_WIDTH=0..2 — кадр выбранной тропы.

const ProbeInput = preload("res://scripts/probe_input.gd")
const Cat = preload("res://scripts/cat.gd")
const NPC = preload("res://scripts/npc.gd")
const Art = preload("res://scripts/geometry.gd")

const ROAD_LENGTH := 34.0
const TREE_GLb := "res://assets/cc0/tree_quaternius.glb"
const MAN_GLB := "res://assets/cc0/man_quaternius.glb"
## Технические ширины в единицах мира: ~1.5 / ~3 / ~5 высот кота.
const WIDTHS := [4.2, 8.95, 13.7]
const WIDTH_TITLES := ["узкая", "средняя", "широкая"]
const SEGMENT_GAP := 26.0

var segments: Array[Dictionary] = []
var camera: Camera3D
var focus := Vector3.ZERO
var capture_path := ""
var width_index := 0
var skip_collisions := false

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	skip_collisions = not OS.get_environment("STAGE1_SKIP_COLLISIONS").is_empty()
	if not OS.get_environment("STAGE1_WIDTH").is_empty():
		width_index = clampi(int(OS.get_environment("STAGE1_WIDTH")), 0, WIDTHS.size() - 1)
	_build_light()
	for i in WIDTHS.size():
		_build_segment(i)
	_build_camera()

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

func _glb(path: String) -> Node3D:
	var packed: PackedScene = load(path)
	return packed.instantiate()

func _build_segment(index: int) -> void:
	var width: float = WIDTHS[index]
	var center_x := (index - 1) * SEGMENT_GAP
	var root := Node3D.new()
	root.name = "Width%d" % index
	add_child(root)

	# Тропа: каменистая полоса с бортиками земли
	var road := StaticBody3D.new()
	road.position = Vector3(center_x, 0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.2, ROAD_LENGTH)
	shape.shape = box
	shape.position.y = -0.1
	road.add_child(shape)
	root.add_child(road)
	var road_mesh := Art.box(road, Vector3.ZERO, Vector3(width, 0.2, ROAD_LENGTH), Art.material(Color("9b8a6f"), true))

	# Земля по бокам (чтобы край тропы читался)
	for side in [-1, 1]:
		var ground := StaticBody3D.new()
		ground.position = Vector3(center_x + side * (width / 2 + 6.0), -0.12, 0)
		var gshape := CollisionShape3D.new()
		var gbox := BoxShape3D.new()
		gbox.size = Vector3(12.0, 0.2, ROAD_LENGTH + 12.0)
		gshape.shape = gbox
		ground.add_child(gshape)
		root.add_child(ground)
		Art.box(ground, Vector3.ZERO, Vector3(12.0, 0.2, ROAD_LENGTH + 12.0), Art.material(Color("77895c"), true))

	# Кот на тропе (вид сзади — кот смотрит вдоль тропы, в −Z)
	var cat := Cat.new()
	root.add_child(cat)
	cat.position = Vector3(center_x, 0.02, ROAD_LENGTH * 0.32)
	cat.visual.rotation.y = PI

	# Встречный НПС ближе к краю противоположной стороны
	var man := _glb(MAN_GLB)
	root.add_child(man)
	_fix_materials(man)
	man.position = Vector3(center_x + width * 0.28, 0, -ROAD_LENGTH * 0.22)
	var man_height := 1.78
	man.scale = Vector3.ONE * (man_height / maxf(_measured_height(man), 0.01))

	# Деревья сплошной стеной по обоим краям тропы
	var tree_scene: PackedScene = load(TREE_GLb)
	for step in range(0, 7):
		var z := -ROAD_LENGTH / 2 + step * (ROAD_LENGTH / 6.0)
		for side in [-1, 1]:
			var tree := tree_scene.instantiate()
			root.add_child(tree)
			_fix_materials(tree)
			var tree_height := 5.8
			var measured := _measured_height(tree)
			tree.scale = Vector3.ONE * (tree_height / maxf(measured, 0.01))
			var jitter := 0.3 if step % 2 == 0 else -0.3
			tree.position = Vector3(center_x + side * (width / 2 + 2.2 + jitter), 0, z + jitter)
			_add_trimesh(tree)

	var label := Label3D.new()
	label.text = "%s тропа — ширина %0.1f ед. (~%0.1f высоты кота) — техническое" % [WIDTH_TITLES[index], width, width / 2.75]
	label.position = Vector3(center_x, 4.6, -ROAD_LENGTH / 2 + 2.0)
	label.font_size = 30
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	segments.append({"index": index, "center_x": center_x, "width": width, "root": root})

func _add_trimesh(node: Node3D) -> void:
	if skip_collisions:
		return
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		(mesh_instance as MeshInstance3D).create_trimesh_collision()

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
				top = maxf(top, (to_world * corner).y)
		for child in current.get_children():
			stack.append(child)
	return top

func _build_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)
	focus_segment(width_index)

func focus_segment(index: int) -> void:
	var segment: Dictionary = segments[index]
	var center_x: float = segment.center_x
	focus = Vector3(center_x, 1.2, -4.0)
	# Вид сзади кота: камера позади и чуть выше.
	camera.position = Vector3(center_x, 2.3, ROAD_LENGTH * 0.32 + 4.6)
	camera.look_at(focus)

func toggle_projection() -> bool:
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 16.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	return camera.projection == Camera3D.PROJECTION_ORTHOGONAL

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			focus_segment(0)
		KEY_2:
			focus_segment(1)
		KEY_3:
			focus_segment(2)
		KEY_C:
			toggle_projection()

func _process(_delta: float) -> void:
	if capture_path.is_empty():
		return
	set_process(false)
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
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
