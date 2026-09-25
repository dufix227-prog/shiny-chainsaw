extends SceneTree

const Route = preload("res://scripts/route.gd")
const Cat = preload("res://scripts/cat.gd")
const World = preload("res://scripts/world.gd")
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
	check(is_equal_approx(Route.metres(Cat.SPAWN), 0), "Spawn is zero metres")
	check(is_equal_approx(Route.metres(Vector3(0, 0, -54.2)), 5), "Forward progress at 12.24 world units per metre")
	check(is_equal_approx(Route.metres(Vector3(5, 0, -54.2)), 5), "Sideways does not add metres")
	check(is_equal_approx(Route.metres(Vector3(0, 0, -29.72)), 3), "Return reduces current metres")
	check(is_equal_approx(Route.metres(Vector3(0, 0, Route.world_z(33))), 33), "Progress at arbitrary point stays on the shared scale")
	check(is_equal_approx(Route.metres(Vector3(0, 0, Route.world_z(500))), 500), "Progress upper bound is the 500 m endpoint")
	check(is_equal_approx(Route.metres(Vector3(0, 0, 50)), 0), "Progress lower bound")
	var route := Route.new()
	check(route.discovered.is_empty(), "No discoveries before visiting")
	route.discover(Cat.SPAWN)
	var count := route.discovered.size()
	check(count > 0 and not route.discovered.has(Vector2i(0, -9)), "Only nearby map cells revealed")
	route.discover(Cat.SPAWN)
	check(route.discovered.size() == count, "Repeated visit is idempotent")
	route.discover(Vector3(0, 0, -10))
	check(route.discovered.size() > count, "Exploration retains previous cells")
	route.reset()
	check(route.discovered.is_empty(), "Reset clears exploration")
	for angle in [0.0, 0.5, 1.2]:
		var basis := Basis.from_euler(Vector3(-0.6, angle, 0))
		check(is_equal_approx(Cat.direction_for(Vector2(1, 1), basis).length(), 1), "Diagonal normalized")
		check(is_equal_approx(Cat.direction_for(Vector2.ZERO, basis).length(), 0), "Idle direction zero")
		check(is_equal_approx(Cat.direction_for(Vector2(0.3, 0), basis).length(), 0.3), "Analog magnitude retained")
	for action in ["move_left", "move_right", "move_up", "move_down", "run", "jump"]:
		InputMap.add_action(action)
	var world := World.new()
	root.add_child(world)
	var cat := Cat.new()
	world.add_child(cat)
	await frames(30)
	check(cat.is_on_floor(), "Cat settles on ground")
	check(cat.visual.scale == Vector3.ONE * 1.15, "Cat visual scale is slightly smaller without changing collision")
	var start: Vector3 = cat.position
	Input.action_press("move_up")
	await frames(60)
	Input.action_release("move_up")
	await frames(2)
	var distance: float = start.z - cat.position.z
	check(absf(distance - Cat.SPEED) < 0.12, "60 fixed physics ticks move at declared speed")
	start = cat.position
	Input.action_press("move_up")
	Input.action_press("run")
	await frames(55)
	var run_limb_angle := absf(cat.legs[0].rotation.x)
	Input.action_release("run")
	Input.action_release("move_up")
	await frames(2)
	distance = start.z - cat.position.z
	check(absf(distance - Cat.SPEED * Cat.RUN_MULTIPLIER * 55.0 / 60.0) < 0.18, "Run is exactly 1.75 times faster")
	check(run_limb_angle > 0.5, "Running uses a wider limb swing than walking")
	var floor_y := cat.position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await frames(8)
	check(cat.position.y > floor_y + 0.1, "Jump leaves the ground from a standing state")
	check(cat.legs[0].rotation.x < -0.4 and cat.arms[0].rotation.x > 0.2, "Jump uses a distinct airborne limb pose")
	for i in 180:
		await physics_frame
	check(cat.is_on_floor(), "Jump lands back on the ground")
	await frames(2)
	var idle: Vector3 = cat.position
	await frames(30)
	check(cat.position.distance_to(idle) < 0.005, "Idle cat does not drift")
	check(is_zero_approx(cat.legs[0].rotation.x), "Idle animation stops")
	cat.position = Vector3(-3.25, 0.1, World.TREE_Z + 2.5)
	Input.action_press("move_up")
	await frames(90)
	Input.action_release("move_up")
	check(cat.position.z > World.TREE_Z + 0.6, "Relocated tree trunk blocks entry at unchanged dimensions")
	cat.position = Vector3(-3, 0.1, 7)
	Input.action_press("move_left")
	await frames(120)
	Input.action_release("move_left")
	check(cat.position.x > -5 and cat.position.y > -0.1, "Shore blocks entry into water")
	cat.reset()
	await frames(10)
	check(cat.position.distance_to(Cat.SPAWN) < 0.1, "Reset returns to spawn")
	world.queue_free()
	await process_frame
	print("Probe tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
