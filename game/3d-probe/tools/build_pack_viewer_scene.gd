extends SceneTree

## Разовая расстановка витрины пачки ассетов с сохранением результата в сцену.
## Это исполнение правила scene-first из AGENTS.md: мир — данные сцены, а не
## создание в _ready() при запуске. Скрипт нужен ОДИН раз (и при изменении
## пачки), в рантайме он не участвует.
##
## Запуск:
##   ENGINE=~/.cache/10000-metres-probe/godot-4.7.2-linux-x86_64/godot
##   $ENGINE --headless --path game/3d-probe --script tools/build_pack_viewer_scene.gd
##
## Что делает: собирает PackViewer (земля, небо, солнце, эталонная капсула,
## семь моделей с подписями-номерами, камера, HUD) и сохраняет его в
## res://probes/pack_viewer.tscn. Перезапуск перезаписывает сцену целиком.

const Viewer = preload("res://probes/pack_viewer.gd")

const ASSETS_DIR := "res://assets/own/"
const OUT_PATH := "res://probes/pack_viewer.tscn"

## Порядок показа совпадает с порядком в реестре ассетов. `title` — русское
## имя для автора, `file` — id ассета (нужен, когда автор называет, что править).
const EXHIBITS := [
	{"file": "goose_guard_v1", "title": "Гусь-охранник",
		"note": "птица с мостика на 470 м, погоня в концовке"},
	{"file": "bridge_v1", "title": "Мостик",
		"note": "деревянный, 4 × 1,5 м, точка спасения на 470 м"},
	{"file": "strawberry_bed_v1", "title": "Грядка",
		"note": "клубничная грядка бабушки 2 × 1 м, кража"},
	{"file": "strawberry_basket_v1", "title": "Корзина",
		"note": "плетёная с дужкой, 42 клубнички — кот несёт её в зубах"},
	{"file": "grandma_house_v1", "title": "Дом бабушки",
		"note": "жилой размер 6 × 4,5 м, конёк 4,2 м, сени и крыльцо; внутрь не заходим"},
	{"file": "yard_fence_v1", "title": "Забор",
		"note": "секция 2,4 м — двор бабушки"},
	{"file": "yard_shed_v1", "title": "Сарай",
		"note": "2,8 × 2,2 м под крышей — двор бабушки"},
	{"file": "woodpile_v1", "title": "Поленница",
		"note": "колотые дрова 1,8 м — двор бабушки"},
	{"file": "barrel_v1", "title": "Бочка",
		"note": "деревянная с обручами, 0,74 м — двор бабушки"},
	{"file": "cat_v2_faceted", "title": "Кот v2",
		"note": "гранёный low-poly, кандидат для сравнения"},
	{"file": "cat_v3_voxel", "title": "Кот v3",
		"note": "ступенчатый voxel, кандидат для сравнения"},
]

const CAT_HEIGHT := 1.8      # рост кота из промптов, м
const GAP := 1.6             # просвет между объектами в ряду, м
const REFERENCE_GAP := 3.5   # после капсулы просторнее, иначе она нависает над первым
const LABEL_LIFT := 0.35     # насколько подпись-номер выше верхушки модели, м


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var root := Node3D.new()
	root.name = "PackViewer"
	# Кладём корень в дерево сцены: owner принимается только у узлов, у которых
	# владелец — реальный предок в дереве. Скрипт надеваем в самом конце:
	# иначе _ready() отработает в момент add_child, когда детей ещё нет.
	get_root().add_child(root)

	_add_environment(root)
	_add_ground(root, 30.0, 14.0)     # размер уточняется ниже по длине ряда
	var cursor := _add_reference(root) - REFERENCE_GAP
	_add_exhibits(root, cursor)
	_add_camera(root)
	_add_hud(root)

	# Земля — по фактической длине ряда: слишком большая плита уводит взгляд.
	var bounds := _row_bounds(root)
	var ground := root.get_node("Ground") as MeshInstance3D
	var box := ground.mesh as BoxMesh
	box.size = Vector3(maxf((bounds.y - bounds.x) + 8.0, 20.0), 0.4, 14.0)
	ground.position = Vector3((bounds.x + bounds.y) / 2, -box.size.y / 2, 0)

	# Скрипт поведения — в самом конце сборки (см. пояснение выше).
	root.set_script(Viewer)

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		printerr("Не удалось упаковать сцену: ", pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUT_PATH)
	if save_error != OK:
		printerr("Не удалось сохранить сцену: ", save_error)
		quit(1)
		return
	print("PACK_VIEWER_SCENE saved: ", OUT_PATH)
	quit(0)


# ------------------------------------------------------------- окружение ---
func _add_environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.43, 0.56, 0.74)
	sky_material.sky_horizon_color = Color(0.76, 0.79, 0.82)
	sky_material.ground_bottom_color = Color(0.30, 0.32, 0.28)
	sky_material.ground_horizon_color = Color(0.62, 0.64, 0.60)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# Линейный тонмаппинг, а не AgX: у плоских материалов пачки цвет должен
	# читаться как в промпте, а не уходить в бежевый (та же грабля, что в Blender).
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	_attach(root, world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	_attach(root, sun)


func _add_ground(root: Node3D, width: float, depth: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Ground"
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.4, depth)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.47, 0.34)
	material.roughness = 1.0
	material.metallic = 0.0
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0, -box.size.y / 2, 0)
	_attach(root, mesh_instance)


## Эталонная капсула «рост кота 1,8 м»: автор сверяет по ней масштаб
## (правило «игрок — капсула» действует до визуальной приёмки пачки).
func _add_reference(root: Node3D) -> float:
	var holder := Node3D.new()
	holder.name = "Reference"
	_attach(root, holder)

	var capsule := MeshInstance3D.new()
	capsule.name = "Capsule"
	var mesh := CapsuleMesh.new()
	mesh.height = CAT_HEIGHT
	mesh.radius = 0.35
	capsule.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.74, 0.78)
	material.roughness = 1.0
	capsule.material_override = material
	# CapsuleMesh стоит центром в нуле — поднимаем, чтобы низ лёг на землю.
	capsule.position = Vector3(0, CAT_HEIGHT / 2, 0)
	holder.add_child(capsule)
	capsule.set_owner(root)

	var label := _make_label("рост 1,8 м", Vector3(0, CAT_HEIGHT + LABEL_LIFT, 0))
	label.name = "Label"
	holder.add_child(label)
	label.set_owner(root)

	holder.position = Vector3(0, 0, 0)
	return mesh.radius * 2


func _add_exhibits(root: Node3D, cursor: float) -> void:
	var holder := Node3D.new()
	holder.name = "Exhibits"
	_attach(root, holder)

	for i in EXHIBITS.size():
		var spec: Dictionary = EXHIBITS[i]
		var packed: PackedScene = load(ASSETS_DIR + spec["file"] + ".glb")
		if packed == null:
			printerr("Не загрузилась модель: ", spec["file"])
			continue

		var wrapper := Node3D.new()
		wrapper.name = "%d_%s" % [i + 1, spec["file"]]
		holder.add_child(wrapper)
		wrapper.set_owner(root)
		# Русское имя и пояснение храним в самой сцене: витрина читает их отсюда,
		# и скрипту не нужно держать список объектов у себя.
		wrapper.set_meta("title", spec["title"])
		wrapper.set_meta("note", spec["note"])
		wrapper.set_meta("file", spec["file"])

		var instance := packed.instantiate() as Node3D
		instance.name = spec["file"]
		wrapper.add_child(instance)
		instance.set_owner(root)

		var size := Viewer.measure_local_size(wrapper)
		# Ряд укладываем в сторону −X, а капсулу-эталон оставляем на X=0.
		# Камера по умолчанию смотрит с −Z (на перед моделей), и там экранный
		# «вправо» — это мировой −X: при обратной укладке номера шли бы справа
		# налево. Так номера растут слева направо, а капсула стоит в начале ряда.
		cursor -= size.x / 2
		wrapper.position = Vector3(cursor, 0, 0)

		var label := _make_label("%d" % (i + 1),
				Vector3(0, size.y + LABEL_LIFT, 0))
		label.name = "Number"
		wrapper.add_child(label)
		label.set_owner(root)

		print("PACK_VIEWER_ROW %d %s size=(%.3f, %.3f, %.3f)" % [
				i + 1, spec["file"], size.x, size.y, size.z])
		cursor -= size.x / 2 + GAP


func _add_camera(root: Node3D) -> void:
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.far = 400.0
	camera.position = Vector3(0, 3, 14)
	camera.rotation_degrees = Vector3(-12, 180, 0)
	_attach(root, camera)


func _add_hud(root: Node3D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	_attach(root, layer)

	var label := Label.new()
	label.name = "Hint"
	label.position = Vector2(18, 14)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.10, 0.12, 0.14))
	label.add_theme_color_override("font_outline_color", Color(0.95, 0.96, 0.97))
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	label.set_owner(root)


func _make_label(text: String, where: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 14
	label.pixel_size = 0.0026
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = where
	return label


# -------------------------------------------------------------- служебное ---
## Узел становится частью сохраняемой сцены только при owner = корень.
## Порядок важен: сначала add_child, потом owner — иначе «Owner must be
## an ancestor in the tree».
func _attach(root: Node3D, node: Node) -> void:
	root.add_child(node)
	node.set_owner(root)


## Границы ряда по X с учётом капсулы-эталона: она часть ряда, и без неё
## площадка и камера общего вида не покрывали её.
func _row_bounds(root: Node3D) -> Vector2:
	var left := INF
	var right := -INF
	for wrapper in root.get_node("Exhibits").get_children():
		var node := wrapper as Node3D
		var size := Viewer.measure_local_size(node)
		left = minf(left, node.position.x - size.x / 2)
		right = maxf(right, node.position.x + size.x / 2)
	var reference := root.get_node_or_null("Reference") as Node3D
	if reference != null:
		var size := Viewer.measure_local_size(reference)
		left = minf(left, reference.position.x - size.x / 2)
		right = maxf(right, reference.position.x + size.x / 2)
	if left > right:
		return Vector2.ZERO
	return Vector2(left, right)
