extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const VtuberData = preload("res://scripts/vtuber_data.gd")

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

func bratishkin(probe) -> Node:
	for npc in probe.npcs:
		if npc.npc_id == "bratishkin":
			return npc
	return null

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	check(VtuberData.ENTRIES.size() == 30, "All thirty approved vtubers are available")
	var ids := {}
	var all_have_intros := true
	for entry in VtuberData.ENTRIES:
		ids[entry.id] = true
		all_have_intros = all_have_intros and not String(entry.intro).is_empty()
	check(ids.size() == 30, "Vtuber identifiers are unique")
	check(all_have_intros, "Every vtuber has her passport introduction")
	check(not ids.has("veoshang") and not ids.has("razdva"), "Excluded channels are absent")
	probe._finish_stream(true)
	check(probe.bratishkin_stream_success and probe.folder_found, "A good stream unlocks the basement without changing folder discovery")
	probe._close_dialogue()
	probe._open_dialogue(bratishkin(probe))
	check(probe.dialogue_box.line_label.text == probe.DialogueData.BRATISHKIN.basement_lines[0], "Good stream starts the canonical basement offer")
	probe._on_dialogue_option(0)
	check(probe.dialogue_box.line_label.text == probe.DialogueData.BRATISHKIN.basement_lines[1], "Offer includes the canonical warning")
	probe._on_dialogue_option(0)
	check(probe.vtuber_room.opened and probe.vtuber_room.roster.item_count == 30, "Accepting opens the full choice roster")
	probe.vtuber_room.roster.select(17)
	probe.vtuber_room._show_entry(17)
	check(probe.vtuber_room.introduction.text.contains("Ш-ш-ш! Стой"), "Browsing shows the passport introduction")
	probe.vtuber_room._choose()
	check(probe.selected_vtuber == "myawa" and not probe.vtuber_room.opened, "Choosing stores exactly one companion")
	probe._on_dialogue_option(0)
	probe.player.global_position = probe.stolen_pig.global_position
	probe._interact_with_pig()
	check(probe.stolen_pig.passenger_count == 2, "Chosen companion occupies the pig's second seat")
	probe._reset()
	check(probe.selected_vtuber.is_empty() and not probe.basement_offer_resolved, "Full reset clears the basement choice")
	probe._finish_stream(true)
	probe._close_dialogue()
	probe._open_dialogue(bratishkin(probe))
	probe._on_dialogue_option(0)
	probe._on_dialogue_option(1)
	check(probe.basement_offer_resolved and not probe.vtuber_room.opened, "Player can refuse to enter the basement")
	probe._open_dialogue(bratishkin(probe))
	check(probe.dialogue_box.line_label.text == probe.DialogueData.BRATISHKIN.pig_offer, "Refusal continues to the separate pig work")
	probe.queue_free()
	await process_frame
	print("Vtuber room tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
