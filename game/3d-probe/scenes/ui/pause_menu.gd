extends CanvasLayer

## Пауза: Esc/Start открывает и закрывает; потеря фокуса окна тоже ставит паузу.
## Отсюда же — сохранение, загрузка и настройки (те же сцены, что в главном меню).
## Узел работает и во время паузы (process_mode = Always в сцене).

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"

## Куда игрок хотел уйти, когда выскочило напоминание о сохранении.
enum Leave { NONE, MAIN_MENU, QUIT }

var _leave_target := Leave.NONE

@onready var panel: Control = $Panel
@onready var resume_button: Button = %ResumeButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var save_menu: Control = $SaveMenu
@onready var unsaved_dialog: Control = $UnsavedDialog


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_open_submenu.bind(save_menu, save_menu.Mode.SAVE))
	load_button.pressed.connect(_open_submenu.bind(save_menu, save_menu.Mode.LOAD))
	settings_button.pressed.connect(_open_submenu.bind(settings_menu, null))
	main_menu_button.pressed.connect(_try_leave.bind(Leave.MAIN_MENU))
	quit_button.pressed.connect(_try_leave.bind(Leave.QUIT))
	settings_menu.closed.connect(_back_from_submenu.bind(settings_button))
	save_menu.closed.connect(_back_from_submenu.bind(save_button))
	unsaved_dialog.save_chosen.connect(_open_submenu.bind(save_menu, save_menu.Mode.SAVE))
	unsaved_dialog.leave_chosen.connect(_leave)
	unsaved_dialog.cancelled.connect(_back_from_submenu.bind(resume_button))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# Вложенные экраны закрываются сами (по Esc/Start).
	if settings_menu.visible or save_menu.visible or unsaved_dialog.visible:
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not visible:
		open()


func open() -> void:
	visible = true
	panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_submenu(menu: Control, mode: Variant) -> void:
	panel.visible = false
	if mode == null:
		menu.open()
	else:
		menu.open(mode)


func _back_from_submenu(focus: Button) -> void:
	panel.visible = true
	focus.grab_focus()


func _try_leave(target: Leave) -> void:
	_leave_target = target
	if SaveGame.has_unsaved_progress:
		panel.visible = false
		unsaved_dialog.open()
	else:
		_leave()


func _leave() -> void:
	get_tree().paused = false
	if _leave_target == Leave.QUIT:
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU)
