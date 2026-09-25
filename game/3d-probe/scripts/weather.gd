extends RefCounted
## К10: погода пролога.
##
## Канон (решение автора 06.09.2026): дождь в прологе даёт усталость, болезни в
## прологе нет; спасают укрытие и зонтик; дождь приходит постепенно, но бывает и
## внезапный сильный. Сколько именно усталости даёт дождь и как часто он меняется —
## технические числа до решения автора, как и остальные параметры пробы.

const DRY := 0.0                        # сухо
const RAIN := 0.55                      # установившийся дождь
const DOWNPOUR := 1.0                   # ливень

const RAMP_UP := 0.055                  # мокнем постепенно: до полного дождя ≈ 18 с
const RAMP_DOWN := 0.035                # сохнем медленнее, чем мокнем
const SUDDEN_RAMP := 0.35               # внезапный ливень набирает силу ≈ 3 с

const CHANGE_EVERY := Vector2(45.0, 110.0)   # как часто погода пересматривается
const FATIGUE_AT_FULL_RAIN := 0.55           # усталость в секунду под ливнем
const UMBRELLA_PROTECTION := 0.65            # зонтик снимает часть усталости

var intensity := DRY                    # 0 — сухо, 1 — ливень
var target := DRY
var shelter := false                    # игрок под крышей
var umbrella := false                   # зонтик в лапах
var randomness := true                  # в автотестах выключается
var until_change := 0.0
var ramp := RAMP_UP                      # текущая скорость набора/схода
var rng := RandomNumberGenerator.new()

func _init() -> void:
	reset()

func reset(seed_value: int = 20260919) -> void:
	intensity = DRY
	target = DRY
	shelter = false
	umbrella = false
	randomness = true
	ramp = RAMP_UP
	until_change = rng.randf_range(CHANGE_EVERY.x, CHANGE_EVERY.y)
	rng.seed = seed_value

func advance(delta: float) -> void:
	if delta <= 0:
		return
	if randomness:
		until_change -= delta
		if until_change <= 0.0:
			_pick_new_weather()
	if target > intensity:
		intensity = move_toward(intensity, target, ramp * delta)
	else:
		intensity = move_toward(intensity, target, RAMP_DOWN * delta)

func _pick_new_weather() -> void:
	until_change = rng.randf_range(CHANGE_EVERY.x, CHANGE_EVERY.y)
	ramp = RAMP_UP
	var roll := rng.randf()
	if roll < 0.60:
		target = DRY
	elif roll < 0.90:
		target = RAIN
	else:
		target = DOWNPOUR

func start_sudden() -> void:
	# Внезапный сильный дождь: цель сразу ливень, но набирает силу за пару секунд,
	# а не появляется одним кадром — поэтому скорость набора своя, SUDDEN_RAMP.
	target = DOWNPOUR
	ramp = SUDDEN_RAMP
	intensity = maxf(intensity, RAMP_UP)
	until_change = rng.randf_range(CHANGE_EVERY.x, CHANGE_EVERY.y)

func clear() -> void:
	target = DRY
	ramp = RAMP_UP
	until_change = rng.randf_range(CHANGE_EVERY.x, CHANGE_EVERY.y)

func is_raining() -> bool:
	return intensity > 0.02

func is_downpour() -> bool:
	return intensity >= DOWNPOUR - 0.02

func wetting() -> float:
	# Насколько игрок мокнет: укрытие защищает полностью, зонтик — частично.
	if shelter:
		return 0.0
	if umbrella:
		return intensity * (1.0 - UMBRELLA_PROTECTION)
	return intensity

func fatigue_per_second() -> float:
	return wetting() * FATIGUE_AT_FULL_RAIN

func status_text() -> String:
	if is_downpour():
		return "Ливень"
	if is_raining():
		return "Дождь"
	return "Ясно"
