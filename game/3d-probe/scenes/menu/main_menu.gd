extends Control

## Главное меню: фон-картинка, версия слева сверху, кнопки.
## «Продолжить» — одна кнопка: последний снимок или выбор другого
## (просьба автора 25.09.2026 вместо двух кнопок «Продолжить» и «Загрузить»).
## «Новая игра» — имя и модель котика (с превью и мимикой), затем катсцена.
## Настройки и снимки — общие сцены (те же открываются из паузы).

const CatModel = preload("res://scenes/player/cat_model.gd")
const INTRO_CUTSCENE := "res://scenes/cutscene/intro.tscn"
## Техническое имя, если игрок оставил поле пустым (как в прежней пробе).
const DEFAULT_HERO_NAME := "Кот"

var _variant_index := 0

@onready var main_buttons: Control = %MainButtons
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var name_panel: Control = %NamePanel
@onready var name_field: LineEdit = %NameField
@onready var model_name: Label = %ModelName
@onready var previous_model: Button = %PreviousModel
@onready var next_model: Button = %NextModel
@onready var emotion_button: Button = %EmotionButton
@onready var cat_preview: Node3D = %CatPreview
@onready var start_button: Button = %StartButton
@onready var name_back_button: Button = %NameBackButton
@onready var continue_panel: Control = %ContinuePanel
@onready var latest_button: Button = %LatestButton
@onready var other_saves_button: Button = %OtherSavesButton
@onready var continue_back_button: Button = %ContinueBackButton
@onready var settings_menu: Control = %SettingsMenu
@onready var save_menu: Control = %SaveMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameSettings.apply_to_world(self)
	new_game_button.pressed.connect(_ask_name)
	continue_button.pressed.connect(_open_continue)
	settings_button.pressed.connect(_open_submenu.bind(settings_menu, null))
	quit_button.pressed.connect(get_tree().quit)
	start_button.pressed.connect(_start_new_game)
	name_field.text_submitted.connect(func(_text: String): _start_new_game())
	name_back_button.pressed.connect(_show_main.bind(new_game_button))
	previous_model.pressed.connect(_change_variant.bind(-1))
	next_model.pressed.connect(_change_variant.bind(1))
	emotion_button.pressed.connect(func(): emotion_button.text = "Мимика: " + cat_preview.next_emotion())
	latest_button.pressed.connect(func(): SaveGame.load_slot(SaveGame.latest_slot()))
	other_saves_button.pressed.connect(_open_submenu.bind(save_menu, save_menu.Mode.LOAD))
	continue_back_button.pressed.connect(_show_main.bind(continue_button))
	settings_menu.closed.connect(_show_main.bind(settings_button))
	save_menu.closed.connect(_show_main.bind(continue_button))
	_refresh_save_buttons()
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var cancel := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	if cancel and (name_panel.visible or continue_panel.visible):
		_show_main(new_game_button if name_panel.visible else continue_button)
		get_viewport().set_input_as_handled()


func _refresh_save_buttons() -> void:
	var has_saves := SaveGame.latest_slot() > 0
	continue_button.disabled = not has_saves
	continue_button.tooltip_text = "" if has_saves else "Сохранений пока нет"


func _open_continue() -> void:
	var slot := SaveGame.latest_slot()
	var data := SaveGame.read_slot(slot)
	var date := Time.get_datetime_string_from_unix_time(int(data.saved_at), true).replace("T", " ").substr(0, 16)
	latest_button.text = "Последнее: %s · %s · %d м" % [data.title, date, roundi(data.metres)]
	main_buttons.visible = false
	continue_panel.visible = true
	latest_button.grab_focus()


func _ask_name() -> void:
	main_buttons.visible = false
	name_panel.visible = true
	_show_variant()
	name_field.grab_focus()


func _change_variant(step: int) -> void:
	var ids: Array = CatModel.VARIANT_NAMES.keys()
	_variant_index = wrapi(_variant_index + step, 0, ids.size())
	_show_variant()


func _show_variant() -> void:
	var ids: Array = CatModel.VARIANT_NAMES.keys()
	var id: String = ids[_variant_index]
	model_name.text = "%s  (%d из %d)" % [CatModel.VARIANT_NAMES[id], _variant_index + 1, ids.size()]
	cat_preview.show_variant(id)


func _start_new_game() -> void:
	var hero := name_field.text.strip_edges()
	var variant: String = CatModel.VARIANT_NAMES.keys()[_variant_index]
	SaveGame.start_new_game(hero if not hero.is_empty() else DEFAULT_HERO_NAME, variant)
	get_tree().change_scene_to_file(INTRO_CUTSCENE)


func _open_submenu(menu: Control, mode: Variant) -> void:
	main_buttons.visible = false
	continue_panel.visible = false
	if mode == null:
		menu.open()
	else:
		menu.open(mode)


func _show_main(focus: Button) -> void:
	name_panel.visible = false
	continue_panel.visible = false
	main_buttons.visible = true
	_refresh_save_buttons()
	focus.grab_focus()
