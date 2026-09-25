extends Control

## Напоминание при выходе без сохранения (канон автора 11.09.2026).
## ЗАГЛУШКА: точный текст и набор кнопок автор ещё не утвердил
## (ideas/common/design/saves/plan.md, «Открыто»). Напоминание не запрещает выход.

signal save_chosen
signal leave_chosen
signal cancelled

@onready var save_button: Button = %SaveButton
@onready var leave_button: Button = %LeaveButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	visible = false
	save_button.pressed.connect(_choose.bind(save_chosen))
	leave_button.pressed.connect(_choose.bind(leave_chosen))
	cancel_button.pressed.connect(_choose.bind(cancelled))


func open() -> void:
	visible = true
	save_button.grab_focus()


func _choose(result: Signal) -> void:
	visible = false
	result.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_choose(cancelled)
		get_viewport().set_input_as_handled()
