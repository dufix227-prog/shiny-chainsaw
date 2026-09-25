extends SceneTree

## Этап 1F: проверки интерфейса — экраны существуют, фокус виден, dev-панель
## только в dev-режиме, диалоги содержат нейтральные метки.

const Stage1UI = preload("res://probes/stage1_ui.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	var probe: Stage1UI = Stage1UI.new()
	root.add_child(probe)
	await frames(4)

	for screen in ["menu", "menu_filled", "menu_pill", "menu_corner", "menu_bottom", "settings", "dialog_a", "dialog_b"]:
		probe._show_screen(screen)
		await frames(2)
		check(probe.screens[screen].visible, "Screen %s is shown" % screen)
		check(probe.focus_request != null and probe.focus_request.focus_mode == Control.FOCUS_ALL,
			"Screen %s requests visible focus on a focusable control" % screen)
	probe._show_screen("menu")
	await frames(2)

	check(probe.screens["menu"].visible, "Menu stays after returning")
	var settings: PanelContainer = probe.screens["settings"]
	check(settings.find_children("*", "HSlider", true, false).size() == 2, "Settings keep two sliders")
	check(settings.find_children("*", "OptionButton", true, false).size() == 1, "Settings keep camera mode selector")

	check(probe.dev_panel.visible == false, "Dev panel is hidden without dev flag")

	# Без сейва — одна кнопка «Начать»; со STAGE1_HAS_SAVE — «Продолжить» и
	# «Новая игра» вместо неё (проба раскладки на оба состояния).
	var menu_buttons: Array = probe.screens["menu"].find_children("*", "Button", true, false)
	var menu_texts: Array = []
	for button in menu_buttons:
		menu_texts.append(button.text)
	check("Начать" in menu_texts, "Menu without save shows 'Начать'")
	check(not ("Продолжить" in menu_texts), "Menu without save has no 'Продолжить'")

	# Отдельный экземпляр со STAGE1_HAS_SAVE=1 — проверяем обратное состояние.
	OS.set_environment("STAGE1_HAS_SAVE", "1")
	var probe_with_save: Stage1UI = Stage1UI.new()
	root.add_child(probe_with_save)
	await frames(4)
	var save_menu_buttons: Array = probe_with_save.screens["menu"].find_children("*", "Button", true, false)
	var save_menu_texts: Array = []
	for button in save_menu_buttons:
		save_menu_texts.append(button.text)
	check("Продолжить" in save_menu_texts, "Menu with save shows 'Продолжить'")
	check("Новая игра" in save_menu_texts, "Menu with save shows 'Новая игра'")
	check(not ("Начать" in save_menu_texts), "Menu with save no longer shows plain 'Начать'")

	# Автор уточнил 11.09.2026: «Новая игра» должна быть первой и в фокусе,
	# «Продолжить» — второй кнопкой, не главным действием.
	check(save_menu_texts[0] == "Новая игра", "'Новая игра' is the first button when a save exists")
	check(probe_with_save.focus_request != null and probe_with_save.focus_request.text == "Новая игра",
		"'Новая игра' receives default focus when a save exists")

	# Автор спросил, почему «Продолжить» была видна только в одном варианте —
	# на деле флаг общий для всех экранов меню; явная проверка на этом.
	for screen in ["menu_filled", "menu_pill", "menu_corner", "menu_bottom"]:
		var buttons: Array = probe_with_save.screens[screen].find_children("*", "Button", true, false)
		var texts: Array = []
		for button in buttons:
			texts.append(button.text)
		check("Продолжить" in texts, "Screen %s with save also shows 'Продолжить'" % screen)
	probe_with_save.queue_free()

	print("Stage 1F ui probe: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
