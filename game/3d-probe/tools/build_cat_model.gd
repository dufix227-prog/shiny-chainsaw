extends SceneTree

## Пересобирает все варианты модели кота: меши частей и лиц
## (scenes/player/cat_parts/<id>/) и сцены (scenes/player/cat_variants/cat_<id>.tscn).
## godot --headless --path game/3d-probe -s res://tools/build_cat_model.gd

const CatVoxels = preload("res://scenes/player/cat_voxels.gd")
const MODEL_SCRIPT = preload("res://scenes/player/cat_model.gd")
const NODE_NAMES := {"body": "Body", "leg_left": "LegLeft", "leg_right": "LegRight", "arm_left": "ArmLeft",
	"arm_right": "ArmRight", "tail": "Tail", "head": "Head"}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/player/cat_variants/"))
	for id in CatVoxels.VARIANTS:
		_build_variant(id)
	quit()


func _build_variant(id: String) -> void:
	var recipe := CatVoxels.new(id)
	var meshes := recipe.build()
	var folder := "res://scenes/player/cat_parts/%s/" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for mesh_name in meshes:
		ResourceSaver.save(meshes[mesh_name], folder + mesh_name + ".res", ResourceSaver.FLAG_COMPRESS)
	var root := Node3D.new()
	root.name = "CatModel"
	root.set_script(MODEL_SCRIPT)
	root.variant_id = id
	root.eye_height = recipe.eye_height
	for part in NODE_NAMES:
		var node := MeshInstance3D.new()
		node.name = NODE_NAMES[part]
		node.mesh = _load(folder + part + ".res")
		node.position = recipe.pivots[part]
		root.add_child(node)
		node.owner = root
	var head: Node3D = root.get_node("Head")
	for face in [["Eyes", "eyes_neutral"], ["Mouth", "mouth_neutral"]]:
		var node := MeshInstance3D.new()
		node.name = face[0]
		node.mesh = _load(folder + face[1] + ".res")
		head.add_child(node)
		node.owner = root
	var steps := AudioStreamPlayer3D.new()
	steps.name = "Footsteps"
	steps.bus = &"Effects"
	steps.unit_size = 4.0
	steps.max_distance = 30.0
	root.add_child(steps)
	steps.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "res://scenes/player/cat_variants/cat_%s.tscn" % id
	ResourceSaver.save(packed, path)
	print("Кот «%s» (%s): %s" % [CatVoxels.VARIANTS[id].name, id, path])
	root.free()


func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
