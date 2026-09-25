extends Node3D

## Витрина пачки ассетов пролога (19.09.2026) — для автора.
## Назначение: автор сам открывает пачку и крутит модели, не дожидаясь скриншотов.
## Ничего не проверяет автоматически и НЕ является приёмкой: это витрина.
##
## Запуск:  bash game/start.sh res://probes/pack_viewer.tscn
##
## Мир здесь — ДАННЫЕ СЦЕНЫ (правило scene-first из AGENTS.md): земля, свет,
## камера, эталонная капсула и все семь моделей лежат в pack_viewer.tscn.
## Расставлены один раз скриптом-сборщиком tools/build_pack_viewer_scene.gd,
## результат сохранён в сцену. В этом файле — только поведение: облёт, зум,
## выбор объекта, подписи и снимок кадра. Ничего не создаётся в _ready().
##
## Управление:
##   1…7       — смотреть один объект (остальные прячутся)
##   0         — вся пачка
##   Tab       — следующий объект
##   ЛКМ / Q,E / ←,→   — облетать
##   колесо / +,- / ↑,↓ — приблизить-отдалить
##   Space     — автоповорот, C — ортография, R — сброс, Esc — выход
##
## Модели стоят рядом с капсулой «рост кота 1,8 м» — по ней виден масштаб.

const REFERENCE_HINT := "рост кота 1,8 м"
const ProbeInput = preload("res://scripts/probe_input.gd")

const ORBIT_SPEED := 1.7     # радиан в секунду на полном отклонении стика
const ZOOM_SPEED := 1.1      # доля дистанции в секунду на полном отклонении
## Просвет между выбранным объектом и эталоном при одиночном показе.
const REFERENCE_GAP := 0.45

@onready var exhibits_root: Node3D = $Exhibits
@onready var camera: Camera3D = $Camera
@onready var hint: Label = $HUD/Hint

## Плоский список экспонатов по порядку номеров: [{index, node, label, size, center}].
var exhibits: Array[Dictionary] = []

var orbit_angle := PI          # PI — камера со стороны −Z, то есть перед моделей
var orbit_pitch := 0.26
var orbit_distance := 6.0
var focus_point := Vector3(0, 1.0, 0)
var whole_pack_view := true
var focused_index := -1        # -1 — общий вид; иначе номер выбранного объекта
var autorotate := true
var dragging := false

## Исходное место эталона в сцене: в общем виде он возвращается туда.
var reference_home := Vector3.ZERO

## Кадры без монитора: PACK_VIEW_CAPTURE=/путь.png сохраняет кадр и выходит.
## PACK_VIEW_OBJECT=0..7 выбирает объект, PACK_VIEW_ANGLE — градусы облёта,
## PACK_VIEW_DIST — дистанция.
var capture_path := ""


func _ready() -> void:
	ProbeInput.install_viewer()
	_collect_exhibits()
	var reference := _reference()
	if reference != null:
		reference_home = reference.position
	capture_path = OS.get_environment("PACK_VIEW_CAPTURE")
	var wanted := OS.get_environment("PACK_VIEW_OBJECT")
	if wanted.is_empty() or wanted == "0":
		show_whole_pack()
	else:
		show_exhibit(int(wanted) - 1)
	if not OS.get_environment("PACK_VIEW_ANGLE").is_empty():
		orbit_angle = deg_to_rad(float(OS.get_environment("PACK_VIEW_ANGLE")))
	if not OS.get_environment("PACK_VIEW_DIST").is_empty():
		orbit_distance = float(OS.get_environment("PACK_VIEW_DIST"))
	_update_camera()
	# Автоповорот мешает кадру: к моменту снимка камера уедет.
	if not capture_path.is_empty():
		autorotate = false


## Читаем экспонаты из сцены: каждый — Node3D с номером в имени, внутри модель
## и подпись-номер. Порядок берём из имени («1_…», «2_…»), а не из кода.
func _collect_exhibits() -> void:
	exhibits.clear()
	var children := exhibits_root.get_children()
	# Сравниваем именно String: у StringName оператор «<» не лексикографический,
	# и сортировка по нему выдавала порядок, не совпадающий с номерами.
	children.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	for child in children:
		var node := child as Node3D
		if node == null:
			continue
		var entry := {
			"index": exhibits.size() + 1,
			# Русское имя и id лежат в самой сцене (метаданные узла): витрина
			# показывает русское, а id остаётся для правок по просьбе автора.
			"title": String(node.get_meta("title", node.name)),
			"note": String(node.get_meta("note", "")),
			"id": String(node.get_meta("file", "")),
			"node": node,
			"label": node.get_node_or_null("Number") as Label3D,
			"size": measure_local_size(node),
		}
		entry["center"] = node.position + Vector3(0, entry["size"].y / 2, 0)
		exhibits.append(entry)


## «1_goose_guard_v1» -> «goose_guard_v1»: id ассета без номера ряда.
func _title_of(node: Node3D) -> String:
	var text := String(node.name)
	var cut := text.find("_")
	return text.substr(cut + 1) if cut >= 0 else text


## Габариты узла по его собственным координатам. Обход по локальным трансформам,
## поэтому работает и в скрипте-сборщике (вне дерева сцены), и в рантайме.
static func measure_local_size(node: Node3D) -> Vector3:
	var box := AABB()
	var started := false
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var current: Node = pair[0]
		var xform: Transform3D = pair[1]
		if current is MeshInstance3D:
			var mesh := current as MeshInstance3D
			var bounds := xform * mesh.get_aabb()
			box = bounds if not started else box.merge(bounds)
			started = true
		for child in current.get_children():
			if child is Node3D:
				stack.append([child, xform * (child as Node3D).transform])
	return box.size


# ----------------------------------------------------------------- камера ---
func _update_camera() -> void:
	var horizontal := cos(orbit_pitch) * orbit_distance
	camera.position = focus_point + Vector3(
		sin(orbit_angle) * horizontal,
		sin(orbit_pitch) * orbit_distance,
		cos(orbit_angle) * horizontal)
	camera.look_at(focus_point)
	_scale_labels()


## Подписи-номера в мировых координатах: размер в метрах умножаем на дистанцию,
## иначе при подлёте к корзине номер вырастает на весь экран, а в общем виде
## превращается в точку. Так он остаётся одного размера на экране.
func _scale_labels() -> void:
	var pixel_size := clampf(orbit_distance * 0.0011, 0.0006, 0.010)
	for entry in exhibits:
		var label := entry["label"] as Label3D
		if label != null:
			label.pixel_size = pixel_size
	var reference := get_node_or_null("Reference/Label") as Label3D
	if reference != null:
		reference.pixel_size = pixel_size


func _pack_bounds() -> Vector2:
	# Возвращает (левая, правая) границы ряда.
	var left := INF
	var right := -INF
	for entry in exhibits:
		left = minf(left, entry["center"].x - entry["size"].x / 2)
		right = maxf(right, entry["center"].x + entry["size"].x / 2)
	# Капсула-эталон — тоже часть ряда: без её границ камера общего вида
	# центровалась по моделям и уезжала так, что капсула оставалась за кадром.
	# Считаем по её исходному месту: при одиночном показе эталон уезжает к
	# выбранному объекту, и границы ряда от этого меняться не должны.
	var reference := _reference()
	if reference != null:
		var size := measure_local_size(reference)
		left = minf(left, reference_home.x - size.x / 2)
		right = maxf(right, reference_home.x + size.x / 2)
	if left > right:
		return Vector2.ZERO
	return Vector2(left, right)


## Показ одного объекта: остальные прячем. В ряду сосед вроде дома загораживал
## половину кадра, когда автор рассматривал корзину или гуся вплотную.
##
## Эталон «рост кота 1,8 м» при этом НЕ прячется, а переезжает вплотную к
## выбранному объекту: без него мелочь вроде корзины (0,26 м) разворачивается
## на весь кадр и понять её размер не с чем — замечание автора 19.09.2026
## («непонятно как оценивать»).
func _set_solo(index: int) -> void:
	for i in exhibits.size():
		(exhibits[i]["node"] as Node3D).visible = index < 0 or i == index
	var reference := _reference()
	if reference == null:
		return
	reference.visible = true
	if index < 0:
		reference.position = reference_home
		return
	var entry: Dictionary = exhibits[index]
	var ref_size := measure_local_size(reference)
	reference.position = Vector3(
		_span_right_edge(entry) + REFERENCE_GAP + ref_size.x / 2,
		reference_home.y,
		entry["center"].z)


## Правая граница выбранного объекта вместе с просветом — общая точка отсчёта
## и для эталона, и для кадра: иначе они считались бы по-разному и эталон
## уезжал за край экрана.
func _span_right_edge(entry: Dictionary) -> float:
	return entry["center"].x + (entry["size"] as Vector3).x / 2


func _reference() -> Node3D:
	return get_node_or_null("Reference") as Node3D


func show_whole_pack() -> void:
	whole_pack_view = true
	focused_index = -1
	# Сначала возвращаем эталон на место: иначе его сдвинутая позиция попадёт
	# в границы ряда и кадр общего вида уедет вбок.
	_set_solo(-1)
	var bounds := _pack_bounds()
	focus_point = Vector3((bounds.x + bounds.y) / 2, 1.2, 0)
	# Коэффициент подобран так, чтобы ряд занимал кадр целиком, а не тонул в нём.
	orbit_distance = maxf((bounds.y - bounds.x) * 0.60, 7.0)
	orbit_pitch = 0.33
	_update_camera()
	_refresh_hint("вся пачка: %d объектов" % exhibits.size(), -1)


func show_exhibit(index: int) -> void:
	if exhibits.is_empty():
		return
	var entry: Dictionary = exhibits[index]
	whole_pack_view = false
	focused_index = index
	_set_solo(index)
	var size := entry["size"] as Vector3
	var ref_size := Vector3.ZERO
	var reference := _reference()
	if reference != null:
		ref_size = measure_local_size(reference)
	# Кадр строится и по эталону: если считать только по объекту, при подлёте к
	# корзине эталон оказывается за кадром и объект снова не с чем сравнить.
	var span_x := size.x + REFERENCE_GAP + ref_size.x
	var span_y := maxf(size.y, ref_size.y)
	var span := maxf(maxf(span_x, span_y), size.z)
	focus_point = Vector3(_span_right_edge(entry) + (REFERENCE_GAP + ref_size.x) / 2,
			span_y / 2, entry["center"].z)
	orbit_distance = maxf(span * 1.5, 2.2)
	orbit_pitch = 0.26
	_update_camera()
	# Запятая в дробях и «(id)» в конце: автору читать по-русски, а id нужен,
	# когда он называет, какой объект править.
	_refresh_hint("%d. %s (%s) — %s\n%s" % [
			entry["index"], entry["title"], entry["id"], entry["note"],
			_size_text(size),
		], index)


## «0.53 × 0.98 × 1.15 м» -> «0,53 × 0,98 × 1,15 м»: в русском дробь через запятую.
func _size_text(size: Vector3) -> String:
	return ("%.2f × %.2f × %.2f м (ширина × глубина × высота)" % [
			size.x, size.z, size.y,
		]).replace(".", ",")


func _refresh_hint(title: String, index: int) -> void:
	if hint == null:
		return
	var lines := [title, ""]
	if index < 0:
		for entry in exhibits:
			lines.append("%d. %s — %s" % [
					entry["index"], entry["title"], entry["note"]])
		lines.append("")
	else:
		# Иначе неясно, что за капсула стоит рядом и зачем она нужна.
		lines.append("Справа — эталон «%s»: по нему виден размер." % REFERENCE_HINT)
	# Первой строкой — геймпад: автор смотрит витрину на Deck, клавиатуры там нет.
	lines.append("Стик или крестовина — облететь и приблизить")
	lines.append("A — следующий, L1 — предыдущий, B — вся пачка")
	lines.append("X — автоповорот, Y — ортография, R1 — сброс, Menu — выход")
	lines.append("(клавиатура: стрелки, 1…7, 0, Q/E, Space, C, R, Esc)")
	hint.text = "\n".join(lines)


# ------------------------------------------------------------------ ввод ---
## Мышь — для запуска за столом; стик, крестовина и кнопки — основной способ,
## потому что автор смотрит витрину на Steam Deck без клавиатуры.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-0.12)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.12)
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			autorotate = not autorotate
	elif event is InputEventMouseMotion and dragging:
		var motion := event as InputEventMouseMotion
		orbit_angle -= motion.relative.x * 0.010
		orbit_pitch = clampf(orbit_pitch - motion.relative.y * 0.006, -0.2, 1.2)
		_update_camera()


func _zoom(factor: float) -> void:
	orbit_distance = clampf(orbit_distance * (1.0 + factor), 0.5,
			maxf((_pack_bounds().y - _pack_bounds().x) * 1.6, 20.0))
	_update_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Цифры оставлены на прямых кодах: на геймпаде их заменяют «следующий/
	# предыдущий», а клавиатурой удобно прыгать сразу к нужному объекту.
	if key.keycode >= KEY_1 and key.keycode <= KEY_7:
		var index := key.keycode - KEY_1
		if index < exhibits.size():
			show_exhibit(index)


## Непрерывные действия (стик, крестовина, стрелки) и разовые (кнопки).
func _handle_actions(delta: float) -> void:
	var orbit := Input.get_axis("viewer_orbit_left", "viewer_orbit_right")
	var zoom := Input.get_axis("viewer_zoom_in", "viewer_zoom_out")
	if not is_zero_approx(orbit):
		orbit_angle += orbit * ORBIT_SPEED * delta
	if not is_zero_approx(zoom):
		orbit_distance = clampf(orbit_distance * (1.0 + zoom * ZOOM_SPEED * delta),
				0.4, maxf((_pack_bounds().y - _pack_bounds().x) * 1.6, 20.0))
	if not is_zero_approx(orbit) or not is_zero_approx(zoom):
		_update_camera()

	if Input.is_action_just_pressed("viewer_next"):
		_step_exhibit(1)
	if Input.is_action_just_pressed("viewer_prev"):
		_step_exhibit(-1)
	if Input.is_action_just_pressed("viewer_all"):
		show_whole_pack()
	if Input.is_action_just_pressed("viewer_spin"):
		autorotate = not autorotate
	if Input.is_action_just_pressed("viewer_ortho"):
		_toggle_projection()
	if Input.is_action_just_pressed("viewer_reset"):
		show_whole_pack() if whole_pack_view else show_exhibit(_focused_index())
	if Input.is_action_just_pressed("viewer_quit"):
		get_tree().quit()


## Перелистывание по кругу: из общего вида — на первый объект.
func _step_exhibit(step: int) -> void:
	if exhibits.is_empty():
		return
	var current := -1 if whole_pack_view else _focused_index()
	show_exhibit((current + step + exhibits.size() * 2) % exhibits.size())


## Номер выбранного объекта хранится отдельно: центр кадра считается и по
## эталону, поэтому по нему одного объект уже не найти.
func _focused_index() -> int:
	return clampi(focused_index, 0, maxi(exhibits.size() - 1, 0))


func _toggle_projection() -> void:
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = maxf(orbit_distance * 0.8, 2.0)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func _process(delta: float) -> void:
	if not capture_path.is_empty():
		set_process(false)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(capture_path)
		print("PACK_VIEW_CAPTURE saved: ", capture_path)
		get_tree().quit()
		return
	if autorotate and not dragging:
		orbit_angle += delta * 0.32
		_update_camera()
	_handle_actions(delta)
