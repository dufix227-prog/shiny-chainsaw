extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const FightState = preload("res://scripts/fight_state.gd")
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
	var fight := FightState.new()
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	fight.advance(0.59, true, false)
	var dodge := fight.player_dodge()
	check(dodge.event == "dodge", "An early dash is a regular dodge")
	var dodged_hit := fight.advance(0.22, true, false)
	check(dodged_hit.event == "dodged" and fight.player_hp == 10, "Dodge invulnerability avoids the incoming hit")
	fight.begin(10, "normal")
	fight.advance(0.0, true, false)
	fight.advance(0.65, true, false)
	var perfect := fight.player_dodge()
	check(perfect.event == "perfect_dodge", "Last-moment dash becomes a perfect dodge")
	check(fight.enemy_slow_seconds == 3.0 and not fight.enemy_attacking, "Perfect dodge cancels the swing and slows for three seconds")
	var normal_slow := fight.enemy_speed_multiplier()
	fight.begin(10, "casual")
	fight.enemy_slow_seconds = 3.0
	check(fight.enemy_speed_multiplier() < normal_slow, "Casual difficulty applies stronger slow scaling")
	fight.begin(10, "hard")
	fight.enemy_slow_seconds = 3.0
	check(fight.enemy_speed_multiplier() > normal_slow, "Hard difficulty applies weaker slow scaling")
	var hard_regular := fight.enemy_speed_multiplier()
	fight.begin(15, "hard")
	fight.enemy_slow_seconds = 3.0
	check(fight.enemy_speed_multiplier() > hard_regular, "Higher-HP bandit resists more of the slow")
	fight.advance(1.0, false, false)
	check(fight.enemy_slow_seconds == 2.0, "Slow timer advances with combat")
	var rules := RoadInteraction.new()
	var fish_result := rules.resolve("road_rucksack", 0, false, false, false)
	check(fish_result.item_id == "road_fish" and fish_result.complete, "Rucksack can yield its fish")
	var bag_result := rules.resolve("road_rucksack", 1, false, false, false)
	check(bag_result.item_id == "small_rucksack" and bag_result.complete, "Rucksack can be taken whole")
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	var event = probe.road_encounters.rucksack
	check(event != null and event.visible, "Random rucksack event spawns in the world")
	var first_position: Vector3 = event.position
	probe.road_encounters.regenerate(124)
	var seeded_position: Vector3 = event.position
	probe.road_encounters.regenerate(125)
	check(event.position != seeded_position or seeded_position != first_position, "Rucksack placement changes between runs")
	var metres := Route.metres(event.position)
	var valid_slot := probe.road_encounters.EVENT_METRE_SLOTS.any(func(slot): return is_equal_approx(metres, slot))
	check(valid_slot and is_equal_approx(absf(event.position.x), 1.35), "Rucksack stays in safe roadside slots")
	var target = probe.road_encounters.random_npcs[0]
	probe.player.global_position = target.global_position
	probe.road_encounters.begin_fight(target)
	probe.road_encounters.fight.enemy_slow_seconds = 3.0
	probe.road_encounters.paused = true
	probe.road_encounters._physics_process(1.0)
	check(probe.road_encounters.fight.enemy_slow_seconds == 3.0, "Pause freezes the perfect-dodge slow timer")
	probe.road_encounters.paused = false
	probe.road_encounters.fight.enemy_slow_seconds = 0.0
	probe.needs.stamina = 100.0
	check(not probe._try_dodge("move_left"), "First directional tap only opens the double-tap window")
	check(probe._try_dodge("move_left"), "Second directional tap starts the dash")
	check(probe.needs.stamina == 88.0, "Dash spends the temporary twelve-point stamina cost")
	check(probe.player.dodge_seconds_remaining > 0.0, "Runtime cat receives visible dash movement")
	var dash_remaining: float = probe.player.dodge_seconds_remaining
	probe.player.movement_enabled = false
	probe.player._physics_process(0.1)
	check(probe.player.dodge_seconds_remaining == dash_remaining, "Pause freezes dash movement time")
	probe.player.movement_enabled = true
	probe.needs.stamina = 11.0
	probe.dodge_tap_windows["move_right"] = Probe.DODGE_DOUBLE_TAP_SECONDS
	check(not probe._try_dodge("move_right") and probe.needs.stamina == 11.0, "Insufficient stamina rejects a dash without overdraft")
	probe.road_encounters.fight.reset()
	probe.road_interaction.reset()
	event.reset_to(event.position)
	probe._open_road_event_dialogue(event)
	var food_before := probe.inventory.food_count()
	probe._resolve_road_option(event, 0)
	check(event.interaction_completed and not event.visible, "Choosing fish consumes the one-shot world event")
	check(probe.inventory.food_count() == food_before + 1, "Rucksack fish is edible inventory food")
	probe._reset()
	check(probe.road_encounters.rucksack.visible and not probe.road_encounters.rucksack.interaction_completed, "Reset restores the random rucksack")
	probe.queue_free()
	await process_frame
	print("Road dodge/event tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
