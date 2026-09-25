extends SceneTree

## Этап 1A-v2: проверки пробы масштаба на CC0-моделях — загрузка сцен,
## подгонка высот, подписи, коллизии, платформа. Автопроверка геометрии,
## не визуальная приёмка.

const Stage1Scale = preload("res://probes/stage1_scale.gd")

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
	var probe: Stage1Scale = Stage1Scale.new()
	root.add_child(probe)
	await frames(4)
	probe.measure_heights()

	var by_id := {}
	for entry in probe.entries:
		by_id[entry.id] = entry
	for id in Stage1Scale.TARGETS:
		check(by_id.has(id), "Line-up contains %s" % id)
		if by_id.has(id):
			check(by_id[id].offset > 0.0, "Measured height of %s is positive" % id)
			check(by_id[id].label.text.contains("—"), "Label of %s carries the measured height" % id)

	var specs: Dictionary = Stage1Scale.TARGETS
	for id in specs:
		var spec: Dictionary = specs[id]
		var target: float = spec.height
		if by_id.has(id) and not spec.get("stub", false):
			var delta: float = absf(by_id[id].offset - target)
			check(delta < target * 0.12, "%s fits its technical target (%.2f vs %.2f)" % [id, by_id[id].offset, target])
	check(by_id["super_pig"].offset > by_id["pig"].offset, "Super pig stands taller than the regular pig")
	check(by_id["tree"].offset > by_id["man"].offset * 1.8, "Tree is well above the human height")

	var stubs := ["door", "sign"]
	for id in stubs:
		check(by_id[id].origin == "техническая заглушка", "%s is honestly marked as a stub" % id)
	check(by_id["cat"].origin == "текущий кодовый кот", "Cat stays the current code-built model")
	check(by_id["cat_blender"].origin.contains("Blender"), "Blender cat candidate is labeled as own model")
	for id in ["pig", "tree", "bush", "rocks", "car", "man", "farmer"]:
		check(by_id[id].origin.contains("CC0"), "%s is marked as a CC0 candidate" % id)

	var platform := probe.get_node_or_null("Platform")
	check(platform != null, "Neutral platform exists")
	if platform != null:
		check(absf(platform.position.y + 0.1) < 0.001, "Platform top surface sits at y=0")

	# Коллизия точь-в-точь: у каждого объекта — trimesh по его мешам.
	for id in ["pig", "super_pig", "car", "tree", "bush", "rocks", "door", "sign"]:
		var colliders: int = by_id[id].node.find_children("*", "StaticBody3D", true, false).size()
		check(colliders > 0, "%s carries exact trimesh collision (%d shapes)" % [id, colliders])

	probe.set_collision_preview(true)
	check(probe.preview_shapes[0].visible, "Collision preview can be toggled on")
	check(probe.preview_shapes[0].material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Collision preview is a translucent overlay")
	probe.set_collision_preview(false)
	check(not probe.preview_shapes[0].visible, "Collision preview can be toggled off")

	var eyes := 0
	for entry in probe.entries:
		if entry.id != "pig" and entry.id != "super_pig":
			continue
		for descendant in entry.node.find_children("ProbeEye*", "", true, false):
			eyes += 1
	check(eyes == 4, "Both pigs carry two eyes each (found %d)" % eyes)

	check(probe.toggle_projection() == true, "Orthographic toggle switches on")
	check(probe.toggle_projection() == false, "Orthographic toggle switches back")

	print("Stage 1A scale probe v2: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
