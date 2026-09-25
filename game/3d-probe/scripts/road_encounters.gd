class_name RoadEncounters
extends Node3D

signal fight_won(encounter_id: String)
signal fight_lost(encounter_id: String)

const Route = preload("res://scripts/route.gd")
const RoadNPC = preload("res://scripts/road_npc.gd")
const RoadEncounterData = preload("res://scripts/road_encounter_data.gd")
const RoadEvent = preload("res://scripts/road_event.gd")
const FightState = preload("res://scripts/fight_state.gd")
const RANDOM_METRE_SLOTS := [112.0, 128.0, 145.0, 163.0, 222.0, 238.0, 272.0,
	288.0, 305.0, 335.0, 355.0, 375.0, 398.0, 420.0, 446.0]
const BANDIT_METRES := 320.0
const STORY_METRES := {"herbalist": 390.0, "farm_guard": 448.0, "guardian_goose": 470.0}
const EVENT_METRE_SLOTS := [135.0, 170.0, 215.0, 290.0, 350.0, 410.0]
const HIT_REACH := 2.6
const ENEMY_REACH := 2.1

var random_npcs: Array[RoadNPC] = []
var bandit: RoadNPC
var story_npcs: Array[RoadNPC] = []
var rucksack: RoadEvent
var player: CharacterBody3D
var fight := FightState.new()
var active_enemy: RoadNPC
var rng := RandomNumberGenerator.new()
var generation := 0
var last_message := ""
var message_seconds := 0.0
var paused := false
var block_held_seconds := 0.0
var player_health := FightState.PLAYER_MAX_HP

func _ready() -> void:
	rng.randomize()
	fight.won.connect(_on_won)
	fight.lost.connect(_on_lost)
	_build_all()
	regenerate()

func setup_player(value: CharacterBody3D) -> void:
	player = value

func _build_all() -> void:
	for data in RoadEncounterData.RANDOM_NPCS:
		var npc := RoadNPC.new()
		add_child(npc)
		npc.setup(data, Vector3.ZERO)
		random_npcs.append(npc)
	bandit = RoadNPC.new()
	add_child(bandit)
	bandit.setup(RoadEncounterData.BANDIT, Vector3(1.1, 0, Route.world_z(BANDIT_METRES)))
	for data in RoadEncounterData.STORY_NPCS:
		var npc := RoadNPC.new()
		add_child(npc)
		var id := String(data.id)
		var side := 1.1 if id == "guardian_goose" else (-2.2 if id == "herbalist" else 1.5)
		npc.setup(data, Vector3(side, 0, Route.world_z(float(STORY_METRES[id]))))
		story_npcs.append(npc)
	rucksack = RoadEvent.new()
	add_child(rucksack)
	rucksack.setup("road_rucksack", "Рюкзачок с рыбкой")

func regenerate(test_seed: int = -1) -> void:
	if test_seed >= 0:
		rng.seed = test_seed
	var slots := RANDOM_METRE_SLOTS.duplicate()
	for index in range(slots.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temp = slots[index]
		slots[index] = slots[other]
		slots[other] = temp
	for index in random_npcs.size():
		var metres := float(slots[index]) + rng.randf_range(-3.0, 3.0)
		var side := -1.0 if rng.randi() % 2 == 0 else 1.0
		random_npcs[index].reset_to(Vector3(side * rng.randf_range(2.0, 3.1), 0, Route.world_z(metres)))
	bandit.reset_to(Vector3(1.1, 0, Route.world_z(BANDIT_METRES)))
	for npc in story_npcs:
		var side := 1.1 if npc.encounter_id == "guardian_goose" else (-2.2 if npc.encounter_id == "herbalist" else 1.5)
		npc.reset_to(Vector3(side, 0, Route.world_z(float(STORY_METRES[npc.encounter_id]))))
	var event_metres := float(EVENT_METRE_SLOTS[rng.randi_range(0, EVENT_METRE_SLOTS.size() - 1)])
	var event_side := -1.0 if rng.randi() % 2 == 0 else 1.0
	rucksack.reset_to(Vector3(event_side * 1.35, 0, Route.world_z(event_metres)))
	generation += 1
	fight.reset()
	player_health = FightState.PLAYER_MAX_HP
	active_enemy = null
	last_message = ""
	message_seconds = 0.0
	block_held_seconds = 0.0

func _physics_process(delta: float) -> void:
	if paused:
		return
	if message_seconds > 0.0:
		message_seconds = maxf(0.0, message_seconds - delta)
	if not fight.active or not is_instance_valid(active_enemy) or not is_instance_valid(player):
		block_held_seconds = 0.0
		return
	active_enemy.chase(player.global_position, fight.enemy_speed_multiplier())
	var blocking := Input.is_action_pressed("block")
	block_held_seconds = block_held_seconds + delta if blocking else 0.0
	fight.advance(delta, active_enemy.distance_to_player(player.global_position) <= ENEMY_REACH,
		blocking, block_held_seconds)

func try_player_dodge() -> Dictionary:
	var result := fight.player_dodge()
	if result.get("event", "") == "perfect_dodge":
		last_message = "Идеальный уворот · враг замедлен на 3 секунды"
		message_seconds = 2.0
	return result

func event_in_reach(player_position: Vector3) -> RoadEvent:
	return rucksack if is_instance_valid(rucksack) and rucksack.is_player_in_reach(player_position) else null

func try_player_attack(player_position: Vector3) -> bool:
	if fight.active:
		if not is_instance_valid(active_enemy):
			return false
		return fight.player_attack(active_enemy.distance_to_player(player_position) <= HIT_REACH)
	var target := closest_fight_target(player_position)
	if target == null:
		return false
	active_enemy = target
	fight.begin(target.max_hp, "normal", player_health)
	last_message = "Драка: ЛКМ/R1 — палка, ПКМ/L1 — блок, двойное направление — уворот"
	message_seconds = 2.5
	return fight.player_attack(true)

func begin_fight(target: RoadNPC) -> bool:
	if fight.active or not is_instance_valid(target) or target.defeated:
		return false
	active_enemy = target
	fight.begin(target.max_hp, "normal", player_health)
	last_message = "Драка: ЛКМ/R1 — палка, ПКМ/L1 — блок, двойное направление — уворот"
	message_seconds = 2.5
	return true

func closest_interaction_target(player_position: Vector3) -> RoadNPC:
	var closest: RoadNPC
	var best := RoadNPC.REACH
	for npc in random_npcs + [bandit] + story_npcs:
		if npc.defeated or npc.interaction_completed:
			continue
		var distance: float = npc.distance_to_player(player_position)
		if distance <= best:
			best = distance
			closest = npc
	return closest

func closest_fight_target(player_position: Vector3) -> RoadNPC:
	var closest: RoadNPC
	var best := HIT_REACH
	for npc in random_npcs + [bandit] + story_npcs:
		if npc.defeated:
			continue
		var distance: float = npc.distance_to_player(player_position)
		if distance <= best:
			best = distance
			closest = npc
	return closest

func spawn_signature() -> String:
	var parts: Array[String] = []
	for npc in random_npcs:
		parts.append("%s:%.2f:%.2f" % [npc.encounter_id, npc.position.x, Route.metres(npc.position)])
	return "|".join(parts)

func npc_by_id(id: String) -> RoadNPC:
	for npc in random_npcs + [bandit] + story_npcs:
		if npc.encounter_id == id:
			return npc
	return null

func heal_player() -> void:
	player_health = FightState.PLAYER_MAX_HP
	if fight.active:
		fight.player_hp = player_health

func apply_story_damage(target: RoadNPC, damage: int) -> void:
	if is_instance_valid(target) and damage >= target.max_hp:
		target.mark_defeated()

func _on_won() -> void:
	if not is_instance_valid(active_enemy):
		return
	var id := active_enemy.encounter_id
	player_health = fight.player_hp
	active_enemy.mark_defeated()
	active_enemy = null
	last_message = "Победа"
	message_seconds = 2.0
	fight_won.emit(id)

func _on_lost() -> void:
	if not is_instance_valid(active_enemy):
		return
	var id := active_enemy.encounter_id
	player_health = FightState.PLAYER_MAX_HP
	active_enemy.reset_to(active_enemy.spawn_position)
	active_enemy = null
	last_message = "Поражение"
	message_seconds = 2.0
	fight_lost.emit(id)

func reset() -> void:
	paused = false
	regenerate()

func set_paused(value: bool) -> void:
	paused = value
