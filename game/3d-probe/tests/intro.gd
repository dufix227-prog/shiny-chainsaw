extends SceneTree

## Проверки стартовой катсцены по канону: около минуты, крупный план таблички
## 3 секунды, кот не выходит на проезжую часть, пропуск ведёт к управлению.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/intro.gd

const INTRO := "res://scenes/cutscene/intro.tscn"
const GAME_SCENE := "res://scenes/style_probe/style_probe.tscn"

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("НЕ ПРОШЛО: ", message)


func _run() -> void:
	var scene: Node = load(INTRO).instantiate()
	var animation: Animation = scene.get_node("AnimationPlayer").get_animation("intro")
	check(animation.length >= 45.0 and animation.length <= 75.0, "катсцена около минуты (%.0f с)" % animation.length)
	var sign: Node3D = scene.get_node("Builder/Sign").get_child(0)
	check(sign.get_node("Text").text == "через 500 метров\nклубничные запасы", "текст таблички — формулировка автора")
	var tracks := {}
	for i in animation.get_track_count():
		tracks[str(animation.track_get_path(i)) + ":" + str(animation.track_get_type(i))] = i
	var cat_track: int = tracks["CatModel:%d" % Animation.TYPE_POSITION_3D]
	var camera_track: int = tracks["ShotCamera:%d" % Animation.TYPE_POSITION_3D]
	var camera_rotation: int = tracks["ShotCamera:%d" % Animation.TYPE_ROTATION_3D]
	var sign_center := sign.position + Vector3(0, 2.05, 0)
	var closeup := 0.0
	var longest_closeup := 0.0
	var on_road := 0
	var t := 0.0
	while t <= animation.length:
		var cat: Vector3 = animation.position_track_interpolate(cat_track, t)
		if absf(cat.z) < 5.2:
			on_road += 1
		var camera: Vector3 = animation.position_track_interpolate(camera_track, t)
		var facing: Vector3 = Basis(animation.rotation_track_interpolate(camera_rotation, t)) * Vector3.FORWARD
		var looks_at_sign := camera.distance_to(sign_center) < 3.5 and facing.dot((sign_center - camera).normalized()) > 0.95
		closeup = closeup + 0.05 if looks_at_sign else 0.0
		longest_closeup = maxf(longest_closeup, closeup)
		t += 0.05
	check(on_road == 0, "кот не выходит на проезжую часть")
	check(longest_closeup >= 2.9 and longest_closeup <= 3.6, "крупный план таблички ≈3 с (%.2f с)" % longest_closeup)
	scene.free()

	# Пропуск — сразу к управлению.
	change_scene_to_file(INTRO)
	for i in 5:
		await process_frame
	current_scene.finish()
	for i in 5:
		await process_frame
	check(current_scene.scene_file_path == GAME_SCENE, "пропуск ведёт в игру")

	# Целиком до конца — тоже в игру.
	change_scene_to_file(INTRO)
	for i in 5:
		await process_frame
	var frames := 0
	while current_scene.scene_file_path == INTRO and frames < 60 * 90:
		await process_frame
		frames += 1
	check(current_scene.scene_file_path == GAME_SCENE, "после катсцены игрок в игре (%.0f с)" % (frames / 60.0))
	print("Катсцена: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)
