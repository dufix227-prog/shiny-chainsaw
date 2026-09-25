extends SceneTree

## Пересобирает пробу графики и сохраняет style_probe.tscn.
## godot --path game/3d-probe -s res://tools/build_style_probe.gd
## Запускать с окном (без --headless): трава и дальний лес — MultiMesh, а в
## headless-режиме Godot не хранит их данные, и они сохранились бы пустыми.

const SCENE_PATH := "res://scenes/style_probe/style_probe.tscn"


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		printerr("Не удалось открыть ", SCENE_PATH, " — проверь, что файлы в generated/ и kinds/ на месте.")
		quit(1)
		return
	var root: Node = scene.instantiate()
	var builder = root.get_node("Builder")
	builder.rebuild(root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	var save_result := ResourceSaver.save(packed, SCENE_PATH)
	print("Проба пересобрана за %.1f с: деревьев %d, pack=%d, save=%d" % [
		(Time.get_ticks_msec() - started) / 1000.0, builder.get_node("Forest").get_child_count(), pack_result, save_result])
	root.free()
	quit(0 if pack_result == OK and save_result == OK else 1)
