extends Control

## Экран снимков: 20 слотов, в каждом — имя, дата и метры; снимок можно
## переименовать и удалить (канон автора). Одна сцена для меню и паузы.
## Режим SAVE — выбор слота записывает игру, LOAD — загружает.

signal closed

enum Mode { SAVE, LOAD }

var mode := Mode.LOAD
var _renaming_slot := -1
## Удаление — в два нажатия, чтобы не стереть снимок случайно.
var _delete_armed_slot := -1

@onready var title: Label = %Title
@onready var list: VBoxContainer = %List
@onready var rename_row: HBoxContainer = %RenameRow
@onready var rename_field: LineEdit = %RenameField
@onready var rename_confirm: Button = %RenameConfirm
@onready var back_button: Button = %BackButton


func _ready() -> void:
	visible = false
	for row in list.get_children():
		var slot: int = row.get_meta("slot")
		row.get_node("Pick").pressed.connect(_pick.bind(slot))
		row.get_node("Rename").pressed.connect(_start_rename.bind(slot))
		row.get_node("Delete").pressed.connect(_delete.bind(slot))
	rename_confirm.pressed.connect(_finish_rename)
	rename_field.text_submitted.connect(func(_text: String): _finish_rename())
	back_button.pressed.connect(close)


func open(new_mode: Mode) -> void:
	mode = new_mode
	title.text = "Сохранить игру" if mode == Mode.SAVE else "Загрузить игру"
	rename_row.visible = false
	_refresh()
	visible = true
	list.get_child(0).get_node("Pick").grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_delete_armed_slot = -1
	for row in list.get_children():
		row.get_node("Delete").text = "Удалить"
		var slot: int = row.get_meta("slot")
		var data := SaveGame.read_slot(slot)
		var pick: Button = row.get_node("Pick")
		if data.is_empty():
			pick.text = "%d. пусто" % slot
			pick.disabled = mode == Mode.LOAD
		else:
			var date := Time.get_datetime_string_from_unix_time(int(data.saved_at), true).replace("T", " ")
			pick.text = "%d. %s · %s · %d м" % [slot, data.title, date.substr(0, 16), roundi(data.metres)]
			pick.disabled = false
		row.get_node("Rename").disabled = data.is_empty()
		row.get_node("Delete").disabled = data.is_empty()


func _pick(slot: int) -> void:
	if mode == Mode.SAVE:
		SaveGame.save_to_slot(slot)
		_refresh()
	else:
		SaveGame.load_slot(slot)


func _start_rename(slot: int) -> void:
	_renaming_slot = slot
	rename_field.text = SaveGame.read_slot(slot).get("title", "")
	rename_row.visible = true
	rename_field.grab_focus()
	rename_field.select_all()


func _finish_rename() -> void:
	if _renaming_slot > 0:
		SaveGame.rename_slot(_renaming_slot, rename_field.text)
	_renaming_slot = -1
	rename_row.visible = false
	_refresh()


func _delete(slot: int) -> void:
	if _delete_armed_slot != slot:
		_refresh()
		_delete_armed_slot = slot
		list.get_child(slot - 1).get_node("Delete").text = "Точно?"
		return
	SaveGame.delete_slot(slot)
	_refresh()
