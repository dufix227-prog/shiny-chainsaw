extends SceneTree

## Портрет модели кота на нейтральном фоне: спереди, сбоку и в шаге.
## godot --path game/3d-probe -s res://tools/capture_cat.gd -- <файл.jpg>


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#3b3440")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#d9c3a8")
	environment.environment.ambient_light_energy = 0.7
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1, 0.8, 0.62)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	sun.look_at_from_position(Vector3(3, 5, -4), Vector3.ZERO)
	var model_scene: PackedScene = load("res://scenes/player/cat_model.tscn")
	var poses := [[-2.4, 0.0, 0.0], [0.0, -PI / 2.0, 0.0], [2.4, PI * 0.75, 3.4]]
	for pose in poses:
		var cat: Node3D = model_scene.instantiate()
		stage.add_child(cat)
		cat.position.x = pose[0]
		cat.rotation.y = PI + pose[1]
		cat.move_speed = pose[2]
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 40
	camera.look_at_from_position(Vector3(0, 2.2, 9.5), Vector3(0, 1.7, 0))
	camera.current = true
	for i in 23:
		await process_frame
	root.get_texture().get_image().save_jpg(OS.get_cmdline_user_args()[0], 0.9)
	quit()
