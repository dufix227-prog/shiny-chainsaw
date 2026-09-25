extends Node3D

## Проба Forward+ (эксперимент по запросу автора 11.09.2026, не канон и не
## часть открытого 500-метрового маршрута): закрытая пещера с факелами,
## деревянным мечом в левой лапе и текущим кодовым котом. Показывает
## glow/SSAO/volumetric fog — эти эффекты недоступны на GL Compatibility
## (текущий рендерер проекта, выбран ради Web-предпросмотра). Стены/пол/меч
## используют настоящие фото-текстуры CC0 (ambientCG, реестр ассетов) вместо
## процедурной заливки цветом — просьба автора «реальные хорошие текстуры»
## 12.09.2026. STAGE1_CAPTURE=/путь.png — кадр.

const Art = preload("res://scripts/geometry.gd")
const Cat = preload("res://scripts/cat.gd")
const ProbeInput = preload("res://scripts/probe_input.gd")

const TORCH_POSITIONS := [
	{"pos": Vector3(2.9, 1.6, 2.2), "side": -1.0},
	{"pos": Vector3(-2.9, 1.55, -1.5), "side": 1.0},
	{"pos": Vector3(2.9, 1.65, -5.5), "side": -1.0},
	{"pos": Vector3(-2.85, 1.5, -9.5), "side": 1.0},
]

var cat: Cat
var camera: Camera3D
var capture_path := ""
var flicker_lights: Array[OmniLight3D] = []
var flicker_base: Array[float] = []
var flicker_phase: Array[float] = []

func _ready() -> void:
	ProbeInput.install()
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	_build_environment()
	_build_cave()
	for torch in TORCH_POSITIONS:
		_build_torch(torch.pos, torch.side)
	_build_cat_with_sword()
	_build_camera()

func _material(color: Color, rough: float = 0.92) -> StandardMaterial3D:
	var mat := Art.material(color, true)
	mat.roughness = rough
	return mat

## Тёмная замкнутая пещера: без солнца, весь свет — от факелов. Glow/SSAO/
## volumetric fog дают объёмные лучи и мягкое рассеивание — то, чего нет
## на Compatibility.
func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.008, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.15, 0.16)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.82
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.7, 0.62, 0.5)
	env.volumetric_fog_emission = Color(0.35, 0.2, 0.09)
	env.volumetric_fog_emission_energy = 0.22
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_length = 26.0
	env.volumetric_fog_detail_spread = 1.6
	world_env.environment = env
	add_child(world_env)

## Неровный блочный тоннель (сплошные стены StaticBody, как в остальных
## пробах): пол + рваные боковые сегменты разной высоты/глубины + частичный
## потолок в дальней части — силуэт читается только светом факелов. Тоннель
## начинается у z=+5 (за камерой) и уходит в глубину — камера всегда внутри
## стен, без открытого проёма позади кота. Пол и стены — настоящие фото-
## текстуры CC0 (ambientCG): мшистый камень на стенах/потолке, грунтовая
## тропа на полу.
func _build_cave() -> void:
	var floor_mat := Art.textured_material("ground107", 1.6)
	var rock_mat := Art.textured_material("rock063", 1.1)
	var rock_mat_dark := Art.textured_material("rock063", 1.3)
	rock_mat_dark.albedo_color = Color(0.72, 0.72, 0.72)
	Art.box(self, Vector3(0, -0.1, -6.0), Vector3(6.0, 0.2, 34.0), floor_mat, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 411
	for i in 16:
		var z := 4.0 - i * 2.0
		var height_l := rng.randf_range(2.2, 3.7)
		var height_r := rng.randf_range(2.2, 3.7)
		var depth_l := rng.randf_range(0.9, 1.6)
		var depth_r := rng.randf_range(0.9, 1.6)
		var mat_l := rock_mat if i % 2 == 0 else rock_mat_dark
		var mat_r := rock_mat_dark if i % 2 == 0 else rock_mat
		Art.box(self, Vector3(-3.0 - depth_l * 0.5, height_l * 0.5 - 0.1, z), Vector3(depth_l, height_l, 1.9), mat_l, true)
		Art.box(self, Vector3(3.0 + depth_r * 0.5, height_r * 0.5 - 0.1, z), Vector3(depth_r, height_r, 1.9), mat_r, true)
	for i in 5:
		var z := -11.0 - i * 2.6
		Art.box(self, Vector3(0, 4.3, z), Vector3(6.4, 1.0, 2.0), rock_mat_dark, true)

## Факел на стене: деревянная рукоять (текстура коры) + светящееся ядро
## пламени + OmniLight3D с мягким мерцанием ( _process ). wall_side
## определяет, к какой стене крепится (для будущего разворота рукояти к
## центру тоннеля).
func _build_torch(pos: Vector3, wall_side: float) -> void:
	var torch := Node3D.new()
	torch.position = pos
	torch.rotation.z = -0.12 * wall_side
	add_child(torch)
	Art.box(torch, Vector3.ZERO, Vector3(0.12, 0.62, 0.12), Art.textured_material("bark012", 0.5))
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.55, 0.16)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.5, 0.12)
	flame_mat.emission_energy_multiplier = 4.5
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.135
	flame_mesh.height = 0.3
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 8
	flame.mesh = flame_mesh
	flame.material_override = flame_mat
	flame.position = Vector3(0, 0.42, 0)
	torch.add_child(flame)
	var embers := GPUParticles3D.new()
	embers.position = flame.position
	embers.amount = 14
	embers.lifetime = 1.4
	embers.emitting = true
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 18.0
	particle_mat.initial_velocity_min = 0.25
	particle_mat.initial_velocity_max = 0.55
	particle_mat.gravity = Vector3(0, 0.4, 0)
	particle_mat.scale_min = 0.02
	particle_mat.scale_max = 0.05
	particle_mat.color = Color(1.0, 0.6, 0.2)
	embers.process_material = particle_mat
	embers.draw_pass_1 = SphereMesh.new()
	torch.add_child(embers)
	var light := OmniLight3D.new()
	light.position = flame.position
	light.light_color = Color(1.0, 0.72, 0.45)
	light.light_energy = 2.4
	light.omni_range = 6.0
	light.shadow_enabled = true
	torch.add_child(light)
	flicker_lights.append(light)
	flicker_base.append(light.light_energy)
	flicker_phase.append(randf() * TAU)

## Деревянный меч (не металл — просьба автора) в левой лапе; правая лапа
## сохраняет канонический дорожный посох из cat.gd нетронутым. hand's local
## +Z становится мировым −Z после разворота кота на 180°, поэтому меч
## смещён в local −Z, чтобы клинок читался со стороны камеры, а не прятался
## за корпусом. Рукоять/гарда — текстура коры (та же, что у факелов).
func _build_sword(hand: Node3D) -> void:
	var sword := Node3D.new()
	hand.add_child(sword)
	sword.position = Vector3(0.05, -0.42, -0.24)
	sword.rotation.x = 0.55
	sword.rotation.z = 0.18
	var pale_wood := _material(Color("d8b978"))
	var dark_wood := Art.textured_material("bark012", 0.4)
	Art.box(sword, Vector3(0, 0.34, 0), Vector3(0.055, 0.9, 0.055), pale_wood)
	Art.box(sword, Vector3(0, -0.11, 0), Vector3(0.24, 0.06, 0.06), dark_wood)
	Art.box(sword, Vector3(0, -0.28, 0), Vector3(0.065, 0.3, 0.065), dark_wood)

func _build_cat_with_sword() -> void:
	cat = Cat.new()
	cat.name = "ProbeCat"
	add_child(cat)
	cat.position = Vector3(0, 0.05, 1.4)
	cat.visual.rotation.y = PI
	_build_sword(cat.arms[0])

func _build_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)
	# Кот развёрнут на 180° (лицом в тоннель), поэтому его левая лапа с
	# мечом (arms[0]) оказывается на мировой +X стороне — камера должна
	# быть с той же стороны, иначе тело кота закрывает меч.
	camera.position = Vector3(1.7, 1.5, 3.9)
	camera.look_at(Vector3(0.1, 1.15, 0.2), Vector3.UP)
	camera.current = true
	camera.far = 60
	camera.fov = 58

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in flicker_lights.size():
		var light := flicker_lights[i]
		var base: float = flicker_base[i]
		var phase: float = flicker_phase[i]
		light.light_energy = base * (0.86 + 0.14 * sin(t * 6.2 + phase) + 0.06 * sin(t * 13.7 + phase * 1.7))
	if capture_path.is_empty():
		return
	set_process(false)
	for i in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(capture_path)
	print("STAGE1_CAPTURE saved: ", capture_path)
	get_tree().quit()
