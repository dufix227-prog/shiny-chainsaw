extends SceneTree

## Пересобирает общий мир стартового места (start_area_world.tscn),
## затем постановку катсцены (intro.tscn) — она опирается на форму мира.
## godot --path game/3d-probe -s res://tools/build_start_area.gd
## С окном (xvfb-run на сервере): трава — MultiMesh, в headless она сохранится пустой.

const WORLD := "res://scenes/world/start_area_world.tscn"
const INTRO := "res://scenes/cutscene/intro.tscn"


func _initialize() -> void:
	var ok := _rebuild(WORLD, "Builder") and _rebuild(INTRO, "Builder")
	quit(0 if ok else 1)


func _rebuild(path: String, builder_path: String) -> bool:
	var scene: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if scene == null:
		printerr("Не удалось открыть ", path)
		return false
	var root: Node = scene.instantiate()
	root.get_node(builder_path).rebuild(root)
	var packed := PackedScene.new()
	var result := packed.pack(root)
	if result == OK:
		result = ResourceSaver.save(packed, path)
	var summary := ""
	if root.has_node("Builder/Forest"):
		summary = "деревьев %d, машин %d" % [root.get_node("Builder/Forest").get_child_count(),
			root.get_node("Builder/Street/Traffic").get_child_count()]
	if root.has_node("AnimationPlayer"):
		summary = "катсцена %.1f с" % root.get_node("AnimationPlayer").get_animation("intro").length
	print("Пересобрано ", path.get_file(), ": ", summary, ", результат ", result)
	root.free()
	return result == OK
