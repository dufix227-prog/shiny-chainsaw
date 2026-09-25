extends SceneTree

## Пересобирает меши деревьев и участок first40.tscn и сохраняет результат.
## Запуск: godot --headless --path game/3d-probe -s res://tools/build_first40.gd

const TreeShapes = preload("res://scenes/trees/tree_shapes.gd")
const SCENE_PATH := "res://scenes/world/first40.tscn"


func _initialize() -> void:
	TreeShapes.build_all()
	var root: Node = load(SCENE_PATH).instantiate()
	var builder = root.get_node("Builder")
	builder.rebuild(root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	var save_result := ResourceSaver.save(packed, SCENE_PATH)
	print("Участок пересобран: деревьев ", builder.get_node("Forest").get_child_count(),
		", кустов ", builder.get_node("Bushes").get_child_count(),
		", pack=", pack_result, ", save=", save_result)
	root.free()
	quit(0 if pack_result == OK and save_result == OK else 1)
