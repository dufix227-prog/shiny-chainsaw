extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const RoadEncounterData = preload("res://scripts/road_encounter_data.gd")
const RoadInteraction = preload("res://scripts/road_interaction.gd")

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
	check(RoadEncounterData.INTERACTIONS.size() == 20, "Every random, fixed, bandit, and rucksack encounter has interaction data")
	check(String(RoadEncounterData.interaction("postcat").line).begins_with("Стоять!.."), "Postcat uses the approved opening")
	check(RoadInteraction.NOTE_TEXT == "Если лес шепчет — это ветер. Если молчит — это я сплю. Персик.", "Sleepy cat note remains verbatim")
	check(RoadEncounterData.robbery_loot("bridge_goose") == "Перья", "Goose robbery loot is canonical")
	check(RoadEncounterData.robbery_loot("sleepy_cat").is_empty(), "Sleepy cat has no invented robbery loot")
	var rules := RoadInteraction.new()
	var result := rules.resolve("lamplighter", 0, false, false, false)
	check(result.message == "Нет монетки." and not result.has("complete"), "Shop rejects purchase without a coin")
	result = rules.resolve("alarm_dog", 0, false, false, false)
	check(result.message == "Нечего отдать.", "Dog cannot be fed without food")
	result = rules.resolve("hedgehog", 0, false, false, false)
	check(not result.has("complete"), "Hedgehog does not reward player before the wheel is found")
	result = rules.resolve("hedgehog", 0, false, false, true)
	check(result.item_id == "speed_apple" and result.consume == "wheel", "Wheel is exchanged for the approved speed apple")
	rules.mark_completed("hedgehog")
	check(rules.resolve("hedgehog", 0, false, false, true).get("close", false), "Completed reward cannot repeat")
	result = rules.resolve("kitten_a", 1, false, false, false)
	check(rules.kitten_choice == "kitten_b", "A nod records exactly one kitten side")
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	var wheel_slot := ""
	for drop in probe.road_pickups:
		if is_instance_valid(drop) and drop.item.id == "wheel":
			wheel_slot = drop.item.id
	check(wheel_slot == "wheel", "A collectible wheel spawns near the hedgehog")
	var postcat = probe.road_encounters.npc_by_id("postcat")
	probe._open_road_dialogue(postcat)
	probe._resolve_road_option(postcat, 0)
	check(postcat.interaction_completed, "Successful optional encounter becomes one-shot")
	check(not probe.inventory.first_slot_with_id("pie").is_empty(), "Postcat pie keeps its identity and enters the inventory as food")
	probe.player.eat_speed_apple()
	check(probe.player.apple_seconds_remaining == 180.0, "Apple starts the canonical three-minute timer")
	probe.player.movement_enabled = false
	probe.player._physics_process(1.0)
	check(probe.player.apple_seconds_remaining == 180.0, "Apple timer stops while control is paused")
	probe.player.movement_enabled = true
	probe.player._physics_process(1.0)
	check(probe.player.apple_seconds_remaining < 180.0, "Apple timer advances during active control")
	var food_before := probe.inventory.food_count()
	var drops_before := probe.dropped_items.size()
	probe._on_fight_won("bridge_goose")
	check(probe.inventory.food_count() == food_before - 1, "Forest defender outcome makes the hero lose one resource")
	check(probe.dropped_items.size() == drops_before + 1, "Resource lost after fighting the goose drops into the world")
	probe.road_interaction.mark_completed("quiet_cat")
	probe._reset()
	check(not probe.road_interaction.is_completed("quiet_cat"), "New run resets optional encounter state")
	probe.queue_free()
	await process_frame
	print("Road interaction tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
