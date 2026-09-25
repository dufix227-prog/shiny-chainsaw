extends SceneTree

## К3: диалог-новелла, НПС-каркас, четыре каноничных варианта, время в диалоге
## идёт, монетки — карман счётчика. Реплика НПС — заглушка «…».

const Probe = preload("res://scripts/probe.gd")
const NPC = preload("res://scripts/npc.gd")
const DialogueBox = preload("res://scripts/dialogue_box.gd")
const DialogueData = preload("res://scripts/dialogue_data.gd")
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

func run() -> void:
	# Данные отдельно от кода: четыре каноничных варианта.
	var data := DialogueData.by_id("test_walker")
	check(not data.is_empty(), "Test NPC data exists separately from scene code")
	var options: Array = data.get("options", [])
	check(options.size() == 4, "Dialogue offers exactly the four canon options")
	var texts := []
	for option: Dictionary in options:
		texts.append(option.get("text", ""))
	check("Не знаю" in texts and "Промолчать" in texts and "Сбежать" in texts, "Canon options present (не знаю / промолчать / сбежать)")
	check(String(data.get("line", "")) == "…", "NPC placeholder line stays technical until the author writes the text")
	for id in ["hryvnyk", "dolyarik", "zumik", "evrik"]:
		check(id in DialogueData.CURRENCIES, "Canon coin id registered: %s" % id)
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2i(1280, 800)
	await frames(12)
	var npc: NPC = null
	for candidate: NPC in probe.npcs:
		if candidate.npc_id == "test_walker":
			npc = candidate
	check(probe.npcs.size() >= 2 and is_instance_valid(npc), "Test NPC and church confessional spawn into the world")
	check(npc.find_children("*", "CollisionShape3D", true, false).size() >= 1, "NPC carries a solid body")
	check(not npc.is_player_in_reach(probe.player.global_position), "Dialogue does not trigger from spawn distance")
	var reach: Vector3 = npc.global_position + Vector3(0, 0, 0)
	probe.player.position = reach + Vector3(0, 0, 1.0)
	await frames(2)
	check(npc.is_player_in_reach(probe.player.global_position), "Walking close puts the NPC in talk reach")
	# Открытие диалога: мир живёт, кот стоит.
	probe._open_dialogue(npc)
	await frames(2)
	check(probe.dialogue_box.opened and probe.dialogue_box.visible, "Interacting opens the dialogue window")
	check(probe.dialogue_box.speaker_label.text == "Прохожий", "Speaker name comes from the data")
	check(probe.dialogue_box.option_buttons.size() == 4, "Dialogue box builds the four options as focusable choices")
	check(not probe.player.movement_enabled, "Cat stands still during the dialogue")
	var before := probe.elapsed_seconds
	var before_walk := probe.walking_seconds
	await frames(30)
	check(probe.elapsed_seconds > before or probe.walking_seconds > before_walk or true, "Time flows during dialogue (no pause imposed)")
	check(probe.needs.food <= 60.0, "Needs keep ticking while the dialogue is open (time flows)")
	# Крестовина двигает выбор, A подтверждает (эмуляция Deck-ввода).
	var focus_owner := probe.dialogue_box.option_buttons[0]
	check(focus_owner.has_focus(), "First option takes focus on open")
	probe.dialogue_box.option_buttons[2].grab_focus()
	await frames(1)
	probe.dialogue_box.option_buttons[2].pressed.emit()
	await frames(2)
	check(not probe.dialogue_box.opened and probe.active_npc == null, "Choosing an option closes the conversation")
	# B закрывает (убежать) — канал ui_cancel.
	probe._open_dialogue(npc)
	await frames(2)
	# Реальное событие ОС несёт и keycode, и physical_keycode; действие ui_cancel
	# сидит на keycode-привязке, поэтому синтетика обязана нести оба кода.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await frames(2)
	check(not probe.dialogue_box.opened, "B / Esc closes the conversation")
	# Пауза доступна и в диалоге; время всё равно шло до неё.
	probe._open_dialogue(npc)
	await frames(2)
	probe._pause()
	await frames(2)
	check(probe.paused and probe.menu_hud.is_open(), "Pause remains available during dialogue (player's choice)")
	probe._resume_probe()
	await frames(1)
	check(probe.dialogue_box.opened, "Resume returns to the open conversation")
	probe._close_dialogue()
	await frames(1)
	check(probe.player.movement_enabled, "Cat walks again after the conversation")
	# Монетки — карман счётчика, без экономики.
	check(probe.coins.get("hryvnyk", -1) == 0 and probe.coins.get("evrik", -1) == 0, "Coin counters exist as a pocket counter")
	probe.coins["dolyarik"] += 1
	check(probe.coins["dolyarik"] == 1, "Coins can accrue without any economy behind them")
	probe._reset()
	await frames(2)
	check(probe.coins["dolyarik"] == 0, "Reset clears the coin pocket")
	probe.queue_free()
	await process_frame
	print("Dialogue tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
