extends SceneTree

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

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2(1280, 800)
	await frames(12)
	check(probe.inventory.hotbar.size() == 5 and probe.inventory.pockets.size() == 5, "Proof UI begins with exactly five hotbar and five pocket slots")
	probe._toggle_inventory()
	await frames(2)
	check(probe.inventory_hud.opened and not probe.inventory.has_backpack(), "Proof opens without a backpack grid")
	check(not probe.inventory_hud.backpack_row.visible or probe.inventory_hud.backpack_row.get_child_count() > 0, "Backpack controls remain a test-only affordance")
	probe._inventory_slot_selected("hotbar:0")
	probe._inventory_slot_selected("pocket:2")
	check(probe.inventory.slot("hotbar:0") == null and probe.inventory.slot("pocket:2") != null, "Selecting an empty target transfers a whole item once")
	probe._inventory_context_requested("pocket:2")
	check(probe.inventory_hud.context_menu.visible, "Context menu opens for an occupied slot")
	probe._drop_inventory_slot("pocket:2")
	await process_frame
	await frames(2)
	check(probe.inventory.slot("pocket:2")["count"] == 1 and probe.dropped_items.size() == 1, "Drop creates one world item and removes exactly one from the stack")
	var drop = probe.dropped_items[0]
	probe.player.position = drop.global_position
	probe._collect_dropped_item()
	check(probe.dropped_items.is_empty() and probe.inventory.food_count() == 2, "Dropped food is picked up once into a free inventory slot")
	probe._equip_test_backpack("level_1_test")
	check(probe.inventory.page_count() == 1, "Level one test backpack unlocks one large page")
	probe._equip_test_backpack("level_10_a_test")
	check(probe.inventory.page_count() == 2, "First level ten test backpack unlocks page two")
	probe._equip_test_backpack("level_10_b_test")
	check(probe.inventory.page_count() == 2, "Second level ten test backpack unlocks page two")
	var first_weight := probe.inventory.total_weight()
	probe._set_backpack_page(1)
	check(is_equal_approx(probe.inventory.total_weight(), first_weight), "Both backpack pages share one total weight")
	probe.queue_free()
	await process_frame
	print("Inventory proof tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
