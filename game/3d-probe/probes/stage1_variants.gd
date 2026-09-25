extends Node3D

## Этап 1E (начало): лист кандидатов «камни» и «вода» (отзыв автора 11.09.2026:
## «камни надо много видов», «воду мб не пиксельную, ассеты получше»).
## Верхний ряд — камни CC0 (все Quaternius), нижний — варианты воды.
## STAGE1_CAPTURE=/путь.png — сохранить кадр и выйти.

const ProbeInput = preload("res://scripts/probe_input.gd")
const Art = preload("res://scripts/geometry.gd")

const ROCKS := [
	{"title": "Rocks (текущий)", "asset": "res://assets/cc0/rocks_quaternius.glb"},
	{"title": "Rock v1", "asset": "res://assets/cc0/rock_v1.glb"},
	{"title": "Rocks v2", "asset": "res://assets/cc0/rock_v2.glb"},
	{"title": "Rock v3", "asset": "res://assets/cc0/rock_v3.glb"},
	{"title": "Rock Large v4", "asset": "res://assets/cc0/rock_v4.glb"},
]

var camera: Camera3D
var capture_path := ""

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c8d2c5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9c0b4")
	env.ambient_light_energy = 1.0
	environment.environment = env
	add_child(environment)

	_slab("Ground", Vector3(0, -0.1, 0), Vector3(40, 0.2, 12), Color("77895c"))

	var x := -14.0
	for rock in ROCKS:
		var packed: PackedScene = load(rock.asset)
		var node: Node3D = packed.instantiate()
		add_child(node)
		_fix_materials(node)
		node.scale = Vector3.ONE * (1.6 / maxf(_measured_height(node), 0.01))
		node.position = Vector3(x, 0, 0)
		var label := Label3D.new()
		label.text = rock.title
		label.position = Vector3(x, 2.1, 0)
		label.font_size = 30
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		x += 6.0

	# Вода: три варианта материала на одинаковых бассейнах
	_water_panel("Вода: шейдер пробы", Vector3(-10.0, 0.35, 5.5), _shader_water())
	_water_panel("Вода: прозрачная гладкая", Vector3(0.0, 0.35, 5.5), _plain_water(Color(0.29, 0.49, 0.55, 0.72)))
	_water_panel("Вода: тёмная глубокая", Vector3(10.0, 0.35, 5.5), _plain_water(Color(0.13, 0.27, 0.38, 0.85)))

	_build_camera()

func _slab(name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	Art.box(body, Vector3.ZERO, size, Art.material(color, true))

func _shader_water() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water.gdshader")
	return material

func _plain_water(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.roughness = 0.1
	material.metallic = 0.0
	return material

func _water_panel(title: String, pos: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(7.5, 0.12, 4.5)
	mesh.mesh = plane
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	var label := Label3D.new()
	label.text = title
	label.position = pos + Vector3(0, 1.2, 0)
	label.font_size = 30
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 4.2, 12.5)
	add_child(camera)
	camera.look_at(Vector3(0, 0.4, 1.0))

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

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_C:
		if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 20.0
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE

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
