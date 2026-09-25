extends SceneTree

## Этап 1D: проверки рельефа — склоны проходимы, кусты замедляют ×2,
## мелкий камень проходим, крупный блокирует, глубокая вода недоступна.

const Stage1Terrain = preload("res://probes/stage1_terrain.gd")
const Cat = preload("res://scripts/cat.gd")

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

func walk(probe: Stage1Terrain, direction: Vector3, seconds: float, delta: float = 1.0 / 60.0) -> void:
	probe.cat.start_scripted_walk(direction)
	for i in int(seconds / delta):
		await physics_frame
	probe.cat.stop_scripted_walk()

func run() -> void:
	var probe: Stage1Terrain = Stage1Terrain.new()
	root.add_child(probe)
	await frames(8)

	# 1) Открытая база: эталонная скорость на ровном полу
	var base_start: float = probe.cat.position.x
	await walk(probe, Vector3(-1, 0, 0), 1.0)
	var open_dist: float = base_start - probe.cat.position.x
	check(open_dist > 2.0, "Cat walks the flat base at normal speed (%.2f)" % open_dist)

	# 2) Склоны проходимы при движении +X (мягкий, затем крутой)
	probe.cat.position = Vector3(-15.0, 0.15, 0)
	probe.cat.visual.rotation.y = PI / 2
	await frames(6)
	var slope_start: float = probe.cat.position.x
	await walk(probe, Vector3(1, 0, 0), 5.2)
	check(probe.cat.position.x > slope_start + 10.0, "Cat walks over both slopes")
	check(probe.cat.position.y > 1.6, "Cat reaches the upper plateau (%.2f)" % probe.cat.position.y)
	check(probe.cat.position.y < 3.0, "Slope keeps the cat near ground level")

	# 3) Кусты по бокам тропы: в кустах ×2, посередине тропы — обычная скорость
	probe.cat.position = Vector3(-18.6, 0.3, 5.0)
	await frames(4)
	check(absf(probe.cat.mount_speed_multiplier - 0.5) < 0.001, "Side bush zone halves the cat speed")
	probe.cat.position = Vector3(-18.6, 0.2, 0.0)
	await frames(4)
	check(absf(probe.cat.mount_speed_multiplier - 1.0) < 0.001, "Trail middle keeps full speed")

	# 4) Мелкий камень проходим, крупный блокирует
	probe.cat.position = Vector3(3.5, 2.6, 2.0)
	await frames(14)
	check(probe.cat.position.y < 3.3, "Cat passes over the small rock")
	probe.cat.position = Vector3(3.2, 2.5, -1.5)
	await frames(14)
	await walk(probe, Vector3(1, 0, 0), 1.0)
	check(probe.cat.position.x < 4.9, "Big rock blocks the cat")

	# 5) Мелководье проходимо, глубокая вода недоступна
	probe.cat.position = Vector3(11.0, 2.5, 0.0)
	await frames(8)
	await walk(probe, Vector3(1, 0, 0), 1.6)
	check(probe.cat.position.x > 12.5, "Cat wades into shallow water")
	probe.cat.position = Vector3(17.5, 2.1, 0.0)
	await frames(8)
	await walk(probe, Vector3(1, 0, 0), 1.6)
	check(probe.cat.position.x < 19.45, "Deep water stops the cat")

	print("Stage 1D terrain probe: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
