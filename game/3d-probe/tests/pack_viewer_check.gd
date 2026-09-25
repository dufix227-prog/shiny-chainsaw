extends SceneTree

## Проверка витрины пачки (19.09.2026). Что проверяет:
##   1. эталон «рост кота 1,8 м» НЕ прячется при показе одного объекта, а стоит
##      вплотную к нему — иначе мелочь вроде корзины не с чем сравнить
##      (замечание автора 19.09.2026: «непонятно как оценивать»);
##   2. и объект, и эталон целиком попадают в кадр на каждом объекте ряда;
##   3. в общем виде эталон возвращается на своё место, а видны все объекты.
##
## Это проверка раскладки и кадра, а НЕ визуальная приёмка: как выглядят модели,
## решает автор.
##
## Запуск:
##   ENGINE=~/.cache/10000-metres-probe/godot-4.7.2-linux-x86_64/godot
##   $ENGINE --headless --path game/3d-probe --script tests/pack_viewer_check.gd

const SCENE := "res://probes/pack_viewer.tscn"
const Viewer = preload("res://probes/pack_viewer.gd")

var failures := 0
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


## AABB узла в мировых координатах: обходим сами меши, потому что
## get_aabb() у MeshInstance3D — в его собственных координатах.
func world_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var started := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		box = world if not started else box.merge(world)
		started = true
	return box


func corners(box: AABB) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in 8:
		points.append(box.position + Vector3(
			box.size.x * (i & 1), box.size.y * ((i >> 1) & 1), box.size.z * ((i >> 2) & 1)))
	return points


func all_inside(camera: Camera3D, box: AABB) -> bool:
	for point in corners(box):
		if not camera.is_position_in_frustum(point):
			return false
	return true


func run() -> void:
	var packed := load(SCENE) as PackedScene
	check(packed != null, "сцена витрины загружается: %s" % SCENE)
	if packed == null:
		quit(1)
		return

	var viewer := packed.instantiate() as Node3D
	check(viewer != null, "витрина инстанцируется как Node3D")
	if viewer == null:
		quit(1)
		return

	root.add_child(viewer)
	# Автоповорот увёл бы камеру между проверками кадра.
	viewer.set_process(false)
	# В headless окно по умолчанию крошечное (64×64), а кадр считается по нему:
	# берём размер окна из настроек проекта — тот же кадр, что видит автор.
	root.size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 800)))

	var camera := viewer.get_node("Camera") as Camera3D
	var reference := viewer.get_node_or_null("Reference") as Node3D
	check(camera != null, "камера на месте")
	check(reference != null, "эталон на месте")
	if camera == null or reference == null:
		quit(1)
		return

	var count: int = (viewer.get("exhibits") as Array).size()
	check(count >= 7, "в витрине семь объектов, найдено %d" % count)

	# ------------------------------------------------ показ одного объекта ---
	for i in count:
		viewer.call("show_exhibit", i)
		var entry: Dictionary = (viewer.get("exhibits") as Array)[i]
		var node := entry["node"] as Node3D
		var size := entry["size"] as Vector3

		check(reference.visible, "объект %d: эталон не спрятан" % (i + 1))
		var ref_box := world_aabb(reference)
		var ref_left := ref_box.position.x
		var obj_right: float = node.position.x + size.x / 2
		check(ref_left > obj_right,
			"объект %d: эталон справа от объекта (%.3f против %.3f)" %
			[i + 1, ref_left, obj_right])
		var gap := ref_left - obj_right
		check(absf(gap - Viewer.REFERENCE_GAP) <= 0.01,
			"объект %d: просвет до эталона %.3f против %.2f" %
			[i + 1, gap, Viewer.REFERENCE_GAP])

		# Эталон — мерило 1,8 м: если он в кадре не целиком, сравнить нельзя.
		check(absf(ref_box.size.y - 1.8) <= 0.01,
			"эталон ростом 1,80 м, измерено %.3f" % ref_box.size.y)
		check(all_inside(camera, ref_box),
			"объект %d: эталон целиком в кадре" % (i + 1))
		check(all_inside(camera, world_aabb(node)),
			"объект %d: объект целиком в кадре" % (i + 1))

		# Соседи спрятаны: они загораживали кадр при близком просмотре.
		for j in count:
			if j == i:
				continue
			var neighbour := ((viewer.get("exhibits") as Array)[j] as Dictionary)["node"] as Node3D
			check(not neighbour.visible,
				"объект %d: сосед %d спрятан" % [i + 1, j + 1])

	# ------------------------------------------------------- общий вид ---
	viewer.call("show_whole_pack")
	var home: Vector3 = viewer.get("reference_home")
	check(reference.position.is_equal_approx(home),
		"общий вид: эталон вернулся на место (%.3f против %.3f)" %
		[reference.position.x, home.x])
	for i in count:
		var node := ((viewer.get("exhibits") as Array)[i] as Dictionary)["node"] as Node3D
		check(node.visible, "общий вид: объект %d виден" % (i + 1))
		check(all_inside(camera, world_aabb(node)),
			"общий вид: объект %d целиком в кадре" % (i + 1))
	check(all_inside(camera, world_aabb(reference)), "общий вид: эталон целиком в кадре")

	print("PACK_VIEWER_CHECK: проверок %d, провалов %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
