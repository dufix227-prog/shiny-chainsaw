class_name FightState
extends RefCounted

signal won
signal lost

const PLAYER_MAX_HP := 10
const STICK_DAMAGE := 2
const ENEMY_DAMAGE := 2
const ATTACK_COOLDOWN := 0.45
const PERFECT_BLOCK_WINDOW := 0.2
const PERFECT_DODGE_WINDOW := 0.2
const PERFECT_DODGE_SLOW_SECONDS := 3.0
const DODGE_INVULNERABILITY := 0.24
const ENEMY_RECOVERY := 1.2
const TELEGRAPH_WINDOWS := {"casual": 1.2, "normal": 0.8, "hard": 0.5}
const SLOW_SPEED_FACTORS := {"casual": 0.4, "normal": 0.55, "hard": 0.7}

var active := false
var player_hp := PLAYER_MAX_HP
var enemy_hp := 0
var enemy_max_hp := 0
var difficulty := "normal"
var attack_cooldown := 0.0
var telegraph_time := 0.0
var recovery_time := 0.0
var enemy_attacking := false
var dodge_seconds := 0.0
var enemy_slow_seconds := 0.0

func begin(hp: int, selected_difficulty := "normal", starting_player_hp := PLAYER_MAX_HP) -> void:
	active = true
	player_hp = clampi(starting_player_hp, 1, PLAYER_MAX_HP)
	enemy_max_hp = hp
	enemy_hp = hp
	difficulty = selected_difficulty if TELEGRAPH_WINDOWS.has(selected_difficulty) else "normal"
	attack_cooldown = 0.0
	telegraph_time = 0.0
	recovery_time = 0.0
	enemy_attacking = false
	dodge_seconds = 0.0
	enemy_slow_seconds = 0.0

func player_attack(in_reach: bool) -> bool:
	if not active or not in_reach or attack_cooldown > 0.0:
		return false
	enemy_hp = maxi(0, enemy_hp - STICK_DAMAGE)
	attack_cooldown = ATTACK_COOLDOWN
	if enemy_hp == 0:
		active = false
		won.emit()
	return true

func player_dodge() -> Dictionary:
	if not active:
		return {}
	dodge_seconds = DODGE_INVULNERABILITY
	if enemy_attacking and telegraph_time <= PERFECT_DODGE_WINDOW:
		enemy_attacking = false
		telegraph_time = 0.0
		recovery_time = ENEMY_RECOVERY
		enemy_slow_seconds = PERFECT_DODGE_SLOW_SECONDS
		return {"event": "perfect_dodge"}
	return {"event": "dodge"}

func enemy_speed_multiplier() -> float:
	if enemy_slow_seconds <= 0.0:
		return 1.0
	var factor := float(SLOW_SPEED_FACTORS[difficulty])
	if enemy_max_hp > 10:
		factor = minf(0.85, factor + 0.1)
	return factor

func advance(delta: float, in_reach: bool, blocking: bool, block_held_seconds := 0.0) -> Dictionary:
	if not active:
		return {}
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_seconds = maxf(0.0, dodge_seconds - delta)
	enemy_slow_seconds = maxf(0.0, enemy_slow_seconds - delta)
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return {}
	if not in_reach:
		enemy_attacking = false
		telegraph_time = 0.0
		return {}
	if not enemy_attacking:
		enemy_attacking = true
		telegraph_time = float(TELEGRAPH_WINDOWS[difficulty])
		return {"event": "telegraph"}
	telegraph_time -= delta
	if telegraph_time > 0.0:
		return {}
	enemy_attacking = false
	recovery_time = ENEMY_RECOVERY
	if blocking:
		if block_held_seconds <= PERFECT_BLOCK_WINDOW:
			enemy_hp = maxi(0, enemy_hp - STICK_DAMAGE * 2)
			if enemy_hp == 0:
				active = false
				won.emit()
			return {"event": "counter"}
		return {"event": "blocked"}
	if dodge_seconds > 0.0:
		return {"event": "dodged"}
	player_hp = maxi(0, player_hp - ENEMY_DAMAGE)
	if player_hp == 0:
		active = false
		lost.emit()
	return {"event": "hit"}

func reset() -> void:
	active = false
	player_hp = PLAYER_MAX_HP
	enemy_hp = 0
	enemy_max_hp = 0
	attack_cooldown = 0.0
	telegraph_time = 0.0
	recovery_time = 0.0
	enemy_attacking = false
	dodge_seconds = 0.0
	enemy_slow_seconds = 0.0
