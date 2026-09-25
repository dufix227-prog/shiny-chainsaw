extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const DialogueData = preload("res://scripts/dialogue_data.gd")
const Cat = preload("res://scripts/cat.gd")

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
	await frames(8)
	var stint = null
	for npc in probe.npcs:
		if npc.npc_id == "stint":
			stint = npc
	check(stint != null, "Stint spawns into the prologue")
	if stint != null:
		check(is_equal_approx(stint.position.z, Route.world_z(100.0)), "Stint stands at the canonical 100 metres")
		check(stint.position.x >= 2.0, "Stint leaves the straight road clear")
		check(stint.get_node_or_null("DarkOversizeHoodie") != null and stint.get_node_or_null("ShoulderBag") != null,
			"Stint model carries the canonical dark hoodie and shoulder bag")
		check(stint.get_node_or_null("Headphones") != null and stint.get_node_or_null("RingedTail") != null,
			"Stint model carries headphones and a ringed tail")
		check(stint.get_node_or_null("TiltedEar") != null, "One tilted ear remains the model's identifying feature")
		probe.player.global_position = stint.global_position + Vector3(-1.0, 0, 0)
		probe._open_dialogue(stint)
		var data := DialogueData.STINT
		for line_index in data.lines.size():
			check(probe.dialogue_box.line_label.text == data.lines[line_index], "Dialogue shows canonical Stint line %d" % (line_index + 1))
			if line_index < data.lines.size() - 1:
				check(probe.dialogue_box.option_buttons.size() == 1, "Intermediate Stint line only continues the novel dialogue")
				probe._on_dialogue_option(0)
		check(probe.dialogue_box.option_buttons.size() == 2, "Final Stint line offers help or refusal")
		probe._on_dialogue_option(0)
		check(probe.stint_help_accepted, "Helping Stint completes the one-time agreement")
		var coffee_slot := probe.inventory.first_slot_with_id("coffee")
		check(not coffee_slot.is_empty(), "Stint gives exactly one coffee item")
		probe._close_dialogue()
		probe._open_dialogue(stint)
		check(not probe.dialogue_box.opened, "Completed Stint dialogue cannot duplicate the reward")
		probe.inventory_hud.set_open(true)
		probe._use_inventory_slot(coffee_slot)
		check(probe.inventory.first_slot_with_id("coffee").is_empty(), "Using coffee consumes its cup once")
		check(is_equal_approx(probe.player.speed_multiplier, Cat.COFFEE_SPEED_MULTIPLIER), "Coffee applies the trial movement multiplier")
		check(is_equal_approx(probe.player.coffee_seconds_remaining, Cat.COFFEE_DURATION_SECONDS), "Coffee applies the trial duration")
		probe._reset()
		check(not probe.stint_help_accepted and is_equal_approx(probe.player.speed_multiplier, 1.0), "Full reset clears Stint state and coffee buff")
		probe.player.global_position = stint.global_position + Vector3(-1.0, 0, 0)
		probe._open_dialogue(stint)
		for line_index in range(data.lines.size() - 1):
			probe._on_dialogue_option(0)
		probe._on_dialogue_option(1)
		check(probe.dialogue_box.line_label.text == data.refusal_line, "Refusal uses the canonical return invitation")
		check(probe.inventory.first_slot_with_id("coffee").is_empty(), "Refusal grants no coffee")
		probe._close_dialogue()
		probe._open_dialogue(stint)
		check(probe.dialogue_box.line_label.text == data.lines[0], "Refusal leaves the dialogue available on return")
	probe.queue_free()
	await process_frame
	print("Stint tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
