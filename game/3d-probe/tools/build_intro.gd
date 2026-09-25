extends SceneTree

## Пересобирает стартовую катсцену и сохраняет intro.tscn.
## godot --path game/3d-probe -s res://tools/build_intro.gd
## Запускать с окном (xvfb-run на сервере): трава — MultiMesh, в headless она сохранится пустой.

const SCENE_PATH := "res://scenes/cutscene/intro.tscn"


func _initialize() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		printerr("Не удалось открыть ", SCENE_PATH)
		quit(1)
		return
	var root: Node = scene.instantiate()
	root.get_node("Builder").rebuild(root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	var save_result := ResourceSaver.save(packed, SCENE_PATH)
	var animation: Animation = root.get_node("AnimationPlayer").get_animation("intro")
	print("Катсцена пересобрана: длина %.1f с, деревьев %d, машин %d, pack=%d, save=%d" % [animation.length,
		root.get_node("Builder/Forest").get_child_count(), root.get_node("Builder/Traffic").get_child_count(),
		pack_result, save_result])
	root.free()
	quit(0 if pack_result == OK and save_result == OK else 1)
