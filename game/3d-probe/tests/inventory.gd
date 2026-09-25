extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Pickup = preload("res://scripts/food_pickup.gd")
const Inventory = preload("res://scripts/food_inventory.gd")
const ProbeInventory = preload("res://scripts/probe_inventory.gd")
var failures := 0
var checks := 0
var under_test: Control

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

## GUI focus and accept actions match real joypad events, so the Deck path
## is exercised directly instead of synthesizing keyboard actions.
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

func frames(count: int) -> void:
	for i in count:
		if is_instance_valid(under_test):
			# The physical Deck controller stays live in headless runs; a stray
			# L3 press must not freeze the suite behind the full-map overlay.
			if under_test.paused:
				under_test._resume_probe()
			if under_test.full_map_hud.opened:
				under_test._toggle_full_map()
		await physics_frame

func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	# Script-mode headless windows otherwise start at 64x64 and reject these GUI clicks.
	root.size = Vector2i(1280, 800)
	var stock := Inventory.new()
	check(not stock.consume_portion() and stock.portions == 0, "Empty stack cannot go negative")
	stock.add_portion()
	check(stock.consume_portion() and stock.portions == 0, "A collected portion is consumed once")
	var probe := Probe.new()
	root.add_child(probe)
	under_test = probe
	probe.size = Vector2(1280, 800)
	await frames(10)
	check(not probe.pickup.enabled and not probe.pickup.visible, "World food is an optional separate test")
	check(not probe.needs.enabled and probe.needs.portions == 2, "Clean walking and original laboratory supply remain default")
	await key(KEY_B)
	check(probe.inventory_hud.opened and not probe.player.movement_enabled, "B opens inventory and blocks movement")
	check(probe.inventory_hud.status.text.contains("Нужды выключены"), "Needs-off food use explains itself in the window")
	await key(KEY_ENTER)
	check(probe.needs.portions == 2, "Disabled needs cannot consume through inventory")
	await key(KEY_B, true)
	check(probe.inventory_hud.opened, "Held B does not toggle repeatedly")
	await key(KEY_ESCAPE)
	check(not probe.inventory_hud.opened and probe.player.movement_enabled, "Escape returns control to clean walking")
	await key(KEY_N)
	await click(probe.inventory_hud.mode_button)
	check(probe.pickup.enabled and probe.pickup.visible, "Mouse enables the visible world-food test")
	check(not probe.needs_hud.eat_button.visible, "Pickup mode removes the old quick-eat button")
	var before: int = probe.needs.portions
	await key(KEY_E)
	check(probe.needs.portions == before and not probe.pickup.collected, "E out of reach neither picks up nor eats")
	check(probe.inventory_hud.pickup_button.disabled, "Out-of-reach pickup is visibly disabled")
	for action in ["move_left", "move_right", "move_up", "move_down", "run", "jump"]:
		Input.action_release(action)
	Input.flush_buffered_events()
	Input.action_press("route_forward")
	var steps := 0
	while not probe.pickup.can_collect(probe.player.global_position) and steps < 240:
		await physics_frame
		if probe.paused:
			probe._resume_probe()
		steps += 1
	Input.action_release("route_forward")
	await frames(2)
	check(probe.pickup.can_collect(probe.player.global_position), "Normal walking reaches food without teleporting")
	check(probe.route.discovered.size() < 100, "Finding food does not reveal the rest of the route")
	check(not probe.inventory_hud.pickup_button.disabled, "Nearby food exposes the pickup action")
	var food: float = probe.needs.food
	await key(KEY_E)
	check(probe.pickup.collected and not probe.pickup.visible, "E removes the collected object from the world")
	check(probe.needs.portions == before + 1, "Pickup adds exactly one portion to the shared stock")
	check(probe.needs.food <= food, "Pickup does not automatically eat the food")
	await key(KEY_E)
	await key(KEY_E, true)
	probe._collect_food()
	probe._eat()
	check(probe.needs.portions == before + 1, "Repeated input and callbacks cannot duplicate or eat the pickup")
	await click(probe.inventory_hud.mode_button)
	await click(probe.inventory_hud.mode_button)
	check(probe.pickup.collected and not probe.pickup.visible, "Toggling pickup mode cannot respawn collected food")
	await key(KEY_B)
	check(probe.inventory_hud.stock.text.contains("3"), "Inventory displays the same three portions")
	var position: Vector3 = probe.player.position
	food = probe.needs.food
	var stamina: float = probe.needs.stamina
	var elapsed: float = probe.elapsed_seconds
	Input.action_press("route_forward")
	await frames(30)
	Input.action_release("route_forward")
	check(probe.player.position.distance_to(position) < 0.005, "Inventory stops held movement")
	check(probe.needs.food == food and probe.needs.stamina == stamina, "Inventory freezes laboratory needs")
	check(probe.elapsed_seconds == elapsed, "Inventory time is excluded from the walking experiment")
	await key(KEY_E)
	await key(KEY_N)
	await key(KEY_SPACE)
	await key(KEY_R)
	probe._toggle_pickup()
	check(probe.needs.portions == 3 and probe.needs.enabled and not probe.needs.resting, "World shortcuts do not leak through the modal")
	check(probe.pickup.collected and probe.elapsed_seconds == elapsed, "R cannot reset the route through the modal")
	await joy(JOY_BUTTON_A)
	check(probe.needs.portions == 3 and probe.inventory_hud.selected == "hotbar:0", "Deck A on a focused slot selects it instead of eating")
	await key(KEY_ENTER)
	check(probe.needs.portions == 2 and is_equal_approx(probe.needs.food, minf(100, food + 35)), "Enter consumes exactly one stored portion")
	await key(KEY_ENTER, true)
	check(probe.needs.portions == 2, "Held Enter cannot repeat food use")
	probe.inventory_hud.slots["hotbar:0"].grab_focus()
	await joy(JOY_BUTTON_Y)
	await frames(2)
	check(probe.inventory_hud.context_menu.visible, "Context menu offers actions on the focused food")
	var use_action: Button = null
	for child in probe.inventory_hud.context_box.get_children():
		if child is Button and child.text == "Использовать":
			use_action = child
	check(use_action != null, "The context menu has a use action")
	await click(use_action)
	check(probe.needs.portions == 1 and probe.needs.food == 100, "Context use consumes one portion and caps satiety")
	await key(KEY_ENTER)
	check(probe.needs.portions == 1 and probe.needs.food == 100, "Full cat keeps its remaining food")
	probe.inventory.hotbar = [null, null, null, null, null]
	probe.inventory.pockets = [null, null, null, null, null]
	probe.needs.food = 0
	probe._refresh_needs()
	await key(KEY_ENTER)
	check(probe.needs.portions == 0 and probe.needs.food == 0, "Empty inventory cannot recover food")
	check(probe.inventory_hud.status.text.contains("Пусто"), "Empty inventory has an explicit explanation")
	probe._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await key(KEY_B)
	check(probe.paused and not probe.player.movement_enabled, "Closing inventory cannot undo a focus-loss pause")
	await key(KEY_B)
	probe.inventory.hotbar[0] = ProbeInventory.food_stack()
	probe._refresh_needs()
	await key(KEY_ENTER)
	check(probe.inventory.food_count() == 1 and probe.needs.food == 0, "Paused inventory cannot consume")
	await key(KEY_B)
	await key(KEY_P)
	probe._reset()
	check(probe.pickup.enabled and not probe.pickup.collected and probe.pickup.visible, "R respawns world food only for the new attempt")
	check(probe.needs.portions == 2 and not probe.inventory_hud.opened, "R restores one shared starting supply and closes inventory")
	check(probe.walking_seconds == 0 and probe.elapsed_seconds == 0, "Inventory integration preserves reset timers")
	probe.player.position = Pickup.LOCATION + Vector3(0, 4, 0)
	check(not probe.pickup.can_collect(probe.player.global_position), "Pickup reach includes height, not just map coordinates")
	probe.player.position = Pickup.LOCATION
	await frames(2)
	await click(probe.inventory_hud.pickup_button)
	check(probe.needs.portions == 3 and probe.pickup.collected, "Mouse can collect exactly once")
	probe.needs.food = 0
	await key(KEY_B)
	await key(KEY_ENTER)
	await click(probe.inventory_hud.close_button)
	check(not probe.inventory_hud.opened and probe.needs.food > 0 and probe.player.movement_enabled, "Inventory food recovers movement from zero satiety")
	check(probe.needs.inventory.portions == probe.needs.portions, "There is no separate duplicate laboratory stock")
	await key(KEY_B)
	check(probe.inventory_hud.opened, "Rebuilt inventory reopens for the reworked UI checks")
	var stable_slot: Button = probe.inventory_hud.slots["hotbar:0"]
	probe._refresh_needs()
	await frames(3)
	check(probe.inventory_hud.slots["hotbar:0"] == stable_slot and is_instance_valid(stable_slot),
		"Per-frame refresh keeps the same slot buttons so real clicks and D-pad focus survive")
	await click(stable_slot)
	check(probe.inventory_hud.selected == "hotbar:0", "A real mouse click selects the source slot")
	await click(probe.inventory_hud.slots["pocket:2"])
	check(probe.inventory.slot("pocket:2") != null and probe.inventory.slot("hotbar:0") == null,
		"A second real click transfers the item into the empty pocket")
	check(probe.inventory_hud.selected.is_empty(), "Transfer clears the selection")
	await click(probe.inventory_hud.slots["pocket:0"])
	await click(probe.inventory_hud.slots["pocket:2"])
	check(probe.inventory.slot("pocket:0")["id"] == "food" and probe.inventory.slot("pocket:2")["id"] == "water",
		"Clicking two occupied slots swaps their stacks Minecraft-style")
	var pack_button: Button = null
	for child in probe.inventory_hud.backpack_row.get_children():
		if child is Button and child.text.contains("1 ур."):
			pack_button = child
	check(pack_button != null, "Test backpack buttons are offered without a backpack")
	await click(pack_button)
	check(probe.inventory.has_backpack() and probe.inventory.page_count() == 1, "A real click equips the level one test backpack")
	await frames(2)
	check(probe.inventory_hud.slots.has("backpack:14"), "Backpack page exposes fifteen slots")
	await click(probe.inventory_hud.remove_button)
	check(not probe.inventory.has_backpack(), "Remove button unequips the test backpack")
	var pack_a: Button = null
	for child in probe.inventory_hud.backpack_row.get_children():
		if child is Button and child.text.contains("10 ур. A"):
			pack_a = child
	check(pack_a != null, "Both level ten test backpacks are offered")
	await click(pack_a)
	check(probe.inventory.page_count() == 2, "Level ten test backpack opens two pages")
	await frames(2)
	var page_two: Button = probe.inventory_hud.page_row.get_child(1)
	await click(page_two)
	check(probe.inventory.current_page == 1, "A real click switches to backpack page two")
	await joy(JOY_BUTTON_X)
	check(not probe.inventory_hud.opened, "Deck X closes the inventory like B")
	await joy(JOY_BUTTON_X)
	check(probe.inventory_hud.opened and root.gui_get_focus_owner() == probe.inventory_hud.slots["hotbar:0"],
		"Reopening refocuses the first slot for the Deck path")
	await joy(JOY_BUTTON_DPAD_RIGHT)
	var moved: Control = root.gui_get_focus_owner()
	check(moved != null and moved != probe.inventory_hud.slots["hotbar:0"] and probe.inventory_hud.slots.values().has(moved),
		"D-pad right moves focus between slots")
	probe.inventory_hud.slots["pocket:2"].grab_focus()
	var y_press := InputEventJoypadButton.new()
	y_press.button_index = JOY_BUTTON_Y
	y_press.pressed = true
	Input.parse_input_event(y_press)
	Input.flush_buffered_events()
	await process_frame
	check(probe.inventory_hud.context_menu.visible, "Deck Y opens the context menu on the focused slot")
	await joy(JOY_BUTTON_B)
	check(probe.inventory_hud.opened and not probe.inventory_hud.context_menu.visible, "B closes the context menu before the inventory")
	check(probe.inventory_hud.slots["pocket:2"].has_focus(), "Closing the context returns focus to its slot")
	await joy(JOY_BUTTON_B)
	check(not probe.inventory_hud.opened, "Second B closes the inventory")
	probe._reset()
	await frames(2)
	for display: Vector2i in [Vector2i(1280, 720), Vector2i(1280, 800)]:
		root.size = display
		probe.size = display
		await frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(display))
		check(screen.encloses(probe.inventory_hud.toolbar.get_global_rect()), "Inventory toolbar fits the target display")
		check(probe.inventory_hud.toolbar.get_global_rect().position.y >= probe.needs_hud.get_global_rect().end.y,
			"Expanded needs and pickup controls do not overlap")
		await key(KEY_B)
		check(screen.encloses(probe.inventory_hud.close_button.get_global_rect())
			and screen.encloses(probe.inventory_hud.status.get_global_rect()), "Inventory actions fit 16:9 and Deck 16:10")
		await key(KEY_B)
	probe.queue_free()
	await process_frame
	print("Inventory tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
