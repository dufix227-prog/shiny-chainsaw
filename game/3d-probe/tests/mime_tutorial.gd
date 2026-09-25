extends SceneTree

const MimeTutorial = preload("res://scripts/mime_tutorial.gd")
const Probe = preload("res://scripts/probe.gd")
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
	var mime := MimeTutorial.new()
	root.add_child(mime)
	await physics_frame
	check(is_equal_approx(Route.metres(mime.position), MimeTutorial.SPAWN_METRES), "Mime starts before the church")
	check(mime.stage == MimeTutorial.Stage.WAITING, "Mime waits for player interaction")
	check(mime.begin(), "Player can start the silent tutorial once")
	check(not mime.begin(), "Tutorial cannot be started twice")
	for i in 2600:
		if mime.stage == MimeTutorial.Stage.RUN:
			break
		await physics_frame
	check(mime.stage == MimeTutorial.Stage.RUN, "Walking lesson advances into the running chase")
	var paused_position := mime.position
	mime.paused = true
	for i in 10:
		await physics_frame
	check(mime.position.distance_to(paused_position) < 0.01, "Pause freezes the mime challenge")
	mime.paused = false
	for i in 6000:
		if Route.metres(mime.position) >= MimeTutorial.CHURCH_METRES:
			break
		await physics_frame
	check(Route.metres(mime.position) >= MimeTutorial.CHURCH_METRES, "Mime reaches the church")
	mime.update_player(Vector3(0, 0, Route.world_z(MimeTutorial.CHURCH_METRES)))
	check(mime.stage == MimeTutorial.Stage.INVENTORY, "Arriving player receives the inventory lesson")
	mime.inventory_opened()
	check(mime.stage == MimeTutorial.Stage.DONE, "Opening inventory completes the challenge")
	mime.reset()
	check(mime.stage == MimeTutorial.Stage.WAITING, "Reset restores the full tutorial")
	mime.queue_free()

	var probe := Probe.new()
	root.add_child(probe)
	for i in 8:
		await physics_frame
	check(probe.mime != null and probe.mime_hint_label.text.contains("мим"), "Probe spawns the mime and tutorial HUD")
	probe.mime.stage = MimeTutorial.Stage.INVENTORY
	probe._toggle_inventory()
	check(probe.mime.stage == MimeTutorial.Stage.DONE, "Opening the real inventory completes the mime lesson")
	check(probe.mime_hint_label.text.contains("View"), "Completion rewards the canonical map hint")
	probe.queue_free()
	await process_frame
	print("Mime tutorial tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
