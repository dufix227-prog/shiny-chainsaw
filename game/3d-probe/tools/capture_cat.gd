extends SceneTree

## Кадры моделей кота на нейтральном фоне.
## godot --path game/3d-probe -s res://tools/capture_cat.gd -- <папка>
## Пишет: variants.jpg (все модели в ряд, три четверти), faces_<id>.jpg (лица с эмоциями).

const CatModel = preload("res://scenes/player/cat_model.gd")


func _initialize() -> void:
	_capture.call_deferred()


func _stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#3b3440")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d9c3a8")
	environment.environment.ambient_light_energy = 0.75
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, 0.82, 0.64)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	sun.look_at_from_position(Vector3(3, 5, 4), Vector3.ZERO)
	return stage


func _cat(stage: Node3D, id: String, position: Vector3, yaw: float, mood: String) -> Node3D:
	var cat: Node3D = load(CatModel.scene_path(id)).instantiate()
	cat.blink_enabled = false
	cat.footsteps_enabled = false
	stage.add_child(cat)
	cat.position = position
	cat.rotation.y = yaw
	cat.emotion = mood
	return cat


func _camera(stage: Node3D, from: Vector3, to: Vector3, fov: float) -> void:
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = fov
	camera.look_at_from_position(from, to)
	camera.current = true


func _save(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_jpg(path, 0.9)
	print("Кадр: ", path)


func _capture() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var ids := CatModel.VARIANT_NAMES.keys()
	var stage := _stage()
	for i in ids.size():
		# Модель смотрит вдоль −Z; поворот PI+0.5 — три четверти к камере.
		_cat(stage, ids[i], Vector3((i - 1.5) * 2.6, 0, 0), PI + 0.45, "neutral")
	_camera(stage, Vector3(0, 2.4, 9.5), Vector3(0, 1.6, 0), 45)
	await _save(folder + "/variants.jpg")
	stage.free()
	var moods := CatModel.EMOTION_NAMES.keys()
	for id in ids:
		var faces := _stage()
		for i in moods.size():
			_cat(faces, id, Vector3((i - 2) * 2.7, 0, 0), PI, moods[i])
			var label := Label3D.new()
			label.text = CatModel.EMOTION_NAMES[moods[i]]
			label.font = load("res://assets/fonts/ptsans/PT_Sans-Web-Bold.ttf")
			label.font_size = 48
			label.pixel_size = 0.006
			label.position = Vector3((i - 2) * 2.7, 0.4, 1.2)
			faces.add_child(label)
		var probe: Node3D = load(CatModel.scene_path(id)).instantiate()
		var eye_y: float = probe.eye_height
		probe.free()
		_camera(faces, Vector3(0, eye_y * 0.75, 11.5), Vector3(0, eye_y * 0.6, 0), 42)
		await _save(folder + "/faces_%s.jpg" % id)
		faces.free()
	quit()
