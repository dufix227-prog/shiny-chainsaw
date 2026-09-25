extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const FishingData = preload("res://scripts/fishing_data.gd")
const FishingMinigame = preload("res://scripts/fishing_minigame.gd")
const ProbeInventory = preload("res://scripts/probe_inventory.gd")

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
		await process_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	check(FishingData.FISH.size() == 15, "Canonical table contains fifteen fish")
	check(FishingData.total_chance() == 100, "Fish, coins and trash fill exactly one hundred percent")
	check(FishingData.catch_for_roll(0).name == "Плотва", "Common table starts with roach")
	check(FishingData.catch_for_roll(35).name == "Карп", "Medium table starts at thirty-five percent")
	check(FishingData.catch_for_roll(55).name == "Щука", "Rare table starts at fifty-five percent")
	check(FishingData.catch_for_roll(70, 3) == {"kind": "coins", "count": 3}, "Coins occupy the canonical fifteen-percent range")
	check(FishingData.catch_for_roll(85).name == "Сапог" and FishingData.catch_for_roll(99).name == "Ветка", "Trash occupies the final fifteen percent")
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	check(is_equal_approx(Route.metres(probe.fishing_location.position), 260.0), "Fishing dock is at the canonical 260 metres")
	check(probe.fishing_location.rod_available and probe.fishing_location.rod_model.visible, "Rod starts in the world at the lake")
	probe.player.global_position = probe.fishing_location.global_position
	probe._interact_with_fishing()
	check(not probe.fishing_location.rod_available, "First interaction takes the rod")
	check(not probe.inventory.first_slot_with_id("fishing_rod").is_empty(), "Rod is stored in inventory")
	probe._close_dialogue()
	probe._interact_with_fishing()
	check(probe.fishing_minigame.opened and probe._simulation_stopped(), "Rod and lake open the optional minigame and stop movement")
	probe.fishing_minigame.act()
	check(probe.fishing_minigame.phase == FishingMinigame.Phase.WAITING and probe.fishing_minigame.attempts == 1, "Player actively casts the rod")
	probe.fishing_minigame.act()
	check(probe.fishing_minigame.phase == FishingMinigame.Phase.READY, "Striking before a bite loses the attempt")
	probe.fishing_minigame.act()
	probe.fishing_minigame.phase_time = 0.01
	probe.fishing_minigame._process(0.02)
	check(probe.fishing_minigame.phase == FishingMinigame.Phase.HOOK, "Waiting reaches the hook phase")
	check(is_equal_approx(probe.fishing_minigame.phase_time, 4.0), "Canonical hook window lasts four seconds")
	probe.fishing_minigame.set_paused(true)
	probe.fishing_minigame._process(2.0)
	check(is_equal_approx(probe.fishing_minigame.phase_time, 4.0), "Pause freezes the hook window")
	probe.fishing_minigame.set_paused(false)
	probe.fishing_minigame.act()
	check(probe.fishing_minigame.successes == 1 and probe.fishing_minigame.phase == FishingMinigame.Phase.READY, "Hooking in time resolves one catch")
	probe.fishing_minigame.phase = FishingMinigame.Phase.HOOK
	probe.fishing_minigame.phase_time = 0.01
	probe.fishing_minigame._process(0.02)
	check(probe.fishing_minigame.phase == FishingMinigame.Phase.READY and probe.fishing_minigame.successes == 1, "Missing the four-second window loses the catch")
	probe.fishing_minigame.act()
	check(probe.fishing_minigame.attempts == 3, "Fishing has no attempt limit")
	probe.fishing_minigame.close_game()
	check(probe.player.movement_enabled, "Leaving the optional minigame restores movement")
	var rod_slot := probe.inventory.first_slot_with_id("fishing_rod")
	probe.inventory.set_slot(rod_slot, null)
	check(not probe._interact_with_fishing() and not probe.fishing_minigame.opened, "Lake alone cannot start fishing without the rod")
	var coin_before: int = probe.coins.hryvnyk
	probe._receive_fishing_catch({"kind": "coins", "count": 3})
	check(probe.coins.hryvnyk == coin_before + 3, "Coin catch awards all one-to-three coins")
	probe._receive_fishing_catch({"kind": "trash", "name": "Банка"})
	check(not probe.inventory.first_slot_with_id("fishing_trash").is_empty(), "Trash is kept without a benefit")
	probe.inventory.hotbar[0] = ProbeInventory.fish_stack("Сом", 25)
	probe.needs.enabled = true
	probe.needs.food = 50.0
	probe.inventory_hud.set_open(true)
	probe._use_inventory_slot("hotbar:0")
	check(is_equal_approx(probe.needs.food, 75.0), "Caught fish restores its canonical food value")
	probe._reset()
	check(probe.fishing_location.rod_available and probe.inventory.first_slot_with_id("fishing_rod").is_empty(), "Full reset returns the rod to the lake")
	check(not probe.fishing_minigame.opened and probe.fishing_minigame.attempts == 0, "Full reset clears fishing progress")
	for address in ["hotbar:0", "hotbar:1", "hotbar:2", "hotbar:3", "hotbar:4",
			"pocket:0", "pocket:1", "pocket:2", "pocket:3", "pocket:4"]:
		probe.inventory.set_slot(address, ProbeInventory.trash_stack("Банка"))
	probe._interact_with_fishing()
	check(probe.fishing_location.rod_available, "A full inventory leaves the rod at the lake")
	probe.queue_free()
	await process_frame
	print("Fishing tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
