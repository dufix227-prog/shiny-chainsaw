extends SceneTree

## Пересобирает меши частей кота (scenes/player/cat_parts/*.res).
## godot --headless --path game/3d-probe -s res://tools/build_cat_model.gd

const CatVoxels = preload("res://scenes/player/cat_voxels.gd")


func _initialize() -> void:
	CatVoxels.new().build_all()
	print("Части кота пересобраны: ", CatVoxels.PIVOTS.keys())
	quit()
