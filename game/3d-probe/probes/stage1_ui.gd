extends Control

## Этап 1F: пробы интерфейса (план исполнения, раздел 8) — только нейтральные
## метки («Имя», «Текст», «Вариант 1»), без новых реплик. Клавиши 1–4
## переключают базовые экраны, 5–6 — раскладки меню (угол/нижняя панель),
## 7–8 — прежние стили кнопок на сравнение (FILLED/PILL); основной экран
## `menu` уже использует выбранный автором стиль OUTLINE (11.09.2026).
## STAGE1_CAPTURE=/путь.png и STAGE1_SCREEN=menu|menu_filled|menu_pill|
## menu_corner|menu_bottom|settings|dialog_a|dialog_b — кадр; STAGE1_DEV=1 —
## dev-панель (только dev); STAGE1_HAS_SAVE=1 — показать меню в состоянии
## «есть сохранение» («Новая игра» первой в фокусе, «Продолжить» — второй,
## порядок и приоритет — решение автора; сейвов ещё нет технически, это
## проба раскладки на оба состояния).

const CAPTURE_FRAMES := 12

## Шрифты и фон меню — проба типографики (PT Sans/Yeseva One, OFL, реестр
## ассетов); стиль остальных экранов пока не тронут по решению автора.
const TITLE_FONT := preload("res://assets/fonts/yesevaone/YesevaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/ptsans/PT_Sans-Web-Regular.ttf")
const BODY_FONT_BOLD := preload("res://assets/fonts/ptsans/PT_Sans-Web-Bold.ttf")
const MENU_BACKGROUND_IMAGE := preload("res://assets/art/menu_background_candidate.jpg")

## Ken Burns на фоне меню: медленный зум + лёгкий снос кадра, чтобы статичная
## картинка ощущалась «живой» без частиц/видео (просьба автора 11.09.2026).
const MENU_BG_ZOOM_FROM := 1.06
const MENU_BG_ZOOM_TO := 1.16
const MENU_BG_PAN := Vector2(-14, -10)
const MENU_BG_CYCLE_SECONDS := 18.0

## Три раскладки меню на сравнение (пункт автора «продизайнить ещё пару
## вариантов»): CENTER — заголовок и кнопки по центру экрана, **автор
## подтвердил её удобнее для игроков 11.09.2026** — используется как база
## для стилей кнопок; CORNER/BOTTOM_BAR остаются как альтернативы раскладки.
enum MenuLayout { CENTER, CORNER, BOTTOM_BAR }

## Стили самих кнопок при раскладке CENTER (пункт автора «дизайн кнопок»,
## не раскладка): OUTLINE — **выбор автора 11.09.2026**, тонкий контур без
## заливки, фон картинки просвечивает — основной стиль (экран `menu`);
## FILLED — прежний вариант с плотной заливкой; PILL — скруглённая
## «капсула» с плотной заливкой, крупнее и весомее. Оба остаются на
## сравнении (menu_filled/menu_pill), не удалены.
enum ButtonStyle { FILLED, OUTLINE, PILL }

var screens := {}
var current := "menu"
var dev_panel: PanelContainer
var camera_height := HSlider.new()
var camera_dist := HSlider.new()
var camera_mode := OptionButton.new()

func _ready() -> void:
	capture_path = OS.get_environment("STAGE1_CAPTURE")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var has_save := not OS.get_environment("STAGE1_HAS_SAVE").is_empty()
	_build_menu("menu", MenuLayout.CENTER, has_save, ButtonStyle.OUTLINE)
	_build_menu("menu_filled", MenuLayout.CENTER, has_save, ButtonStyle.FILLED)
	_build_menu("menu_pill", MenuLayout.CENTER, has_save, ButtonStyle.PILL)
	_build_menu("menu_corner", MenuLayout.CORNER, has_save, ButtonStyle.OUTLINE)
	_build_menu("menu_bottom", MenuLayout.BOTTOM_BAR, has_save, ButtonStyle.OUTLINE)
	_build_settings()
	_build_dialog_a()
	_build_dialog_b()
	_build_dev_panel()
	_show_screen(OS.get_environment("STAGE1_SCREEN") if not OS.get_environment("STAGE1_SCREEN").is_empty() else "menu")
	if OS.get_environment("STAGE1_DEV").is_empty():
		dev_panel.visible = false

func _panel_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("c5ae7a")
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("33524a")
	style.border_color = Color("f0d98c")
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	return style

## Focus-рамка, повторяющая радиус скругления стиля кнопки (иначе на PILL
## получается квадратная рамка фокуса поверх скруглённой кнопки).
func _focus_style_for(corner_radius: int) -> StyleBoxFlat:
	var style := _focus_style()
	style.set_corner_radius_all(corner_radius)
	return style

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus", _focus_style())
	return button

## Кнопка меню в одном из трёх стилей (пункт автора «дизайн кнопок»):
## FILLED — тёплая плотная заливка с прямым углом (базовый, уже показан);
## OUTLINE — только контур, фон-картинка просвечивает сквозь кнопку;
## PILL — скруглённая капсула с более крупной плотной заливкой.
## compact — версия для горизонтальной панели (BOTTOM_BAR), меньше размер.
func _menu_button(text: String, style: ButtonStyle = ButtonStyle.FILLED, compact: bool = false) -> Button:
	var button := _button(text)
	button.custom_minimum_size = Vector2(230, 56) if compact else Vector2(360, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", BODY_FONT_BOLD)
	button.add_theme_font_size_override("font_size", 17 if compact else 22)

	var normal := StyleBoxFlat.new()
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat
	var corner_radius := 6
	match style:
		ButtonStyle.OUTLINE:
			corner_radius = 2
			normal.bg_color = Color(0.05, 0.06, 0.05, 0.18)
			normal.border_color = Color("f4e9c9")
			normal.set_border_width_all(2)
			normal.set_content_margin_all(12)
			normal.set_corner_radius_all(corner_radius)
			hover = normal.duplicate()
			hover.bg_color = Color(0.05, 0.06, 0.05, 0.4)
			hover.border_color = Color("f0d98c")
			pressed = hover.duplicate()
			pressed.bg_color = Color(0.05, 0.06, 0.05, 0.55)
		ButtonStyle.PILL:
			corner_radius = 34
			button.custom_minimum_size = Vector2(260, 62) if compact else Vector2(390, 68)
			normal.bg_color = Color(0.145, 0.102, 0.055, 0.92)
			normal.border_color = Color("e8c77e")
			normal.set_border_width_all(2)
			normal.set_content_margin_all(14)
			normal.set_corner_radius_all(corner_radius)
			hover = normal.duplicate()
			hover.bg_color = Color(0.204, 0.145, 0.078, 0.96)
			hover.border_color = Color("f7dfa0")
			pressed = hover.duplicate()
			pressed.bg_color = Color(0.263, 0.184, 0.098, 1.0)
		_:
			corner_radius = 6
			normal.bg_color = Color(0.086, 0.114, 0.098, 0.82)
			normal.border_color = Color("c5ae7a")
			normal.set_border_width_all(2)
			normal.set_content_margin_all(12)
			normal.set_corner_radius_all(corner_radius)
			hover = normal.duplicate()
			hover.bg_color = Color(0.153, 0.204, 0.173, 0.9)
			hover.border_color = Color("f0d98c")
			pressed = hover.duplicate()
			pressed.bg_color = Color(0.204, 0.267, 0.227, 0.95)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _focus_style_for(corner_radius))
	return button

## Плавный зациклённый зум+снос картинки (Ken Burns), чтобы статичный фон не
## выглядел «мёртвым»; не частицы и не видео — их не потребовалось.
func _animate_menu_background(background: TextureRect) -> void:
	var tween := background.create_tween()
	tween.set_loops()
	tween.tween_method(
		func(t: float) -> void:
			var zoom: float = lerp(MENU_BG_ZOOM_FROM, MENU_BG_ZOOM_TO, t)
			background.scale = Vector2(zoom, zoom)
			background.pivot_offset = background.size / 2.0
			background.position = MENU_BG_PAN * t,
		0.0, 1.0, MENU_BG_CYCLE_SECONDS / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void:
			var zoom: float = lerp(MENU_BG_ZOOM_TO, MENU_BG_ZOOM_FROM, t)
			background.scale = Vector2(zoom, zoom)
			background.pivot_offset = background.size / 2.0
			background.position = MENU_BG_PAN * (1.0 - t),
		0.0, 1.0, MENU_BG_CYCLE_SECONDS / 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_menu(screen_name: String, layout: MenuLayout, has_save: bool, button_style: ButtonStyle = ButtonStyle.FILLED) -> void:
	# Обычный Control, не PanelContainer: слои фона/версии/колонки кнопок
	# позиционируются вручную поверх друг друга, PanelContainer бы их растянул.
	var panel := Control.new()
	panel.name = "Menu_%s" % screen_name
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = MENU_BACKGROUND_IMAGE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.pivot_offset = Vector2(background.size.x / 2.0, background.size.y / 2.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.clip_contents = true
	panel.add_child(background)
	_animate_menu_background(background)

	var scrim := ColorRect.new()
	scrim.color = Color(0.03, 0.04, 0.03, 0.32 if layout == MenuLayout.CENTER else 0.16)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scrim)

	var version_label := Label.new()
	version_label.text = "v0.0.10"
	version_label.add_theme_font_override("font", BODY_FONT)
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72, 0.85))
	version_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	version_label.position = Vector2(18, 14)
	panel.add_child(version_label)

	# «Новая игра» идёт первой и получает фокус по умолчанию (решение автора
	# 11.09.2026); «Продолжить» — второй кнопкой, не главным действием.
	var button_labels := ["Новая игра", "Продолжить"] if has_save else ["Начать"]
	button_labels.append_array(["Настройки", "Выйти из игры"])
	var primary_action := "Новая игра" if has_save else "Начать"
	var focus_button: Button

	match layout:
		MenuLayout.CENTER:
			focus_button = _menu_layout_center(panel, button_labels, primary_action, button_style)
		MenuLayout.CORNER:
			focus_button = _menu_layout_corner(panel, button_labels, primary_action, button_style)
		MenuLayout.BOTTOM_BAR:
			focus_button = _menu_layout_bottom_bar(panel, button_labels, primary_action, button_style)

	panel.set_meta("focus_node", focus_button)
	add_child(panel)
	screens[screen_name] = panel

## Раскладка 1 — CENTER: заголовок и кнопки по центру экрана. Автор
## подтвердил её удобнее для игроков 11.09.2026 — используется как база
## для сравнения стилей кнопок (FILLED/OUTLINE/PILL).
func _menu_layout_center(panel: Control, button_labels: Array, primary_action: String, button_style: ButtonStyle) -> Button:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var title := _menu_title()
	column.add_child(title)
	var hint := _menu_hint()
	column.add_child(hint)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)
	var focus_button: Button
	for text in button_labels:
		var button := _menu_button(text, button_style)
		column.add_child(button)
		if text == primary_action:
			focus_button = button
	return focus_button

## Раскладка 2 — CORNER: карточка кнопок в нижнем левом углу, заголовок
## отдельно вверху. Не закрывает домик и водопад в центре картинки.
func _menu_layout_corner(panel: Control, button_labels: Array, primary_action: String, button_style: ButtonStyle) -> Button:
	var title := _menu_title()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 36)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(36, 40)
	panel.add_child(title)
	var hint := _menu_hint()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hint.position = Vector2(38, 96)
	panel.add_child(hint)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	column.position = Vector2(36, -230)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var focus_button: Button
	for text in button_labels:
		var button := _menu_button(text, button_style)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(button)
		if text == primary_action:
			focus_button = button
	return focus_button

## Раскладка 3 — BOTTOM_BAR: заголовок сверху по центру, кнопки одной
## горизонтальной панелью снизу — ближе к консольным меню.
func _menu_layout_bottom_bar(panel: Control, button_labels: Array, primary_action: String, button_style: ButtonStyle) -> Button:
	var title := _menu_title()
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 44
	panel.add_child(title)
	var hint := _menu_hint()
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.position.y = 100
	panel.add_child(hint)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.position.y = -100
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var focus_button: Button
	for text in button_labels:
		var button := _menu_button(text, button_style, true)
		row.add_child(button)
		if text == primary_action:
			focus_button = button
	return focus_button

func _menu_title() -> Label:
	var title := Label.new()
	title.text = "У БЕРЕГА — проба интерфейса"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("f4e9c9"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	return title

func _menu_hint() -> Label:
	var hint := Label.new()
	hint.text = "Видимый фокус: жёлтая рамка (Steam Deck)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", BODY_FONT)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78, 0.8))
	return hint

func _build_settings() -> void:
	var panel := PanelContainer.new()
	panel.name = "Settings"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.1, 0.88)))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Настройки камеры"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	camera_height.min_value = 1.0
	camera_height.max_value = 5.0
	camera_height.value = 3.4
	camera_height.custom_minimum_size = Vector2(420, 40)
	column.add_child(_labeled("Высота камеры", camera_height))
	camera_dist.min_value = 2.0
	camera_dist.max_value = 9.0
	camera_dist.value = 6.4
	camera_dist.custom_minimum_size = Vector2(420, 40)
	column.add_child(_labeled("Дистанция", camera_dist))
	camera_mode.add_item("Третье лицо (дальше/выше)")
	camera_mode.add_item("GTA-стиль")
	camera_mode.add_item("Первое лицо")
	camera_mode.add_item("Спереди")
	camera_mode.custom_minimum_size = Vector2(420, 44)
	camera_mode.focus_mode = Control.FOCUS_ALL
	camera_mode.add_theme_stylebox_override("focus", _focus_style())
	column.add_child(_labeled("Режим", camera_mode))
	var back := _button("Назад")
	column.add_child(back)
	panel.set_meta("focus_node", back)
	add_child(panel)
	screens["settings"] = panel

func _labeled(title: String, control: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = title
	column.add_child(label)
	column.add_child(control)
	return column

func _dialog_panel(bg: Color, portrait_left: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(bg))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(180, 220)
	portrait.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.16, 0.14)))
	var portrait_label := Label.new()
	portrait_label.text = "Портрет"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_label)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = "Имя"
	name_label.add_theme_font_size_override("font_size", 24)
	text_column.add_child(name_label)
	var text_label := Label.new()
	text_label.text = "Текст"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 18)
	text_column.add_child(text_label)
	if portrait_left:
		row.add_child(portrait)
		row.add_child(text_column)
	else:
		# Вариант B: крупный портрет поверх, текст отдельным блоком снизу
		column.add_child(portrait)
		row.add_child(text_column)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 14)
	column.add_child(options)
	var focus_button: Button
	for option in ["Вариант 1", "Вариант 2"]:
		var option_button := _button(option)
		options.add_child(option_button)
		if focus_button == null:
			focus_button = option_button
	panel.set_meta("focus_node", focus_button)
	add_child(panel)
	return panel

func _build_dialog_a() -> void:
	screens["dialog_a"] = _dialog_panel(Color(0.04, 0.07, 0.09, 0.9), true)

func _build_dialog_b() -> void:
	screens["dialog_b"] = _dialog_panel(Color(0.07, 0.05, 0.09, 0.9), false)

func _build_dev_panel() -> void:
	dev_panel = PanelContainer.new()
	dev_panel.name = "DevPanel"
	dev_panel.position = Vector2(24, 24)
	dev_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.2, 0.08, 0.05, 0.9)))
	var label := Label.new()
	label.text = "DEV · телепорт · коллизии · множители"
	dev_panel.add_child(label)
	add_child(dev_panel)

func _show_screen(name: String) -> void:
	if not screens.has(name):
		name = "menu"
	current = name
	for key in screens:
		var panel: Control = screens[key]
		panel.visible = key == current
	if screens[current].has_meta("focus_node"):
		var focus: Control = screens[current].get_meta("focus_node")
		focus_request = focus
		focus.grab_focus.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var keys := {KEY_1: "menu", KEY_2: "settings", KEY_3: "dialog_a", KEY_4: "dialog_b", KEY_5: "menu_corner", KEY_6: "menu_bottom", KEY_7: "menu_filled", KEY_8: "menu_pill"}
	if keys.has(key.keycode):
		_show_screen(keys[key.keycode])

func _process(_delta: float) -> void:
	if capture_path.is_empty():
		return
	set_process(false)
	for i in CAPTURE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(capture_path)
	print("STAGE1_CAPTURE saved: ", capture_path)
	get_tree().quit()

var capture_path := ""
var focus_request: Control
