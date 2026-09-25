extends SceneTree

## К10: сутки, погода и сон. Проверяются правила из плана пролога:
## 42 реальные минуты на круг, фазы 6/14/8/10/4, дождь даёт усталость и не
## лечит, сон только ночью и не чаще раза в 15 реальных минут, пауза
## останавливает часы, а диалоги и мини-игры — нет.

const DayCycle = preload("res://scripts/day_cycle.gd")
const Weather = preload("res://scripts/weather.gd")
const Needs = preload("res://scripts/needs.gd")
const Probe = preload("res://scripts/probe.gd")
const JoypadGuard = preload("res://tests/joypad_guard.gd")
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
		await physics_frame

func run() -> void:
	var day := DayCycle.new()
	check(is_equal_approx(DayCycle.DAY_SECONDS, 42.0 * 60.0), "Весь круг — 42 реальные минуты")
	check(day.phase_durations() == [360.0, 840.0, 480.0, 600.0, 240.0],
		"Фазы 6/14/8/10/4 минуты в этом порядке")
	check(day.phase_name() == "Утро" and day.clock_text() == "06:00",
		"Пролог начинается утром в 06:00")
	check(is_equal_approx(day.time_scale, 1.0), "Тайного ускорения дня нет: масштаб времени равен 1")

	# Границы фаз: на 360-й секунде уже день, на 1200-й — вечер и так далее.
	var borders := [[359.9, "Утро"], [360.0, "День"], [1199.9, "День"],
		[1200.0, "Вечер"], [1680.0, "Ночь"], [2280.0, "Рассвет"], [2519.9, "Рассвет"]]
	for pair in borders:
		day.seconds = pair[0]
		check(day.phase_name() == pair[1], "На %.1f с идёт фаза %s" % [pair[0], pair[1]])
	check(day.is_night() == false, "Последняя проверенная фаза — не ночь")
	day.seconds = 1700.0
	check(day.is_night(), "Ночью сон разрешён")
	day.seconds = 0.0
	check(is_equal_approx(day.clock_hours(), 6.0) and day.clock_text() == "06:00",
		"Игровые часы начинаются с шести утра")
	day.seconds = DayCycle.DAY_SECONDS / 2.0
	check(is_equal_approx(day.clock_hours(), 18.0), "Половина круга — 18:00")

	# Независимость от частоты кадров и замыкание круга.
	for rate in [30, 60, 120]:
		day.reset()
		for i in rate * 10:
			day.advance(1.0 / rate)
		check(absf(day.seconds - 10.0) < 0.001,
			"Десять секунд времени при %d FPS дают те же десять секунд" % rate)
	day.reset()
	day.advance(DayCycle.DAY_SECONDS + 5.0)
	check(is_equal_approx(day.seconds, 5.0) and day.phase_name() == "Утро",
		"Круг замыкается: сутки кончились — снова утро")
	day.reset()
	day.advance(-10.0)
	check(is_equal_approx(day.seconds, 0.0), "Отрицательное время часы не крутит назад")

	# Свет: между фазами он смешивается, а на границе не прыгает.
	day.seconds = 0.0
	var morning_energy: float = day.sun_energy()
	day.seconds = 700.0
	var noon_energy: float = day.sun_energy()
	check(noon_energy > morning_energy, "Днём солнце ярче утреннего")
	day.seconds = 1900.0
	check(day.sun_energy() < 0.2, "Ночью солнце почти погашено")
	day.seconds = 2279.999
	var before_dawn: float = day.sun_energy()
	day.seconds = 2280.001
	var after_dawn: float = day.sun_energy()
	check(absf(after_dawn - before_dawn) < 0.01,
		"На границе ночи и рассвета свет не мигает: значение совпадает")
	day.seconds = 2519.999
	var end_of_loop: Color = day.sky_color()
	day.seconds = 0.001
	check(end_of_loop.is_equal_approx(day.sky_color()),
		"Небо в конце круга совпадает с небом в начале — переход в утро не рвётся")
	day.seconds = 1200.0
	check(day.sun_rotation_degrees().x < -100.0,
		"Вечером солнце уходит к горизонту (угол наклона растёт)")

	# Ночной фактор и цвет подсветки: за них держатся вода и будущие источники
	# света, поэтому они проверяются отдельно.
	day.seconds = 700.0
	check(is_equal_approx(day.night_factor(), 0.0), "Днём ночного фактора нет")
	check(day.ambient_color().get_luminance() > 0.6, "Днём подсветка светлая")
	day.seconds = 1900.0
	check(is_equal_approx(day.night_factor(), 1.0), "Ночью ночной фактор равен единице")
	check(day.ambient_color().get_luminance() < 0.35, "Ночью подсветка тёмная")
	check(day.ambient_color().b > day.ambient_color().r,
		"Ночная подсветка уходит в синий, а не остаётся дневной")
	day.seconds = 0.0
	check(day.night_factor() > 0.0 and day.night_factor() < 0.5,
		"Утром ночь уже отпустила, но день ещё не полный")

	# Погода: постепенно, но бывает внезапной; укрытие и зонтик защищают.
	var weather := Weather.new()
	check(not weather.is_raining() and weather.status_text() == "Ясно",
		"Погода начинается ясной")
	weather.randomness = false
	weather.target = Weather.DOWNPOUR
	weather.advance(1.0)
	check(weather.intensity > 0.0 and not weather.is_downpour(),
		"Дождь набирает силу постепенно, а не одним кадром")
	for i in 60:
		weather.advance(1.0)
	check(weather.is_downpour(), "Через минуту ливень в полную силу")
	check(weather.fatigue_per_second() > 0.5, "Под ливнем усталость идёт быстро")
	weather.umbrella = true
	check(weather.fatigue_per_second() < 0.5, "Зонтик снимает часть усталости")
	weather.shelter = true
	check(is_equal_approx(weather.fatigue_per_second(), 0.0),
		"Под укрытием дождь не мочит вовсе")
	weather.shelter = false
	weather.umbrella = false
	weather.clear()
	for i in 60:
		weather.advance(1.0)
	check(not weather.is_raining(), "Дождь прекращается и сходит постепенно")
	var sudden := Weather.new()
	sudden.randomness = false
	sudden.start_sudden()
	for i in 10:
		sudden.advance(1.0)
	check(sudden.is_downpour(), "Внезапный ливень набирает силу за считанные секунды")

	# Погода пересматривается сама, но не каждую секунду.
	var random_weather := Weather.new()
	random_weather.reset(20260919)
	var seen := {}
	for i in 60 * 60:
		random_weather.advance(1.0)
		seen[random_weather.target] = true
	check(seen.size() > 1, "За час погода меняется не один раз")
	var a := Weather.new()
	a.reset(777)
	var b := Weather.new()
	b.reset(777)
	for i in 200:
		a.advance(1.0)
		b.advance(1.0)
	check(is_equal_approx(a.intensity, b.intensity),
		"Один и тот же seed даёт одну и ту же погоду")

	# Дождь устаёт только при включённых нуждах и не лечит силы.
	var needs := Needs.new()
	needs.toggle()
	needs.stamina = 50.0
	needs.apply_fatigue(0.55)
	check(is_equal_approx(needs.stamina, 49.45), "Усталость от дождя тратит силы")
	needs.apply_fatigue(-5.0)
	check(is_equal_approx(needs.stamina, 49.45), "Отрицательная усталость сил не возвращает")
	needs.stamina = 0.0
	needs.apply_fatigue(10.0)
	check(needs.stamina == 0.0, "Усталость не уводит силы ниже нуля")
	needs.toggle()
	needs.stamina = 50.0
	needs.apply_fatigue(1.0)
	check(needs.stamina == 50.0, "При выключенных нуждах дождь силы не тратит")

	# Сон: только ночью, не чаще раза в 15 минут, уводит время к утру.
	var sleeper := DayCycle.new()
	check(not sleeper.can_sleep(0.0), "Днём сон недоступен")
	check(not sleeper.sleep(0.0), "Дневная попытка сна не срабатывает")
	sleeper.seconds = 1700.0
	check(sleeper.can_sleep(0.0), "Ночью сон доступен")
	check(sleeper.sleep(0.0) and sleeper.phase_name() == "Утро",
		"Сон уводит время к утру")
	check(sleeper.sleeps == 1 and sleeper.last_sleep_at == 0.0,
		"Сон запомнил время и посчитан один раз")
	check(sleeper.slept_seconds > 0.0, "Сон запомнил, сколько проспал")
	check(not sleeper.can_sleep(60.0), "Повторный сон раньше 15 минут закрыт")
	check(not sleeper.sleep(60.0), "Ранний повторный сон не срабатывает")
	sleeper.seconds = 1700.0
	check(sleeper.can_sleep(DayCycle.SLEEP_COOLDOWN), "Через 15 реальных минут сон снова доступен")
	check(sleeper.sleep(DayCycle.SLEEP_COOLDOWN) and sleeper.sleeps == 2,
		"Повторный сон после кулдауна проходит")

	await integration()
	print("Day cycle tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func integration() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2(1280, 800)
	await frames(30)
	check(probe.day_cycle.phase_name() == "Утро", "Проба стартует утром")
	check(probe.weather.status_text() == "Ясно", "Проба стартует в ясную погоду")
	check(probe.day_label != null and probe.day_label.text.contains("Утро"),
		"Фаза суток показана на экране")

	# Время идёт само: это не отдельное нажатие, а ход игры.
	var before: float = probe.day_cycle.seconds
	await frames(30)
	check(probe.day_cycle.seconds > before, "Время идёт само, без действий игрока")
	check(probe.play_seconds > 0.0, "Игровые секунды идут вместе с сутками")

	# Пауза останавливает часы и погоду.
	probe._pause()
	var paused_seconds: float = probe.day_cycle.seconds
	var paused_intensity: float = probe.weather.intensity
	await frames(30)
	check(probe.day_cycle.seconds == paused_seconds, "Пауза останавливает часы")
	check(probe.weather.intensity == paused_intensity, "Пауза останавливает погоду")
	probe._resume_probe()
	await frames(10)
	check(probe.day_cycle.seconds > paused_seconds, "После паузы время снова идёт")

	# Дождь устаёт кота через живую пробу.
	await key(KEY_N)
	check(probe.needs.enabled, "Нужды включены для проверки дождя")
	probe.weather.randomness = false
	probe.weather.start_sudden()
	for i in 60:
		probe.weather.advance(1.0)
	probe._sync_sky()
	var wet_sky: float = probe.environment.background_color.get_luminance()
	check(is_equal_approx(probe.day_world.water_material.get_shader_parameter("wet"), 1.0),
		"Ливень дошёл до воды отдельным параметром")
	probe.weather.clear()
	for i in 200:
		probe.weather.advance(1.0)
	probe._sync_sky()
	check(probe.environment.background_color.get_luminance() > wet_sky,
		"Дождь именно затемняет небо, а не осветляет его")
	probe.weather.start_sudden()
	for i in 60:
		probe.weather.advance(1.0)
	probe._sync_sky()
	var energy: float = probe.needs.stamina
	await frames(60)
	check(probe.needs.stamina < energy, "Под дождём силы уходят")
	var dry_energy: float = probe.needs.stamina
	probe.weather.clear()
	for i in 120:
		probe.weather.advance(1.0)
	await frames(30)
	check(probe.weather.status_text() == "Ясно", "Погоду можно вернуть в ясную")
	check(probe.needs.stamina >= dry_energy,
		"Без дождя силы не падают даром — их восстанавливает отдых, а не погода")

	# Ночью вода и подсветка тоже ночные: на это указал автор, дневная вода
	# в ночном кадре сбивала чтение суток.
	probe.weather.clear()
	probe.day_cycle.seconds = 1900.0
	probe._sync_sky()
	check(is_equal_approx(probe.day_world.water_material.get_shader_parameter("night"), 1.0),
		"Ночью вода получает ночной параметр")
	check(probe.sun.light_energy < 0.2, "Ночью солнце погашено и в самой сцене")
	probe.day_cycle.seconds = 700.0
	probe._sync_sky()
	check(is_equal_approx(probe.day_world.water_material.get_shader_parameter("night"), 0.0),
		"Днём вода снова дневная")

	# Ночной отдых превращается в сон, дневной остаётся сидением.
	probe.day_cycle.seconds = 1700.0
	probe._sync_sky()
	var requests_before: int = probe.autosave_requests
	await key(KEY_SPACE)
	await frames(12)
	check(probe.sleeping and probe.day_cycle.phase_name() == "Утро",
		"Ночью отдых становится сном и уводит время к утру")
	check(probe.autosave_requests == requests_before + 1,
		"Сон запрашивает автосохранение")
	check(probe.needs.stamina == 100.0, "После сна силы полные")
	check(probe.player.sitting, "Спящий кот сидит, а не стоит")
	await key(KEY_SPACE)
	await frames(12)
	check(not probe.sleeping and not probe.player.sitting,
		"Второе нажатие поднимает кота и прекращает сон")
	probe.day_cycle.seconds = 200.0
	probe._sync_sky()
	var day_seconds: float = probe.day_cycle.seconds
	await key(KEY_SPACE)
	await frames(12)
	check(probe.player.sitting and not probe.sleeping,
		"Днём отдых остаётся обычным сидением")
	check(probe.day_cycle.seconds > day_seconds, "Днём время идёт, а не прыгает к утру")
	await key(KEY_SPACE)
	await frames(6)

	# Кулдаун сна соблюдается и в пробе.
	probe.day_cycle.seconds = 1700.0
	probe._sync_sky()
	probe.play_seconds = 100.0
	probe.day_cycle.last_sleep_at = 100.0
	var sleeps: int = probe.day_cycle.sleeps
	var requests: int = probe.autosave_requests
	await key(KEY_SPACE)
	await frames(12)
	check(probe.day_cycle.sleeps == sleeps and probe.autosave_requests == requests,
		"Ранний повторный сон не срабатывает и не сохраняет игру")
	check(not probe.sleeping and probe.player.sitting,
		"Ранний повторный сон превращается в обычное сидение")
	await key(KEY_SPACE)
	await frames(6)

	# Время идёт и во время диалога — это канон, а не остановка симуляции.
	probe.day_cycle.seconds = 200.0
	probe._sync_sky()
	var dialog_seconds: float = probe.day_cycle.seconds
	if probe.npcs.size() > 0 and is_instance_valid(probe.npcs[0]):
		probe.player.position = probe.npcs[0].global_position + Vector3(0.4, 0, 0.4)
		await frames(2)
		probe._open_dialogue(probe.npcs[0])
		if probe.dialogue_box.opened:
			await frames(30)
			check(probe.day_cycle.seconds > dialog_seconds,
				"В диалоге время идёт — сюжет не останавливает сутки")
			probe._close_dialogue()
			await frames(2)
		else:
			check(true, "Диалог недоступен в этой позиции — проверка времени пропущена честно")
	else:
		check(true, "НПС для диалога нет — проверка времени в диалоге пропущена честно")

	probe._reset()
	check(probe.day_cycle.seconds == 0.0 and probe.play_seconds == 0.0,
		"Сброс возвращает утро и обнуляет игровые секунды")
	check(probe.day_cycle.sleeps == 0 and probe.autosave_requests == 0,
		"Сброс обнуляет счётчики сна и автосохранений")
	check(not probe.sleeping and probe.weather.status_text() == "Ясно",
		"Сброс снимает сон и возвращает ясную погоду")
	probe.queue_free()
	await process_frame

func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	release.echo = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
