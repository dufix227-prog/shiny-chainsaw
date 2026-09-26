extends Node

## Настройки игрока: графика, интерфейс, камера, управление, звук. Хранятся в user://settings.cfg
## и переживают перезапуск. Автозагрузка GameSettings (project.godot).
##
## Графика применяется в двух местах:
## - к окну и экрану — apply() (режим окна, VSync, FPS, масштаб, сглаживание, тени);
## - к миру сцены — apply_to_world(scene): тени, туман, SSAO, свечение, яркость
##   (угол обзора и дальность камеры игрока — в cat_player.gd).
##   Каждая игровая сцена вызывает apply_to_world(self) в _ready().

const SETTINGS_PATH := "user://settings.cfg"
## Путь можно подменить (тесты пишут в отдельный файл, не трогая настройки игрока).
var settings_path := SETTINGS_PATH

signal changed

enum WindowMode { WINDOWED, FULLSCREEN, BORDERLESS }
enum Antialiasing { OFF, FXAA, MSAA_2X, MSAA_4X, TAA }
enum Quality { OFF, LOW, MEDIUM, HIGH }
enum UiFont { PIXEL, READABLE, READABLE_BOLD }
enum CameraMode { THIRD_PERSON, BEHIND, FIRST_PERSON, CUSTOM }

## Шрифты интерфейса: [обычный текст, заголовки]. «Обычный» — для читаемости
## (просьба автора 25.09.2026: «не особо читабельный иногда»).
const UI_FONTS := {
	UiFont.PIXEL: ["res://assets/fonts/tiny5/Tiny5-Regular.ttf", "res://assets/fonts/pressstart2p/PressStart2P-Regular.ttf"],
	UiFont.READABLE: ["res://assets/fonts/ptsans/PT_Sans-Web-Regular.ttf", "res://assets/fonts/ptsans/PT_Sans-Web-Bold.ttf"],
	UiFont.READABLE_BOLD: ["res://assets/fonts/ptsans/PT_Sans-Web-Bold.ttf", "res://assets/fonts/ptsans/PT_Sans-Web-Bold.ttf"],
}
const UI_THEME := "res://scenes/ui/menu_theme.tres"
## Громкость настройки → аудиошина (default_bus_layout.tres).
const VOLUME_BUSES := {
	"master_volume": "Master", "music_volume": "Music", "effects_volume": "Effects",
	"ambient_volume": "Ambient", "interface_volume": "Interface", "voice_volume": "Voice",
}

## Все настройки с их значениями по умолчанию. Ключ — [раздел файла, имя].
const DEFAULTS := {
	"window_mode": WindowMode.WINDOWED,
	"vsync": true,
	"max_fps": 0,  # 0 — без ограничения
	"render_scale": 1.0,  # доля разрешения 3D-картинки (0,5–1)
	"antialiasing": Antialiasing.FXAA,
	"shadow_quality": Quality.HIGH,
	"ambient_occlusion": true,
	"glow": true,
	"fog": true,
	"draw_distance": 400.0,
	"field_of_view": 70.0,
	"pixel_size": 1,  # 1 — без пикселизации
	"brightness": 1.0,
	"ui_font": UiFont.PIXEL,
	"ui_scale": 1.0,
	"camera_mode": CameraMode.THIRD_PERSON,
	"camera_distance": 10.0,
	"camera_height": 3.2,
	"camera_side": 0.0,
	"camera_pitch": -20.0,
	"mouse_sensitivity": 0.25,
	"stick_sensitivity": 1.0,
	"invert_camera_y": false,
	"master_volume": 0.8,
	"music_volume": 0.7,
	"effects_volume": 0.8,
	"ambient_volume": 0.7,
	"interface_volume": 0.6,
	"voice_volume": 0.8,
	"mute_unfocused": true,
}
## Раздел файла настроек для каждой настройки (по началу имени).
const SECTIONS := {
	"mouse_sensitivity": "controls", "stick_sensitivity": "controls", "invert_camera_y": "controls",
	"camera_mode": "camera", "camera_distance": "camera", "camera_height": "camera", "camera_side": "camera",
	"camera_pitch": "camera", "ui_font": "interface", "ui_scale": "interface", "mute_unfocused": "audio",
}
const SHADOW_ATLAS_SIZES := {Quality.OFF: 512, Quality.LOW: 1024, Quality.MEDIUM: 2048, Quality.HIGH: 4096}

var values := DEFAULTS.duplicate()

# Удобные имена для кода игры (кот читает чувствительность и инверсию).
var mouse_sensitivity: float:
	get: return values.mouse_sensitivity
var invert_camera_y: bool:
	get: return values.invert_camera_y
var pixel_size: int:
	get: return values.pixel_size


func _ready() -> void:
	load_settings()
	apply()


func get_value(key: String) -> Variant:
	return values[key]


func set_value(key: String, value: Variant) -> void:
	values[key] = value


func reset_to_defaults() -> void:
	values = DEFAULTS.duplicate()


func section_of(key: String) -> String:
	if SECTIONS.has(key):
		return SECTIONS[key]
	return "audio" if key.ends_with("_volume") else "video"


## Звук при свёрнутой игре выключается, если так выбрано в настройках.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and values.mute_unfocused:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(settings_path) != OK:
		return
	for key in DEFAULTS:
		values[key] = file.get_value(section_of(key), key, DEFAULTS[key])


func save_settings() -> void:
	var file := ConfigFile.new()
	for key in DEFAULTS:
		file.set_value(section_of(key), key, values[key])
	file.save(settings_path)


func apply() -> void:
	_apply_window()
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if values.render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = values.render_scale
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if values.antialiasing == Antialiasing.FXAA else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = values.antialiasing == Antialiasing.TAA
	match values.antialiasing:
		Antialiasing.MSAA_2X: viewport.msaa_3d = Viewport.MSAA_2X
		Antialiasing.MSAA_4X: viewport.msaa_3d = Viewport.MSAA_4X
		_: viewport.msaa_3d = Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[values.shadow_quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH if values.shadow_quality == Quality.HIGH else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	Engine.max_fps = values.max_fps
	for key in VOLUME_BUSES:
		var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(values[key], 0.0001)))
	_apply_interface()
	var scene := get_tree().current_scene
	if scene:
		apply_to_world(scene)
	changed.emit()


## Мировые настройки: меняют узлы открытой сцены, а не файлы сцены.
func apply_to_world(scene: Node) -> void:
	for environment_node in scene.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = environment_node.environment
		if environment == null:
			continue
		# Исходные значения сцены запоминаются один раз: настройка только выключает
		# или ослабляет эффект, но не переписывает то, что задал художник.
		if not environment.has_meta("scene_fog"):
			environment.set_meta("scene_fog", environment.fog_enabled)
			environment.set_meta("scene_ssao", environment.ssao_enabled)
			environment.set_meta("scene_glow", environment.glow_enabled)
		environment.fog_enabled = values.fog and environment.get_meta("scene_fog")
		environment.ssao_enabled = values.ambient_occlusion and environment.get_meta("scene_ssao")
		environment.glow_enabled = values.glow and environment.get_meta("scene_glow")
		environment.adjustment_enabled = true
		environment.adjustment_brightness = values.brightness
	for light in scene.find_children("*", "DirectionalLight3D", true, false):
		light.shadow_enabled = values.shadow_quality != Quality.OFF
	# Угол обзора и дальность камеры игрока применяет сам кот (cat_player.gd):
	# у камер катсцен свой угол, выбранный постановкой.


## Шрифт и размер интерфейса. Тема общая для всех экранов, поэтому смена
## шрифта в ней сразу видна везде.
func _apply_interface() -> void:
	var theme: Theme = load(UI_THEME)
	var fonts: Array = UI_FONTS[values.ui_font]
	theme.default_font = load(fonts[0])
	theme.set_font("font", "TitleLabel", load(fonts[1]))
	get_tree().root.content_scale_factor = values.ui_scale


func _apply_window() -> void:
	# В headless-проверках окна нет.
	if DisplayServer.get_name() == "headless":
		return
	match values.window_mode:
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
