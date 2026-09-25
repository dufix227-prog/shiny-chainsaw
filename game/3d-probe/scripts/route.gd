extends RefCounted

## Маршрут пролога: 500 м дороги (6120 ед. мира) за ~30 минут чистой ходьбы
## при 3,4 ед./с — рабочий скелет К1 из game/ПЛАН-ПРОЛОГА.md.
##
## Метры сцены — только привязки к карте. Сами сцены (К2+) не реализованы:
## метка появляется на карте по факту физической встречи кота с зоной.

const ORIGIN_Z := 7.0
const LENGTH := 500.0
const WORLD_UNITS_PER_METRE := 12.24
const WORLD_LENGTH := LENGTH * WORLD_UNITS_PER_METRE
const END_Z := ORIGIN_Z - WORLD_LENGTH
const CELL := 2.0

## Метры утверждены автором 09.09.2026; фывфыв находится у фермы и не имеет
## отдельной дорожной метки.
const SCENES := [
	{"id": "forest", "metres": 0.0, "discovered_from_start": true},
	{"id": "church", "metres": 40.0, "discovered_from_start": false},
	{"id": "stint", "metres": 100.0, "discovered_from_start": false},
	{"id": "bratishkin", "metres": 189.0, "discovered_from_start": false},
	{"id": "fishing", "metres": 260.0, "discovered_from_start": false},
	{"id": "farm", "metres": 500.0, "discovered_from_start": false},
	{"id": "end", "metres": 500.0, "discovered_from_start": false},
]

var discovered: Dictionary = {}
var encountered := {}


static func metres(pos: Vector3) -> float:
	return clampf((ORIGIN_Z - pos.z) / WORLD_UNITS_PER_METRE, 0.0, LENGTH)


static func world_z(progress: float) -> float:
	return ORIGIN_Z - progress * WORLD_UNITS_PER_METRE


static func scene_position(scene: Dictionary) -> Vector3:
	return Vector3(0, 0, world_z(scene.metres))


static func scene_cell(scene: Dictionary) -> Vector2i:
	var pos := scene_position(scene)
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


## Встреча с зоной = физически осмотренные клетки вокруг её центра.
## Дальность 2 клетки (4 ед.) — чуть меньше радиуса обычного открытия,
## чтобы метка появлялась от посещения, а не от дальнего края видимости.
static func encounter_radius_cells() -> int:
	return 2


func _scene_met(scene: Dictionary) -> bool:
	if scene.discovered_from_start:
		return true
	var cell := scene_cell(scene)
	for x in range(cell.x - encounter_radius_cells(), cell.x + encounter_radius_cells() + 1):
		for z in range(cell.y - encounter_radius_cells(), cell.y + encounter_radius_cells() + 1):
			if discovered.has(Vector2i(x, z)):
				return true
	return false


## Идентификаторы сцен, показанных на карте сейчас (встреченные).
func visible_scene_ids() -> Array:
	var ids: Array = []
	for scene in SCENES:
		if _scene_met(scene):
			ids.append(scene.id)
	return ids


## Однократная фиксация встречи — для будущих счётчиков прохождения.
func record_encounters() -> void:
	for scene in SCENES:
		if _scene_met(scene):
			encountered[scene.id] = true


func discover(pos: Vector3) -> void:
	var center := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for x in range(center.x - 2, center.x + 3):
		for z in range(center.y - 2, center.y + 3):
			if Vector2i(x, z).distance_to(center) <= 2.4:
				discovered[Vector2i(x, z)] = true


func reset() -> void:
	discovered.clear()
	encountered.clear()
