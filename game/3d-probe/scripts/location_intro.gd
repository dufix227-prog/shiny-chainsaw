extends RefCounted

const Art = preload("res://scripts/geometry.gd")
const IntroTraffic = preload("res://scripts/intro_traffic.gd")

const SIGN_TEXT := "через 500 метров клубничные запасы"
const CUTSCENE_SPAWN := Vector3(0, 0.08, 31.0)
const SIGN_STOP := Vector3(0, 0.08, 20.5)
const RELEASE_SPAWN := Vector3(0, 0.08, 9.5)

static func build(parent: Node3D) -> Node3D:
	var intro := Node3D.new()
	intro.name = "PrologueIntro"
	parent.add_child(intro)
	var asphalt := Art.material(Color("4b5052"), true)
	var concrete := Art.material(Color("8e8d80"), true)
	var stone := Art.material(Color("77766d"), true)
	var moss := Art.material(Color("556b3a"), true)
	var wood := Art.material(Color("65472f"), true)
	var paint := Art.material(Color("d4c28e"), true)
	var leaves := Art.material(Color("3f572e"), true)
	var leaves_light := Art.material(Color("526f38"), true)

	var street := Node3D.new()
	street.name = "BusyStreet"
	intro.add_child(street)
	Art.box(street, Vector3(0, -0.08, 31.5), Vector3(22, 0.16, 5), asphalt, true)
	for x in range(-9, 10, 3):
		Art.box(street, Vector3(x, 0.015, 31.5), Vector3(1.3, 0.025, 0.12), paint)
	for side in [-1.0, 1.0]:
		Art.box(street, Vector3(side * 7.5, 1.7, 29.0), Vector3(0.12, 3.4, 0.12), wood)
		Art.box(street, Vector3(side * 7.5, 3.35, 29.0), Vector3(0.8, 0.12, 0.12), wood)
	var traffic := IntroTraffic.new()
	traffic.name = "Traffic"
	traffic.position.z = 31.5
	street.add_child(traffic)

	var stone_trail := Node3D.new()
	stone_trail.name = "StoneTrail"
	intro.add_child(stone_trail)
	for i in 7:
		var z := 28.5 - i * 1.35
		var material := concrete if i < 3 else stone
		Art.box(stone_trail, Vector3(sin(i * 0.8) * 0.12, 0.02, z),
			Vector3(2.1 - i * 0.08, 0.08, 1.42), material, true)

	var forest_trail := Node3D.new()
	forest_trail.name = "ForestTrail"
	intro.add_child(forest_trail)
	for i in 9:
		var t := float(i) / 8.0
		var z := lerpf(19.8, RELEASE_SPAWN.z, t)
		Art.box(forest_trail, Vector3(sin(i * 0.9) * 0.18, 0.025, z),
			Vector3(1.55 - t * 0.25, 0.05, 1.45), moss, true)

	var forest_sides := Node3D.new()
	forest_sides.name = "ForestSides"
	intro.add_child(forest_sides)
	for i in 14:
		var z := 28.0 - i * 1.4
		for side in [-1.0, 1.0]:
			var x: float = side * (2.65 + 0.15 * sin(i * 1.7))
			Art.box(forest_sides, Vector3(x, 0.42, z), Vector3(1.15, 0.84, 1.5), leaves, true)
			if i % 2 == 0:
				_add_tree(forest_sides, Vector3(side * 4.1, 0, z + 0.35), wood, leaves, leaves_light)

	var sign := Node3D.new()
	sign.name = "StrawberrySign"
	sign.position = Vector3(2.1, 0, 20.4)
	intro.add_child(sign)
	Art.box(sign, Vector3(-0.72, 1.05, 0), Vector3(0.12, 2.1, 0.12), wood, true)
	Art.box(sign, Vector3(0, 1.75, 0), Vector3(2.8, 1.15, 0.16), paint)
	var label := Label3D.new()
	label.name = "Text"
	label.text = SIGN_TEXT
	label.font_size = 44
	label.pixel_size = 0.005
	label.position = Vector3(0, 1.75, 0.1)
	label.modulate = Color("302a26")
	label.outline_size = 3
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.add_child(label)
	return intro

static func _add_tree(parent: Node3D, position: Vector3, wood: Material,
		leaves: Material, leaves_light: Material) -> void:
	var tree := Node3D.new()
	tree.position = position
	parent.add_child(tree)
	Art.box(tree, Vector3(0, 1.35, 0), Vector3(0.55, 2.7, 0.55), wood, true)
	Art.box(tree, Vector3(0, 3.0, 0), Vector3(1.7, 1.45, 1.6), leaves)
	Art.box(tree, Vector3(0.15, 3.8, 0), Vector3(1.25, 0.9, 1.2), leaves_light)
