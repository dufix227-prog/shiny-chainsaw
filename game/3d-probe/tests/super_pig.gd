extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const SuperPig = preload("res://scripts/super_pig.gd")

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

func npc(probe, id: String):
	for candidate in probe.npcs:
		if candidate.npc_id == id:
			return candidate
	return null

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	check(not probe.super_pig.visible and not probe.super_pig.summoned, "Black boar starts absent")
	probe.folder_found = true
	probe.previous_route_metres = 180.0
	probe.player.position = Vector3(0, 0.1, Route.world_z(174.0))
	probe._on_step(0.1, 0.1)
	check(probe.super_pig.summoned and probe.super_pig.visible, "Black boar runs up while player returns toward Stint")
	check(probe.mime_hint_label.text.contains("чёрный кабанчик"), "Arrival needs no character prompt")
	probe.selected_vtuber = "myawa"
	probe.player.global_position = probe.super_pig.global_position
	probe.super_pig.mount(probe.player.global_position, true)
	probe.player.set_mount_speed_multiplier(SuperPig.SPEED_MULTIPLIER)
	check(probe.super_pig.passenger_count == SuperPig.SEAT_CAPACITY, "Outbound ride uses both seats with the companion")
	check(is_equal_approx(probe.player.mount_speed_multiplier, 2.2), "Super pig has its separate technical speed")
	probe.stint_help_accepted = true
	probe._open_dialogue(npc(probe, "stint"))
	probe._on_dialogue_option(0)
	check(probe.super_pig.exhausted and not probe.super_pig.mounted, "Return trip exhausts the black boar")
	check(probe.super_pig.visible, "Exhausted black boar does not disappear")
	check(probe.vtuber_waiting_at_stint, "Companion waits while Stint occupies the return seat")
	check(is_equal_approx(probe.player.mount_speed_multiplier, 1.0), "Return trip removes the transport multiplier")
	probe._reset()
	check(not probe.super_pig.summoned and not probe.super_pig.exhausted, "Full reset restores the one-time transport")
	probe.queue_free()
	await process_frame
	print("Super pig tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
