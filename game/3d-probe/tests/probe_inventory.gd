extends SceneTree

const Inventory = preload("res://scripts/probe_inventory.gd")
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
	var inventory := Inventory.new()
	check(inventory.hotbar.size() == 5 and inventory.pockets.size() == 5, "Base inventory has exactly five hotbar and five pocket slots")
	check(not inventory.has_backpack() and inventory.page_count() == 0, "No backpack storage exists without equipment")
	check(inventory.transfer("hotbar:0", "pocket:2"), "Whole item transfers into an empty slot")
	check(inventory.slot("hotbar:0") == null and inventory.slot("pocket:2") != null, "Transfer clears source only after target accepts item")
	check(inventory.transfer("pocket:2", "pocket:0"), "Occupied target swaps stacks Minecraft-style")
	check(inventory.slot("pocket:0")["id"] == "food" and inventory.slot("pocket:2")["id"] == "water",
		"Swap exchanges both stacks in place without losses")
	inventory.equip_test_backpack("level_1_test")
	check(inventory.page_count() == 1 and inventory.has_backpack(), "Level one test backpack unlocks one large page")
	inventory.equip_test_backpack("level_10_a_test")
	check(inventory.page_count() == 2, "First level ten backpack unlocks a second page")
	inventory.equip_test_backpack("level_10_b_test")
	check(inventory.page_count() == 2, "Second level ten backpack unlocks a second page")
	var before_weight := inventory.total_weight()
	check(before_weight > 0 and before_weight <= Inventory.MAX_WEIGHT_KG, "Weight is shared and starts within the common eighty kilogram cap")
	var dropped = inventory.remove_one("pocket:2")
	check(dropped != null and dropped["count"] == 1, "Removing one item prepares exactly one ground stack")
	check(inventory.restore_one("pocket:2", dropped), "Failed ground spawn can restore the original slot atomically")
	print("Probe inventory tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
