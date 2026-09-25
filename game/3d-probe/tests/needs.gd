extends SceneTree

const Needs = preload("res://scripts/needs.gd")
const Probe = preload("res://scripts/probe.gd")
const JoypadGuard = preload("res://tests/joypad_guard.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	release.echo = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var needs := Needs.new()
	check(not needs.enabled and needs.can_move(), "Clean walking is the default")
	needs.advance(100, 1)
	check(needs.food == 60 and needs.stamina == 100, "Disabled needs are frozen")
	check(not needs.eat() and needs.portions == 2, "Disabled test cannot spend food")
	needs.toggle()
	for rate in [30, 60, 120]:
		needs.reset()
		for i in rate * 10:
			needs.advance(1.0 / rate, 3.4 / rate)
		check(absf(needs.food - (60.0 - 100.0 / 90.0)) < 0.001, "Walking food use targets fifteen real minutes and is frame-rate independent")
		check(absf(needs.stamina - 100.0 + 17.0 / 12.24) < 0.001, "Walking stamina uses game metres and is frame-rate independent")
	needs.reset()
	needs.stamina = 60
	needs.advance(10, 0)
	check(is_equal_approx(needs.food, 60.0 - 100.0 / 180.0) and is_equal_approx(needs.stamina, 61), "Standing spends slower food and restores stamina slowly")
	needs.reset()
	needs.advance(10, 0.5)
	check(is_equal_approx(needs.stamina, 100.0 - 0.25 / 12.24), "All actual travelled metres spend stamina")
	needs.reset()
	needs.advance(1, 12.24, true)
	check(is_equal_approx(needs.stamina, 98.5), "Running spends three times more stamina per game metre")
	needs.reset()
	needs.food = needs.profile.warning_threshold - 1
	needs.advance(1, 12.24)
	check(is_equal_approx(needs.stamina, 99.25), "Hungry walking spends 1.5 times more stamina")
	needs.reset()
	needs.food = needs.profile.warning_threshold - 1
	needs.advance(1, 12.24, true)
	check(is_equal_approx(needs.stamina, 97.75), "Hungry running combines the 1.5 and 3 multipliers")
	needs.advance(-10, 1)
	check(is_equal_approx(needs.stamina, 97.75), "Negative time cannot refill needs")
	needs.reset()
	needs.stamina = 20
	needs.toggle_rest()
	needs.advance(2, 0)
	check(is_equal_approx(needs.stamina, 20.7) and not needs.can_move(), "Sitting restores stamina faster and blocks movement")
	needs.food = 20
	needs.advance(2, 0)
	check(is_equal_approx(needs.stamina, 21.05), "Hungry sitting restores more slowly")
	check(needs.eat() and needs.portions == 1 and needs.food > 54, "Eating consumes one portion and restores food")
	needs.food = 99
	check(needs.eat() and needs.food == 100 and needs.portions == 0, "Food is capped at 100")
	needs.food = 20
	check(not needs.eat() and needs.portions == 0 and needs.food == 20, "Empty supply cannot refill")
	needs.reset()
	needs.food = 100
	check(not needs.eat() and needs.portions == 2, "Full cat does not waste portions")
	needs.stamina = 0
	check(not needs.can_move() and needs.status().contains("Space"), "Exhaustion explains how to rest, not a death")
	needs.food = 0
	check(not needs.can_move() and needs.status().contains("поесть"), "Hunger explains how to recover")
	needs.eat()
	needs.toggle_rest()
	needs.advance(5, 0)
	needs.toggle_rest()
	check(needs.can_move(), "Food and rest recover movement without a reset")
	needs.food = 0
	needs.portions = 0
	check(needs.status().contains("R"), "Empty laboratory offers an explicit reset")
	needs.advance(1000, 1)
	check(needs.food == 0 and needs.stamina >= 0 and needs.stamina <= 100, "Resources stay within valid bounds")
	needs.toggle()
	check(needs.can_move(), "Disabling needs never traps the walking test")
	needs.toggle()
	check(needs.food == 0 and needs.portions == 0, "Toggling does not refill resources")
	needs.reset()
	check(needs.enabled and needs.food == 60 and needs.stamina == 100 and needs.portions == 2, "Reset preserves mode and restores laboratory state")
	needs.toggle_rest()
	needs.advance(1000, 0)
	check(needs.stamina == 100, "Rest cannot overfill stamina")
	await integration()
	print("Needs tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func integration() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2(1280, 800)
	await frames(30)
	check(not probe.needs.enabled and not probe.needs_hud.values.visible, "Needs UI is collapsed initially")
	await key(KEY_N)
	check(probe.needs.enabled and probe.needs_hud.values.visible, "N reveals the separate needs test")
	var portions: int = probe.needs.portions
	await key(KEY_E)
	check(probe.needs.portions == portions - 1, "E spends exactly one portion")
	await key(KEY_E, true)
	check(probe.needs.portions == portions - 1, "Held E cannot spend repeated portions")
	probe._reset()
	for action in ["move_left", "move_right", "move_up", "move_down", "run"]:
		Input.action_release(action)
	Input.flush_buffered_events()
	Input.action_press("route_forward")
	Input.flush_buffered_events()
	await frames(60)
	Input.action_release("route_forward")
	Input.flush_buffered_events()
	await frames(2)
	check(probe.walking_seconds > 0.9 and probe.needs.stamina < 100, "F moves at normal speed and consumes stamina")
	check(absf(probe.player.position.x) < 0.05, "F follows the road regardless of camera angle")
	var at_rest: Vector3 = probe.player.position
	var energy: float = probe.needs.stamina
	await key(KEY_SPACE)
	await frames(12)
	check(probe.player.sitting and probe.player.visual.position.y < -0.2, "Space visibly seats the cat for active rest")
	Input.action_press("route_forward")
	await frames(30)
	Input.action_release("route_forward")
	check(probe.player.position.distance_to(at_rest) < 0.005, "Movement input cannot move a resting cat")
	check(probe.needs.stamina > energy and probe.player.legs[0].rotation.x < -0.8, "Sitting restores stamina with a seated visual pose")
	probe._pause()
	var food: float = probe.needs.food
	energy = probe.needs.stamina
	var elapsed: float = probe.elapsed_seconds
	await frames(60)
	await key(KEY_E)
	check(probe.needs.food == food and probe.needs.stamina == energy, "Pause freezes resource use and recovery")
	check(probe.elapsed_seconds == elapsed, "Pause freezes the timer")
	check(probe.needs_hud.eat_button.disabled and probe.needs_hud.rest_button.disabled, "Paused actions visibly disabled")
	probe._resume_probe()
	probe.needs_hud.rest_button.pressed.emit()
	await frames(30)
	check(not probe.needs.resting and not probe.player.sitting and absf(probe.player.visual.position.y) < 0.02, "Mouse returns the seated cat to standing")
	probe.needs_hud.eat_button.pressed.emit()
	check(probe.needs.portions == 1, "Mouse can eat")
	probe._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(probe.paused and not probe.player.movement_enabled, "Losing app focus pauses movement and needs")
	await key(KEY_P)
	var position: Vector3 = probe.player.position
	var discovered: Dictionary = probe.route.discovered.duplicate()
	food = probe.needs.food
	probe.needs_hud.mode_button.pressed.emit()
	check(not probe.needs.enabled and probe.needs.food == food, "Mouse disables needs without refilling")
	check(probe.player.position == position and probe.route.discovered == discovered, "Mode switching preserves route and discoveries")
	probe._reset()
	check(probe.walking_seconds == 0 and probe.elapsed_seconds == 0 and probe.needs.portions == 2, "Reset clears both clocks and refills supplies")
	check(probe.quality_index == 1 and not probe.needs.enabled, "Reset retains quality and needs choice")
	probe.queue_free()
	await process_frame
