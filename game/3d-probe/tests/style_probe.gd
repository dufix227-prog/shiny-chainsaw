extends SceneTree

## Проверки пробы графики: по тропе можно пройти, забор и завал держат,
## у деревьев есть коллизии, невидимых твёрдых тел нет.
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/style_probe.gd

const Terrain = preload("res://scenes/style_probe/probe_terrain.gd")
const SCENE_PATH := "res://scenes/style_probe/style_probe.tscn"

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
	var world: Node3D = load(SCENE_PATH).instantiate()
	root.add_child(world)
	await physics_frame
	var builder = world.get_node("Builder")
	var forest := world.get_node("Builder/Forest")
	var kinds := {}
	var without_collision := 0
	for tree in forest.get_children():
		kinds[tree.scene_file_path] = true
		if tree.get_node_or_null("TrunkCollision") == null:
			without_collision += 1
	check(kinds.size() >= 6, "в лесу не меньше шести видов деревьев")
	check(without_collision == 0, "у каждого дерева коллизия ствола")
	for body in world.find_children("*", "StaticBody3D", true, false):
		var parent := body.get_parent()
		var visible := body.get_node_or_null("Mesh") != null or parent.get_node_or_null("Ground") != null \
			or (body.name == "CameraBlocker" and parent.get_node_or_null("Mesh") != null)
		check(visible, "твёрдое тело видно: %s" % body.get_path())

	var player: CharacterBody3D = world.get_node("CatPlayer")
	var pivot: Node3D = player.get_node("CameraPivot")
	await _check_camera_stays_outside(world, builder, player, pivot)
	# По тропе от старта до завала.
	_put(player, builder, 6.0)
	Input.action_press("move_up")
	var seconds := 0.0
	while player.global_position.z > Terrain.BARRIER_Z + 4.0 and seconds < 60.0:
		var look_z := player.global_position.z - 3.0
		var to_path := Vector3(builder.path_center_x(look_z), 0, look_z) - player.global_position
		pivot.rotation.y = atan2(-to_path.x, -to_path.z)
		await physics_frame
		seconds += 1.0 / 60.0
	check(player.global_position.z <= Terrain.BARRIER_Z + 4.0, "по тропе можно дойти до завала")
	# Упереться в завал с прыжками.
	pivot.rotation.y = 0.0
	Input.action_press("jump")
	for i in 60 * 5:
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_up")
	check(player.global_position.z > Terrain.BARRIER_Z - 1.0, "завал не пропускает даже с прыжками")
	# Упереться в забор у обрыва (идти вправо).
	_put(player, builder, -30.0)
	pivot.rotation.y = -PI / 2.0
	Input.action_press("move_up")
	Input.action_press("jump")
	for i in 60 * 6:
		await physics_frame
	Input.action_release("jump")
	Input.action_release("move_up")
	check(player.global_position.x < world.get_node("Builder").terrain.cliff_x(player.global_position.z) - 0.5,
		"забор не даёт упасть с обрыва")
	check(player.global_position.y > -2.0, "кот не провалился")
	print("Проба графики: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)


## Кот стоит у края тропы рядом с деревом, камера повёрнута сквозь его крону:
## она должна остановиться снаружи, а не оказаться внутри листвы.
func _check_camera_stays_outside(world: Node3D, builder, player: CharacterBody3D, pivot: Node3D) -> void:
	var arm: SpringArm3D = pivot.get_node("SpringArm3D")
	var camera: Camera3D = arm.get_node("Camera3D")
	var space := player.get_world_3d().direct_space_state
	var tested := 0
	var inside := 0
	var blocked := 0
	for tree: Node3D in world.get_node("Builder/Forest").get_children():
		var z := tree.position.z
		if z > 5.0 or z < -60.0:
			continue
		var center: float = builder.path_center_x(z)
		var half_width: float = builder.terrain.path_width(z) / 2.0
		var edge := absf(tree.position.x - center) - half_width
		if edge < 2.5 or edge > 5.0:
			continue
		var side := signf(tree.position.x - center)
		var x := center + side * (half_width - 0.8)
		player.global_position = Vector3(x, builder.block_height(x, z) + 0.2, z)
		player.velocity = Vector3.ZERO
		var to_tree := tree.position - player.global_position
		pivot.rotation = Vector3(-0.3, atan2(to_tree.x, to_tree.z), 0)
		for i in 3:
			await physics_frame
		var query := PhysicsPointQueryParameters3D.new()
		query.position = camera.global_position
		query.collision_mask = 5
		if not space.intersect_point(query).is_empty():
			inside += 1
		if arm.get_hit_length() < arm.spring_length - 0.5:
			blocked += 1
		tested += 1
		if tested >= 12:
			break
	check(tested >= 6, "нашлись деревья у тропы для проверки камеры (%d)" % tested)
	check(inside == 0, "камера не оказывается внутри деревьев (внутри: %d из %d)" % [inside, tested])
	check(blocked == tested, "кроны останавливают камеру (%d из %d)" % [blocked, tested])
	pivot.rotation = Vector3(-0.35, 0, 0)


func _put(player: CharacterBody3D, builder, z: float) -> void:
	var x: float = builder.path_center_x(z)
	player.global_position = Vector3(x, builder.block_height(x, z) + 0.3, z)
	player.velocity = Vector3.ZERO
