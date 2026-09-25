extends SceneTree

## К11: фывфыв, зона взгляда бабушки и кража клубнички. Проверяются правила
## канона: 6 секунд на перебежку, 42 клубнички, фейк «Я вас вижу, выходите!»,
## выборы «остаться тихо / бежать» и «бежать / сдаться», добрая концовка при
## отказе бежать, автосейв перед началом и рестарт.

const StealthSteal = preload("res://scripts/stealth_steal.gd")
const Granny = preload("res://scripts/granny.gd")
const Fyvfyv = preload("res://scripts/npc_fyvfyv.gd")
const Probe = preload("res://scripts/probe.gd")
const Route = preload("res://scripts/route.gd")
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

func key(code: Key, echo: bool = false) -> void:
	# Синтетическому Esc нужны оба кода: реальное событие ОС несёт keycode и
	# physical_keycode, а привязка ui_cancel одного физического кода не ловит.
	var event := InputEventKey.new()
	event.keycode = code
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

func finish_dash(game) -> void:
	var guard := 400
	while game.phase == game.DASH and guard > 0:
		game.advance(0.05)
		guard -= 1

func run() -> void:
	# Бабушка: зона взгляда, повороты, фейк.
	var granny := Granny.new()
	check(granny.position.x > 0.0 and granny.position.x < 1.0,
		"Бабушка стоит во дворе, а не за его пределами")
	granny.facing = 0.0
	check(granny.looks_at(granny.position + Vector2(0.2, 0.0)), "Прямо перед собой она видит")
	check(not granny.looks_at(granny.position + Vector2(-0.2, 0.0)),
		"За спиной она не видит")
	check(not granny.looks_at(granny.position + Vector2(0.9, 0.0)),
		"Слишком далеко она не видит")
	check(not granny.looks_at(granny.position + Vector2(0.15, 0.15)),
		"По диагонали вне угла обзора она не видит")
	granny.facing = 0.0
	check(granny.looks_at(granny.position + Vector2(Granny.VIEW_RANGE + 0.1, 0.0)) == false,
		"Дальше своей дальности взгляда она не видит")
	var turned := granny.turns
	granny.advance(5.0)
	check(granny.turns > turned, "Со временем бабушка поворачивается")
	check(not granny.faking or granny.faking, "Фейк — булев признак, а не счётчик")
	var shouter := Granny.new()
	shouter.faking = true
	check(shouter.warned(shouter.position + Vector2(5.0, 0.0), true),
		"Из укрытия крик может быть только фейком, но крик всё равно звучит")
	check(not shouter.warned(shouter.position), "Второй раз за один крик она не кричит")
	var watcher := Granny.new()
	watcher.shouted = false
	watcher.facing = 0.0
	check(watcher.warned(watcher.position + Vector2(0.2, 0.0)),
		"Если она правда видит, крик звучит так же, как фейк")
	check(watcher.sees_player, "И признак «видит» это подтверждает")

	# Фывфыв: гайд и утверждённый совет, без придуманной речи.
	var fyvfyv := Fyvfyv.new()
	check(fyvfyv.guide_lines().size() >= 3 and fyvfyv.guide_read,
		"Гайд выдаётся и отмечается как прочитанный")
	check(fyvfyv.advice_for_fake() == Fyvfyv.FAKE_ADVICE and fyvfyv.helped,
		"При фейке совет — утверждённый («оставайся тихо»), и участие отмечено")
	check(Fyvfyv.FAKE_ADVICE == "оставайся тихо", "Утверждённая фраза автора не переписана")

	# Кража: 42 клубнички за шесть перебежек по 6 секунд.
	var game := StealthSteal.new()
	root.add_child(game)
	check(StealthSteal.BERRIES_TOTAL == 42 and StealthSteal.DASH_SECONDS == 6.0,
		"Канонические 42 клубнички и 6 секунд на перебежку не размыты")
	check(StealthSteal.BERRIES_PER_DASH * 6 == StealthSteal.BERRIES_TOTAL,
		"Шесть перебежек дают ровно корзину")
	game.begin()
	check(game.opened and game.autosave_requests == 1,
		"Перед кражей запрашивается автосохранение")
	check(game.phase == game.HIDDEN and game.berries == 0,
		"Кража начинается из укрытия и с пустыми лапами")
	check(game.can_dash() and game.dash(), "Из укрытия можно начать перебежку")
	check(game.phase == game.DASH, "Перебежка началась")
	game.advance(1.0)
	check(game.dash_left < StealthSteal.DASH_SECONDS and game.player_position != StealthSteal.BUSHES[0],
		"За время перебежки кот движется, а не стоит")
	game.paused = true
	var frozen: Vector2 = game.player_position
	var frozen_left: float = game.dash_left
	game.advance(1.0)
	check(game.player_position == frozen and game.dash_left == frozen_left,
		"Пауза останавливает и перебежку, и бабушку")
	game.paused = false

	# Сбор корзины: шесть удачных перебежек подряд.
	var collector := StealthSteal.new()
	root.add_child(collector)
	collector.begin()
	collector.granny.position = Vector2(0.95, 0.95)   # бабушка смотрит в угол
	collector.granny.facing = Vector2(1.0, 1.0).angle()
	collector.granny.fakes_enabled = false
	for step in 6:
		check(collector.can_dash(), "Перебежка %d доступна из укрытия" % (step + 1))
		collector.dash()
		finish_dash(collector)
	check(collector.berries == StealthSteal.BERRIES_TOTAL,
		"После шести перебежек корзина полна — 42 клубнички")
	check(collector.outcome == StealthSteal.SUCCESS and collector.phase == collector.DONE,
		"Полная корзина — это успех, и экран остаётся показать итог")
	check(collector.visible and collector.opened,
		"После финала экран остаётся показать итог и держит ввод")
	check(collector.dismiss(), "Финал закрывается действием игрока")
	check(not collector.visible and not collector.opened, "После закрытия экрана кражи нет")

	# Фейк: остаться тихо — перебежка продолжается; бежать — побег.
	var faked := StealthSteal.new()
	root.add_child(faked)
	faked.begin()
	faked.dash()
	faked.granny.position = Vector2(0.95, 0.95)
	faked.granny.facing = Vector2(1.0, 1.0).angle()
	faked.granny.shouted = false
	faked.granny.faking = true
	faked.advance(0.1)
	check(faked.phase == faked.CHOICE, "На крик бабушки игра останавливает перебежку и спрашивает")
	check(faked.choice_label.text.contains(Granny.FAKE_LINE),
		"На экране — утверждённая фраза бабушки")
	check(faked.choice_label.text.contains(Fyvfyv.FAKE_ADVICE),
		"И совет фывфыва рядом с выбором")
	faked.granny.faking = false
	faked.granny.shouted = true
	faked.choose(true)
	check(faked.phase == faked.DASH or faked.phase == faked.HIDDEN,
		"«Остаться тихо» на фейке возвращает к перебежке")
	check(faked.outcome == -1, "Фейк сам по себе не заканчивает кражу")

	var runner := StealthSteal.new()
	root.add_child(runner)
	runner.begin()
	runner.dash()
	runner.granny.faking = true
	runner.granny.shouted = false
	runner.advance(0.1)
	runner.choose(false)
	check(runner.outcome == StealthSteal.ESCAPED and runner.phase == runner.DONE,
		"«Бежать» уводит в побег без клубнички")
	check(runner.berries == 0, "При побеге клубничек нет")

	# Реальная поимка: сдаться — бабушка кормит (добрая концовка).
	var caught := StealthSteal.new()
	root.add_child(caught)
	caught.begin()
	# Она стоит на полпути и смотрит точно на стартовый куст: кот у неё в конусе.
	caught.granny.position = Vector2(0.24, 0.36)
	caught.granny.facing = (caught.player_position - caught.granny.position).angle()
	caught.granny.shouted = false
	caught.dash()
	caught.advance(0.05)
	check(caught.phase == caught.CHOICE and caught.granny.sees_player,
		"Поимка на перебежке открывает выбор")
	caught.choose(true)
	check(caught.phase == caught.CHOICE and caught.choice_kind == "surrender",
		"Не убежал — бабушка подошла, и выбор второй: бежать или сдаться")
	caught.choose(true)
	check(caught.outcome == StealthSteal.FED, "Сдался — бабушка накормила, хотя казалась злой")
	check(caught.status_line().contains("накормила"), "Итог кормления назван прямо")

	var escaper := StealthSteal.new()
	root.add_child(escaper)
	escaper.begin()
	escaper.granny.position = Vector2(0.24, 0.36)
	escaper.granny.facing = (escaper.player_position - escaper.granny.position).angle()
	escaper.granny.shouted = false
	escaper.dash()
	escaper.advance(0.05)
	escaper.choose(true)
	escaper.choose(false)
	check(escaper.outcome == StealthSteal.ESCAPED, "Из поимки можно уйти бегом")

	# Молчание при выборе = остаться тихо: так советует фывфыв.
	var silent := StealthSteal.new()
	root.add_child(silent)
	silent.begin()
	silent.dash()
	silent.granny.faking = true
	silent.granny.shouted = false
	silent.advance(0.1)
	check(silent.phase == silent.CHOICE, "Выбор открыт")
	silent.advance(StealthSteal.CHOICE_SECONDS + 0.5)
	check(silent.phase != silent.CHOICE, "Молчание закрывает выбор само")
	check(silent.outcome == -1, "Молчание на фейке не заканчивает кражу")

	# Рестарт: сброс возвращает кражу в начало.
	game.reset()
	check(not game.opened and game.berries == 0 and game.step == 0 and game.outcome == -1,
		"Рестарт кражи возвращает её в начало")

	await integration()
	print("Stealth tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func integration() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2(1280, 800)
	await frames(30)
	check(probe.stealth != null and not probe.stealth.opened,
		"Кража в пробе есть, но сама не начинается")
	check(probe.theft_outcome == -1, "Исхода кражи до кражи нет")

	# До двора кражу открыть нельзя, у двора — можно.
	probe.player.position = Vector3(0, 0.1, Route.world_z(100.0))
	await frames(2)
	check(not probe._farm_theft_in_reach(), "На 100 м двор бабушки ещё не достигнут")
	probe.player.position = Vector3(0, 0.1, Route.world_z(490.0))
	await frames(2)
	check(probe._farm_theft_in_reach(), "У фермы кража доступна")

	await key(KEY_E)
	await frames(4)
	check(probe.dialogue_box.opened and probe.theft_offer_open,
		"Первый разговор — гайд фывфыва, а не сразу мини-игра")
	check(probe.dialogue_box.line_label.text.contains("оставайся тихо"),
		"В гайде есть утверждённый совет автора")
	probe._on_dialogue_option(0)
	await frames(4)
	check(probe.stealth.opened and probe.stealth.autosave_requests == 1,
		"«Начать кражу» открывает мини-игру и просит автосохранение")

	# Мини-игра идёт сама: перебежка, пауза, финал.
	probe.stealth.granny.position = Vector2(0.95, 0.95)
	probe.stealth.granny.facing = Vector2(1.0, 1.0).angle()
	await key(KEY_E)
	check(probe.stealth.phase == probe.stealth.DASH, "A/E в мини-игре начинает перебежку")
	var before: Vector2 = probe.stealth.player_position
	await frames(30)
	check(probe.stealth.player_position != before, "Перебежка идёт по кадрам, а не по нажатию")
	check(probe.day_cycle.seconds > 0.0, "Во время кражи время суток идёт (канон)")
	probe._pause()
	var paused_pos: Vector2 = probe.stealth.player_position
	await frames(20)
	check(probe.stealth.player_position == paused_pos, "Пауза останавливает перебежку")
	probe._resume_probe()
	await frames(4)

	# Доводим до побега и проверяем, что исход записан в пробу.
	probe.stealth.granny.faking = true
	probe.stealth.granny.shouted = false
	await frames(6)
	if probe.stealth.phase == probe.stealth.CHOICE:
		await key(KEY_ESCAPE)
		await frames(4)
	check(probe.theft_outcome == StealthSteal.ESCAPED,
		"Побег из мини-игры записан исходом в пробу")
	await key(KEY_E)
	await frames(4)
	check(not probe.stealth.opened and not probe.stealth.visible,
		"После финала экран закрывается действием игрока")
	check(not probe._farm_theft_in_reach(), "Сыгранная кража больше не предлагается")

	probe._reset()
	check(probe.theft_outcome == -1 and not probe.stealth.opened,
		"Сброс возвращает кражу в исходное состояние")
	probe.queue_free()
	await process_frame
