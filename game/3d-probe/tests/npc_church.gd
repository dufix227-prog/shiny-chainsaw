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

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	var world: Node3D = probe.world_viewport.get_child(0)
	var booth = world.get_node_or_null("Church/Confessional")
	check(booth != null, "Church contains the confessional booth")
	if booth != null:
		check(booth.get_node_or_null("Divider") != null, "Confessional has a solid dividing wall")
		check(booth.get_node_or_null("HiddenPriest") != null, "Priest stays on the hidden side of the divider")
		check(booth.get_node("HiddenPriest").position.x > 0 and booth.interaction_position().x < booth.global_position.x,
			"Player and priest occupy opposite sides of the wall")
		var data := DialogueData.by_id(booth.dialogue_id)
		check(data.get("line", "") == "…", "Confession keeps an explicit placeholder instead of invented dialogue")
		check(not data.get("portrait", true), "Confession hides the unseen priest portrait")
		probe.player.global_position = booth.interaction_position()
		check(probe._npc_in_reach() == booth, "Player can interact from their side of the confessional")
		var coins_before := probe.coins.duplicate()
		probe._open_dialogue(booth)
		check(probe.dialogue_box.opened, "Confessional opens the dialogue interface")
		check(not probe.dialogue_box.portrait.visible, "Dialogue does not reveal the priest")
		probe._on_dialogue_option(0)
		check(not probe.dialogue_box.opened, "Technical confession can be ended")
		check(probe.coins == coins_before, "Confession grants no unconfirmed reward or currency")
	probe.queue_free()
	await process_frame
	print("Church NPC tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
