extends SceneTree

const World = preload("res://scripts/world.gd")
const Forest = preload("res://scripts/location_forest.gd")
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

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	var world := World.new()
	root.add_child(world)
	await frames(8)
	var forest: Node3D = world.get_node_or_null("ForestStart")
	check(forest != null, "Forest start location builds into the world as a landmark node")
	if forest == null:
		print("Location forest tests: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var meshes := forest.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() >= 15 and meshes.size() <= Forest.MESH_BUDGET,
		"Forest keeps a modest mesh count inside the budget (now %d)" % meshes.size())
	var bodies := forest.find_children("*", "StaticBody3D", true, false)
	check(bodies.size() >= 5, "Trunks near the road carry solid collision")
	var boundaries: Node3D = forest.get_node_or_null("TrailBoundaries")
	check(boundaries != null, "Dense forest boundaries line the playable start trail")
	if boundaries != null:
		var boundary_shapes := boundaries.find_children("*", "CollisionShape3D", true, false)
		check(boundary_shapes.size() >= 46, "Forest boundaries prevent leaving the marked trail")
		var min_boundary_z := INF
		var max_boundary_z := -INF
		for shape: CollisionShape3D in boundary_shapes:
			min_boundary_z = minf(min_boundary_z, shape.global_position.z)
			max_boundary_z = maxf(max_boundary_z, shape.global_position.z)
		check(min_boundary_z <= Route.world_z(Forest.TRAIL_ROAD_Z) + 0.1,
			"Forest boundaries reach the main road end of the trail")
		check(max_boundary_z >= Forest.TRAIL_FOREST_Z - 0.1,
			"Forest boundaries reach the deep forest end of the trail")
	# Батчинг сливает видимые меши в один узел на позиции (0,0,0), поэтому
	# безопасность дороги проверяем по узлам коллизий — они не двигались.
	var shapes := forest.find_children("*", "CollisionShape3D", true, false)
	var on_road := 0
	var closest := 999.0
	for shape: CollisionShape3D in shapes:
		var x: float = shape.global_position.x
		closest = minf(closest, absf(x))
		if absf(x) < 1.8:
			on_road += 1
	check(on_road == 0, "No forest collision enters the marked trail corridor")
	check(closest >= 1.8, "Forest boundaries keep a walking margin from the trail axis")
	var span := Forest.SPAN_METRES * 12.24
	var outside := 0
	for shape: CollisionShape3D in shapes:
		if shape.global_position.z < -210.0 or shape.global_position.z > 210.0 + span:
			outside += 1
	check(outside == 0, "Solid trunks stay inside the start span")
	var visuals := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh != null:
			visuals += 1
	check(visuals >= 1, "Batched forest keeps merged visible geometry")
	world.queue_free()
	await process_frame
	print("Location forest tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
