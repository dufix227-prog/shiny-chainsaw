extends SceneTree

## Проверки стартового места: первые 10 м проходимы, завал держит, склоны
## не выпускают, вернуться к дороге можно (без невидимой стены), машина
## запускает концовку С9-машина, пропуск ведёт к титрам, невидимых тел нет.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/start_area.gd

const SCENE := "res://scenes/world/start_area.tscn"
const StartArea = preload("res://scenes/world/start_area_builder.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("НЕ ПРОШЛО: ", message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	change_scene_to_file(SCENE)
	await frames(3)
	var scene := current_scene
	scene.get_node("CarEnding").quit_on_finish = false
	var terrain = scene.get_node("World/Builder").terrain
	var player: CharacterBody3D = scene.get_node("CatPlayer")
	var pivot: Node3D = player.get_node("CameraPivot")

	_check_world(scene)
	check(player.global_position.distance_to(StartArea.spawn_position_static()) < 0.6, "кот начинает там, где кончилась катсцена")
	check(scene.metres_walked() < 0.1, "в начале 0 м")

	# По тропе до завала.
	Input.action_press("move_up")
	var seconds := 0.0
	while player.global_position.z > StartArea.BARRIER_Z + 3.0 and seconds < 90.0:
		_steer(pivot, player, terrain, -3.0)
		await physics_frame
		seconds += 1.0 / 60.0
	check(player.global_position.z <= StartArea.BARRIER_Z + 3.0, "по тропе можно дойти до завала")
	check(scene.metres_walked() > 9.5, "у завала — почти 10 м (%.1f)" % scene.metres_walked())
	print("  до завала: %.0f с" % seconds)
	# Упереться в завал с прыжками.
	pivot.rotation.y = 0.0
	Input.action_press("jump")
	await frames(60 * 5)
	Input.action_release("jump")
	check(player.global_position.z > StartArea.BARRIER_Z - 1.0, "завал не пропускает даже с прыжками")
	Input.action_release("move_up")

	# Склоны по бокам тропы не выпускают.
	for side: float in [-1.0, 1.0]:
		_put(player, terrain, -120.0)
		pivot.rotation.y = -side * PI / 2.0
		Input.action_press("move_up")
		Input.action_press("jump")
		await frames(60 * 8)
		Input.action_release("jump")
		Input.action_release("move_up")
		var from_center := absf(player.global_position.x - terrain.trail_center_x(player.global_position.z))
		check(from_center < terrain.CORRIDOR_HALF + 3.0, "склон не выпускает (сторона %d, %.1f от тропы)" % [side, from_center])

	# Назад к дороге — без невидимой стены; на проезжей части машина сбивает.
	_put(player, terrain, StartArea.SPAWN_Z)
	Input.action_press("move_up")
	seconds = 0.0
	var ending: Node = scene.get_node("CarEnding")
	while not ending.running and seconds < 90.0:
		_steer(pivot, player, terrain, 3.0)
		await physics_frame
		seconds += 1.0 / 60.0
	Input.action_release("move_up")
	check(ending.running, "вернувшись к дороге, кот попадает под машину (%.0f с)" % seconds)
	check(absf(player.global_position.z) < 6.0, "концовка началась на дороге")
	check(not scene.get_node("PauseMenu").enabled, "во время концовки пауза не открывается")
	check(not player.controls_enabled, "во время концовки управления нет")
	var finished := [false]
	ending.finished.connect(func(): finished[0] = true)
	await frames(60 * 4)
	check(player.get_node("Visual").position.y > 30.0, "кот летит в небо")
	ending.skip_to_credits()
	check(ending.credits.visible, "пропуск ведёт сразу к титрам")
	await frames(60 * 12)
	check(finished[0], "после титров концовка заканчивается (игра закрывается)")
	print("Стартовое место: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)


func _check_world(scene: Node) -> void:
	var forest := scene.get_node("World/Builder/Forest")
	check(forest.get_child_count() > 500, "лес густой (%d деревьев)" % forest.get_child_count())
	var kinds := {}
	for tree in forest.get_children():
		kinds[tree.scene_file_path] = true
	check(kinds.size() >= 6, "в лесу не меньше шести видов деревьев")
	check(scene.get_node("World/Builder/Street/Traffic").get_child_count() >= 10, "по улице едут машины")
	var invisible := []
	for body in scene.find_children("*", "StaticBody3D", true, false):
		var parent := body.get_parent()
		var visible := body.get_node_or_null("Mesh") != null or parent.name == "Terrain" \
			or (body.name == "CameraBlocker" and parent.get_node_or_null("Mesh") != null)
		if not visible:
			invisible.append(str(body.get_path()))
	check(invisible.is_empty(), "невидимых твёрдых тел нет: %s" % [invisible.slice(0, 3)])


## Повернуть камеру так, чтобы «вперёд» вело по тропе (ahead < 0 — вглубь, > 0 — к дороге).
func _steer(pivot: Node3D, player: Node3D, terrain, ahead: float) -> void:
	var look_z := player.global_position.z + ahead
	var target_x: float = terrain.trail_center_x(look_z) if look_z < -8.0 else -1.0
	var to_target := Vector3(target_x, 0, look_z) - player.global_position
	pivot.rotation.y = atan2(-to_target.x, -to_target.z)


func _put(player: CharacterBody3D, terrain, z: float) -> void:
	var x: float = terrain.trail_center_x(z)
	player.global_position = Vector3(x, terrain.height(x, z) + 0.3, z)
	player.velocity = Vector3.ZERO
