extends RefCounted

## Стартовая локация «лес» (С1): по решению автора кот начинает путь в лесу
## и выходит из него на дорогу. Только геометрия; сюжетных элементов нет.

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const SPAN_METRES := 14.0
const SIDE_MARGIN := 3.4
const MESH_BUDGET := 290
## К2: роща у точки старта и тропа к дороге — геометрия С1, без сюжета.
const SPAWN := Vector3(0, 0, 9.5)
const TRAIL_ROAD_Z := 2.0
const TRAIL_FOREST_Z := 12.0

static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var forest := Node3D.new()
	forest.name = "ForestStart"
	forest.set_meta("landmark", true)
	parent.add_child(forest)
	var trunk := Art.material(Color("5a4028"), true)
	var crown := Art.material(Color("42592c"), true)
	var crown_light := Art.material(Color("517038"), true)
	var bush := Art.material(Color("3f5a2e"), true)
	var moss := Art.material(Color("556b3a"), true)
	var span := SPAN_METRES * Route.WORLD_UNITS_PER_METRE
	var count := 14
	for i in count:
		var t := float(i) / float(maxi(count - 1, 1))
		var z := Route.ORIGIN_Z + t * span
		var density := 1.0 - t * 0.55
		for side in [-1.0, 1.0]:
			if rng.randf() > 0.3 + density * 0.6:
				continue
			var x: float = side * rng.randf_range(SIDE_MARGIN + 0.4, 9.6)
			_tree(forest, Vector3(x, 0, z + rng.randf_range(-4.0, 4.0)), trunk, crown, crown_light, rng)
	for i in 14:
		var x := rng.randf_range(2.8, 10.0)
		if rng.randf() < 0.45:
			x = -x
		var z := Route.ORIGIN_Z + rng.randf_range(0.0, span)
		if rng.randf() < 0.5:
			Art.box(forest, Vector3(x, 0.28, z), Vector3(1.1, 0.56, 0.9), bush)
			Art.box(forest, Vector3(x + 0.08, 0.62, z), Vector3(0.7, 0.28, 0.6), crown_light)
		else:
			var log := Art.box(forest, Vector3(x, 0.22, z), Vector3(0.4, 0.4, 1.6), trunk)
			log.rotation.y = rng.randf_range(-0.4, 0.4)
	for i in 10:
		var x := rng.randf_range(2.8, 10.0)
		if rng.randf() < 0.45:
			x = -x
		Art.box(forest, Vector3(x, 0.045, Route.ORIGIN_Z + rng.randf_range(0.0, span)),
			Vector3(rng.randf_range(1.2, 2.6), 0.05, rng.randf_range(1.2, 2.6)), moss)
	# Роща вокруг точки спавна: кот начинает среди деревьев. Стволы не должны
	# попадать на дорогу (|x| >= 3) — то же правило, что и для основного леса.
	for i in 10:
		var angle := TAU * float(i) / 10.0 + 0.35
		var radius := rng.randf_range(3.6, 5.4)
		var pos := SPAWN + Vector3(sin(angle) * radius, 0, cos(angle) * radius * 0.8)
		if absf(pos.x) < 3.2:
			pos.x = (3.2 + rng.randf_range(0.0, 0.6)) * (1.0 if pos.x >= 0.0 else -1.0)
		_tree(forest, pos, trunk, crown, crown_light, rng)
	for i in 8:
		var side := 1.0 if i % 2 == 0 else -1.0
		var pos := Vector3(side * rng.randf_range(3.8, 6.5), 0, rng.randf_range(9.0, 12.4))
		if rng.randf() < 0.5:
			Art.box(forest, Vector3(pos.x, 0.28, pos.z), Vector3(1.1, 0.56, 0.9), bush)
			Art.box(forest, Vector3(pos.x + 0.08, 0.62, pos.z), Vector3(0.7, 0.28, 0.6), crown_light)
		else:
			_tree(forest, pos, trunk, crown, crown_light, rng)
	# Тропа от края дороги вглубь леса: сужается и слегка петляет к спавну.
	for i in 10:
		var t := float(i) / 9.0
		var z := lerpf(Route.world_z(TRAIL_ROAD_Z), TRAIL_FOREST_Z, t)
		var wobble := sin(t * 9.0) * 0.35
		Art.box(forest, Vector3(wobble, 0.028, z), Vector3(1.7 - 0.4 * t, 0.05, 1.6), moss)
	# Плотные края оставляют проходимой только отмеченную тропу.
	var boundaries := Node3D.new()
	boundaries.name = "TrailBoundaries"
	forest.add_child(boundaries)
	for i in 23:
		var z := lerpf(Route.world_z(TRAIL_ROAD_Z), TRAIL_FOREST_Z, float(i) / 22.0)
		for side in [-1.0, 1.0]:
			Art.box(boundaries, Vector3(side * 2.55, 0.42, z), Vector3(1.1, 0.84, 1.45), bush, true)

static func _tree(parent: Node3D, pos: Vector3, trunk: Material, crown: Material,
		crown_light: Material, rng: RandomNumberGenerator) -> void:
	var scale := rng.randf_range(0.85, 1.25)
	var tree := Node3D.new()
	tree.position = pos
	parent.add_child(tree)
	Art.box(tree, Vector3(0, 1.45 * scale, 0), Vector3(0.6, 2.9, 0.6) * scale, trunk, true)
	var base := Vector3(0, 3.1 * scale, 0)
	for step in 2:
		var size := Vector3(2.0 - step * 0.5, 1.4, 2.0 - step * 0.45) * scale
		var offset := base + Vector3(rng.randf_range(-0.15, 0.15), step * 1.1 * scale,
			rng.randf_range(-0.15, 0.15))
		Art.box(tree, offset, size, crown)
		Art.box(tree, offset + Vector3(0, size.y * 0.42, 0),
			Vector3(size.x * 0.75, 0.1, size.z * 0.75), crown_light)
