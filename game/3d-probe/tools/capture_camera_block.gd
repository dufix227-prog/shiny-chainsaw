extends SceneTree

## Кадр для проверки камеры: кот у дерева на краю тропы, камера повёрнута
## в сторону кроны. Камера должна остановиться перед кроной, а кот — стать прозрачным.
## godot --path game/3d-probe -s res://tools/capture_camera_block.gd -- <файл.jpg>
func _initialize(): _go.call_deferred()
func _go():
	var out: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/style_probe/style_probe.tscn")
	for i in 3: await process_frame
	var s = current_scene
	var b = s.get_node("Builder")
	var p: CharacterBody3D = s.get_node("CatPlayer")
	var best: Node3D = null
	for t in s.get_node("Builder/Forest").get_children():
		if not t.name.begins_with("Spruce") or t.position.z > 5 or t.position.z < -60: continue
		var edge = absf(t.position.x - b.path_center_x(t.position.z)) - b.terrain.path_width(t.position.z) / 2.0
		if edge > 2.5 and edge < 4.0 and t.position.x < b.path_center_x(t.position.z):
			best = t; break
	var z = best.position.z
	var x = b.path_center_x(z) - b.terrain.path_width(z) / 2.0 + 0.8
	p.global_position = Vector3(x, b.block_height(x, z) + 0.2, z)
	var d = best.position - p.global_position
	var pivot: Node3D = p.get_node("CameraPivot")
	pivot.rotation = Vector3(-0.3, atan2(d.x, d.z), 0)
	for i in 40: await process_frame
	root.get_texture().get_image().save_jpg(out, 0.88)
	print("Дерево ", best.name, ", камера на расстоянии ", p.get_node("CameraPivot/SpringArm3D").get_hit_length())
	quit()
