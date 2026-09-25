extends SceneTree

## К2 (С1): старт в лесу — роща вокруг спавна, тропа к дороге, экран имени.
## Только геометрия и экраны; сюжетных текстов нет.

const World = preload("res://scripts/world.gd")
const Forest = preload("res://scripts/location_forest.gd")
const Cat = preload("res://scripts/cat.gd")
const Route = preload("res://scripts/route.gd")
const Probe = preload("res://scripts/probe.gd")
const MenuHUD = preload("res://scripts/menu_hud.gd")
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
	root.size = Vector2i(1280, 800)
	check(is_equal_approx(Route.metres(Cat.SPAWN), 0.0), "Forest spawn keeps the zero metre on the route scale")
	check(Cat.SPAWN.z == Forest.SPAWN.z and absf(Cat.SPAWN.x - Forest.SPAWN.x) < 0.01, "Cat and forest agree on the spawn point")
	var world := World.new()
	root.add_child(world)
	await frames(8)
	var forest: Node3D = world.get_node_or_null("ForestStart")
	check(forest != null, "Forest start location builds into the world")
	if forest != null:
		var shapes := forest.find_children("*", "CollisionShape3D", true, false)
		var near_spawn := 0
		var closest := 999.0
		for shape: CollisionShape3D in shapes:
			var distance: float = shape.global_position.distance_to(Forest.SPAWN)
			if distance < 6.0:
				near_spawn += 1
			closest = minf(closest, distance)
		check(near_spawn >= 8, "A grove of trunks surrounds the spawn (now %d)" % near_spawn)
		check(closest >= 1.2, "No trunk spawns inside the cat's personal space (closest %.2f)" % closest)
		for shape: CollisionShape3D in shapes:
			var z: float = shape.global_position.z
			var x: float = shape.global_position.x
			if z > Forest.TRAIL_ROAD_Z and z < Forest.TRAIL_FOREST_Z + 2.0 and absf(x) < 2.0:
				check(false, "Trail corridor stays free of solid trunks (%.2f, %.2f)" % [x, z])
				break
	world.queue_free()
	await process_frame
	# Экран имени: у автора «Начать пробу» ведёт к вводу имени, у автотестов —
	# прежний автостарт.
	var probe := Probe.new()
	root.add_child(probe)
	probe.size = Vector2i(1280, 800)
	await frames(10)
	check(probe.started and not probe.menu_hud.is_open(), "Headless automated runs keep the previous auto-start")
	check(probe.cat_name == "Кот", "Headless auto-start uses the technical default name")
	probe._return_to_menu()
	await frames(3)
	check(probe.menu_hud.mode == MenuHUD.START and not probe.menu_hud.name_row.visible, "Start menu hides the name row")
	probe.menu_hud.primary_button.pressed.emit()
	await frames(2)
	check(probe.menu_hud.mode == MenuHUD.NAME and probe.menu_hud.visible, "Start action opens the cat name screen (C1)")
	check(probe.menu_hud.name_row.visible and not probe.started, "Name screen asks for a name before the walk begins")
	probe.menu_hud.name_field.text = "  Рыжик  "
	probe.menu_hud.name_confirm.pressed.emit()
	await frames(2)
	check(probe.started and probe.cat_name == "Рыжик", "Confirming trims and applies the entered name")
	check(not probe.menu_hud.name_row.visible, "Name row hides once the walk begins")
	# Пустой ввод падает на техническое имя по умолчанию, без сюжетных текстов.
	probe._return_to_menu()
	await frames(3)
	probe.menu_hud.primary_button.pressed.emit()
	await frames(2)
	probe.menu_hud.name_confirm.pressed.emit()
	await frames(2)
	check(probe.started and probe.cat_name == "Кот", "Empty name falls back to the technical default")
	# Headless сохраняет быстрый автозапуск старых сюитов; интеграцию катсцены
	# проверяем явным запуском того же метода, который использует игра.
	probe._begin_intro()
	await frames(3)
	check(probe.intro_sequence.is_active(), "Named start launches the intro sequence in the real game flow")
	check(not probe.player.movement_enabled and not probe.timing_started, "Intro blocks player control and route timers")
	for i in 800:
		if not probe.intro_sequence.is_active():
			break
		await physics_frame
	check(not probe.intro_sequence.is_active(), "Intro hands control over after entering the forest")
	check(probe.player.movement_enabled and is_equal_approx(Route.metres(probe.player.position), 0.0), "Control returns at zero metres")
	check(not probe.timing_started and is_zero_approx(probe.walking_seconds), "Cutscene movement is excluded from walk timing")
	probe.queue_free()
	await process_frame
	print("Prologue start tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
