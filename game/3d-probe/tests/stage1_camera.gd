extends SceneTree

## Этап 1C: проверки камеры — пресеты, первое лицо, независимость движения
## вперёд от поворота камеры (логика направления из cat.gd).

const Stage1Camera = preload("res://probes/stage1_camera.gd")
const Cat = preload("res://scripts/cat.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var probe: Stage1Camera = Stage1Camera.new()
	root.add_child(probe)
	await frames(6)
	check(probe.camera != null, "Camera exists")

	# Три пресета третьего лица: камера позади кота, выше уровня глаз
	for i in probe.PRESETS.size():
		probe.preset = i
		probe.mode = "third"
		await frames(2)
		var spec: Dictionary = probe.PRESETS[i]
		check(absf(probe.camera.position.y - (probe.cat.position.y + spec.height)) < 0.3,
			"Preset %d camera height matches (%.2f)" % [i, probe.camera.position.y])
		check(probe.camera.position.z > probe.cat.position.z, "Preset %d camera stays behind the cat" % i)

	# Первое лицо: камера у головы кота, модель кота скрыта (фикс «видно текстуры»)
	probe.set_mode("first")
	await frames(2)
	check(probe.mode == "first", "First-person mode switches on")
	check(probe.cat.visual.visible == false, "First person hides the cat model")
	check(probe.camera.position.distance_to(probe.cat.position + Vector3(0, 1.62, 0.1)) < 0.05,
		"First-person camera sits at the cat head")

	# Спереди (Minecraft-цикл) и GTA-стиль
	probe.set_mode("front")
	await frames(2)
	check(probe.camera.position.z < probe.cat.position.z, "Front mode places camera ahead of the cat")
	probe.set_mode("gta")
	await frames(2)
	check(probe.camera.position.z > probe.cat.position.z and probe.camera.position.y < 1.4,
		"GTA mode is close and low behind the cat")
	probe.set_mode("third")
	probe.preset = 2
	await frames(2)
	check(probe.cat.visual.visible, "Third person shows the cat again")

	# Движение вперёд независимо от поворота камеры: направление из
	# direction_for должно совпадать с плоским взглядом камеры, без сноса вбок.
	var turned := Basis(Vector3.UP, PI / 4)
	var direction: Vector3 = Cat.direction_for(Vector2(0, -1), turned)
	check(direction.dot(turned.z) < -0.9, "Camera-relative input moves along the camera view")
	var right := Vector3(turned.x.x, 0, turned.x.z).normalized()
	check(absf(direction.dot(right)) < 0.02, "No sideways drift relative to the camera")

	var shapes: int = probe.cat.find_children("*", "CollisionShape3D", true, false).size()
	check(shapes >= 1, "Probe cat keeps its body collision shape")

	print("Stage 1C camera probe: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
