extends SceneTree

## Проверки участка «первые 40 м» и кота.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/first40.gd
## (--fixed-fps 60 — физика считается без ожидания реального времени)

const Builder = preload("res://scenes/world/first40_builder.gd")
const SCENE_PATH := "res://scenes/world/first40.tscn"

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
	if not InputMap.has_action("move_up"):
		root.add_child(load("res://scenes/controls.gd").new())
	_check_path_shape()
	var world: Node3D = load(SCENE_PATH).instantiate()
	root.add_child(world)
	await physics_frame
	_check_forest(world)
	_check_no_invisible_walls(world)
	await _check_path_walkable(world)
	await _check_barrier_blocks(world)
	await _check_bush_slows(world)
	_check_stamina(world)
	print("Участок 40 м: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)


func _check_path_shape() -> void:
	var first := Builder.new()
	var second := Builder.new()
	first.setup_noise()
	second.setup_noise()
	var narrowest := INF
	var widest := 0.0
	var z := 0.0
	while z > Builder.SECTION_END_Z:
		var width: float = first.path_width(z)
		narrowest = minf(narrowest, width)
		widest = maxf(widest, width)
		check(is_equal_approx(width, second.path_width(z)), "одинаковый seed даёт ту же тропу (z=%.0f)" % z)
		z -= 7.0
	check(narrowest >= first.path_min_width - 0.01 and widest <= first.path_max_width + 0.01,
		"ширина тропы в заданных пределах")
	check(widest - narrowest > 3.0, "тропа заметно сужается и расширяется")
	# Склоны за краем долины круче, чем кот может подняться (45°).
	for sample_z in [-50.0, -200.0, -400.0]:
		var edge_x: float = first.path_center_x(sample_z) + first.valley_half_width + 3.0
		var rise: float = first.ground_height(edge_x + 1.0, sample_z) - first.ground_height(edge_x, sample_z)
		check(rise > 1.0, "склон у края долины непроходим (z=%.0f)" % sample_z)
	first.free()
	second.free()


func _check_forest(world: Node3D) -> void:
	var forest := world.get_node("Builder/Forest")
	check(forest.get_child_count() > 1000, "лес густой: больше 1000 деревьев")
	var kinds := {}
	var without_collision := 0
	for tree in forest.get_children():
		kinds[tree.scene_file_path] = true
		if not (tree is StaticBody3D and tree.get_node_or_null("TrunkCollision") is CollisionShape3D):
			without_collision += 1
	check(kinds.size() >= 5, "в лесу не меньше пяти видов деревьев")
	check(without_collision == 0, "у каждого дерева своя коллизия ствола")


## Любое твёрдое тело должно быть видно: меш у самого тела или рядом с ним.
func _check_no_invisible_walls(world: Node3D) -> void:
	var invisible := []
	for body in world.find_children("*", "StaticBody3D", true, false):
		if not (_has_visible_geometry(body) or _has_visible_geometry(body.get_parent())):
			invisible.append(body.get_path())
	check(invisible.is_empty(), "невидимых стен нет: %s" % [invisible.slice(0, 3)])


func _has_visible_geometry(node: Node) -> bool:
	for child in node.get_children():
		if child is GeometryInstance3D and child.visible:
			return true
		if child is Node3D and not child is CollisionObject3D and _has_visible_geometry(child):
			return true
	return false


func _put_player_on_path(world: Node3D, metres: float) -> CharacterBody3D:
	var builder = world.get_node("Builder")
	builder.setup_noise()
	var player: CharacterBody3D = world.get_node("CatPlayer")
	var z := -metres * Builder.WORLD_UNITS_PER_METRE
	var x: float = builder.path_center_x(z)
	player.global_position = Vector3(x, builder.ground_height(x, z) + 0.2, z)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").rotation.y = 0.0
	return player


## Кот, идущий по середине тропы, доходит от старта до завала без помех.
func _check_path_walkable(world: Node3D) -> void:
	var builder = world.get_node("Builder")
	var player := _put_player_on_path(world, 0.3)
	var pivot: Node3D = player.get_node("CameraPivot")
	var seconds := 0.0
	Input.action_press("move_up")
	while player.global_position.z > Builder.SECTION_END_Z + 8.0 and seconds < 200.0:
		var look_z := player.global_position.z - 4.0
		var to_path := Vector3(builder.path_center_x(look_z), 0, look_z) - player.global_position
		pivot.rotation.y = atan2(-to_path.x, -to_path.z)
		await physics_frame
		seconds += 1.0 / 60.0
	Input.action_release("move_up")
	check(player.global_position.z <= Builder.SECTION_END_Z + 8.0, "по тропе можно дойти от 0 до завала")
	check(player.global_position.y > -1.0, "кот не проваливается сквозь землю")
	print("  дорога до завала заняла %.0f с игрового времени" % seconds)


func _check_barrier_blocks(world: Node3D) -> void:
	var player := _put_player_on_path(world, 38.5)
	var start_z := player.global_position.z
	Input.action_press("move_up")
	Input.action_press("jump")
	for i in 60 * 8:
		await physics_frame
	Input.action_release("move_up")
	Input.action_release("jump")
	check(player.global_position.z < start_z - 3.0, "кот дошёл до завала (прошёл %.1f)" % (start_z - player.global_position.z))
	check(player.global_position.z > Builder.SECTION_END_Z, "завал на 40 м не пропускает даже с прыжками")


func _check_bush_slows(world: Node3D) -> void:
	var player := _put_player_on_path(world, 5.0)
	await physics_frame
	player.enter_bush()
	Input.action_press("move_up")
	await physics_frame
	await physics_frame
	var speed_in_bush := Vector2(player.velocity.x, player.velocity.z).length()
	player.leave_bush()
	await physics_frame
	var speed_outside := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_up")
	check(is_equal_approx(speed_in_bush, player.WALK_SPEED * player.BUSH_SPEED_FACTOR), "в кустах кот идёт вдвое медленнее")
	check(is_equal_approx(speed_outside, player.WALK_SPEED), "вне кустов обычная скорость")


func _check_stamina(world: Node3D) -> void:
	var player = world.get_node("CatPlayer")
	player.stamina = player.STAMINA_MAX
	var seconds_of_running := 0.0
	while player.stamina > 0.0 and seconds_of_running < 60.0:
		player._update_stamina(true, 1.0 / 60.0)
		seconds_of_running += 1.0 / 60.0
	check(seconds_of_running > 5.0 and seconds_of_running < 8.0, "полной выносливости хватает на 5–8 секунд бега")
	player._update_stamina(true, 1.0)
	check(not player.is_running, "без выносливости бег прекращается и сразу не возвращается")
	for i in 3:
		player._update_stamina(false, 1.0)
	player._update_stamina(true, 0.01)
	check(player.is_running, "после отдыха бег возвращается")
