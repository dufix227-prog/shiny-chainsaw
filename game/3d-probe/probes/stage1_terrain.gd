extends Node3D

## Этап 1D: проба рельефа и окружения (план исполнения, раздел 8).
## Слева направо: ровная база (контроль), мягкий перепад, крутой проходимый
## склон, верхнее плато с деревом/кустами/камнями, берег с мелкой (×2) и
## глубокой (недоступной) водой. Кусты замедляют ×2 в своей зоне.
## STAGE1_CAPTURE=/путь.png и STAGE1_VIEW=0..3 — кадры: база/склоны, плато,
## камни, вода. Кот повёрнут вдоль +X.

const ProbeInput = preload("res://scripts/probe_input.gd")
const Cat = preload("res://scripts/cat.gd")
const Art = preload("res://scripts/geometry.gd")

var cat: Cat
var camera: Camera3D
var bush_zones := [AABB(Vector3(-21.0, -1.0, -6.5), Vector3(5.0, 4.0, 4.0)), AABB(Vector3(-21.0, -1.0, 2.5), Vector3(5.0, 4.0, 4.0))]
var deep_wall_x := 19.0
var capture_path := ""
var view := 0
var skip_collisions := false

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	skip_collisions = not OS.get_environment("STAGE1_SKIP_COLLISIONS").is_empty()
	if not OS.get_environment("STAGE1_VIEW").is_empty():
		view = clampi(int(OS.get_environment("STAGE1_VIEW")), 0, 3)
	var t0 := Time.get_ticks_msec()
	_textures()
	_build_light()
	_build_base()
	print("T_BUILD base ", Time.get_ticks_msec() - t0)
	_build_slopes()
	print("T_BUILD slopes ", Time.get_ticks_msec() - t0)
	_build_upper()
	print("T_BUILD upper ", Time.get_ticks_msec() - t0)
	_build_water()
	print("T_BUILD water ", Time.get_ticks_msec() - t0)
	_build_cat()
	_build_camera()
	print("T_BUILD done ", Time.get_ticks_msec() - t0)

func _material(color: Color) -> StandardMaterial3D:
	return Art.material(color, true)

## Настоящие фото-текстуры CC0 (ambientCG, реестр ассетов) вместо плоской
## заливки — тот же приём, что уже одобрен автором на пробе пещеры
## (stage1_cave.gd, 12.09.2026). uv_scale подобран под размер конкретной
## поверхности, чтобы текстура не растягивалась и не мельчила.
var _grass_mat: StandardMaterial3D
var _ground_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D

func _textures() -> void:
	_grass_mat = Art.textured_material("grass001", 1.4, 0.92)
	_ground_mat = Art.textured_material("ground107", 1.6, 0.85)
	# rock063 (пещера) — замшелый камень, зелёно-жёлтые пятна мха; автор
	# отметил их как «мох, фу» на открытом рельефе. rock023 — тот же CC0-
	# источник (ambientCG), но чистый камень без мха.
	_rock_mat = Art.textured_material("rock023", 1.2, 0.85)

func _slab(name: String, pos: Vector3, size: Vector3, color: Color, rotation_z := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.rotation_degrees = Vector3(0, 0, rotation_z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	Art.box(body, Vector3.ZERO, size, _material(color))
	return body

## То же, что _slab(), но с настоящей фото-текстурой вместо плоского цвета
## (просьба автора 12.09.2026: «реальные хорошие текстуры»).
func _textured_slab(name: String, pos: Vector3, size: Vector3, mat: Material, rotation_z := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.rotation_degrees = Vector3(0, 0, rotation_z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	Art.box(body, Vector3.ZERO, size, mat)
	return body

func _build_light() -> void:
	# В прошлых кадрах сцена была без света — отсюда «чёрные текстуры».
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 140, 0)
	fill.light_energy = 0.3
	add_child(fill)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a7c2d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Нейтрально-прохладный ambient вместо тёплого оливкового — иначе
	# реальная зелёная фото-текстура травы тонировалась в жёлтый оттенок.
	env.ambient_light_color = Color("c2ccd6")
	env.ambient_light_energy = 0.85
	# Forward+ пост-обработка (тот же приём, что уже одобрен на пробе пещеры
	# 12.09.2026): мягкий glow и контактные тени SSAO читаются на реальных
	# фото-текстурах лучше, чем на плоской заливке.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.2
	environment.environment = env
	add_child(environment)

func _build_base() -> void:
	_slab("SafetyFloor", Vector3(-2.0, -4.0, 0), Vector3(80.0, 0.2, 30.0), Color("5c6b4e"))
	_textured_slab("Flat", Vector3(-22.0, -0.1, 0), Vector3(12.0, 0.2, 14.0), _grass_mat)

func _build_slopes() -> void:
	# Мягкий перепад: подъём 0.85 на длине 12 (≈3.8°)
	_textured_slab("Gentle", Vector3(-10.0, 0.325, 0), Vector3(12.0, 0.2, 14.0), _ground_mat, 4.05)
	# Крутой, но проходимый: подъём 1.6 на длине 6 (≈14.9°)
	_textured_slab("Steep", Vector3(-0.25, 1.4, 0), Vector3(7.5, 0.2, 14.0), _rock_mat, 9.83)

func _build_upper() -> void:
	_textured_slab("Upper", Vector3(7.25, 2.05, 0), Vector3(7.5, 0.2, 14.0), _grass_mat)

	var tree_scene: PackedScene = load("res://assets/cc0/tree_quaternius.glb")
	var tree := tree_scene.instantiate()
	add_child(tree)
	_fix_materials(tree)
	tree.scale = Vector3.ONE * (5.8 / maxf(_measured_height(tree), 0.01))
	tree.position = Vector3(8.6, 2.4, 3.6)
	_add_trimesh(tree)

	# Кусты-зона (проходимые, замедление ×2)
	var bush_scene: PackedScene = load("res://assets/cc0/bush_quaternius.glb")
	for offset in [Vector3(-19.6, 0.0, -4.4), Vector3(-18.2, 0.0, 5.0), Vector3(-19.9, 0.0, 4.3), Vector3(-20.3, 0.0, -5.2)]:
		var bush := bush_scene.instantiate()
		add_child(bush)
		_fix_materials(bush)
		bush.scale = Vector3.ONE * (1.1 / maxf(_measured_height(bush), 0.01))
		bush.position = offset
		_add_trimesh(bush)

	# Мелкий камень: проходимый (без коллизии), крупный: блокирующий trimesh
	var rocks_scene: PackedScene = load("res://assets/cc0/rocks_quaternius.glb")
	var small := rocks_scene.instantiate()
	add_child(small)
	_fix_materials(small)
	small.scale = Vector3.ONE * 1.4
	small.position = Vector3(4.5, 2.35, 2.0)
	var big := rocks_scene.instantiate()
	add_child(big)
	_fix_materials(big)
	big.scale = Vector3.ONE * 5.2
	big.position = Vector3(6.0, 2.3, -1.5)
	_add_trimesh(big)

func _build_water() -> void:
	_textured_slab("Shore", Vector3(13.0, 2.05, 0), Vector3(4.0, 0.2, 14.0), _ground_mat)
	_slab("ShallowFloor", Vector3(17.0, 1.94, 0), Vector3(5.0, 0.12, 14.0), Color("8a7f5f"))
	_slab("DeepFloor", Vector3(23.0, 0.94, 0), Vector3(6.0, 0.12, 14.0), Color("6f6a52"))
	# Видимый каменный обрыв: глубокая вода недоступна без невидимой стены
	_textured_slab("DeepWall", Vector3(19.75, 1.7, 0), Vector3(0.5, 2.4, 14.0), _rock_mat)
	var water := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(13.5, 0.08, 14.0)
	water.mesh = plane
	water.material_override = _material(Color("4a7d8c"))
	water.position.x = 20.0
	# Вода заходит под кромку песка — стык текстур не рвётся
	water.position = Vector3(20.0, 2.3, 0)
	add_child(water)

func _build_cat() -> void:
	cat = Cat.new()
	cat.name = "ProbeCat"
	add_child(cat)
	cat.position = Vector3(-22.0, 0.12, 0)
	cat.visual.rotation.y = PI / 2 # смотрит вдоль +X: рельеф → пропсы → вода

func _add_trimesh(node: Node3D) -> void:
	if skip_collisions:
		return
	var t0 := Time.get_ticks_msec()
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
	_apply_view()

func _apply_view() -> void:
	var centers := [Vector3(-19.0, 2.4, 9.5), Vector3(-4.0, 3.4, 10.0), Vector3(4.4, 4.2, 10.0), Vector3(14.0, 4.6, 10.0)]
	var target: Vector3 = centers[clampi(view, 0, 3)]
	camera.position = target
	camera.look_at(Vector3(target.x + 2.0, 1.4, 0))

func toggle_projection() -> bool:
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 18.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	return camera.projection == Camera3D.PROJECTION_ORTHOGONAL

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_0 and key.keycode <= KEY_3:
		view = key.keycode - KEY_0
		_apply_view()
	elif key.keycode == KEY_C:
		toggle_projection()

func _process(_delta: float) -> void:
	cat.camera_basis = camera.global_transform.basis
	# Кусты по бокам тропы: замедление ×2 (канон)
	var in_bushes := false
	for zone in bush_zones:
		if zone.has_point(cat.position):
			in_bushes = true
	cat.mount_speed_multiplier = 0.5 if in_bushes else 1.0
	var capture_dir := OS.get_environment("STAGE1_CAPTURE_DIR")
	if capture_path.is_empty() and capture_dir.is_empty():
		return
	set_process(false)
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if capture_dir.is_empty():
		image.save_png(capture_path)
		print("STAGE1_CAPTURE saved: ", capture_path)
		get_tree().quit()
		return
	# Один прогон сохраняет все 4 вида: медленный импорт амортизируется
	for view_index in 4:
		view = view_index
		_apply_view()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		var path := capture_dir.path_join("stage1_1D_view%d.png" % view_index)
		frame.save_png(path)
		print("STAGE1_CAPTURE saved: ", path)
	get_tree().quit()
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
