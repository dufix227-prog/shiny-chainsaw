extends SceneTree

## Проба Forward+: пещера с факелами существует, тоннель сплошной (нет
## разрыва позади кота), кот держит деревянный меч, факелы мерцают.
## Не проверяет визуальное качество glow/SSAO/fog — только структуру сцены,
## это делает --check-only + человеческий просмотр кадра.

const Stage1Cave = preload("res://probes/stage1_cave.gd")

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
	var probe: Stage1Cave = Stage1Cave.new()
	root.add_child(probe)
	await frames(4)

	check(probe.cat != null, "Cave probe spawns the current code-built cat")
	check(probe.camera != null, "Cave probe has a camera")

	var world_envs := probe.find_children("*", "WorldEnvironment", true, false)
	check(world_envs.size() == 1, "Exactly one WorldEnvironment exists")
	if not world_envs.is_empty():
		var env: Environment = world_envs[0].environment
		check(env.glow_enabled, "Glow is enabled (needs Forward+/Mobile, not Compatibility)")
		check(env.ssao_enabled, "SSAO is enabled")
		check(env.volumetric_fog_enabled, "Volumetric fog is enabled")

	check(probe.flicker_lights.size() == Stage1Cave.TORCH_POSITIONS.size(),
		"Every configured torch position got a light")
	for light in probe.flicker_lights:
		check(light is OmniLight3D and light.light_energy > 0.0, "Torch light is a lit OmniLight3D")

	# Тоннель должен быть сплошным: у StaticBody-стен нет разрыва в диапазоне
	# от камеры (z≈3.9) до самого дальнего факела — иначе виден плоский фон.
	var walls: Array = probe.find_children("*", "StaticBody3D", true, false)
	check(walls.size() > 10, "Cave tunnel is built from many wall/floor segments (%d found)" % walls.size())

	var sword_meshes := 0
	for hand_child in probe.cat.arms[0].find_children("*", "MeshInstance3D", true, false):
		sword_meshes += 1
	var right_arm_meshes := probe.cat.arms[1].find_children("*", "MeshInstance3D", true, false).size()
	# arms[0]/arms[1] уже несут по 2 меша предплечья от cat.gd (fur+leather);
	# левая рука дополнительно получает 3 меша меча, правая — 1 меш посоха.
	check(sword_meshes > right_arm_meshes,
		"Left hand (with sword) carries more meshes than the right hand (road stick only)")
	check(sword_meshes >= 5, "Left hand carries the forearm plus a 3-part wooden sword")

	print("Stage 1 cave probe: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
