extends SceneTree

const Probe = preload("res://scripts/probe.gd")
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

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	for i in 8:
		await physics_frame
	var beggar = null
	for npc in probe.npcs:
		if npc.npc_id == "church_beggar":
			beggar = npc
	check(beggar != null, "Beggar always stands near the church")
	check(DialogueData.by_id("church_beggar").options.size() == 3, "Beggar offers food, coin, or leave")
	var food_before := probe.inventory.food_count()
	probe._open_dialogue(beggar)
	probe._on_dialogue_option(0)
	check(probe.inventory.food_count() == food_before - 1, "Giving food consumes exactly one portion")
	check(probe.beggar_hint_given, "Successful exchange records the first hint")
	check(probe.dialogue_box.line_label.text == DialogueData.FIRST_BEGGAR_HINT, "First prologue hint is always about Bratishkin's pig")
	check(probe.coins.values().all(func(value): return value == 0), "Food exchange does not consume or grant coins")
	probe._reset()
	probe.coins["zumik"] = 1
	probe._open_dialogue(beggar)
	probe._on_dialogue_option(1)
	check(probe.coins["zumik"] == 0 and probe.beggar_hint_given, "One canonical coin can buy the same first hint")
	probe._reset()
	for address in ["hotbar:0"]:
		probe.inventory.set_slot(address, null)
	probe._open_dialogue(beggar)
	probe._on_dialogue_option(0)
	check(not probe.beggar_hint_given, "Failed exchange does not unlock a hint")
	check(probe.dialogue_box.line_label.text == "Нечего отдать.", "Failed exchange reports missing payment without NPC fiction")
	probe.queue_free()
	await process_frame
	print("Church beggar tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
