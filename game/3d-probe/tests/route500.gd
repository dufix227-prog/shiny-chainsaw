extends SceneTree

## К1: правила скелета 500 м — масштаб, привязки сцен, встречи и карта.

const Route = preload("res://scripts/route.gd")
const World = preload("res://scripts/world.gd")
const FullMapHUD = preload("res://scripts/full_map_hud.gd")
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
	check(is_equal_approx(Route.LENGTH, 500.0), "Route length is the 500 m prologue skeleton")
	check(is_equal_approx(Route.WORLD_LENGTH, 6120.0), "500 m is 6120 world units at 12.24 per metre")
	check(is_equal_approx(Route.END_Z, 7.0 - 6120.0), "Endpoint sits at the scaled road end")
	var seconds := Route.WORLD_LENGTH / 3.4
	check(absf(seconds - 1800.0) < 1.0, "Scale matches the ~30:00 clean-walk target")
	var by_id := {}
	for scene in Route.SCENES:
		by_id[scene.id] = scene
	check(by_id.has("stint") and is_equal_approx(by_id["stint"].metres, 100.0), "Stint anchor is canon 100 m")
	check(by_id.has("bratishkin") and is_equal_approx(by_id["bratishkin"].metres, 189.0), "Bratishkin anchor is canon 189 m")
	check(by_id.has("forest") and is_equal_approx(by_id["forest"].metres, 0.0), "Forest start anchors the zero metre")
	check(by_id.has("church") and is_equal_approx(by_id["church"].metres, 40.0), "Church anchor is canon 40 m")
	check(by_id.has("fishing") and is_equal_approx(by_id["fishing"].metres, 260.0), "Fishing anchor is canon 260 m")
	check(by_id.has("farm") and is_equal_approx(by_id["farm"].metres, 500.0), "Farm and strawberry theft anchor the 500 m finish")
	check(not by_id.has("fyvfyv"), "Hidden fyvfyv at the farm has no separate road marker")
	check(is_equal_approx(Route.world_z(by_id["stint"].metres), Route.ORIGIN_Z - 100.0 * Route.WORLD_UNITS_PER_METRE), "Scene anchors place scenes on the road")
	var route := Route.new()
	check(route.visible_scene_ids().size() == 1 and route.visible_scene_ids()[0] == "forest", "Only the start scene is visible before any movement")
	route.discover(Vector3(0, 0, Route.world_z(99.9)))
	check(route.visible_scene_ids().has("stint"), "Physically visiting Stint's area reveals its marker")
	check(not route.visible_scene_ids().has("bratishkin"), "Distant scenes stay hidden until encountered")
	route.discover(Vector3(0, 0, Route.world_z(100.1)))
	check(route.visible_scene_ids().has("stint"), "Approach from the other side also reveals the marker")
	route.record_encounters()
	check(route.encountered.has("stint"), "Encounter bookkeeping records the visit once")
	route.reset()
	check(route.discovered.is_empty() and route.encountered.is_empty() and route.visible_scene_ids().size() == 1, "Reset clears discoveries and encounters")
	# World still builds at the new length (segmented batching).
	var world := World.new()
	root.add_child(world)
	for i in 8:
		await physics_frame
	check(world.get_child_count() > 150, "Segmented world builds many chunks across 6120 units")
	world.queue_free()
	await process_frame
	# Full map canvas: no-spoiler rules on the long strip.
	var hud := FullMapHUD.new()
	hud.route = route
	root.add_child(hud)
	hud.set_open(true)
	hud.refresh()
	await process_frame
	check(hud.map_canvas.walkable_cells().size() > 12000, "Full map covers the whole 500 m strip")
	check(hud.info.text.contains("метры"), "Full map caption shows current metres")
	hud.queue_free()
	await process_frame
	print("Route500 tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
