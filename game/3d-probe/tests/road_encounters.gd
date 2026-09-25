extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
const RoadEncounterData = preload("res://scripts/road_encounter_data.gd")
const FightState = preload("res://scripts/fight_state.gd")

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

func cool_attack(fight: FightState) -> void:
	fight.advance(FightState.ATTACK_COOLDOWN, false, false)

func run() -> void:
	root.size = Vector2i(1280, 800)
	var ids := RoadEncounterData.random_ids()
	check(ids.size() == 15 and ids.duplicate().all(func(id): return ids.count(id) == 1), "Canonical random roster has fifteen unique NPCs")
	check(ids.has("kitten_a") and ids.has("kitten_b"), "Both kittens count as separate NPCs")
	check(ids.has("neighbor_dog") and ids.has("fence_chicken") and ids.has("lemonade_merchant"), "Latest three approved slots are present")
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	check(probe.inventory.slot("hotbar:1").id == "stick", "Cat starts the prologue with the canonical stick")
	var encounters = probe.road_encounters
	check(encounters.random_npcs.size() == 15, "All random road NPCs spawn")
	check(encounters.bandit != null and encounters.bandit.max_hp == 15, "Story bandit spawns separately with fifteen HP")
	var in_bounds := true
	for npc in encounters.random_npcs:
		var metres := Route.metres(npc.position)
		in_bounds = in_bounds and metres >= 109.0 and metres <= 450.0 and absf(npc.position.x) >= 2.0
	check(in_bounds, "Random NPCs stay beside the road between key scenes")
	encounters.regenerate(12345)
	var signature_a := encounters.spawn_signature()
	encounters.regenerate(54321)
	var signature_b := encounters.spawn_signature()
	check(signature_a != signature_b, "A new run changes random placements")
	encounters.regenerate(12345)
	check(encounters.spawn_signature() == signature_a, "Injected seed reproduces placements for tests")
	var fight := FightState.new()
	fight.begin(10)
	check(fight.player_hp == 10 and fight.enemy_hp == 10, "Ordinary fight starts at ten HP for both")
	check(fight.player_attack(true) and fight.enemy_hp == 8, "Starting stick deals canonical two damage")
	check(not fight.player_attack(true), "Attack cooldown prevents an immediate extra hit")
	for hit in 4:
		cool_attack(fight)
		fight.player_attack(true)
	check(not fight.active and fight.enemy_hp == 0, "Five stick hits defeat a ten-HP opponent")
	fight.begin(15)
	for hit in 8:
		fight.player_attack(true)
		cool_attack(fight)
	check(fight.enemy_hp == 0, "Bandit needs eight two-damage hits")
	fight.begin(10, "casual")
	fight.advance(0.0, true, false)
	var casual_tell := fight.telegraph_time
	fight.begin(10, "hard")
	fight.advance(0.0, true, false)
	check(casual_tell > fight.telegraph_time, "Difficulty changes the visible wind-up window")
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	var block_result := fight.advance(0.8, true, true)
	check(block_result.event == "counter" and fight.player_hp == 10, "Last-moment block prevents damage")
	check(fight.enemy_hp == 6, "Perfect block counter deals double stick damage")
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	var held_result := fight.advance(0.8, true, true, 0.8)
	check(held_result.event == "blocked" and fight.enemy_hp == 10 and fight.player_hp == 10, "Holding block early protects without a perfect counter")
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	var hit_result := fight.advance(0.8, true, false)
	check(hit_result.event == "hit" and fight.player_hp == 8, "Unblocked enemy hit deals technical two damage")
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	fight.advance(0.2, false, false)
	check(not fight.enemy_attacking and fight.player_hp == 10, "Leaving reach cancels the enemy wind-up")
	encounters.regenerate(77)
	var target = encounters.random_npcs[0]
	probe.player.global_position = target.global_position
	check(probe._attack(), "LMB action can start a fight against a road NPC")
	check(encounters.active_enemy == target and encounters.fight.enemy_hp == 8, "Runtime fight tracks the struck NPC")
	encounters.set_paused(true)
	var paused_tell: float = encounters.fight.telegraph_time
	encounters._physics_process(2.0)
	check(is_equal_approx(encounters.fight.telegraph_time, paused_tell), "Pause freezes combat and its wind-up")
	encounters.set_paused(false)
	for hit in 4:
		encounters.fight.attack_cooldown = 0.0
		encounters.try_player_attack(probe.player.global_position)
	check(target.defeated and not target.visible, "Defeated road NPC leaves the active scene")
	var food_before := probe.inventory.food_count()
	var drops_before := probe.dropped_items.size()
	probe._on_fight_lost("road_bandit")
	check(probe.inventory.food_count() == food_before - 1, "Losing drops one available resource")
	check(probe.dropped_items.size() == drops_before + 1, "Lost resource appears in the world and can be recovered")
	check(InputMap.action_get_events("attack").any(func(event): return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT), "Attack is bound to LMB")
	check(InputMap.action_get_events("block").any(func(event): return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT), "Block is bound to RMB")
	check(InputMap.action_get_events("attack").any(func(event): return event is InputEventJoypadButton and event.button_index == 10), "Attack is available on Deck R1 during combat")
	check(InputMap.action_get_events("block").any(func(event): return event is InputEventJoypadButton and event.button_index == 9), "Block is available on Deck L1 during combat")
	probe._reset()
	check(encounters.random_npcs.all(func(npc): return not npc.defeated and npc.visible), "Reset restores every random NPC")
	check(not encounters.fight.active and encounters.active_enemy == null, "Reset clears combat")
	probe.queue_free()
	await process_frame
	print("Road encounter tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
