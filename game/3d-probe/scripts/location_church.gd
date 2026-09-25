extends RefCounted

## К4: крупная церковь у 40 м. Пока только геометрия без сюжетных реплик,
## награды и системы кармы.

const Art = preload("res://scripts/geometry.gd")
const Route = preload("res://scripts/route.gd")
const Confessional = preload("res://scripts/confessional.gd")

const METRES := 40.0
const CENTRE := Vector3(7.0, 0.0, 0.0)
const WALL_HEIGHT := 10.0
const TOWER_HEIGHT := 18.0

static func build(parent: Node3D) -> Node3D:
	var church := Node3D.new()
	church.name = "Church"
	church.position = Vector3(CENTRE.x, 0, Route.world_z(METRES))
	church.set_meta("landmark", true)
	parent.add_child(church)
	var stone := Art.material(Color("9a9381"), true)
	var stone_dark := Art.material(Color("665f54"), true)
	var roof := Art.material(Color("4f403b"), true)
	var wood := Art.material(Color("5f422d"), true)
	var glass := Art.material(Color("63828b"), true)

	Art.box(church, Vector3(0, 0.08, 0), Vector3(8.0, 0.16, 14.0), stone_dark, true)
	Art.box(church, Vector3(3.8, WALL_HEIGHT * 0.5, 0), Vector3(0.4, WALL_HEIGHT, 14.0), stone, true)
	Art.box(church, Vector3(0, WALL_HEIGHT * 0.5, -6.8), Vector3(8.0, WALL_HEIGHT, 0.4), stone, true)
	Art.box(church, Vector3(0, WALL_HEIGHT * 0.5, 6.8), Vector3(8.0, WALL_HEIGHT, 0.4), stone, true)
	# Западная стена смотрит к дороге; центральный разрыв — настоящий вход.
	for z in [-4.7, 4.7]:
		Art.box(church, Vector3(-3.8, WALL_HEIGHT * 0.5, z), Vector3(0.4, WALL_HEIGHT, 4.6), stone, true)
	Art.box(church, Vector3(-3.8, 8.0, 0), Vector3(0.4, 4.0, 4.8), stone, true)
	var door := Art.box(church, Vector3(-3.15, 2.0, -1.25), Vector3(0.16, 4.0, 2.6), wood)
	door.name = "EntranceDoor"
	door.rotation.y = deg_to_rad(90.0)
	for z in [-4.0, 4.0]:
		Art.box(church, Vector3(-4.02, 6.2, z), Vector3(0.12, 2.5, 1.4), glass)

	var left_roof := Art.box(church, Vector3(-2.0, 10.8, 0), Vector3(4.8, 0.5, 14.8), roof)
	left_roof.rotation.z = deg_to_rad(-24.0)
	var right_roof := Art.box(church, Vector3(2.0, 10.8, 0), Vector3(4.8, 0.5, 14.8), roof)
	right_roof.rotation.z = deg_to_rad(24.0)

	var tower := Node3D.new()
	tower.name = "BellTower"
	tower.position = Vector3(0, 0, -3.8)
	church.add_child(tower)
	Art.box(tower, Vector3(0, 12.5, 0), Vector3(4.0, 11.0, 4.0), stone, true)
	Art.box(tower, Vector3(0, 17.2, 0), Vector3(4.6, 0.8, 4.6), roof)
	var cross := Node3D.new()
	cross.name = "Cross"
	tower.add_child(cross)
	Art.box(cross, Vector3(0, TOWER_HEIGHT + 1.5, 0), Vector3(0.35, 3.4, 0.35), stone_dark)
	Art.box(cross, Vector3(0, TOWER_HEIGHT + 2.0, 0), Vector3(2.2, 0.35, 0.35), stone_dark)
	var confessional := Confessional.new()
	confessional.name = "Confessional"
	church.add_child(confessional)
	confessional.setup_booth(Vector3(1.7, 0.16, 3.8))
	return church
