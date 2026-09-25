extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const ProbeInput = preload("res://scripts/probe_input.gd")
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

func joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	ProbeInput.install()
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "inventory", "rest", "run", "jump", "full_map", "quality", "camera", "pause_probe", "reset"]:
		check(InputMap.has_action(action), "Controller action exists: %s" % action)
	var probe := Probe.new()
	root.add_child(probe)
	probe.size = Vector2(1280, 800)
	await frames(10)
	check(probe.started, "Headless automated runs begin the existing probe")
	check(not probe.menu_hud.is_open(), "Headless automated runs do not block existing suites with the start menu")
	probe._return_to_menu()
	await frames(3)
	check(not probe.started and probe.menu_hud.mode == probe.menu_hud.START, "Main menu freezes a fresh technical attempt")
	var origin: Vector3 = probe.player.position
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	check(probe.player.position.distance_to(origin) < 0.005, "Start menu blocks locomotion")
	probe.menu_hud.primary_button.pressed.emit()
	await frames(2)
	check(probe.menu_hud.mode == probe.menu_hud.NAME, "Start action opens the cat name screen before the walk")
	probe.menu_hud.name_confirm.pressed.emit()
	await frames(2)
	check(probe.started and not probe.menu_hud.is_open(), "Confirmed name begins the probe")
	probe._toggle_full_map()
	await frames(2)
	check(probe.full_map_hud.opened and probe.full_map_hud.info.text.contains("осталось"), "Full map opens with unexplored-space count")
	var map_content := probe.full_map_hud.map_canvas.content_rect()
	check(is_equal_approx(map_content.get_center().x, probe.full_map_hud.map_canvas.size.x / 2), "Full probe route is centered horizontally on the map")
	var unexplored_tint := probe.full_map_hud.map_canvas.cell_tint(Vector2i.ZERO, false)
	var discovered_tint := probe.full_map_hud.map_canvas.cell_tint(Vector2i.ZERO, true)
	check(unexplored_tint.get_luminance() > 0.05 and unexplored_tint != discovered_tint, "Unexplored route is readable without revealing discovered terrain")
	check(probe.full_map_hud.map_canvas.marker_tint(false, Color.RED).get_luminance() > 0.05, "Hidden markers are neutral rather than black")
	origin = probe.player.position
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_up")
	check(probe.player.position.distance_to(origin) < 0.005, "Full map freezes world movement")
	probe._toggle_full_map()
	check(not probe.full_map_hud.opened, "Full map closes without changing the attempt")
	var camera_before := probe.camera_index
	probe._toggle_camera()
	check(probe.camera_index != camera_before, "Camera cycles through added presets")
	await joy(6)
	check(probe.paused and probe.menu_hud.mode == probe.menu_hud.PAUSE, "Deck Menu button opens pause")
	origin = probe.player.position
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	check(probe.player.position.distance_to(origin) < 0.005, "Pause menu freezes movement")
	await joy(1)
	check(not probe.paused and not probe.menu_hud.is_open(), "Deck B closes pause and resumes")
	probe._toggle_inventory()
	await frames(2)
	check(probe.inventory_hud.opened and probe.inventory_hud.slots.size() == 10 and probe.inventory_hud.slots["hotbar:0"].visible, "Inventory exposes ten reachable base slots for controller navigation")
	await joy(1)
	check(not probe.inventory_hud.opened and probe.inventory_hud.open_button.has_focus(), "Deck B closes inventory and restores toolbar focus")
	probe._pause()
	probe.menu_hud._open_settings(probe.menu_hud.PAUSE)
	var previous_quality := probe.quality_index
	probe.menu_hud.primary_button.pressed.emit()
	check(probe.quality_index != previous_quality, "Settings changes existing 3D quality without reset")
	check(probe.audio.music.stream != null and probe.audio.ambience.stream != null, "Ambient music and wind streams are local resources")
	var footstep_events := probe.audio.footstep_events
	probe.audio.advance_steps(0, true)
	probe.audio.advance_steps(2.0, false)
	check(probe.audio.footstep_events == footstep_events, "Idle and paused movement cannot produce footsteps")
	probe.audio.advance_steps(1.5, true)
	check(probe.audio.footstep_events > footstep_events, "Actual distance produces footstep cadence")
	var pickup_events := probe.audio.pickup_events
	probe._collect_food()
	check(probe.audio.pickup_events == pickup_events, "Failed pickup has no confirmation sound")
	probe.queue_free()
	await process_frame
	print("Menu tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
