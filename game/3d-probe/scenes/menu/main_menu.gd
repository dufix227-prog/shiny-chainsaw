extends Control

## Главное меню: фон-картинка, версия слева сверху, кнопки и окно настроек.

const FIRST_SECTION := "res://scenes/world/first40.tscn"

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var main_buttons: Control = %MainButtons
@onready var settings_panel: Control = %SettingsPanel
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var invert_check: CheckBox = %InvertCheck
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var settings_back_button: Button = %SettingsBackButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	new_game_button.pressed.connect(_start_new_game)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(get_tree().quit)
	settings_back_button.pressed.connect(_close_settings)
	# Сохранений пока нет — кнопка честно неактивна, а не ведёт в пустоту.
	continue_button.disabled = true
	settings_panel.visible = false
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_close_settings()
		get_viewport().set_input_as_handled()


func _start_new_game() -> void:
	get_tree().change_scene_to_file(FIRST_SECTION)


func _open_settings() -> void:
	sensitivity_slider.value = GameSettings.mouse_sensitivity
	invert_check.button_pressed = GameSettings.invert_camera_y
	fullscreen_check.button_pressed = GameSettings.fullscreen
	volume_slider.value = GameSettings.master_volume
	main_buttons.visible = false
	settings_panel.visible = true
	sensitivity_slider.grab_focus()


func _close_settings() -> void:
	GameSettings.mouse_sensitivity = sensitivity_slider.value
	GameSettings.invert_camera_y = invert_check.button_pressed
	GameSettings.fullscreen = fullscreen_check.button_pressed
	GameSettings.master_volume = volume_slider.value
	GameSettings.apply()
	GameSettings.save_settings()
	settings_panel.visible = false
	main_buttons.visible = true
	settings_button.grab_focus()
