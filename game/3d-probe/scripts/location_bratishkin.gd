class_name LocationBratishkin
extends RefCounted

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const METRES := 189.0

static func build(world: Node3D) -> Node3D:
	var location := Node3D.new()
	location.name = "BratishkinHouse"
	location.position = Vector3(7.0, 0, Route.world_z(METRES))
	location.set_meta("landmark", true)
	world.add_child(location)
	var wall := Art.material(Color("756353"), true)
	var roof := Art.material(Color("343238"), true)
	var wood := Art.material(Color("49372d"), true)
	Art.box(location, Vector3(0, 1.7, 0), Vector3(5.6, 3.4, 5.2), wall, true)
	Art.box(location, Vector3(0, 3.65, 0), Vector3(6.2, 0.7, 5.8), roof)
	var door := Art.box(location, Vector3(-2.83, 1.05, 0), Vector3(0.14, 2.1, 1.2), wood)
	door.name = "FrontDoor"
	var pig_pen := Node3D.new()
	pig_pen.name = "PigPen"
	pig_pen.position = Vector3(0, 0, Route.world_z(205.0) - location.position.z)
	location.add_child(pig_pen)
	for fence in [Vector4(-2.4, 0, 0.18, 5.0), Vector4(2.4, 0, 0.18, 5.0),
			Vector4(0, -2.4, 4.8, 0.18), Vector4(0, 2.4, 4.8, 0.18)]:
		Art.box(pig_pen, Vector3(fence.x, 0.55, fence.y), Vector3(fence.z, 1.1, fence.w), wood, true)
	return location
