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
		var visible := body.get_node_or_null("Mesh") != null or body.get_parent().get_node_or_null("Ground") != null
		check(visible, "твёрдое тело видно: %s" % body.get_path())

	var player: CharacterBody3D = world.get_node("CatPlayer")
	var pivot: Node3D = player.get_node("CameraPivot")
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


func _put(player: CharacterBody3D, builder, z: float) -> void:
	var x: float = builder.path_center_x(z)
	player.global_position = Vector3(x, builder.block_height(x, z) + 0.3, z)
	player.velocity = Vector3.ZERO
