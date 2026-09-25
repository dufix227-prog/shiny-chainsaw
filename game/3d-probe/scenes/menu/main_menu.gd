extends Control

## Главное меню: фон-картинка, версия слева сверху, кнопки.
## Настройки и снимки — общие сцены (те же открываются из паузы).

const INTRO_CUTSCENE := "res://scenes/cutscene/intro.tscn"
## Техническое имя, если игрок оставил поле пустым (как в прежней пробе).
const DEFAULT_HERO_NAME := "Кот"

@onready var main_buttons: Control = %MainButtons
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var name_panel: Control = %NamePanel
@onready var name_field: LineEdit = %NameField
@onready var start_button: Button = %StartButton
@onready var name_back_button: Button = %NameBackButton
@onready var settings_menu: Control = %SettingsMenu
@onready var save_menu: Control = %SaveMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameSettings.apply_to_world(self)
	new_game_button.pressed.connect(_ask_name)
	continue_button.pressed.connect(_continue)
	load_button.pressed.connect(_open_submenu.bind(save_menu, save_menu.Mode.LOAD))
	settings_button.pressed.connect(_open_submenu.bind(settings_menu, null))
	quit_button.pressed.connect(get_tree().quit)
	start_button.pressed.connect(_start_new_game)
	name_field.text_submitted.connect(func(_text: String): _start_new_game())
	name_back_button.pressed.connect(_show_main.bind(new_game_button))
	settings_menu.closed.connect(_show_main.bind(settings_button))
	save_menu.closed.connect(_show_main.bind(load_button))
	_refresh_save_buttons()
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if name_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_show_main(new_game_button)
		get_viewport().set_input_as_handled()


func _refresh_save_buttons() -> void:
	var has_saves := SaveGame.latest_slot() > 0
	continue_button.disabled = not has_saves
	load_button.disabled = not has_saves
	continue_button.tooltip_text = "" if has_saves else "Сохранений пока нет"


func _ask_name() -> void:
	main_buttons.visible = false
	name_panel.visible = true
	name_field.grab_focus()


func _start_new_game() -> void:
	var hero := name_field.text.strip_edges()
	SaveGame.start_new_game(hero if not hero.is_empty() else DEFAULT_HERO_NAME)
	get_tree().change_scene_to_file(INTRO_CUTSCENE)


func _continue() -> void:
	SaveGame.load_slot(SaveGame.latest_slot())


func _open_submenu(menu: Control, mode: Variant) -> void:
	main_buttons.visible = false
	if mode == null:
		menu.open()
	else:
		menu.open(mode)


func _show_main(focus: Button) -> void:
	name_panel.visible = false
	main_buttons.visible = true
	_refresh_save_buttons()
	focus.grab_focus()
