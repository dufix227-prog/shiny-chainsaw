extends RefCounted
## К10: сутки пролога.
##
## Канон (решение автора 06.09.2026): весь круг — 42 реальные минуты, фазы
## утро 6 / день 14 / вечер-закат 8 / ночь 10 / рассвет 4. Переходы плавные,
## день тайно не ускоряется: время идёт, пока игра не на паузе, — и в диалогах,
## и в мини-играх оно тоже идёт, поэтому пауза здесь отдельная проверка, а не
## общая «остановка симуляции».
##
## `time_scale` существует только для автотестов: в игре он всегда 1, иначе
## это было бы то самое тайное ускорение дня.

const DAY_SECONDS := 42.0 * 60.0        # 2520 с — весь круг
const START_HOUR := 6.0                 # пролог начинается утром
const SLEEP_COOLDOWN := 15.0 * 60.0     # повторный сон не чаще раза в 15 реальных минут

# Фазы: длительность в минутах и свет на начале фазы. Свет между соседними
# границами смешивается линейно (последняя граница смыкается с первой), поэтому
# смена времени суток идёт градиентом, а не скачком.
const PHASES := [
	{"name": "Утро", "minutes": 6.0, "sun_x": -16.0, "energy": 0.55,
		"sun_color": Color("ffdcae"), "sky": Color("c6d6cf"),
		"ambient": 0.42, "ambient_color": Color("c9c3ae"), "night": 0.25},
	{"name": "День", "minutes": 14.0, "sun_x": -68.0, "energy": 0.95,
		"sun_color": Color("fff0cd"), "sky": Color("aacbd0"),
		"ambient": 0.40, "ambient_color": Color("d5e0c9"), "night": 0.0},
	{"name": "Вечер", "minutes": 8.0, "sun_x": -150.0, "energy": 0.50,
		"sun_color": Color("ff9f5a"), "sky": Color("e0a98a"),
		"ambient": 0.34, "ambient_color": Color("c99a72"), "night": 0.35},
	{"name": "Ночь", "minutes": 10.0, "sun_x": -215.0, "energy": 0.06,
		"sun_color": Color("9fb6d8"), "sky": Color("1b2233"),
		"ambient": 0.14, "ambient_color": Color("33405c"), "night": 1.0},
	{"name": "Рассвет", "minutes": 4.0, "sun_x": -24.0, "energy": 0.42,
		"sun_color": Color("ffd0c0"), "sky": Color("b9c6cf"),
		"ambient": 0.36, "ambient_color": Color("b9b3b0"), "night": 0.30},
]

const SUN_AZIMUTH := -35.0              # азимут солнца, как в текущей пробе

var seconds := 0.0                      # 0 … DAY_SECONDS; 0 — начало утра
var time_scale := 1.0                   # только для автотестов
var sleeps := 0                         # сколько раз кот спал
var last_sleep_at := -SLEEP_COOLDOWN    # игровое время последнего сна
var slept_seconds := 0.0                # сколько проспал последний сон

func _init() -> void:
	reset()

func reset() -> void:
	seconds = 0.0
	sleeps = 0
	last_sleep_at = -SLEEP_COOLDOWN
	slept_seconds = 0.0

func advance(delta: float) -> void:
	if delta <= 0:
		return
	seconds = fmod(seconds + delta * time_scale, DAY_SECONDS)
	if seconds < 0:
		seconds += DAY_SECONDS

# --- фазы -------------------------------------------------------------------

func phase_durations() -> Array:
	var list: Array = []
	for phase in PHASES:
		list.append(float(phase["minutes"]) * 60.0)
	return list

func phase_index() -> int:
	var passed := 0.0
	for i in PHASES.size():
		passed += float(PHASES[i]["minutes"]) * 60.0
		if seconds < passed:
			return i
	return 0        # ровно конец круга — снова утро

func phase_name() -> String:
	return str(PHASES[phase_index()]["name"])

func is_night() -> bool:
	return phase_name() == "Ночь"

func progress() -> float:
	# Доля пройденного внутри текущей фазы, 0…1.
	var index := phase_index()
	var start := 0.0
	for i in index:
		start += float(PHASES[i]["minutes"]) * 60.0
	var length := float(PHASES[index]["minutes"]) * 60.0
	return clampf((seconds - start) / length, 0.0, 1.0)

func clock_hours() -> float:
	# Игровые часы: 42 реальные минуты = сутки, старт в 06:00.
	return fmod(START_HOUR + seconds / DAY_SECONDS * 24.0, 24.0)

func clock_text() -> String:
	var hours := clock_hours()
	return "%02d:%02d" % [int(hours), int(round((hours - int(hours)) * 60.0)) % 60]

func status_text() -> String:
	return "%s · %s" % [phase_name(), clock_text()]

# --- свет -------------------------------------------------------------------

const TRANSITION_PART := 0.75            # доля фазы, после которой начинается переход

func _blend(key: String) -> Variant:
	# Фаза держит своё значение и переходит к следующей только в последней
	# четверти: если смешивать всю фазу целиком, «ночь» совпадает с полной
	# темнотой лишь в одной точке, а в кадр попадает полунóчное состояние.
	# На этом и потерялась ночь (замечание автора 19.09.2026).
	var index := phase_index()
	var next := (index + 1) % PHASES.size()
	var t := smoothstep(TRANSITION_PART, 1.0, progress())
	var a = PHASES[index][key]
	var b = PHASES[next][key]
	return a.lerp(b, t) if a is Color else lerpf(a, b, t)

func sun_rotation_degrees() -> Vector3:
	return Vector3(_blend("sun_x"), SUN_AZIMUTH, 0.0)

func sun_color() -> Color:
	return _blend("sun_color")

func sun_energy() -> float:
	return _blend("energy")

func sky_color() -> Color:
	return _blend("sky")

func ambient_energy() -> float:
	return _blend("ambient")

func ambient_color() -> Color:
	# Цвет подсветки тоже живой: ночью он синий, вечером тёплый, днём зелёный.
	# Отдельная кривая нужна потому, что одной яркости мало — с постоянным
	# дневным цветом ночь читается как «день в тени» (замечание автора).
	return _blend("ambient_color")

func night_factor() -> float:
	# 0 — день, 1 — глубокая ночь. Отдаётся тем, что не участвует в расчёте
	# света: воде (её шейдер unshaded) и будущим эффектам вроде костра.
	return _blend("night")

# --- сон --------------------------------------------------------------------

func can_sleep(now_seconds: float) -> bool:
	return is_night() and now_seconds - last_sleep_at >= SLEEP_COOLDOWN

func sleep(now_seconds: float) -> bool:
	# Сон ночью: время уходит до утра, кот высыпается, игра сохраняется.
	if not can_sleep(now_seconds):
		return false
	slept_seconds = DAY_SECONDS - seconds
	seconds = 0.0
	sleeps += 1
	last_sleep_at = now_seconds
	return true
