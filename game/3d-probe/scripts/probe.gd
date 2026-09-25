extends Control

const World = preload("res://scripts/world.gd")
const Cat = preload("res://scripts/cat.gd")
const Route = preload("res://scripts/route.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Needs = preload("res://scripts/needs.gd")
const DayCycle = preload("res://scripts/day_cycle.gd")
const Weather = preload("res://scripts/weather.gd")
const NeedsHUD = preload("res://scripts/needs_hud.gd")
const FoodPickup = preload("res://scripts/food_pickup.gd")
const InventoryHUD = preload("res://scripts/inventory_hud.gd")
const MenuHUD = preload("res://scripts/menu_hud.gd")
const ProbeInput = preload("res://scripts/probe_input.gd")
const ProbeAudio = preload("res://scripts/probe_audio.gd")
const FullMapHUD = preload("res://scripts/full_map_hud.gd")
const ProbeInventory = preload("res://scripts/probe_inventory.gd")
const DroppedInventoryItem = preload("res://scripts/dropped_inventory_item.gd")
const NPC = preload("res://scripts/npc.gd")
const StintNPC = preload("res://scripts/npc_stint.gd")
const BratishkinNPC = preload("res://scripts/npc_bratishkin.gd")
const DialogueBox = preload("res://scripts/dialogue_box.gd")
const DialogueData = preload("res://scripts/dialogue_data.gd")
const IntroSequence = preload("res://scripts/intro_sequence.gd")
const MimeTutorial = preload("res://scripts/mime_tutorial.gd")
const StreamMinigame = preload("res://scripts/stream_minigame.gd")
const PigMinigame = preload("res://scripts/pig_minigame.gd")
const PigFollow = preload("res://scripts/pig_follow.gd")
const VtuberRoom = preload("res://scripts/vtuber_room.gd")
const SuperPig = preload("res://scripts/super_pig.gd")
const EndingScreen = preload("res://scripts/ending_screen.gd")
const LocationFishing = preload("res://scripts/location_fishing.gd")
const FishingMinigame = preload("res://scripts/fishing_minigame.gd")
const StealthSteal = preload("res://scripts/stealth_steal.gd")
const Fyvfyv = preload("res://scripts/npc_fyvfyv.gd")
const RoadEncounters = preload("res://scripts/road_encounters.gd")
const RoadNPC = preload("res://scripts/road_npc.gd")
const RoadEvent = preload("res://scripts/road_event.gd")
const RoadEncounterData = preload("res://scripts/road_encounter_data.gd")
const RoadInteraction = preload("res://scripts/road_interaction.gd")
const FightHUD = preload("res://scripts/fight_hud.gd")
const DebugHUD = preload("res://scripts/debug_hud.gd")
const RENDER_HEIGHTS := [400, 720, 1080]
const DODGE_DOUBLE_TAP_SECONDS := 0.3
const DODGE_STAMINA_COST := 12.0
const DODGE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var player: CharacterBody3D
var camera := Camera3D.new()
var route := Route.new()
var map: Control
var metres_label: Label
var camera_button: Button
var quality_button: Button
var quality_index := 1
var world_viewport := SubViewport.new()
var perspective := false
var target := Vector3.ZERO
var report_time := 0.0
var canvas: TextureRect
var needs := Needs.new()
var day_cycle := DayCycle.new()
var weather := Weather.new()
var sun: DirectionalLight3D
var environment: Environment
var day_world: Node3D
var day_label: Label
var sleeping := false
var play_seconds := 0.0
var autosave_requests := 0
var capture_path := ""
var capture_frames := 0
var needs_hud: PanelContainer
var debug_hud: Control
var paused := false
var walking_seconds := 0.0
var elapsed_seconds := 0.0
var timing_started := false
var timing_finished := false
var time_label: Label
var pickup := FoodPickup.new()
var inventory_hud: Control
var menu_hud: MenuHUD
var full_map_hud: FullMapHUD
var inventory := ProbeInventory.new()
var dropped_items: Array = []
var road_pickups: Array = []
var selected_inventory_slot := ""
var audio: ProbeAudio
var camera_index := 0
var started := false
var cat_name := "Кот"
var npcs: Array = []
var active_npc: NPC = null
var beggar_hint_given := false
var stint_line_index := 0
var stint_help_accepted := false
var bratishkin_line_index := 0
var bratishkin_stream_completed := false
var bratishkin_stream_success := false
var folder_found := false
var pig_work_completed := false
var basement_offer_resolved := false
var basement_line_index := 0
var selected_vtuber := ""
var stint_report_resolved := false
var bratishkin_locked := false
var vtuber_stolen := false
var vtuber_waiting_at_stint := false
var previous_route_metres := 0.0
var moderator_offer_open := false
var moderator_offer_resolved := false
var dialogue_box: DialogueBox
var intro_sequence: Node
var mime: MimeTutorial
var mime_hint_label: Label
var stream_minigame: StreamMinigame
var pig_minigame: PigMinigame
var stolen_pig: PigFollow
var vtuber_room: VtuberRoom
var super_pig: SuperPig
var ending_screen: EndingScreen
var fishing_location: LocationFishing
var fishing_minigame: FishingMinigame
var stealth: StealthSteal
var fyvfyv := Fyvfyv.new()
## Исход кражи для будущих сцен К12: 0 — корзина, 1 — побег, 2 — кормление; -1 — ещё не было.
var theft_outcome := -1
var theft_offer_open := false
## Откуда открывается двор бабушки: место кражи — конец маршрута, 500 м.
const FARM_THEFT_METRES := 480.0
var road_encounters: RoadEncounters
var road_interaction := RoadInteraction.new()
var active_road_npc: RoadNPC
var active_road_event: RoadEvent
var dodge_tap_windows := {}
var fight_hud: FightHUD
# К3: монетки канона — карман счётчика без экономики.
var coins := {"hryvnyk": 0, "dolyarik": 0, "zumik": 0, "evrik": 0}

func _ready() -> void:
	ProbeInput.install()
	canvas = TextureRect.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_viewport)
	canvas.texture = world_viewport.get_texture()
	resized.connect(_resize_world)
	_resize_world()
	var world := World.new()
	world_viewport.add_child(world)
	day_world = world
	var environment_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("aacbd0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e0c9")
	environment.ambient_light_energy = 0.4
	environment_node.environment = environment
	world.add_child(environment_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff0cd")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45
	world.add_child(sun)
	player = Cat.new()
	world.add_child(player)
	player.stepped.connect(_on_step)
	road_encounters = RoadEncounters.new()
	road_encounters.setup_player(player)
	road_encounters.fight_lost.connect(_on_fight_lost)
	road_encounters.fight_won.connect(_on_fight_won)
	world.add_child(road_encounters)
	_spawn_road_wheel(world)
	intro_sequence = IntroSequence.new()
	intro_sequence.finished.connect(_finish_intro)
	world.add_child(intro_sequence)
	world.add_child(pickup)
	_spawn_npcs(world)
	_spawn_mime(world)
	stolen_pig = PigFollow.new()
	world.add_child(stolen_pig)
	super_pig = SuperPig.new()
	world.add_child(super_pig)
	fishing_location = LocationFishing.new()
	world.add_child(fishing_location)
	world.add_child(camera)
	camera.current = true
	camera.far = 160
	target = Vector3(0, 0.8, player.position.z - 2)
	_set_camera()
	_build_ui()
	audio = ProbeAudio.new()
	add_child(audio)
	stream_minigame = StreamMinigame.new()
	stream_minigame.finished.connect(_finish_stream)
	add_child(stream_minigame)
	pig_minigame = PigMinigame.new()
	pig_minigame.finished.connect(_finish_pig_work)
	add_child(pig_minigame)
	vtuber_room = VtuberRoom.new()
	vtuber_room.chosen.connect(_choose_vtuber)
	add_child(vtuber_room)
	ending_screen = EndingScreen.new()
	ending_screen.quit_requested.connect(_quit_after_credits)
	add_child(ending_screen)
	fishing_minigame = FishingMinigame.new()
	fishing_minigame.caught.connect(_receive_fishing_catch)
	fishing_minigame.closed.connect(_refresh_needs)
	add_child(fishing_minigame)
	stealth = StealthSteal.new()
	stealth.finished.connect(_finish_theft)
	add_child(stealth)
	fight_hud = FightHUD.new()
	fight_hud.setup(road_encounters)
	add_child(fight_hud)
	_refresh_needs()
	capture_path = OS.get_environment("PROBE_CAPTURE")
	menu_hud.show_start()
	if DisplayServer.get_name() == "headless" or capture_path != "":
		# Автотесты идут по прежнему сценарию; у автора «Начать пробу» открывает
		# экран имени (С1). Имя по умолчанию — техническая замена, сюжетных
		# текстов нет. Кадр для проверки (PROBE_CAPTURE) тоже минует меню.
		_start_probe()
		cat_name = "Кот"
	_apply_capture_setup()

static func render_size(display_size: Vector2, height: int) -> Vector2i:
	return Vector2i(maxi(1, roundi(height * display_size.x / maxf(display_size.y, 1))), height)

func _resize_world() -> void:
	world_viewport.size = render_size(size, RENDER_HEIGHTS[quality_index])
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if quality_index == 0 else CanvasItem.TEXTURE_FILTER_LINEAR

func _cycle_quality() -> void:
	quality_index = (quality_index + 1) % RENDER_HEIGHTS.size()
	_resize_world()
	quality_button.text = "Q · %dp" % RENDER_HEIGHTS[quality_index]
	quality_button.release_focus()

func _unhandled_input(event: InputEvent) -> void:
	# Отладочная панель переключается везде, включая меню, — технический
	# инструмент приёмки, не игровой экранный шорткат.
	if event is InputEventKey and event.pressed and not event.is_echo() \
			and event.physical_keycode == KEY_F3:
		if is_instance_valid(debug_hud):
			debug_hud.toggle()
		return
	if menu_hud.is_open():
		if (menu_hud.mode == MenuHUD.START or menu_hud.mode == MenuHUD.NAME) \
				and event.is_action_pressed("pause_probe") and not event.is_echo():
			return
		if menu_hud.mode == MenuHUD.PAUSE and event.is_action_pressed("pause_probe") and not event.is_echo():
			_resume_probe()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(ending_screen) and ending_screen.opened:
		get_viewport().set_input_as_handled()
		return
	if full_map_hud.opened:
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(vtuber_room) and vtuber_room.opened:
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(fishing_minigame) and fishing_minigame.opened:
		if event.is_action_pressed("pause_probe") and not event.is_echo():
			_pause()
		elif event.is_action_pressed("ui_cancel") and not event.is_echo():
			fishing_minigame.close_game()
			_refresh_needs()
		elif (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")) and not event.is_echo():
			fishing_minigame.act()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(pig_minigame) and pig_minigame.opened:
		if event.is_action_pressed("pause_probe") and not event.is_echo():
			_pause()
		elif (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")) and not event.is_echo():
			pig_minigame.act()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(stealth) and stealth.opened:
		# Кража: A/E — перебежка или «остаться тихо», B — «бежать». После
		# финала тем же A/E экран закрывается, исход уже записан.
		if event.is_action_pressed("pause_probe") and not event.is_echo():
			_pause()
		elif event.is_action_pressed("ui_cancel") and not event.is_echo():
			if stealth.phase == stealth.CHOICE:
				stealth.choose(false)
			else:
				stealth.dismiss()
		elif (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")) and not event.is_echo():
			if stealth.phase == stealth.CHOICE:
				stealth.choose(true)
			elif stealth.phase == stealth.DONE:
				stealth.dismiss()
			else:
				stealth.dash()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(stream_minigame) and stream_minigame.opened:
		if event.is_action_pressed("pause_probe") and not event.is_echo():
			_pause()
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			stream_minigame.react()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(dialogue_box) and dialogue_box.opened:
		# B/Esc закрывает через сам бокс; A активирует сфокусированный вариант
		# через ui_accept; крестовина двигает фокус через ui_up/ui_down.
		# Остальные мировые действия гасим. Пауза прошла ветку выше — время в
		# диалогах идёт (канон), пауза остаётся выбором игрока.
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			_close_dialogue()
		get_viewport().set_input_as_handled()
		return
	if inventory_hud.opened:
		if event.is_action_pressed("inventory_close") and not event.is_echo():
			_toggle_inventory()
		elif event.is_action_pressed("inventory") and not event.is_echo():
			_toggle_inventory()
		elif event.is_action_pressed("inventory_use") and not event.is_echo():
			# Enter is always the food action; slot selection/transfer goes
			# through GUI activation of the focused slot (A or Enter on it).
			_use_inventory_slot("")
		elif event.is_action_pressed("inventory_context") and not event.is_echo():
			_inventory_context_requested(inventory_hud.focused_address())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_probe") and not event.is_echo():
		_pause()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(intro_sequence) and intro_sequence.is_active():
		get_viewport().set_input_as_handled()
		return
	if not started:
		return
	for action in DODGE_ACTIONS:
		if event.is_action_pressed(action) and not event.is_echo() and _try_dodge(action):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("attack") and not event.is_echo():
		var fight_was_active := road_encounters.fight.active
		if _attack() or fight_was_active:
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("full_map") and not event.is_echo():
		_toggle_full_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not event.is_echo():
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera") and not event.is_echo():
		_toggle_camera()
	if event.is_action_pressed("reset") and not event.is_echo():
		_reset()
	if event.is_action_pressed("quality") and not event.is_echo():
		_cycle_quality()
	if event.is_action_pressed("needs") and not event.is_echo():
		_toggle_needs()
	if dialogue_box.opened:
		# B/Esc закрывает через сам бокс; A активирует сфокусированный вариант
		# через ui_accept; остальные действия гасим. Пауза прошла ветку выше:
		# время в диалогах идёт, но игрок может поставить пробу на паузу.
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			_close_dialogue()
		if not event.is_action_pressed("pause_probe"):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact") and not event.is_echo():
		if road_encounters.fight.active:
			get_viewport().set_input_as_handled()
			return
		if super_pig.mounted:
			super_pig.dismount(player.global_position)
			player.set_mount_speed_multiplier(1.0)
			player.set_sitting(false)
			get_viewport().set_input_as_handled()
			return
		if super_pig.is_player_in_reach(player.global_position):
			if stolen_pig.mounted:
				stolen_pig.dismount(player.global_position)
			super_pig.mount(player.global_position, not selected_vtuber.is_empty())
			player.set_mount_speed_multiplier(SuperPig.SPEED_MULTIPLIER)
			player.set_sitting(true)
			get_viewport().set_input_as_handled()
			return
		if stolen_pig.mounted:
			stolen_pig.dismount(player.global_position)
			player.set_mount_speed_multiplier(1.0)
			player.set_sitting(false)
			get_viewport().set_input_as_handled()
			return
		if stolen_pig.is_player_in_reach(player.global_position):
			_interact_with_pig()
			get_viewport().set_input_as_handled()
			return
		if fishing_location.is_player_in_reach(player.global_position) and _interact_with_fishing():
			get_viewport().set_input_as_handled()
			return
		if _farm_theft_in_reach():
			_offer_theft()
			get_viewport().set_input_as_handled()
			return
		var road_event := road_encounters.event_in_reach(player.global_position)
		if road_event != null:
			_open_road_event_dialogue(road_event)
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(mime) and mime.is_player_in_reach(player.global_position):
			mime.begin()
			get_viewport().set_input_as_handled()
			return
		var road_npc := road_encounters.closest_interaction_target(player.global_position)
		if road_npc != null:
			_open_road_dialogue(road_npc)
			get_viewport().set_input_as_handled()
			return
		var npc := _npc_in_reach()
		if npc != null:
			_open_dialogue(npc)
			get_viewport().set_input_as_handled()
			return
		if pickup.enabled:
			_collect_food()
		else:
			_collect_dropped_item()
	elif event.is_action_pressed("jump") and not event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("eat") and not pickup.enabled and not event.is_echo():
		_eat()
	if event.is_action_pressed("rest") and not road_encounters.fight.active and not event.is_echo():
		_rest()

func _notification(what: int) -> void:
	# При съёмке кадра (PROBE_CAPTURE) окно без фокуса, и пауза по потере фокуса
	# снимала бы кадр меню вместо мира. Игровое поведение это не меняет: без
	# переменной PROBE_CAPTURE пауза работает как раньше.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and capture_path == "" \
			and is_instance_valid(needs_hud) and started:
		paused = true
		if is_instance_valid(intro_sequence):
			intro_sequence.set_paused(true)
		_set_intro_traffic_paused(true)
		if is_instance_valid(stream_minigame):
			stream_minigame.set_paused(true)
		if is_instance_valid(pig_minigame):
			pig_minigame.set_paused(true)
		if is_instance_valid(fishing_minigame):
			fishing_minigame.set_paused(true)
		if is_instance_valid(road_encounters):
			road_encounters.set_paused(true)
		if is_instance_valid(stealth):
			stealth.set_paused(true)
		menu_hud.show_pause()
		_refresh_needs()

func _on_step(delta: float, distance: float) -> void:
	if not _simulation_stopped():
		var current_metres := Route.metres(player.position)
		if folder_found and not stint_report_resolved and not super_pig.summoned \
				and current_metres <= 175.0 and current_metres < previous_route_metres:
			super_pig.summon(player.global_position)
			_set_mime_hint("Сам подбежал чёрный кабанчик. Сесть — E / A.")
		if super_pig.mounted:
			super_pig.follow(player.global_position)
		if is_instance_valid(stolen_pig) and not dialogue_box.opened:
			var was_mounted := stolen_pig.mounted
			stolen_pig.advance(delta, player.global_position)
			if was_mounted and not stolen_pig.mounted:
				player.set_mount_speed_multiplier(1.0)
				player.set_sitting(false)
			if stolen_pig.is_hungry() and not stolen_pig.hunger_warned:
				stolen_pig.hunger_warned = true
				dialogue_box.open("Свинка", "Грустно хрюкает. Покорми обычной едой.", [{"text": "Понятно"}], false)
		var moving := distance > 0.05 * delta
		timing_started = timing_started or moving
		if timing_started and not timing_finished:
			if moving:
				walking_seconds += delta
			elapsed_seconds += delta
			timing_finished = Route.metres(player.position) >= Route.LENGTH
		needs.advance(delta, distance, player.running)
		route.discover(player.position)
		audio.advance_steps(distance, started and not needs.resting)
		previous_route_metres = current_metres
	# Диалог не останавливает время (канон), но кот в нём стоит на месте.
	player.movement_enabled = not _simulation_stopped() and needs.can_move() \
		and not (is_instance_valid(dialogue_box) and dialogue_box.opened)
	if stolen_pig.mounted and not stolen_pig.bratishkin_shouted \
			and absf(Route.metres(player.position) - 189.0) >= 21.0:
		stolen_pig.bratishkin_shouted = true
		dialogue_box.open("Братишкин", "Верни свинку!", [{"text": "Уехать"}])

## К11: двор бабушки — конец маршрута. Отдельной сцены двора ещё нет, поэтому
## кражу открывает зона метров, а не модель двора; сама мини-игра уже настоящая.
func _farm_theft_in_reach() -> bool:
	return theft_outcome < 0 and Route.metres(player.position) >= FARM_THEFT_METRES

func _offer_theft() -> void:
	# Гайд даёт фывфыв. Его реплики в плане помечены как открытые, поэтому в
	# диалоге стоят только технические подсказки, а не придуманная за автора речь.
	var lines: Array = fyvfyv.guide_lines()
	dialogue_box.open("фывфыв",
		"Чёрный котёнок с золотыми зубами показывает на двор.\n" + "\n".join(lines),
		[{"text": "Начать кражу"}, {"text": "Не сейчас"}], false)
	theft_offer_open = true
	_refresh_needs()

func _finish_theft(outcome: int) -> void:
	# Сцены успеха и кормления — этап К12; здесь только фиксируется исход,
	# чтобы концовки подключались к готовому состоянию, а не пересчитывались.
	theft_outcome = outcome
	_refresh_needs()

func _interact_with_pig() -> void:
	if stolen_pig.is_hungry():
		var food_slot := inventory.first_food_slot()
		if food_slot.is_empty() or inventory.remove_one(food_slot) == null:
			dialogue_box.open("Свинка", "Грустно хрюкает. Нужна обычная еда.", [{"text": "Уйти"}], false)
			return
		stolen_pig.feed()
		_refresh_needs()
	if stolen_pig.mount(player.global_position):
		stolen_pig.passenger_count = mini(2, 1 + (0 if selected_vtuber.is_empty() else 1))
		player.set_mount_speed_multiplier(PigFollow.SPEED_MULTIPLIER)
		player.set_sitting(true)

## К3: каркас НПС у дороги; данные реплик — в dialogue_data.gd.
func _spawn_npcs(world: Node3D) -> void:
	var data := DialogueData.by_id("test_walker")
	if data.is_empty():
		return
	var npc := NPC.new()
	var spot := Vector3(2.6, 0, Route.world_z(12.0))
	world.add_child(npc)
	npc.setup("test_walker", spot, data)
	npcs.append(npc)
	var confessional := world.get_node_or_null("Church/Confessional")
	if confessional is NPC:
		npcs.append(confessional)
	var beggar_data := DialogueData.by_id("church_beggar")
	var beggar := NPC.new()
	world.add_child(beggar)
	beggar.setup("church_beggar", Vector3(2.2, 0, Route.world_z(40.0) + 3.2), beggar_data)
	npcs.append(beggar)
	var stint_data := DialogueData.by_id("stint")
	var stint := StintNPC.new()
	world.add_child(stint)
	stint.setup("stint", Vector3(2.2, 0, Route.world_z(100.0)), stint_data)
	npcs.append(stint)
	var bratishkin_data := DialogueData.by_id("bratishkin")
	var bratishkin := BratishkinNPC.new()
	world.add_child(bratishkin)
	bratishkin.setup("bratishkin", Vector3(3.4, 0, Route.world_z(189.0)), bratishkin_data)
	npcs.append(bratishkin)

func _spawn_mime(world: Node3D) -> void:
	mime = MimeTutorial.new()
	mime.objective_changed.connect(_set_mime_hint)
	world.add_child(mime)

func _set_mime_hint(text: String) -> void:
	if is_instance_valid(mime_hint_label):
		mime_hint_label.text = text

func _npc_in_reach() -> NPC:
	for npc in npcs:
		if is_instance_valid(npc) and npc.is_player_in_reach(player.global_position):
			return npc
	return null

func _open_road_dialogue(npc: RoadNPC) -> void:
	var data := RoadEncounterData.interaction(npc.encounter_id)
	if data.is_empty():
		return
	active_road_npc = npc
	var options: Array = []
	for text in data.options:
		options.append({"text": String(text)})
	var speaker := npc.display_name if npc.encounter_id in ["postcat", "bridge_goose", "road_bandit",
		"herbalist", "farm_guard", "guardian_goose"] else "Встреча"
	dialogue_box.open(speaker, String(data.line), options, false)
	_refresh_needs()

func _open_road_event_dialogue(event: RoadEvent) -> void:
	var data := RoadEncounterData.interaction(event.encounter_id)
	if data.is_empty():
		return
	active_road_event = event
	var options: Array = []
	for text in data.options:
		options.append({"text": String(text)})
	dialogue_box.open("Находка", String(data.line), options, false)
	_refresh_needs()

func _open_dialogue(npc: NPC) -> void:
	active_npc = npc
	if npc.npc_id == "stint":
		if stint_help_accepted:
			if folder_found and not stint_report_resolved:
				dialogue_box.open("Выбор", "Рассказать Стинту о найденной папке?",
					[{"text": "Рассказать"}, {"text": "Не сейчас"}], false)
				_refresh_needs()
			else:
				active_npc = null
			return
		stint_line_index = 0
		_open_stint_line()
		_refresh_needs()
		return
	if npc.npc_id == "bratishkin":
		if bratishkin_locked:
			active_npc = null
			return
		if bratishkin_stream_completed and bratishkin_stream_success \
				and not basement_offer_resolved and selected_vtuber.is_empty():
			basement_line_index = 0
			_open_basement_line()
			_refresh_needs()
			return
		if pig_work_completed:
			active_npc = null
			return
		if bratishkin_stream_completed:
			dialogue_box.open(npc.speaker, String(DialogueData.BRATISHKIN.pig_offer),
				[{"text": "Пасти"}, {"text": "Отказаться"}])
			_refresh_needs()
			return
		bratishkin_line_index = 0
		_open_bratishkin_line()
		_refresh_needs()
		return
	if npc.npc_id == "church_beggar" and beggar_hint_given:
		dialogue_box.open(npc.speaker, DialogueData.FIRST_BEGGAR_HINT, [{"text": "Уйти"}])
		_refresh_needs()
		return
	var data := DialogueData.by_id(npc.dialogue_id)
	if data.is_empty():
		active_npc = null
		return
	dialogue_box.open(String(data.get("speaker", npc.speaker)), String(data.get("line", "…")),
		data.get("options", []), bool(data.get("portrait", true)))
	_refresh_needs()

func _close_dialogue() -> void:
	if moderator_offer_open:
		moderator_offer_open = false
		moderator_offer_resolved = true
	theft_offer_open = false
	dialogue_box.opened = false
	dialogue_box.visible = false
	active_npc = null
	active_road_npc = null
	active_road_event = null
	_refresh_needs()

func _on_dialogue_option(index: int) -> void:
	if active_road_npc != null:
		_resolve_road_option(active_road_npc, index)
		return
	if active_road_event != null:
		_resolve_road_option(active_road_event, index)
		return
	if theft_offer_open:
		# Гайд фывфыва: «Начать кражу» открывает мини-игру, «Не сейчас» — закрыть.
		theft_offer_open = false
		_close_dialogue()
		if index == 0:
			stealth.begin()
		_refresh_needs()
		return
	if moderator_offer_open:
		moderator_offer_open = false
		moderator_offer_resolved = true
		_close_dialogue()
		if index == 1:
			ending_screen.begin_moderator()
			_refresh_needs()
		return
	if active_npc != null and active_npc.npc_id == "bratishkin":
		if bratishkin_stream_completed and bratishkin_stream_success \
				and not basement_offer_resolved and selected_vtuber.is_empty():
			if basement_line_index == 0:
				basement_line_index = 1
				_open_basement_line()
			elif index == 0:
				_close_dialogue()
				vtuber_room.begin()
			else:
				basement_offer_resolved = true
				_close_dialogue()
			return
		if bratishkin_stream_completed:
			if index == 0:
				_close_dialogue()
				pig_minigame.begin()
				_refresh_needs()
			else:
				_close_dialogue()
			return
		var lines: Array = DialogueData.BRATISHKIN.lines
		if bratishkin_line_index < lines.size() - 1:
			bratishkin_line_index += 1
			_open_bratishkin_line()
			return
		if index == 0:
			_close_dialogue()
			stream_minigame.begin()
			_refresh_needs()
		else:
			_close_dialogue()
		return
	if active_npc != null and active_npc.npc_id == "stint":
		if stint_help_accepted and folder_found and not stint_report_resolved:
			if index == 0:
				_report_to_stint()
			else:
				_close_dialogue()
			return
		var data := DialogueData.STINT
		var lines: Array = data.lines
		if stint_line_index < lines.size() - 1:
			stint_line_index += 1
			_open_stint_line()
			return
		if index == 0:
			if inventory.add_to_first_free(ProbeInventory.coffee_stack()):
				stint_help_accepted = true
				active_npc = null
				dialogue_box.open("Получено", "Ускоряющий кофе добавлен в инвентарь.", [{"text": "Закрыть"}], false)
			else:
				dialogue_box.open("Инвентарь", "Нет свободного места для кофе.", [{"text": "Закрыть"}], false)
				active_npc = null
		else:
			active_npc = null
			dialogue_box.open(String(data.speaker), String(data.refusal_line), [{"text": "Уйти"}])
		_refresh_needs()
		return
	if active_npc != null and active_npc.npc_id == "church_beggar" and not beggar_hint_given:
		var paid := false
		if index == 0:
			var food_slot := inventory.first_food_slot()
			paid = not food_slot.is_empty() and inventory.remove_one(food_slot) != null
		elif index == 1:
			paid = _spend_first_coin()
		if paid:
			beggar_hint_given = true
			dialogue_box.open(active_npc.speaker, DialogueData.FIRST_BEGGAR_HINT, [{"text": "Уйти"}])
			_refresh_needs()
			return
		elif index < 2:
			active_npc = null
			dialogue_box.open("Обмен", "Нечего отдать.", [{"text": "Закрыть"}], false)
			return
	_close_dialogue()

func _resolve_road_option(encounter: Node, index: int) -> void:
	var id: String = encounter.encounter_id
	var food_slot := inventory.first_food_slot()
	var wheel_slot := inventory.first_slot_with_id("wheel")
	var note_slot := inventory.first_slot_with_id("mysterious_note")
	var bandage_slot := inventory.first_slot_with_id("bandage")
	var apple_slot := inventory.first_slot_with_id("speed_apple")
	var result := road_interaction.resolve(id, index, not food_slot.is_empty(),
		_has_any_coin(), not wheel_slot.is_empty(), not note_slot.is_empty(),
		not bandage_slot.is_empty(), not apple_slot.is_empty(),
		road_encounters.player_health < FightState.PLAYER_MAX_HP)
	if result.has("item_id"):
		var item_id := String(result.item_id)
		var is_food := item_id in ["pie", "bread", "road_fish"]
		var can_use := is_food or item_id == "speed_apple"
		var item := ProbeInventory.road_item_stack(item_id, String(result.item_name), can_use)
		if is_food:
			item.food = true
		if not inventory.add_to_first_free(item):
			result = {"message": "Нет свободного места."}
	if result.get("complete", false):
		match String(result.get("consume", "")):
			"food": inventory.remove_one(food_slot)
			"coin": _spend_first_coin()
			"wheel": inventory.remove_one(wheel_slot)
			"apple": inventory.remove_one(apple_slot)
	if result.get("heal", false):
		road_encounters.heal_player()
	if result.has("damage") and encounter is RoadNPC:
		road_encounters.apply_story_damage(encounter as RoadNPC, int(result.damage))
	if result.get("complete", false):
		road_interaction.mark_completed(id)
		if encounter is RoadEvent:
			encounter.complete()
		else:
			encounter.interaction_completed = true
	if result.get("fight", false):
		road_encounters.begin_fight(encounter as RoadNPC)
	var message := String(result.get("message", ""))
	var message_speaker := String(result.get("speaker", "Встреча"))
	_close_dialogue()
	if not message.is_empty():
		dialogue_box.open(message_speaker, message, [{"text": "Закрыть"}], false)
	_refresh_needs()

func _open_stint_line() -> void:
	var data := DialogueData.STINT
	var lines: Array = data.lines
	var options: Array = data.options if stint_line_index == lines.size() - 1 else [{"text": "Далее"}]
	dialogue_box.open(String(data.speaker), String(lines[stint_line_index]), options)

func _open_bratishkin_line() -> void:
	var data := DialogueData.BRATISHKIN
	var lines: Array = data.lines
	var text := String(lines[bratishkin_line_index]).replace("[Имя]", cat_name)
	var options: Array = data.options if bratishkin_line_index == lines.size() - 1 else [{"text": "Далее"}]
	dialogue_box.open(String(data.speaker), text, options)

func _open_basement_line() -> void:
	var lines: Array = DialogueData.BRATISHKIN.basement_lines
	var options: Array = DialogueData.BRATISHKIN.basement_options \
		if basement_line_index == lines.size() - 1 else [{"text": "Далее"}]
	dialogue_box.open("Братишкин", String(lines[basement_line_index]), options)

func _finish_stream(success: bool) -> void:
	bratishkin_stream_completed = true
	bratishkin_stream_success = success
	folder_found = true
	coins.dolyarik += 2
	dialogue_box.open("Найдено", "Папка «дети» найдена.", [{"text": "Закрыть"}], false)
	_set_mime_hint("Можно вернуться к Стинту и рассказать о папке — или идти дальше.")
	_refresh_needs()

func _report_to_stint() -> void:
	stint_report_resolved = true
	bratishkin_locked = true
	vtuber_stolen = not selected_vtuber.is_empty()
	vtuber_waiting_at_stint = vtuber_stolen
	player.position = Vector3(0, 0.1, Route.world_z(189.0))
	if stolen_pig.mounted:
		stolen_pig.dismount(player.position)
	player.set_mount_speed_multiplier(1.0)
	player.set_sitting(false)
	super_pig.finish_trip(player.position)
	dialogue_box.open("Стинт", "Всё, достал! Папку верни, и разойдёмся!", [{"text": "Уйти"}])
	active_npc = null
	_set_mime_hint("")
	_refresh_needs()

func _choose_vtuber(id: String, _display_name: String) -> void:
	selected_vtuber = id
	basement_offer_resolved = true
	moderator_offer_open = true
	dialogue_box.open("Выбор", "Братишкин предлагает остаться у него навсегда.",
		[{"text": "Неа, бро, у меня другой путь"}, {"text": "Давай, конечно"}])
	_refresh_needs()

func _finish_pig_work() -> void:
	pig_work_completed = true
	coins.dolyarik += 1
	var text := String(DialogueData.BRATISHKIN.pig_finished).replace("[Имя]", cat_name)
	dialogue_box.open("Братишкин", text, [{"text": "Уйти"}])
	_refresh_needs()

func _interact_with_fishing() -> bool:
	if fishing_location.rod_available:
		if inventory.add_to_first_free(ProbeInventory.fishing_rod_stack()):
			fishing_location.take_rod()
			dialogue_box.open("Получено", "Удочка добавлена в инвентарь.", [{"text": "Закрыть"}], false)
		else:
			dialogue_box.open("Инвентарь", "Нет свободного места для удочки.", [{"text": "Закрыть"}], false)
		_refresh_needs()
		return true
	if not inventory.first_slot_with_id("fishing_rod").is_empty():
		fishing_minigame.begin()
		_refresh_needs()
		return true
	return false

func _receive_fishing_catch(result: Dictionary) -> void:
	if result.kind == "coins":
		coins.hryvnyk += int(result.count)
		_refresh_needs()
		return
	var item := ProbeInventory.fish_stack(String(result.name), int(result.food)) \
		if result.kind == "fish" else ProbeInventory.trash_stack(String(result.name))
	if not inventory.add_to_first_free(item):
		fishing_minigame.status_label.text = "Улов некуда положить."
	_refresh_needs()

func _attack() -> bool:
	if inventory.first_slot_with_id("stick").is_empty():
		return false
	return road_encounters.try_player_attack(player.global_position)

func _try_dodge(action: String) -> bool:
	if not road_encounters.fight.active or stolen_pig.mounted or super_pig.mounted:
		return false
	if float(dodge_tap_windows.get(action, 0.0)) <= 0.0:
		dodge_tap_windows[action] = DODGE_DOUBLE_TAP_SECONDS
		return false
	if needs.stamina < DODGE_STAMINA_COST:
		dodge_tap_windows[action] = 0.0
		road_encounters.last_message = "Не хватает выносливости для уворота"
		road_encounters.message_seconds = 1.5
		return false
	var input_direction := {
		"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT,
		"move_up": Vector2.UP, "move_down": Vector2.DOWN,
	}[action] as Vector2
	if not player.begin_dodge(Cat.direction_for(input_direction, player.camera_basis)):
		return false
	needs.stamina -= DODGE_STAMINA_COST
	dodge_tap_windows.clear()
	road_encounters.try_player_dodge()
	_refresh_needs()
	return true

func _on_fight_won(encounter_id: String) -> void:
	if not needs.enabled:
		needs.stamina = 100.0
	var loot_name := RoadEncounterData.robbery_loot(encounter_id)
	if not loot_name.is_empty():
		var loot := ProbeInventory.road_item_stack("road_loot:" + encounter_id, loot_name)
		if not inventory.add_to_first_free(loot):
			var drop := DroppedInventoryItem.new()
			drop.setup(loot, player.global_position + Vector3(-0.8, 0, 0))
			world_viewport.get_child(0).add_child(drop)
			dropped_items.append(drop)
	if encounter_id == "bridge_goose":
		_on_fight_lost("forest_ranger")
		road_encounters.last_message = "Лесной избил героя"
		road_encounters.message_seconds = 2.5
	_refresh_needs()

func _on_fight_lost(_encounter_id: String) -> void:
	if not needs.enabled:
		needs.stamina = 100.0
	var address := inventory.first_droppable_slot()
	if address.is_empty():
		return
	var item = inventory.remove_one(address)
	if item == null:
		return
	var drop := DroppedInventoryItem.new()
	drop.setup(item, player.global_position + Vector3(0.8, 0, 0))
	world_viewport.get_child(0).add_child(drop)
	dropped_items.append(drop)
	_refresh_needs()

func _quit_after_credits() -> void:
	if DisplayServer.get_name() != "headless":
		get_tree().quit()

func _spend_first_coin() -> bool:
	for id in DialogueData.CURRENCIES:
		if int(coins.get(id, 0)) > 0:
			coins[id] -= 1
			return true
	return false

func _has_any_coin() -> bool:
	for id in DialogueData.CURRENCIES:
		if int(coins.get(id, 0)) > 0:
			return true
	return false

func _spawn_road_wheel(world: Node3D) -> void:
	var hedgehog := road_encounters.npc_by_id("hedgehog")
	if hedgehog == null:
		return
	var wheel := DroppedInventoryItem.new()
	wheel.setup(ProbeInventory.road_item_stack("wheel", "Колесо"),
		hedgehog.global_position + Vector3(-hedgehog.global_position.x * 1.5, 0, 3.5))
	world.add_child(wheel)
	road_pickups.append(wheel)

func _refresh_needs() -> void:
	needs.portions = inventory.food_count()
	# Диалог не останавливает время (канон), но кот в нём стоит на месте.
	player.movement_enabled = not _simulation_stopped() and needs.can_move() \
		and not (is_instance_valid(dialogue_box) and dialogue_box.opened)
	needs_hud.refresh(needs, _simulation_stopped(), pickup.enabled)
	inventory_hud.refresh(needs, pickup, pickup.can_collect(player.global_position), paused, inventory)

func _simulation_stopped() -> bool:
	return not started or paused or (is_instance_valid(menu_hud) and menu_hud.is_open()) \
		or (is_instance_valid(intro_sequence) and intro_sequence.is_active()) \
		or (is_instance_valid(full_map_hud) and full_map_hud.opened) \
		or (is_instance_valid(inventory_hud) and inventory_hud.opened) \
		or (is_instance_valid(stream_minigame) and stream_minigame.opened) \
		or (is_instance_valid(pig_minigame) and pig_minigame.opened) \
		or (is_instance_valid(vtuber_room) and vtuber_room.opened) \
		or (is_instance_valid(fishing_minigame) and fishing_minigame.opened) \
		or (is_instance_valid(stealth) and stealth.opened) \
		or (is_instance_valid(ending_screen) and ending_screen.opened)

func _toggle_pickup() -> void:
	if not _simulation_stopped():
		pickup.set_enabled(not pickup.enabled)
	_refresh_needs()

func _toggle_full_map() -> void:
	full_map_hud.set_open(not full_map_hud.opened)
	if full_map_hud.opened:
		full_map_hud.player_position = player.position
		full_map_hud.refresh()
	_refresh_needs()

func _toggle_inventory() -> void:
	inventory_hud.set_open(not inventory_hud.opened)
	_refresh_needs()
	if inventory_hud.opened:
		if is_instance_valid(mime):
			mime.inventory_opened()
		inventory_hud.focus_modal()
	else:
		selected_inventory_slot = ""
		inventory_hud.focus_open_button()

func _collect_food() -> void:
	if not _simulation_stopped() and pickup.can_collect(player.global_position) and inventory.add_to_first_free(ProbeInventory.food_stack()):
		pickup.collected = true
		pickup.visible = false
		audio.play_pickup()
	_refresh_needs()

func _collect_dropped_item() -> void:
	for pickup_item in road_pickups.duplicate():
		if is_instance_valid(pickup_item) and pickup_item.collect(player.global_position, inventory):
			road_pickups.erase(pickup_item)
			audio.play_pickup()
			_refresh_needs()
			return
	for drop in dropped_items.duplicate():
		if is_instance_valid(drop) and drop.collect(player.global_position, inventory):
			dropped_items.erase(drop)
			audio.play_pickup()
			break
	_refresh_needs()

func _inventory_slot_selected(address: String) -> void:
	if selected_inventory_slot.is_empty():
		if inventory.slot(address) != null:
			selected_inventory_slot = address
	else:
		if selected_inventory_slot != address:
			inventory.transfer(selected_inventory_slot, address)
		selected_inventory_slot = ""
	inventory_hud.selected = selected_inventory_slot
	_refresh_needs()

func _inventory_context_requested(address: String) -> void:
	selected_inventory_slot = ""
	inventory_hud.selected = ""
	inventory_hud.show_context(address, inventory.slot(address))
	_refresh_needs()

func _use_inventory_slot(address: String) -> void:
	if address.is_empty():
		address = inventory.first_food_slot()
	var item = inventory.slot(address)
	if item != null and inventory_hud.opened and not paused:
		if (item.id == "food" or item.get("food", false)) and needs.can_eat():
			var food_value := float(item.get("food_value", needs.profile.food_per_portion))
			var used = inventory.remove_one(address)
			if used != null:
				needs.food = minf(100, needs.food + food_value)
				audio.play_eat()
		elif item.id == "coffee":
			var used = inventory.remove_one(address)
			if used != null:
				player.drink_coffee()
		elif item.id == "speed_apple":
			var used = inventory.remove_one(address)
			if used != null:
				player.eat_speed_apple()
	inventory_hud.clear_context()
	_refresh_needs()

func _drop_inventory_slot(address: String) -> void:
	var item = inventory.slot(address)
	if item == null or not item.get("drop", false) or not inventory_hud.opened:
		return
	var drop := DroppedInventoryItem.new()
	drop.setup(item.duplicate(true), player.global_position + player.global_basis.z * -1.0)
	world_viewport.get_child(0).add_child(drop)
	if is_instance_valid(drop):
		var removed = inventory.remove_one(address)
		if removed != null:
			drop.item = removed
			dropped_items.append(drop)
	inventory_hud.clear_context()
	_refresh_needs()

func _equip_test_backpack(kind: String) -> void:
	inventory.equip_test_backpack(kind)
	selected_inventory_slot = ""
	_refresh_needs()

func _set_backpack_page(page: int) -> void:
	if page >= 0 and page < inventory.page_count():
		inventory.current_page = page
	_refresh_needs()

func _toggle_needs() -> void:
	if not _simulation_stopped():
		needs.toggle()
	_refresh_needs()

func _eat() -> void:
	if not _simulation_stopped() and not pickup.enabled and needs.can_eat():
		var food_slot := inventory.first_food_slot()
		if not food_slot.is_empty():
			var item: Dictionary = inventory.slot(food_slot)
			var food_value := float(item.get("food_value", needs.profile.food_per_portion))
			if inventory.remove_one(food_slot) != null:
				needs.food = minf(100, needs.food + food_value)
				audio.play_eat()
	_refresh_needs()

func _rest() -> void:
	if _simulation_stopped():
		_refresh_needs()
		return
	# Ночью отдых — это сон: время уходит до утра, кот высыпается и игра
	# сохраняется. Днём и в кулдаун 15 реальных минут — обычное сидение.
	if not needs.resting and day_cycle.is_night():
		_sleep_until_morning()
		return
	needs.toggle_rest()
	player.set_sitting(needs.resting)
	if not needs.resting:
		sleeping = false
	_refresh_needs()

func _sleep_until_morning() -> void:
	if not day_cycle.sleep(play_seconds):
		# Кулдаун не прошёл — просто сидим, без прыжка времени и сейва.
		needs.toggle_rest()
		player.set_sitting(needs.resting)
		_refresh_needs()
		return
	sleeping = true
	if not needs.resting:
		needs.toggle_rest()
	player.set_sitting(true)
	needs.stamina = 100.0
	_request_autosave()
	_sync_sky()
	_refresh_needs()

func _request_autosave() -> void:
	# Сейвов в пробе ещё нет (этап К13), поэтому сон только отмечает запрос
	# автосохранения. Формат сохранения здесь не выдумывается.
	autosave_requests += 1

func _advance_world_clock(delta: float) -> void:
	# Канон: время идёт и в диалогах, и в мини-играх. Стоят только пауза и меню —
	# поэтому здесь своя проверка, а не общая `_simulation_stopped()`.
	if not started or paused or (is_instance_valid(menu_hud) and menu_hud.is_open()):
		if is_instance_valid(day_label):
			day_label.text = _day_text()
		return
	play_seconds += delta
	day_cycle.advance(delta)
	weather.advance(delta)
	if weather.is_raining() and needs.enabled:
		needs.apply_fatigue(weather.fatigue_per_second() * delta)
	_sync_sky()
	if is_instance_valid(day_label):
		day_label.text = _day_text()

func _sync_sky() -> void:
	sun.rotation_degrees = day_cycle.sun_rotation_degrees()
	sun.light_color = day_cycle.sun_color()
	sun.light_energy = day_cycle.sun_energy()
	# Дождь именно затемняет небо. Раньше здесь был переход к светлой серой
	# краске — ночью он делал небо светлее, и ночь не читалась (замечание автора).
	environment.background_color = day_cycle.sky_color().darkened(weather.wetting() * 0.35)
	environment.ambient_light_energy = day_cycle.ambient_energy()
	environment.ambient_light_color = day_cycle.ambient_color()
	# Вода нарисована без расчёта света — сутки и дождь ей передаются отдельно.
	if is_instance_valid(day_world) and day_world.has_method("set_daylight"):
		day_world.set_daylight(day_cycle.night_factor(), weather.wetting())

func _day_text() -> String:
	var text := "%s · %s" % [day_cycle.status_text(), weather.status_text()]
	if sleeping:
		text += " · сон, автосейв"
	return text

func _apply_capture_setup() -> void:
	# Кадр для проверки без монитора (как STAGE1_CAPTURE у проб этапа 1):
	#   LIBGL_ALWAYS_SOFTWARE=1 PROBE_CAPTURE=/путь.png \
	#   PROBE_CAPTURE_DAY=0.72 PROBE_CAPTURE_WEATHER=sudden godot res://main.tscn
	# PROBE_CAPTURE — только абсолютный путь (относительный save_png не берёт);
	# PROBE_CAPTURE_DAY — доля круга (0 — утро, 0.32 — день, 0.72 — ночь),
	# PROBE_CAPTURE_WEATHER — clear/rain/sudden. Инструмент приёмки, не игра.
	capture_path = OS.get_environment("PROBE_CAPTURE")
	if capture_path == "":
		return
	if OS.has_environment("PROBE_CAPTURE_DAY"):
		var fraction := clampf(OS.get_environment("PROBE_CAPTURE_DAY").to_float(), 0.0, 0.999)
		day_cycle.seconds = fraction * day_cycle.DAY_SECONDS
	match OS.get_environment("PROBE_CAPTURE_WEATHER"):
		"rain":
			weather.randomness = false
			weather.target = weather.RAIN
		"sudden":
			weather.randomness = false
			weather.start_sudden()
		"clear":
			weather.randomness = false
			weather.clear()
	if OS.has_environment("PROBE_CAPTURE_THEFT"):
		# Кадр самой мини-игры кражи: двор, кусты, конус взгляда бабушки.
		stealth.begin()
	_sync_sky()

func _pause() -> void:
	if not started:
		return
	paused = not paused
	if paused:
		if is_instance_valid(intro_sequence):
			intro_sequence.set_paused(true)
		_set_intro_traffic_paused(true)
		if is_instance_valid(stream_minigame):
			stream_minigame.set_paused(true)
		if is_instance_valid(pig_minigame):
			pig_minigame.set_paused(true)
		if is_instance_valid(fishing_minigame):
			fishing_minigame.set_paused(true)
		if is_instance_valid(road_encounters):
			road_encounters.set_paused(true)
		if is_instance_valid(stealth):
			stealth.set_paused(true)
		menu_hud.show_pause()
	else:
		if is_instance_valid(intro_sequence):
			intro_sequence.set_paused(false)
		_set_intro_traffic_paused(false)
		if is_instance_valid(stream_minigame):
			stream_minigame.set_paused(false)
		if is_instance_valid(pig_minigame):
			pig_minigame.set_paused(false)
		if is_instance_valid(fishing_minigame):
			fishing_minigame.set_paused(false)
		if is_instance_valid(road_encounters):
			road_encounters.set_paused(false)
		if is_instance_valid(stealth):
			stealth.set_paused(false)
		menu_hud.close()
	_refresh_needs()

## К2 (С1): «Начать пробу» сначала спрашивает имя кота. Текстов сюжета нет —
## только поле ввода и подтверждение.
func _show_name_entry() -> void:
	menu_hud.name_entry()

func _start_probe_named(value: String) -> void:
	cat_name = value
	if DisplayServer.get_name() == "headless":
		_start_probe()
	else:
		_begin_intro()

func _begin_intro() -> void:
	started = true
	paused = false
	menu_hud.close()
	_set_intro_traffic_paused(false)
	intro_sequence.begin(player)
	target = Vector3(0, 0.8, player.position.z - 2)
	_refresh_needs()

func _finish_intro() -> void:
	target = Vector3(0, 0.8, player.position.z - 2)
	_refresh_needs()

func _start_probe() -> void:
	started = true
	paused = false
	menu_hud.close()
	_refresh_needs()

func _resume_probe() -> void:
	paused = false
	if is_instance_valid(intro_sequence):
		intro_sequence.set_paused(false)
	_set_intro_traffic_paused(false)
	if is_instance_valid(stream_minigame):
		stream_minigame.set_paused(false)
	if is_instance_valid(pig_minigame):
		pig_minigame.set_paused(false)
	if is_instance_valid(fishing_minigame):
		fishing_minigame.set_paused(false)
	if is_instance_valid(road_encounters):
		road_encounters.set_paused(false)
	if is_instance_valid(stealth):
		stealth.set_paused(false)
	menu_hud.close()
	_refresh_needs()

func _return_to_menu() -> void:
	paused = false
	started = false
	_reset()
	menu_hud.show_start()
	_refresh_needs()

func _quit_probe() -> void:
	get_tree().quit()

func _open_settings() -> void:
	_cycle_quality()
	_refresh_needs()

func _set_intro_traffic_paused(value: bool) -> void:
	if world_viewport.get_child_count() == 0:
		return
	var traffic := world_viewport.get_child(0).get_node_or_null("PrologueIntro/BusyStreet/Traffic")
	if traffic != null:
		traffic.set_paused(value)

static func clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _process(delta: float) -> void:
	_refresh_needs()
	_advance_world_clock(delta)
	if is_instance_valid(stealth):
		stealth.advance(delta)
	if capture_path != "":
		capture_frames += 1
		if capture_frames == 40:
			var image := get_viewport().get_texture().get_image()
			# save_png принимает только абсолютный путь: относительный молча
			# падает, и проверка теряет кадр. Поэтому и ошибку сообщаем честно,
			# а не печатаем «saved» при любом исходе.
			var error := image.save_png(capture_path)
			if error == OK:
				print("PROBE_CAPTURE saved: ", capture_path)
			else:
				printerr("PROBE_CAPTURE не сохранился (код ", error, "): ", capture_path)
			# Кадр снят — проба закрывается сама, чтобы проверка не висела
			# процессом. Живой просмотр времени и погоды — кнопками F3.
			get_tree().quit()
	if not _simulation_stopped():
		for action in dodge_tap_windows:
			dodge_tap_windows[action] = maxf(0.0, float(dodge_tap_windows[action]) - delta)
	if is_instance_valid(mime):
		mime.paused = _simulation_stopped()
		mime.update_player(player.global_position)
	if is_instance_valid(mime_hint_label):
		mime_hint_label.visible = started and not (is_instance_valid(intro_sequence) and intro_sequence.is_active())
	target = target.lerp(Vector3(0, 0.8, player.position.z - 2), 1 - exp(-6 * delta))
	_set_camera()
	player.camera_basis = camera.global_basis
	if not (is_instance_valid(intro_sequence) and intro_sequence.is_active()):
		route.discover(player.position)
		route.record_encounters()
	map.player_position = player.position
	map.queue_redraw()
	if full_map_hud.opened:
		full_map_hud.player_position = player.position
		full_map_hud.refresh()
	metres_label.text = "%.1f / 500 м  ·  %s" % [Route.metres(player.position),
		"конец пробы" if Route.metres(player.position) >= Route.LENGTH else "проба"]
	time_label.text = "В движении %s\nВсего %s · цель ≈ 30:00" % [clock(walking_seconds), clock(elapsed_seconds)]
	report_time += delta
	if OS.has_feature("web") and report_time > 0.25:
		report_time = 0
		var state := {"x": player.position.x, "y": player.position.y, "z": player.position.z,
			"metres": Route.metres(player.position), "discovered": route.discovered.size(),
			"camera": "perspective" if perspective else "orthographic", "fps": Engine.get_frames_per_second(),
			"render_width": world_viewport.size.x, "render_height": world_viewport.size.y,
			"needs_enabled": needs.enabled, "food": needs.food, "stamina": needs.stamina,
			"portions": needs.portions, "resting": needs.resting, "paused": paused,
			"walking_seconds": walking_seconds, "elapsed_seconds": elapsed_seconds,
			"timing_finished": timing_finished,
			"pickup_enabled": pickup.enabled, "pickup_collected": pickup.collected,
			"pickup_nearby": pickup.can_collect(player.global_position),
			"inventory_open": inventory_hud.opened,
			"needs_status": needs.status(),
			"moving": Vector2(player.velocity.x, player.velocity.z).length() > 0.05}
		JavaScriptBridge.eval("window.probeState = " + JSON.stringify(state) + ";")

func _set_camera() -> void:
	var presets := [
		[Camera3D.PROJECTION_ORTHOGONAL, Vector3(12, 16, 22), 23.0, 37.0, "Ортография"],
		[Camera3D.PROJECTION_PERSPECTIVE, Vector3(12, 16, 22), 23.0, 37.0, "Перспектива"],
		[Camera3D.PROJECTION_PERSPECTIVE, Vector3(7, 9, 13), 17.0, 42.0, "Близко"],
		[Camera3D.PROJECTION_ORTHOGONAL, Vector3(18, 25, 34), 32.0, 35.0, "Широко"],
	]
	var preset: Array = presets[camera_index]
	camera.projection = preset[0]
	camera.position = target + preset[1]
	camera.size = preset[2]
	camera.fov = preset[3]
	camera.look_at(target)

func _toggle_camera() -> void:
	camera_index = (camera_index + 1) % 4
	perspective = camera_index == 1 or camera_index == 2
	camera_button.text = "C · %s" % [ ["Ортография", "Перспектива", "Близко", "Широко"][camera_index] ]
	camera_button.release_focus()

func _reset() -> void:
	if is_instance_valid(intro_sequence):
		intro_sequence.reset()
	player.reset()
	route.reset()
	needs.reset()
	day_cycle.reset()
	weather.reset()
	play_seconds = 0.0
	sleeping = false
	autosave_requests = 0
	theft_outcome = -1
	theft_offer_open = false
	fyvfyv.reset()
	if is_instance_valid(stealth):
		stealth.reset()
	_sync_sky()
	inventory.reset()
	selected_inventory_slot = ""
	for drop in dropped_items:
		if is_instance_valid(drop):
			drop.queue_free()
	dropped_items.clear()
	for road_pickup in road_pickups:
		if is_instance_valid(road_pickup):
			road_pickup.queue_free()
	road_pickups.clear()
	player.set_sitting(false)
	pickup.reset()
	inventory_hud.set_open(false)
	walking_seconds = 0
	elapsed_seconds = 0
	timing_started = false
	timing_finished = false
	coins = {"hryvnyk": 0, "dolyarik": 0, "zumik": 0, "evrik": 0}
	beggar_hint_given = false
	stint_line_index = 0
	stint_help_accepted = false
	bratishkin_line_index = 0
	bratishkin_stream_completed = false
	bratishkin_stream_success = false
	folder_found = false
	pig_work_completed = false
	basement_offer_resolved = false
	basement_line_index = 0
	selected_vtuber = ""
	stint_report_resolved = false
	bratishkin_locked = false
	vtuber_stolen = false
	vtuber_waiting_at_stint = false
	previous_route_metres = 0.0
	moderator_offer_open = false
	moderator_offer_resolved = false
	road_interaction.reset()
	active_road_npc = null
	active_road_event = null
	dodge_tap_windows.clear()
	_close_dialogue()
	if is_instance_valid(stream_minigame):
		stream_minigame.reset()
	if is_instance_valid(pig_minigame):
		pig_minigame.reset()
	if is_instance_valid(stolen_pig):
		stolen_pig.reset()
	if is_instance_valid(vtuber_room):
		vtuber_room.reset()
	if is_instance_valid(super_pig):
		super_pig.reset()
	if is_instance_valid(ending_screen):
		ending_screen.reset()
	if is_instance_valid(fishing_minigame):
		fishing_minigame.reset()
	if is_instance_valid(fishing_location):
		fishing_location.reset()
	if is_instance_valid(road_encounters):
		road_encounters.reset()
		_spawn_road_wheel(world_viewport.get_child(0))
	if is_instance_valid(mime):
		mime.reset()
	_refresh_needs()
	target = Vector3(0, 0.8, player.position.z - 2)
	get_viewport().gui_release_focus()

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("243c35ee")
	style.border_color = Color("a99b73")
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	return style

func _label(text: String, font_size: int, color: Color = Color("f2dfb6")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_ui() -> void:
	mime_hint_label = _label("E / A · мим показывает дорогу", 16)
	mime_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mime_hint_label.offset_top = 26
	mime_hint_label.offset_bottom = 54
	mime_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mime_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mime_hint_label)
	var top := PanelContainer.new()
	top.position = Vector2(24, 24)
	top.add_theme_stylebox_override("panel", _panel())
	add_child(top)
	var title := VBoxContainer.new()
	top.add_child(title)
	title.add_child(_label("ЛЕСНАЯ ДОРОГА", 24))
	title.add_child(_label("500 М · СКЕЛЕТ МАРШРУТА / НЕ ПОЛНЫЙ ПРОЛОГ", 12, Color("bac7a2")))
	needs_hud = NeedsHUD.new()
	var sidebar := VBoxContainer.new()
	sidebar.position = Vector2(24, 124)
	sidebar.add_theme_constant_override("separation", 12)
	add_child(sidebar)
	needs_hud.add_theme_stylebox_override("panel", _panel())
	needs_hud.mode_requested.connect(_toggle_needs)
	needs_hud.eat_requested.connect(_eat)
	needs_hud.rest_requested.connect(_rest)
	needs_hud.pause_requested.connect(_pause)
	sidebar.add_child(needs_hud)
	var map_panel := PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_panel.position = Vector2(-254, 24)
	map_panel.add_theme_stylebox_override("panel", _panel())
	add_child(map_panel)
	var map_column := VBoxContainer.new()
	map_column.add_theme_constant_override("separation", 8)
	map_panel.add_child(map_column)
	map_column.add_child(_label("ОТКРЫТЫЙ УЧАСТОК", 13))
	map = Minimap.new()
	map.custom_minimum_size = Vector2(196, 154)
	map.route = route
	map_column.add_child(map)
	metres_label = _label("", 13)
	map_column.add_child(metres_label)
	time_label = _label("", 12)
	map_column.add_child(time_label)
	day_label = _label("", 12)
	map_column.add_child(day_label)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -73
	bottom.offset_bottom = -24
	bottom.add_theme_stylebox_override("panel", _panel())
	add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	bottom.add_child(row)
	var hint := _label("WASD / стрелки · идти   F · прямо по дороге", 15)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	quality_button = Button.new()
	quality_button.text = "Q · %dp" % RENDER_HEIGHTS[quality_index]
	quality_button.tooltip_text = "Качество 3D: 720p / 1080p / 400p. Если тормозит, выбери меньшее."
	quality_button.pressed.connect(_cycle_quality)
	row.add_child(quality_button)
	camera_button = Button.new()
	camera_button.text = "C · Ортография"
	camera_button.pressed.connect(_toggle_camera)
	row.add_child(camera_button)
	var reset_button := Button.new()
	reset_button.text = "R · Сначала"
	reset_button.pressed.connect(_reset)
	row.add_child(reset_button)
	inventory_hud = InventoryHUD.new()
	inventory_hud.mode_requested.connect(_toggle_pickup)
	inventory_hud.inventory_requested.connect(_toggle_inventory)
	inventory_hud.pickup_requested.connect(_collect_food)
	inventory_hud.slot_selected.connect(_inventory_slot_selected)
	inventory_hud.context_requested.connect(_inventory_context_requested)
	inventory_hud.use_requested.connect(_use_inventory_slot)
	inventory_hud.drop_requested.connect(_drop_inventory_slot)
	inventory_hud.backpack_requested.connect(_equip_test_backpack)
	inventory_hud.page_requested.connect(_set_backpack_page)
	add_child(inventory_hud)
	inventory_hud.toolbar.add_theme_stylebox_override("panel", _panel())
	sidebar.add_child(inventory_hud.toolbar)
	menu_hud = MenuHUD.new()
	menu_hud.start_requested.connect(_show_name_entry)
	menu_hud.name_confirmed.connect(_start_probe_named)
	menu_hud.resume_requested.connect(_resume_probe)
	menu_hud.settings_requested.connect(func(): pass)
	menu_hud.main_menu_requested.connect(_return_to_menu)
	menu_hud.quit_requested.connect(_quit_probe)
	menu_hud.quality_requested.connect(_open_settings)
	add_child(menu_hud)
	dialogue_box = DialogueBox.new()
	dialogue_box.option_chosen.connect(_on_dialogue_option)
	dialogue_box.closed.connect(_close_dialogue)
	add_child(dialogue_box)
	full_map_hud = FullMapHUD.new()
	full_map_hud.route = route
	full_map_hud.close_requested.connect(_toggle_full_map)
	add_child(full_map_hud)
	debug_hud = DebugHUD.new()
	debug_hud.setup(self)
	add_child(debug_hud)
