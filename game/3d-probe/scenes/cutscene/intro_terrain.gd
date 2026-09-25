extends RefCounted

## Земля стартовой катсцены: оживлённая улица (дорога и тротуары вдоль оси X),
## от северного тротуара в лес уходит тропа — сначала бетонные плиты, потом
## лесная (канон автора 09.09.2026: «тропа сначала бетон/камень, потом лесная»).

const Mesher = preload("res://scenes/voxel/voxel_mesher.gd")
const Recipes = preload("res://scenes/style_probe/voxel_recipes.gd")

const X_MIN := -150.0
const X_MAX := 60.0
const Z_MIN := -95.0
const Z_MAX := 34.0
const ROAD_HALF := 5.0
const SIDEWALK_OUTER := 8.0
## Где бетон тропы переходит в лесную тропу.
const CONCRETE_END_Z := -28.0
const LAYER := 0.25

const ASPHALT := ["#37373b", "#3f3f43", "#48484c"]
const ROAD_PAINT := "#e6e0c6"
const SIDEWALK := ["#a8a296", "#b3ada1", "#bdb7ab"]
const CURB := "#8f897f"
const CONCRETE := ["#96928a", "#a39f97", "#aeaaa2"]
const DIRT := ["#6e4526", "#7d5130", "#8d5d37", "#9c6a40"]

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


func trail_half_width(z: float) -> float:
	# Бетонная дорожка 4 единицы, лесная тропа шире — как в игре.
	return 2.0 if z > CONCRETE_END_Z else lerpf(2.0, 4.0, clampf((CONCRETE_END_Z - z) / 10.0, 0.0, 1.0))


func is_trail(x: float, z: float) -> bool:
	return z < -SIDEWALK_OUTER and absf(x - trail_center_x(z)) < trail_half_width(z)


func is_street(z: float) -> bool:
	return absf(z) < SIDEWALK_OUTER


func height(x: float, z: float) -> float:
	if absf(z) < ROAD_HALF:
		return 0.0
	if absf(z) < SIDEWALK_OUTER or is_trail(x, z):
		return LAYER
	var from_trail := absf(x - trail_center_x(z)) - trail_half_width(z)
	var away := minf(absf(z) - SIDEWALK_OUTER, from_trail if z < 0 else 99.0)
	return snappedf(LAYER + maxf(_noise.get_noise_2d(x, z), 0.0) * 1.0 * smoothstep(1.0, 5.0, away), LAYER)


func color(x: float, z: float, y: float) -> Color:
	var top := y >= height(x, z) - LAYER - 0.01
	if absf(z) < ROAD_HALF:
		var center_dash := absf(z) < 0.3 and fposmod(x, 4.0) < 2.0
		var edge_line := absf(absf(z) - 4.5) < 0.3
		if top and (center_dash or edge_line):
			return Color(ROAD_PAINT)
		return Recipes._pick(ASPHALT, _rng, 0.5)
	if absf(z) < SIDEWALK_OUTER:
		if absf(z) < ROAD_HALF + 0.5:
			return Color(CURB)
		var seam := fposmod(x, 1.5) < 0.5
		return Recipes._pick(SIDEWALK, _rng, 0.2 if seam else 0.6)
	if not top:
		return Recipes._pick(DIRT, _rng, 0.3)
	if is_trail(x, z):
		if z > CONCRETE_END_Z:
			# Плиты 1,5 в длину с травяными щелями между ними.
			var gap := fposmod(z, 2.0) < 0.5
			return Recipes._pick(Recipes.GRASS, _rng, 0.5) if gap else Recipes._pick(CONCRETE, _rng, 0.5)
		return Recipes._pick(DIRT, _rng, 0.4 + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5)
	return Recipes._pick(Recipes.GRASS, _rng, 0.45 + _noise.get_noise_2d(x * 0.6, z * 0.6) * 0.6)


func build_ground() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	Mesher.height_field(X_MIN, X_MAX, Z_MIN, Z_MAX, 0.5, LAYER, height, color).commit(mesh, Recipes.VOXEL)
	return mesh
