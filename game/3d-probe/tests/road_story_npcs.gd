extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const ProbeInventory = preload("res://scripts/probe_inventory.gd")
const RoadEncounterData = preload("res://scripts/road_encounter_data.gd")
const RoadInteraction = preload("res://scripts/road_interaction.gd")
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

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	check(RoadEncounterData.STORY_NPCS.size() == 3, "Three approved late-road story NPCs are separate from the random roster")
	var rules := RoadInteraction.new()
	var result := rules.resolve("herbalist", 0, false, false, false)
	check(result.message == "Нет монетки." and not result.has("complete"), "Herbalist rejects missing coin without consuming the encounter")
	result = rules.resolve("herbalist", 1, true, false, false)
	check(result.heal and result.consume == "food" and result.complete, "Herbalist accepts food for healing")
	rules.reset()
	result = rules.resolve("herbalist", 0, false, true, false, false, false, false, false)
	check(result.message == "Лечение не требуется." and not result.has("complete"), "Full-health player cannot waste payment on healing")
	result = rules.resolve("farm_guard", 0, false, false, false)
	check(not result.has("complete"), "Guard does not pass a player without the requested note")
	result = rules.resolve("farm_guard", 0, false, false, false, true)
	check(result.complete and not result.has("consume"), "Showing the sleepy-cat note passes the guard without surrendering it")
	rules.reset()
	result = rules.resolve("farm_guard", 1, false, false, false, false, true)
	check(result.complete and result.speaker == "Сторож фермы", "Bandage is the second valid non-consumed sign")
	result = rules.resolve("guardian_goose", 1, false, false, false)
	check(result.message == "Нет яблока." and not result.has("complete"), "Guardian goose cannot be poisoned without the speed apple")
	result = rules.resolve("guardian_goose", 1, false, false, false, false, false, true)
	check(result.damage == 15 and result.consume == "apple", "Approved apple outcome applies minus fifteen HP")
	result = rules.resolve("guardian_goose", 0, false, false, false)
	check(result.fight, "Guardian goose also offers a full fight")
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	var encounters = probe.road_encounters
	check(encounters.random_npcs.size() == 15 and encounters.story_npcs.size() == 3, "Fixed story NPCs do not change the fifteen-random-NPC limit")
	var herbalist = encounters.npc_by_id("herbalist")
	var guard = encounters.npc_by_id("farm_guard")
	var goose = encounters.npc_by_id("guardian_goose")
	check(herbalist != null and herbalist.accessory == "herb_bag", "Herbalist has the approved herb bag silhouette")
	check(guard != null and guard.accessory == "lantern", "Farm guard carries a lantern")
	check(goose != null and goose.accessory == "scar" and goose.scale.x > 1.0, "Guardian goose is visibly huge and scarred")
	check(Route.metres(herbalist.position) >= 250.0 and Route.metres(herbalist.position) <= 450.0, "Herbalist stays inside the approved 250-450 metre interval")
	check(Route.metres(guard.position) >= 250.0 and Route.metres(guard.position) <= 450.0, "Farm guard stays inside the approved 250-450 metre interval")
	check(is_equal_approx(Route.metres(goose.position), 470.0), "Guardian goose stands at the approved 470 metre point")
	encounters.player_health = 4
	probe.coins.hryvnyk = 1
	probe._resolve_road_option(herbalist, 0)
	check(encounters.player_health == 10 and probe.coins.hryvnyk == 0, "Paid herbalist treatment restores persistent road health")
	check(herbalist.interaction_completed, "Successful treatment is one-shot")
	probe._resolve_road_option(guard, 0)
	check(not guard.interaction_completed, "Failed sign check leaves the guard available")
	var note := ProbeInventory.road_item_stack("mysterious_note", "Записка")
	probe.inventory.add_to_first_free(note)
	probe._resolve_road_option(guard, 0)
	check(guard.interaction_completed and not probe.inventory.first_slot_with_id("mysterious_note").is_empty(), "Runtime sign check preserves the shown note")
	var apple := ProbeInventory.road_item_stack("speed_apple", "Яблоко +5 скорости · 3 минуты", true)
	probe.inventory.add_to_first_free(apple)
	probe._resolve_road_option(goose, 1)
	check(goose.defeated and not goose.visible, "Fifteen-point apple outcome removes the guardian goose")
	check(probe.inventory.first_slot_with_id("speed_apple").is_empty(), "Guardian goose consumes exactly one apple")
	probe._reset()
	goose = probe.road_encounters.npc_by_id("guardian_goose")
	probe.road_encounters.player_health = 6
	probe._resolve_road_option(goose, 0)
	check(probe.road_encounters.fight.active and probe.road_encounters.fight.enemy_hp == 15, "Fight option starts the guardian goose at technical fifteen HP")
	check(probe.road_encounters.fight.player_hp == 6, "Damage carries into the next road fight for herbalist healing to matter")
	probe._reset()
	check(probe.road_encounters.player_health == 10 and probe.road_encounters.npc_by_id("guardian_goose").visible, "New run restores health and all fixed story NPCs")
	probe.queue_free()
	await process_frame
	print("Road story NPC tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
