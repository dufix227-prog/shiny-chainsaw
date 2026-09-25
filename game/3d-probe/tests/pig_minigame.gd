extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const PigMinigame = preload("res://scripts/pig_minigame.gd")

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
	var probe := Probe.new()
	root.add_child(probe)
	probe.cat_name = "Тест"
	await frames(8)
	var world: Node3D = probe.world_viewport.get_child(0)
	var house = world.get_node_or_null("BratishkinHouse")
	var pen = house.get_node_or_null("PigPen") if house != null else null
	check(pen != null, "Bratishkin location contains a separate pig pen")
	if pen != null:
		check(is_equal_approx(pen.global_position.z, Route.world_z(205.0)), "Pig pen is a walk away from the 189 metre house")
	var bratishkin = null
	for npc in probe.npcs:
		if npc.npc_id == "bratishkin":
			bratishkin = npc
	check(bratishkin != null, "Pig work remains attached to Bratishkin")
	probe.bratishkin_stream_completed = true
	probe._open_dialogue(bratishkin)
	check(probe.dialogue_box.line_label.text == probe.DialogueData.BRATISHKIN.pig_offer, "Completed stream unlocks the canonical pig offer")
	probe._on_dialogue_option(1)
	check(not probe.pig_minigame.opened and not probe.pig_work_completed, "Refusing does not start or complete pig work")
	probe._open_dialogue(bratishkin)
	probe._on_dialogue_option(0)
	check(probe.pig_minigame.opened and probe.pig_minigame.phase == PigMinigame.FEED, "Accepting starts with the feeding phase")
	check(probe.pig_minigame.pigs.size() == PigMinigame.PIG_COUNT, "All three pigs participate")
	for index in PigMinigame.PIG_COUNT:
		probe.pig_minigame.player_position = probe.pig_minigame.pigs[index]
		probe.pig_minigame.act()
	check(probe.pig_minigame.fed.count(true) == PigMinigame.PIG_COUNT, "Player feeds every pig individually")
	check(probe.pig_minigame.phase == PigMinigame.HERD, "Feeding all pigs unlocks herding with the stick")
	probe.pig_minigame.set_paused(true)
	var before := probe.pig_minigame.player_position
	probe.pig_minigame._process(1.0)
	check(probe.pig_minigame.player_position == before, "Pause freezes pig work")
	probe.pig_minigame.set_paused(false)
	for index in PigMinigame.PIG_COUNT:
		probe.pig_minigame.pigs[index] = probe.pig_minigame.pen.get_center()
	probe.pig_minigame.player_position = probe.pig_minigame.pen.position - Vector2(0.07, 0)
	probe.pig_minigame.pigs[0] = probe.pig_minigame.pen.position - Vector2(0.02, 0)
	probe.pig_minigame.act()
	check(probe.pig_work_completed, "Herding every pig into the pen completes the work")
	check(probe.coins.dolyarik == 1, "Completed pig work grants one coin")
	check(probe.dialogue_box.line_label.text.contains("Красава, Тест!"), "Completion uses the canonical named line")
	probe._reset()
	check(not probe.pig_work_completed and not probe.pig_minigame.opened, "Full reset clears pig work")
	probe.queue_free()
	await process_frame
	print("Pig minigame tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
