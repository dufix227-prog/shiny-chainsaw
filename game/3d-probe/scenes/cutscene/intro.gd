extends Node3D

## Стартовая катсцена С1 (канон автора 09.09.2026): кот сходит с оживлённой
## улицы в тропу, видит табличку «через 500 метров клубничные запасы»
## (крупный план 3 секунды), доходит до леса — и игрок получает управление.
## Вся постановка — анимация «intro» в AnimationPlayer этой сцены.
## Пропуск — сразу к управлению (канон). Кнопка пропуска — ЗАГЛУШКА: автор её
## ещё не назначил, сейчас это Esc / Start / Enter / A.

const GAMEPLAY_SCENE := "res://scenes/world/start_area.tscn"

var _finished := false

@onready var animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	GameSettings.apply_to_world(self)
	animation.animation_finished.connect(func(_name: StringName): finish())
	animation.play("intro")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		finish()


func finish() -> void:
	if _finished:
		return
	_finished = true
	SaveGame.has_unsaved_progress = true
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)
