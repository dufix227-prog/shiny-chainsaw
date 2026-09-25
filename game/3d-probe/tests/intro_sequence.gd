extends SceneTree

const Cat = preload("res://scripts/cat.gd")
const IntroLocation = preload("res://scripts/location_intro.gd")
const IntroSequence = preload("res://scripts/intro_sequence.gd")
const ProbeInput = preload("res://scripts/probe_input.gd")
const Route = preload("res://scripts/route.gd")

var failures := 0
var checks := 0
var finished_signals := 0

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
	ProbeInput.install()
	var world := Node3D.new()
	root.add_child(world)
	var location := IntroLocation.build(world)
	check(location.get_node_or_null("BusyStreet") != null, "Intro has the lively street section")
	check(location.get_node_or_null("StoneTrail") != null, "Intro has the concrete and stone trail section")
	check(location.get_node_or_null("ForestTrail") != null, "Intro has the forest trail section")
	var sign: Node3D = location.get_node_or_null("StrawberrySign")
	check(sign != null, "Intro has the canonical strawberry sign")
	if sign != null:
		var label: Label3D = sign.get_node_or_null("Text")
		check(label != null and label.text == IntroLocation.SIGN_TEXT, "Sign shows only the confirmed text")
	var forest_sides: Node3D = location.get_node_or_null("ForestSides")
	check(forest_sides != null, "Dense forest lines both sides of the intro trail")
	if forest_sides != null:
		var side_shapes := forest_sides.find_children("*", "CollisionShape3D", true, false)
		check(side_shapes.size() >= 28, "Forest sides form a continuous physical boundary")
		for shape: CollisionShape3D in side_shapes:
			check(absf(shape.global_position.x) > 2.0, "Forest collision leaves the marked trail corridor clear")

	var cat := Cat.new()
	world.add_child(cat)
	var sequence := IntroSequence.new()
	sequence.finished.connect(func(): finished_signals += 1)
	world.add_child(sequence)
	await frames(3)
	var traffic = location.get_node_or_null("BusyStreet/Traffic")
	check(traffic != null and traffic.cars.size() >= 4, "Cars populate both directions of the street")
	if traffic != null and not traffic.cars.is_empty():
		var car_x: float = traffic.cars[0].position.x
		await frames(12)
		check(absf(traffic.cars[0].position.x - car_x) > 0.1, "Street cars keep driving during the intro")
		traffic.set_paused(true)
		car_x = traffic.cars[0].position.x
		await frames(12)
		check(is_equal_approx(traffic.cars[0].position.x, car_x), "Pause freezes the street traffic")
		traffic.set_paused(false)
	cat.movement_enabled = false
	sequence.begin(cat)
	check(sequence.is_active() and sequence.phase == IntroSequence.Phase.STONE_TRAIL, "Sequence starts on the stone trail")
	check(cat.position.distance_to(IntroLocation.CUTSCENE_SPAWN) < 0.1, "Cat starts beside the street")
	await frames(30)
	var paused_position := cat.position
	sequence.set_paused(true)
	await frames(20)
	check(cat.position.distance_to(paused_position) < 0.02, "Pausing freezes the cutscene walk")
	sequence.set_paused(false)
	for i in 800:
		if not sequence.is_active():
			break
		await physics_frame
	check(sequence.phase == IntroSequence.Phase.DONE, "Sequence reaches the forest release point")
	check(finished_signals == 1 and sequence.finish_count == 1, "Sequence finishes exactly once")
	check(cat.position.distance_to(IntroLocation.RELEASE_SPAWN) < 0.1, "Cat is released at the forest start")
	check(is_equal_approx(Route.metres(cat.position), 0.0), "Intro does not consume any of the 500 route metres")
	check(not cat.scripted_walk, "Scripted movement releases the cat controller")
	world.queue_free()
	await process_frame
	print("Intro sequence tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
