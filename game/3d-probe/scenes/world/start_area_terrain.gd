extends RefCounted

## Форма стартового места: оживлённая улица вдоль оси X и тропа, уходящая от
## северного тротуара в лес — сначала бетонные плиты, потом лесная (канон
## автора 09.09.2026). Одна и та же форма для катсцены и для игры: поэтому
## управление начинается ровно там, где кончилась катсцена.
##
## Где можно ходить: улица с тротуарами, тропа с полосой леса по бокам.
## Всё остальное круто поднимается склоном (круче, чем кот может залезть).
## На концах улицы дорога уходит в ущелье и тоннель.

const Mesher = preload("res://scenes/voxel/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const ROAD_HALF := 5.0
const SIDEWALK_OUTER := 8.0
## Полоса травы между тротуаром и склоном.
const STREET_OPEN_HALF := 13.0
## Докуда улица открыта; дальше — ущелье до тоннеля.
const STREET_OPEN_X := 95.0
const TUNNEL_X := 118.0
## Где бетон тропы переходит в лесную тропу.
const CONCRETE_END_Z := -28.0
## От середины тропы до склона.
const CORRIDOR_HALF := 18.0
## Конец тропы в этом куске; дальше подъём.
const TRAIL_END_Z := -215.0
## Подъём склона на единицу расстояния от проходимого места.
const SLOPE_STEEPNESS := 1.6
## Выше склон не поднимается: за гребнем его всё равно не видно.
const SLOPE_MAX_DISTANCE := 16.0
const LAYER := 0.25

## Табличка «через 500 метров клубничные запасы» — у входа на тропу.
const SIGN_POSITION := Vector3(3.4, 0.25, -11.5)
const SIGN_YAW := -0.4

const ASPHALT := ["#37373b", "#3f3f43", "#48484c"]
const ROAD_PAINT := "#e6e0c6"
const SIDEWALK := ["#a8a296", "#b3ada1", "#bdb7ab"]
const CURB := "#8f897f"
const CONCRETE := ["#96928a", "#a39f97", "#aeaaa2"]
const DIRT := ["#6e4526", "#7d5130", "#8d5d37", "#9c6a40"]
const CLIFF_ROCK := ["#5b4a42", "#6a574c", "#786357", "#877063", "#94806f"]

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_noise.seed = 31
	_noise.frequency = 0.09
	_rng.seed = 31


func trail_center_x(z: float) -> float:
	if z > CONCRETE_END_Z:
		return 0.0
	return sin((z - CONCRETE_END_Z) * 0.05) * 2.5


## Полуширина тропы: бетонная дорожка 4, лесная тропа шире и меняет ширину.
func trail_half_width(z: float) -> float:
	if z > CONCRETE_END_Z:
		return 2.0
	var widening := clampf((CONCRETE_END_Z - z) / 10.0, 0.0, 1.0)
	return lerpf(2.0, 4.2 + 0.9 * sin(z * 0.07), widening)


func is_trail(x: float, z: float) -> bool:
	return z < -SIDEWALK_OUTER and z > TRAIL_END_Z and absf(x - trail_center_x(z)) < trail_half_width(z)


func is_street(z: float) -> bool:
	return absf(z) < SIDEWALK_OUTER


## Насколько точка дальше проходимого места (0 — внутри).
func distance_outside(x: float, z: float) -> float:
	var street := Vector2(maxf(absf(x) - STREET_OPEN_X, 0.0), maxf(absf(z) - STREET_OPEN_HALF, 0.0)).length()
	var canyon := Vector2(maxf(absf(x) - TUNNEL_X - 8.0, 0.0), maxf(absf(z) - ROAD_HALF, 0.0)).length()
	var along := maxf(TRAIL_END_Z - z, 0.0) + maxf(z + SIDEWALK_OUTER, 0.0)
	var trail := Vector2(maxf(absf(x - trail_center_x(z)) - CORRIDOR_HALF, 0.0), along).length()
	return minf(street, minf(canyon, trail))


func height(x: float, z: float) -> float:
	var outside := distance_outside(x, z)
	if absf(z) < ROAD_HALF and outside == 0.0:
		return 0.0
	var base := LAYER
	if not is_trail(x, z) and not is_street(z):
		var from_trail := absf(x - trail_center_x(z)) - trail_half_width(z)
		var away := minf(absf(z) - SIDEWALK_OUTER, from_trail if z < 0.0 else 99.0)
		base += maxf(_noise.get_noise_2d(x, z), 0.0) * smoothstep(1.0, 5.0, away)
	return snappedf(base + minf(outside, SLOPE_MAX_DISTANCE) * SLOPE_STEEPNESS, LAYER)


func color(x: float, z: float, y: float) -> Color:
	var top_height := height(x, z)
	var top := y >= top_height - LAYER - 0.01
	if absf(z) < ROAD_HALF and top_height < 0.1:
		var center_dash := absf(z) < 0.3 and fposmod(x, 4.0) < 2.0
		var edge_line := absf(absf(z) - 4.5) < 0.3
		if top and (center_dash or edge_line):
			return Color(ROAD_PAINT)
		return Recipes._pick(ASPHALT, _rng, 0.5)
	if absf(z) < SIDEWALK_OUTER and absf(x) < STREET_OPEN_X:
		if absf(z) < ROAD_HALF + 0.5:
			return Color(CURB)
		var seam := fposmod(x, 1.5) < 0.5
		return Recipes._pick(SIDEWALK, _rng, 0.2 if seam else 0.6)
	# Крутые места и низ склона — камень, пологие — трава.
	var steep := distance_outside(x, z) > 0.5 and not top
	if steep or (not top and y < top_height - 1.0):
		return Recipes._pick(CLIFF_ROCK, _rng, 0.5 + sin(y * 0.9) * 0.3)
	if not top:
		return Recipes._pick(DIRT, _rng, 0.3)
	if is_trail(x, z):
		if z > CONCRETE_END_Z:
			# Плиты с травяными щелями между ними.
			var gap := fposmod(z, 2.0) < 0.5
			return Recipes._pick(Recipes.GRASS, _rng, 0.5) if gap else Recipes._pick(CONCRETE, _rng, 0.5)
		return Recipes._pick(DIRT, _rng, 0.4 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5)
	return Recipes._pick(Recipes.GRASS, _rng, 0.45 + _noise.get_noise_2d(x * 0.6, z * 0.6) * 0.6)


## Земля — несколько кусков: там, где кот ходит и смотрит вблизи (улица,
## тропа), кубики мелкие (0,5); на склонах — крупнее (1,0), иначе файл земли
## весил бы десятки мегабайт. Куски стыкуются без щелей: по краю у каждого
## столбики уходят вниз «юбкой».
## Возвращает список [имя, меш].
func build_meshes() -> Array:
	var pieces := [
		["StreetGround", -130.0, 130.0, -16.0, 16.0, 0.5],
		["TrailGround", -24.0, 24.0, -240.0, -16.5, 0.5],
		["SouthSlope", -129.75, 129.75, 16.75, 33.75, 1.0],
		["NorthSlopeWest", -129.75, -24.75, -29.75, -16.75, 1.0],
		["NorthSlopeEast", 24.75, 129.75, -29.75, -16.75, 1.0],
		["TrailSlopeWest", -39.75, -24.75, -239.75, -30.75, 1.0],
		["TrailSlopeEast", 24.75, 39.75, -239.75, -30.75, 1.0],
	]
	var result := []
	for piece in pieces:
		var column: float = piece[5]
		var layer := LAYER if column < 0.9 else LAYER * 2.0
		var mesh := ArrayMesh.new()
		Mesher.height_field(piece[1], piece[2], piece[3], piece[4], column, layer, height, color,
			roundi(2.5 / layer)).commit(mesh, Recipes.VOXEL)
		result.append([piece[0], mesh])
	return result


## Коллизия — по той же высоте, но на сетке 1×1 и только там, куда кот может дойти.
func build_collision() -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	_collision_grid(faces, -128.0, 128.0, -30.0, 30.0)
	_collision_grid(faces, -45.0, 45.0, -235.0, -30.0)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


func _collision_grid(faces: PackedVector3Array, x_min: float, x_max: float, z_min: float, z_max: float) -> void:
	var z := z_min
	while z < z_max - 0.01:
		var x := x_min
		while x < x_max - 0.01:
			var a := Vector3(x, height(x, z), z)
			var b := Vector3(x + 1.0, height(x + 1.0, z), z)
			var c := Vector3(x, height(x, z + 1.0), z + 1.0)
			var d := Vector3(x + 1.0, height(x + 1.0, z + 1.0), z + 1.0)
			faces.append_array([a, b, c, b, d, c])
			x += 1.0
		z += 1.0
