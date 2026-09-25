extends Node3D

## Этап 1C: пробы камеры (план исполнения, раздел 8). Одна широкая тропа —
## выбранная автором (1B). Три конфигурации третьего лица: ближе/ниже,
## средняя, дальше/выше; V — первое лицо. Кот двигается по тропе независимо
## от поворота камеры (логика как в игре: направление = камера + ввод).
## Клавиши: 1/2/3 — пресеты камеры, V — первое лицо, Q/E — вращение,
## C — ортография. STAGE1_CAPTURE=/путь.png, STAGE1_PRESET=0..2, STAGE1_FP=1.

const ProbeInput = preload("res://scripts/probe_input.gd")
const Cat = preload("res://scripts/cat.gd")
const Art = preload("res://scripts/geometry.gd")

const ROAD_WIDTH := 13.7
const ROAD_LENGTH := 40.0
const TREE_GLB := "res://assets/cc0/tree_quaternius.glb"
const MAN_GLB := "res://assets/cc0/man_quaternius.glb"

## Технические пресеты третьего лица: [высота, дистанция за спиной, наклон]
const PRESETS := [
	{"title": "ближе и ниже", "height": 1.1, "dist": 3.2},
	{"title": "средняя", "height": 2.2, "dist": 4.6},
	{"title": "дальше и выше", "height": 3.4, "dist": 6.4},
]

var camera: Camera3D
var cat: Cat
var preset := 2
var mode := "third" # third | gta | first | front
var capture_path := ""
var skip_collisions := false

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	skip_collisions = not OS.get_environment("STAGE1_SKIP_COLLISIONS").is_empty()
	if not OS.get_environment("STAGE1_PRESET").is_empty():
		preset = clampi(int(OS.get_environment("STAGE1_PRESET")), 0, PRESETS.size() - 1)
	if not OS.get_environment("STAGE1_FP").is_empty():
		mode = "first"
	if not OS.get_environment("STAGE1_MODE").is_empty():
		mode = OS.get_environment("STAGE1_MODE")
	_build_world()
	_build_camera()

func _build_world() -> void:
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

	var road := StaticBody3D.new()
	road.name = "Trail"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROAD_WIDTH, 0.2, ROAD_LENGTH)
	shape.shape = box
	shape.position.y = -0.1
	road.add_child(shape)
	add_child(road)
	Art.box(road, Vector3(0, 0, 0), Vector3(ROAD_WIDTH, 0.2, ROAD_LENGTH), Art.material(Color("9b8a6f"), true))
	for side in [-1, 1]:
		var ground := StaticBody3D.new()
		ground.position = Vector3(side * (ROAD_WIDTH / 2 + 7.0), -0.12, 0)
		var gshape := CollisionShape3D.new()
		var gbox := BoxShape3D.new()
		gbox.size = Vector3(14.0, 0.2, ROAD_LENGTH + 14.0)
		gshape.shape = gbox
		ground.add_child(gshape)
		add_child(ground)
		Art.box(ground, Vector3.ZERO, Vector3(14.0, 0.2, ROAD_LENGTH + 14.0), Art.material(Color("77895c"), true))

	var tree_scene: PackedScene = load(TREE_GLB)
	for step in range(0, 8):
		for side in [-1, 1]:
			var tree := tree_scene.instantiate()
			add_child(tree)
			_fix_materials(tree)
			var jitter := 0.4 if step % 2 == 0 else -0.4
			tree.scale = Vector3.ONE * (5.8 / maxf(_measured_height(tree), 0.01))
			tree.position = Vector3(side * (ROAD_WIDTH / 2 + 2.2 + jitter), 0, -ROAD_LENGTH / 2 + step * ROAD_LENGTH / 7.0 + jitter)
			_add_trimesh(tree)

	# Дерево-препятствие между камерой и котом при боковом повороте
	var obstacle := tree_scene.instantiate()
	add_child(obstacle)
	obstacle.scale = Vector3.ONE * (5.8 / maxf(_measured_height(obstacle), 0.01))
	obstacle.position = Vector3(2.6, 0, -6.0)
	_add_trimesh(obstacle)

	var man := (_glb(MAN_GLB))
	add_child(man)
	_fix_materials(man)
	man.position = Vector3(ROAD_WIDTH * 0.28, 0, -8.0)
	man.scale = Vector3.ONE * (1.78 / maxf(_measured_height(man), 0.01))

	cat = Cat.new()
	cat.name = "ProbeCat"
	add_child(cat)
	cat.position = Vector3(0, 0.02, 2.0)
	# Кот смотрит вдоль тропы (−Z): тогда камера в +Z — честно за спиной.
	cat.visual.rotation.y = PI

func _glb(path: String) -> Node3D:
	var packed: PackedScene = load(path)
	return packed.instantiate()

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
	_apply_preset()

func _apply_preset() -> void:
	if mode == "first":
		return
	if mode == "front":
		# Minecraft-стиль: камера перед котом (в его направлении взгляда), смотрит на него.
		var facing := cat.visual.global_transform.basis.z
		camera.position = cat.position + facing * 4.2 + Vector3(0, 1.9, 0)
		camera.look_at(cat.position + Vector3(0, 1.3, 0))
		return
	var spec: Dictionary = PRESETS[2] if mode == "gta" else PRESETS[preset]
	var back_offset := Vector3(0, spec.height, spec.dist)
	if mode == "gta":
		# GTA-стиль: близко-низко за спиной, взгляд чуть вниз.
		back_offset = Vector3(0, 0.85, 2.1)
	# Кот смотрит в −Z, поэтому «за спиной» — +Z.
	camera.position = cat.position + back_offset
	var look := cat.position + Vector3(0, 1.6, -4.0)
	if mode == "gta":
		look = cat.position + Vector3(0, 1.2, -2.5)
	camera.look_at(look)

func toggle_projection() -> bool:
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 16.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	return camera.projection == Camera3D.PROJECTION_ORTHOGONAL

func set_mode(value: String) -> void:
	mode = value

func _process(_delta: float) -> void:
	cat.camera_basis = camera.global_transform.basis
	cat.visual.visible = mode != "first"
	match mode:
		"first":
			# Minecraft-стиль: голова не видна, текстуры кота не перекрывают экран.
			camera.position = cat.position + Vector3(0, 1.62, 0.1)
			var forward := cat.visual.global_transform.basis.z
			camera.look_at(camera.position + Vector3(forward.x, 0, forward.z))
		"third", "gta", "front":
			_apply_preset()
	if capture_path.is_empty():
		return
	set_process(false)
	for i in 14:
		await get_tree().process_frame
	measure_label()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(capture_path)
	print("STAGE1_CAPTURE saved: ", capture_path)
	get_tree().quit()

func measure_label() -> void:
	var spec: Dictionary = PRESETS[preset]
	print("STAGE1_PRESET_INFO %s h=%.1f d=%.1f" % [mode, spec.height, spec.dist])

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			mode = "third"
			preset = 0
		KEY_2:
			mode = "third"
			preset = 1
		KEY_3:
			mode = "third"
			preset = 2
		KEY_G:
			mode = "gta"
		KEY_V:
			mode = "first"
		KEY_N:
			mode = "front"
		KEY_F5:
			# Цикл как в Minecraft: первое лицо → за спиной → спереди.
			mode = {"first": "third", "third": "front", "front": "first"}[mode]
		KEY_C:
			toggle_projection()

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
