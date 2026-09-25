extends SceneTree

## Этап 1B: проверки трёх ширин тропы — сегменты, ширины, кот, НПС, деревья.

const Stage1Widths = preload("res://probes/stage1_widths.gd")
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

func run() -> void:
	var probe: Stage1Widths = Stage1Widths.new()
	root.add_child(probe)
	await frames(6)

	check(probe.segments.size() == 3, "Three width variants exist")
	var widths: Array = []
	for segment in probe.segments:
		widths.append(segment.width)
		var root: Node3D = segment.root
		var cats := root.find_children("*", "CharacterBody3D", true, false)
		check(cats.size() >= 1, "Segment %s keeps a cat on the trail" % segment.index)
		var trees: int = root.find_children("*", "MeshInstance3D", true, false).size()
		check(trees > 12, "Segment %s has a tree wall (found %d meshes)" % [segment.index, trees])
	check(widths[0] < widths[1] and widths[1] < widths[2], "Widths increase from narrow to wide")
	check(absf(widths[1] - widths[0] - (widths[2] - widths[1])) < 0.01, "Width steps are even")

	for i in probe.segments.size():
		var segment: Dictionary = probe.segments[i]
		probe.focus_segment(i)
		await frames(2)
		check(probe.camera.position.z > 0.0, "Camera %s stays behind the cat" % i)
		check(absf(probe.camera.position.x - segment.center_x) < 0.01, "Camera %s follows the segment center" % i)
		var cat: Cat = segment.root.find_children("*", "CharacterBody3D", true, false)[0]
		check(cat.is_on_floor(), "Cat %s stands on the trail" % i)
		check(cat.position.z > probe.focus.z, "Cat %s sits between camera and horizon" % i)

	check(probe.toggle_projection() == true, "Orthographic toggle works")
	print("Stage 1B widths probe: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
