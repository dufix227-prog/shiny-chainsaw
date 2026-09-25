class_name InventoryHUD
extends Control

signal mode_requested
signal inventory_requested
signal pickup_requested
signal slot_selected(address: String)
signal context_requested(address: String)
signal use_requested(address: String)
signal drop_requested(address: String)
signal backpack_requested(kind: String)
signal page_requested(page: int)

const Art = preload("res://scripts/inventory_art.gd")
const BACKPACK_TITLES := {
	"level_1_test": "РЮКЗАК · 1 УРОВЕНЬ (ТЕСТ)",
	"level_10_a_test": "РЮКЗАК · 10 УРОВЕНЬ A (ТЕСТ)",
	"level_10_b_test": "РЮКЗАК · 10 УРОВЕНЬ B (ТЕСТ)",
}
const BACKPACK_BUTTONS := {
	"level_1_test": "1 ур.",
	"level_10_a_test": "10 ур. A",
	"level_10_b_test": "10 ур. B",
}

var toolbar := PanelContainer.new()
var modal := ColorRect.new()
var opened := false
var mode_button: Button
var open_button: Button
var pickup_button: Button
var hint: Label
var weight_label: Label
var status: Label
var stock: Label
var close_button: Button
var remove_button: Button
var slots := {}
var selected := ""
var context_slot := ""
var context_menu := PanelContainer.new()
var context_box := VBoxContainer.new()
var backpack_row := HBoxContainer.new()
var grid_container := VBoxContainer.new()
var backpack_grid := VBoxContainer.new()
var backpack_column := VBoxContainer.new()
var page_row := HBoxContainer.new()
var weight_bar: ProgressBar
var satiety_bar: ProgressBar
var stamina_bar: ProgressBar
var icons := {}
var last_inventory: ProbeInventory
var structure_key := ""
var hovered := ""
var focused_slot := ""
var arrow: TransferArrow
var style_slot: StyleBoxFlat
var style_source: StyleBoxFlat
var style_target: StyleBoxFlat
var style_swap: StyleBoxFlat
var style_focus: StyleBoxFlat
var style_button: StyleBoxFlat
var style_button_hover: StyleBoxFlat

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_styles()
	icons = {
		"food": Art.food_texture(),
		"water": Art.water_texture(),
		"map": Art.map_texture(),
		"coffee": Art.coffee_texture(),
	}
	_build_toolbar()
	_build_modal()
	set_open(false)

func _process(_delta: float) -> void:
	if not opened or selected.is_empty() or last_inventory == null:
		arrow.visible = false
		return
	var source: Button = slots.get(selected)
	if source == null:
		arrow.visible = false
		return
	arrow.visible = true
	arrow.from_point = source.get_global_rect().get_center()
	var target := _arrow_target()
	if target.is_empty():
		arrow.to_point = get_global_mouse_position()
	else:
		arrow.to_point = slots[target].get_global_rect().get_center()
	arrow.queue_redraw()

func _arrow_target() -> String:
	for address in [hovered, focused_slot]:
		if _is_valid_target(address):
			return address
	return ""

func _is_valid_target(address: String) -> bool:
	if address.is_empty() or address == selected or not slots.has(address):
		return false
	return last_inventory != null and slots[address].visible

func _make_styles() -> void:
	style_slot = _slot_style(Color("0f2b25"), Color("5a7a5e"))
	style_source = _slot_style(Color("1d4034"), Color("ffe56d"))
	style_target = _slot_style(Color("16362d"), Color("d8c86a"))
	style_swap = _slot_style(Color("16362d"), Color("86c6e0"))
	style_focus = _slot_style(Color("0f2b25"), Color("ffe56d"))
	style_button = _flat(Color("2e4c40"), Color("c5ae7a"))
	style_button_hover = _flat(Color("3a5c4e"), Color("ffe56d"))

func _slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _build_toolbar() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	toolbar.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	mode_button = _menu_button(row, "", func(): mode_requested.emit())
	open_button = _menu_button(row, "", func(): inventory_requested.emit())
	hint = _label(column, "", 12)
	pickup_button = _menu_button(column, "A / E · Подобрать", func(): pickup_requested.emit())

func _build_modal() -> void:
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.color = Color(0.03, 0.08, 0.07, 0.78)
	modal.gui_input.connect(func(event: InputEvent) -> void:
		if context_menu.visible and event is InputEventMouseButton and event.pressed:
			clear_context()
	)
	add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	var style := _flat(Color("14352d"), Color("c5ae7a"))
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	panel.add_child(contents)
	contents.add_child(_title_row())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	contents.add_child(columns)
	columns.add_child(_cat_view())
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.add_theme_constant_override("separation", 10)
	columns.add_child(grid_container)
	backpack_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_column.add_theme_constant_override("separation", 8)
	columns.add_child(backpack_column)
	weight_label = _label(backpack_column, "", 14)
	weight_bar = _bar(backpack_column, Color("7ec86c"))
	backpack_grid.add_theme_constant_override("separation", 10)
	backpack_column.add_child(backpack_grid)
	page_row.add_theme_constant_override("separation", 8)
	backpack_column.add_child(page_row)
	backpack_row.add_theme_constant_override("separation", 8)
	backpack_column.add_child(backpack_row)
	columns.add_child(_stats_column())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	contents.add_child(bottom)
	status = _label(bottom, "", 13)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _menu_button(bottom, "B · Закрыть", func(): inventory_requested.emit())
	arrow = TransferArrow.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(arrow)
	context_menu.add_theme_stylebox_override("panel", _flat(Color("1d4034"), Color("ffe56d")))
	context_menu.visible = false
	context_menu.add_child(context_box)
	context_box.add_theme_constant_override("separation", 6)
	modal.add_child(context_menu)

func _title_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_paw(false))
	_label(row, "ИНВЕНТАРЬ · ПРОБА", 26)
	row.add_child(_paw(true))
	return row

func _paw(flip: bool) -> TextureRect:
	var view := TextureRect.new()
	view.texture = Art.paw_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.custom_minimum_size = Vector2(28, 28)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.flip_h = flip
	return view

func _cat_view() -> TextureRect:
	var view := TextureRect.new()
	view.texture = Art.cat_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.custom_minimum_size = Vector2(140, 400)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return view

func _stats_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(150, 0)
	column.add_theme_constant_override("separation", 6)
	_label(column, "СОСТОЯНИЕ", 15)
	_label(column, "Сытость", 13)
	satiety_bar = _bar(column, Color("86c06c"))
	_label(column, "Выносливость", 13)
	stamina_bar = _bar(column, Color("e8a04c"))
	return column

func _bar(parent: Control, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0f2b25")
	bg.border_color = Color("5a7a5e")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	parent.add_child(bar)
	return bar

func _menu_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_stylebox_override("normal", style_button)
	button.add_theme_stylebox_override("hover", style_button_hover)
	button.add_theme_stylebox_override("pressed", style_button)
	button.add_theme_stylebox_override("disabled", style_button)
	button.add_theme_stylebox_override("focus", style_focus)
	button.add_theme_color_override("font_color", Color("f2dfb6"))
	button.add_theme_color_override("font_hover_color", Color("ffe56d"))
	button.add_theme_color_override("font_disabled_color", Color("8fa396"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f2dfb6"))
	parent.add_child(label)
	return label

func _hint_label(parent: Control, text_value: String) -> Label:
	var label := _label(parent, text_value, 12)
	label.add_theme_color_override("font_color", Color("9db3a4"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(330, 0)
	return label

func set_open(value: bool) -> void:
	opened = value
	modal.visible = value
	arrow.visible = false
	var toolbar_focus := Control.FOCUS_NONE if value else Control.FOCUS_ALL
	mode_button.focus_mode = toolbar_focus
	open_button.focus_mode = toolbar_focus
	pickup_button.focus_mode = toolbar_focus
	if not value:
		context_menu.visible = false
		context_slot = ""
		selected = ""
		hovered = ""

func focus_modal() -> void:
	_focus_first_slot()

func _focus_first_slot() -> void:
	for address in slots:
		if slots[address].visible:
			slots[address].grab_focus()
			return

func focus_open_button() -> void:
	open_button.grab_focus()

func focused_address() -> String:
	if focused_slot.is_empty():
		return ""
	var button: Button = slots.get(focused_slot)
	if button == null or not button.visible:
		return ""
	return focused_slot

func refresh(needs, pickup, nearby: bool, paused: bool, inventory: ProbeInventory) -> void:
	last_inventory = inventory
	mode_button.text = "Подбор: вкл" if pickup.enabled else "Подбор: выкл"
	mode_button.disabled = paused or opened
	open_button.text = "B / X · Инвентарь"
	pickup_button.visible = pickup.enabled
	pickup_button.disabled = paused or opened or not nearby
	if not pickup.enabled:
		hint.text = "Отдельная проба еды в мире · включи подбор"
	elif pickup.collected:
		hint.text = "Порция подобрана · B / X — открыть инвентарь"
	elif nearby:
		hint.text = "Рядом тестовая еда · A / E — подобрать"
	else:
		hint.text = "Подойди к пакету на дороге у старта"
	weight_label.text = "Загрузка: %.1f / %.0f кг" % [inventory.total_weight(), ProbeInventory.MAX_WEIGHT_KG]
	weight_bar.max_value = ProbeInventory.MAX_WEIGHT_KG
	weight_bar.value = inventory.total_weight()
	satiety_bar.value = needs.food
	stamina_bar.value = needs.stamina
	status.text = "ЛКМ/A: перенос или обмен местами · ПКМ/V или Y: действия предмета"
	if inventory.food_count() == 0:
		status.text = "Пусто · найди еду или начни новую пробу"
	elif not needs.enabled:
		status.text += " · Нужды выключены: еду использовать нельзя"
	var key := "%s|%d|%d" % [inventory.backpack, inventory.page_count(), inventory.current_page]
	if key != structure_key:
		structure_key = key
		_rebuild_slots()
		if opened and get_viewport().gui_get_focus_owner() == null:
			_focus_first_slot()
	stock.text = "Порций еды: %d · Сытость: %.0f / 100" % [inventory.food_count(), needs.food]
	_update_slots()

func _rebuild_slots() -> void:
	for child in grid_container.get_children(): child.queue_free()
	for child in backpack_grid.get_children(): child.queue_free()
	for child in backpack_row.get_children(): child.queue_free()
	for child in page_row.get_children(): child.queue_free()
	slots.clear()
	hovered = ""
	focused_slot = ""
	stock = _label(grid_container, "", 14)
	_add_section(grid_container, "БЫСТРАЯ ПАНЕЛЬ", "hotbar", ProbeInventory.HOTBAR_SIZE)
	_add_section(grid_container, "КАРМАНЫ", "pocket", ProbeInventory.POCKET_SIZE)
	remove_button = null
	backpack_row.visible = not last_inventory.has_backpack()
	if last_inventory.has_backpack():
		_add_section(backpack_grid, BACKPACK_TITLES.get(last_inventory.backpack, "РЮКЗАК"), "backpack", ProbeInventory.BACKPACK_PAGE_SIZE)
		if last_inventory.page_count() > 1:
			for page in last_inventory.page_count():
				var page_button := _menu_button(page_row, "Стр. %d" % (page + 1), func(p := page): page_requested.emit(p))
				page_button.disabled = page == last_inventory.current_page
		remove_button = _menu_button(page_row, "Снять рюкзак", func(): backpack_requested.emit("none"))
	else:
		_label(backpack_grid, "РЮКЗАК · НЕТ", 15)
		_hint_label(backpack_grid, "Рюкзаки появятся в полной игре; тестовые кнопки примеряют страницы окна:")
		for kind: String in BACKPACK_BUTTONS:
			_menu_button(backpack_row, BACKPACK_BUTTONS[kind], func(k: String = kind): backpack_requested.emit(k))

func _add_section(parent: Control, title: String, prefix: String, count: int, columns: int = 5) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	_label(section, title, 15)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)
	for index in count:
		var address := "%s:%d" % [prefix, index]
		var button := _make_slot(address)
		grid.add_child(button)
		slots[address] = button

func _make_slot(address: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(64, 64)
	button.focus_mode = Control.FOCUS_ALL
	button.text = "+"
	button.tooltip_text = "Пустой слот"
	button.add_theme_color_override("font_color", Color("5f7f6b"))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", style_slot)
	button.add_theme_stylebox_override("hover", style_slot)
	button.add_theme_stylebox_override("pressed", style_slot)
	button.add_theme_stylebox_override("focus", style_focus)
	button.pressed.connect(func(a := address):
		clear_context()
		slot_selected.emit(a)
	)
	button.gui_input.connect(func(event, a := address):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			context_requested.emit(a)
	)
	button.mouse_entered.connect(func(): hovered = address)
	button.mouse_exited.connect(func():
		if hovered == address:
			hovered = ""
	)
	button.focus_entered.connect(func(): focused_slot = address)
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 10
	icon.offset_right = -12
	icon.offset_bottom = -14
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var count := Label.new()
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -28
	count.offset_top = -22
	count.offset_right = -6
	count.offset_bottom = -4
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_color_override("font_color", Color("ffe56d"))
	count.add_theme_color_override("font_outline_color", Color("1a2c26"))
	count.add_theme_constant_override("outline_size", 4)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	button.set_meta("icon", icon)
	button.set_meta("count", count)
	return button

func _update_slots() -> void:
	if last_inventory == null:
		return
	for address: String in slots:
		var button: Button = slots[address]
		var icon: TextureRect = button.get_meta("icon")
		var count: Label = button.get_meta("count")
		var item = last_inventory.slot(address)
		if item == null:
			button.text = "+"
			button.tooltip_text = "Пустой слот"
			icon.visible = false
			count.text = ""
		else:
			button.text = ""
			button.tooltip_text = "%s · ×%d" % [item.name, item.count]
			icon.texture = icons.get(item.id)
			icon.visible = icon.texture != null
			count.text = "×%d" % item.count
		var style := style_slot
		if address == selected:
			style = style_source
		elif not selected.is_empty():
			# Пустой слот подсвечен как цель переноса, занятый — как обмен.
			style = style_target if item == null else style_swap
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)

func show_context(address: String, item) -> void:
	# Item may be null for an empty slot: the menu simply stays closed.
	context_slot = address
	for child in context_box.get_children(): child.queue_free()
	context_menu.visible = item != null
	if item == null:
		return
	if item.get("use", false):
		_menu_button(context_box, "Использовать", func(): use_requested.emit(address))
	if item.get("drop", false):
		_menu_button(context_box, "Выбросить", func(): drop_requested.emit(address))
	_place_context.call_deferred(address)

func _place_context(address: String) -> void:
	if not context_menu.visible:
		return
	var bounds := get_viewport_rect().size
	var origin := Vector2(bounds.x * 0.5, bounds.y * 0.5)
	if slots.has(address):
		origin = slots[address].get_global_rect().position
	context_menu.position = (origin + Vector2(70, -6)).clamp(Vector2(8, 8), bounds - context_menu.size - Vector2(8, 8))
	if context_box.get_child_count() > 0:
		context_box.get_child(0).grab_focus()

func clear_context() -> void:
	context_menu.visible = false
	var back := context_slot
	context_slot = ""
	if opened and slots.has(back) and slots[back].visible:
		slots[back].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not opened: return
	if event.is_action_pressed("inventory_close") or event.is_action_pressed("ui_cancel"):
		if context_menu.visible:
			clear_context()
		else:
			inventory_requested.emit()
		get_viewport().set_input_as_handled()

class TransferArrow:
	extends Control

	var from_point := Vector2.ZERO
	var to_point := Vector2.ZERO

	func _draw() -> void:
		if from_point.distance_to(to_point) < 2.0:
			return
		var color := Color("ffe56d")
		var mid := (from_point + to_point) * 0.5 - Vector2(0, 46)
		var previous := from_point
		for step in range(1, 17):
			var t := step / 16.0
			var point := from_point.lerp(mid, t).lerp(mid.lerp(to_point, t), t)
			draw_line(previous, point, color, 3.0)
			previous = point
		var direction := (to_point - previous).normalized()
		if direction.length() < 0.5:
			return
		var side := direction.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([to_point + direction * 4.0, to_point - direction * 8.0 + side, to_point - direction * 8.0 - side]), color)
