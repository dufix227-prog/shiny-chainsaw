extends Node

## Настройки игрока. Хранятся в user://settings.cfg и переживают перезапуск.
## Подключён как автозагрузка GameSettings (project.godot).

const SETTINGS_PATH := "user://settings.cfg"
const PIXEL_SIZES := [1, 2, 3, 4]

signal changed

var mouse_sensitivity := 0.25
var invert_camera_y := false
var fullscreen := false
var master_volume := 0.8
## Размер пикселя картинки: 1 — без пикселизации, 4 — самые крупные пиксели.
var pixel_size := 1


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	mouse_sensitivity = file.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	invert_camera_y = file.get_value("controls", "invert_camera_y", invert_camera_y)
	fullscreen = file.get_value("video", "fullscreen", fullscreen)
	master_volume = file.get_value("audio", "master_volume", master_volume)
	pixel_size = file.get_value("video", "pixel_size", pixel_size)


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("controls", "invert_camera_y", invert_camera_y)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("audio", "master_volume", master_volume)
	file.set_value("video", "pixel_size", pixel_size)
	file.save(SETTINGS_PATH)


func apply() -> void:
	# В headless-проверках окна нет, менять режим экрана незачем.
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
	changed.emit()
