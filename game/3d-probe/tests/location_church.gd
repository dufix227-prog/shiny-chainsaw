extends SceneTree

const World = preload("res://scripts/world.gd")
const Church = preload("res://scripts/location_church.gd")
const Route = preload("res://scripts/route.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	var world := World.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var church: Node3D = world.get_node_or_null("Church")
	check(church != null, "Church landmark builds into the world")
	if church != null:
		check(is_equal_approx(church.position.z, Route.world_z(Church.METRES)), "Church stands at the canonical 40 metres")
		check(church.position.x > 3.0, "Church stands beside rather than on the road")
		check(church.get_node_or_null("BellTower") != null, "Church has the large visible bell tower")
		check(church.get_node_or_null("BellTower/Cross") != null, "Bell tower carries the church cross")
		check(church.get_node_or_null("EntranceDoor") != null, "Church entrance faces the road")
		var highest := 0.0
		for mesh: MeshInstance3D in church.find_children("*", "MeshInstance3D", true, false):
			highest = maxf(highest, mesh.global_position.y)
		check(highest >= Church.TOWER_HEIGHT, "Church reads at least ten cat heights tall")
		for shape: CollisionShape3D in church.find_children("*", "CollisionShape3D", true, false):
			check(absf(shape.global_position.x) > 1.8, "Church collision keeps the main road clear")
	world.queue_free()
	await process_frame
	print("Location church tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
