extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const DialogueData = preload("res://scripts/dialogue_data.gd")

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
	check(house != null and is_equal_approx(house.position.z, Route.world_z(189.0)), "Bratishkin house stands at canonical 189 metres")
	check(house != null and house.get_node_or_null("FrontDoor") != null, "The encounter has a road-facing front door")
	var bratishkin = null
	for npc in probe.npcs:
		if npc.npc_id == "bratishkin": bratishkin = npc
	check(bratishkin != null, "Bratishkin waits at his house")
	if bratishkin != null:
		check(bratishkin.get_node_or_null("OversizeShirt") != null and bratishkin.get_node_or_null("ShoulderBag") != null,
			"Temporary model follows the canonical shirt and shoulder bag")
		probe._open_dialogue(bratishkin)
		var lines: Array = DialogueData.BRATISHKIN.lines
		check(probe.dialogue_box.line_label.text == lines[0], "Meeting starts with the canonical door line")
		probe._on_dialogue_option(0)
		check(probe.dialogue_box.line_label.text.contains("Тест"), "Introduction addresses the player by entered name")
		probe._on_dialogue_option(0)
		check(probe.dialogue_box.line_label.text == lines[2], "Stream request uses the canonical line")
		probe._on_dialogue_option(0)
		check(probe.stream_minigame.opened and not probe.dialogue_box.opened, "Accepting starts the interactive stream")
		check(is_equal_approx(probe.stream_minigame.duration, 300.0), "Canonical Slizario phase lasts five minutes")
		check(probe.stream_minigame.bots.size() == 8, "Expanded Slizario field starts with eight bots")
		probe.stream_minigame.react()
		check(probe.stream_minigame.reactions == 0, "Chat reactions cannot skip the Slizario phase")
		probe.stream_minigame.set_paused(true)
		probe.stream_minigame._process(1.0)
		check(is_zero_approx(probe.stream_minigame.elapsed), "Pause freezes the stream timer")
		probe.stream_minigame.set_paused(false)
		probe.stream_minigame.duration = 0.01
		await frames(2)
		check(probe.stream_minigame.reaction_phase, "Slizario phase always advances to chat reactions")
		probe.stream_minigame.success = false
		for i in probe.stream_minigame.REACTIONS_REQUIRED:
			probe.stream_minigame.react()
		check(probe.folder_found, "Folder is found even after a failed stream")
		check(probe.coins.dolyarik == 2, "Finished stream pays the promised pair of dolyariks")
		check(probe.dialogue_box.line_label.text == "Папка «дети» найдена.", "Finding the folder does not explain its contents")
		probe._reset()
		check(not probe.folder_found and probe.coins.dolyarik == 0, "Full reset clears stream progress and payment")
		probe._open_dialogue(bratishkin)
		probe._on_dialogue_option(0)
		probe._on_dialogue_option(0)
		probe._on_dialogue_option(1)
		check(not probe.stream_minigame.opened and not probe.bratishkin_stream_completed, "Refusal leaves the stream unstarted")
	probe.queue_free()
	await process_frame
	print("Bratishkin stream tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
