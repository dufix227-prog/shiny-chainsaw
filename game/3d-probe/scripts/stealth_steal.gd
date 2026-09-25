extends Control
## К11: кража клубнички — мини-игра стелса и тайминга, сердце пролога.
##
## Канон (решения автора 06.09.2026): у бабушки зона взгляда; игрок перебегает
## из куста в куст (6 секунд на перебежку), чтобы собрать корзину из 42
## клубничек; бабушка может фейкнуть «Я вас вижу, выходите!» — игрок гадает;
## фейк и провал перебежки дают выбор; если не пытаться сбежать, бабушка просто
## так кормит (она добрая) — это отдельная добрая концовка; собрал корзину —
## успех; выход из кражи сразу в сцену, сейвов внутри нет.
##
## Числа (сколько ягод за перебежку, сколько длится выбор, как часто кричит
## бабушка) — технические, до решения автора: в плане они помечены как правимые
## по ощущению.

signal finished(outcome: int)

const Granny = preload("res://scripts/granny.gd")
const Fyvfyv = preload("res://scripts/npc_fyvfyv.gd")

const SUCCESS := 0      # корзина собрана: 42 клубнички
const ESCAPED := 1      # побег без клубнички
const FED := 2          # сдался — бабушка накормила (добрая концовка)

const BERRIES_TOTAL := 42
const DASH_SECONDS := 6.0        # канон: 6 секунд на перебежку
const CHOICE_SECONDS := 3.0      # сколько даётся на выбор
const BERRIES_PER_DASH := BERRIES_TOTAL / 6

## Точки двора: старт, кусты-укрытия и грядка с корзиной. Координаты 0…1.
const BUSHES := [
	Vector2(0.16, 0.50), Vector2(0.32, 0.26), Vector2(0.30, 0.74),
	Vector2(0.48, 0.26), Vector2(0.46, 0.74), Vector2(0.64, 0.50),
]
const BED := Vector2(0.86, 0.50)

enum { HIDDEN, DASH, CHOICE, DONE }

var opened := false
var paused := false
var phase := HIDDEN
var step := 0                    # сколько перебежек уже сделано
var berries := 0
var player_position := Vector2.ZERO
var dash_from := Vector2.ZERO
var dash_to := Vector2.ZERO
var dash_left := 0.0
var choice_left := 0.0
var choice_kind := ""            # "fake" или "caught"
var outcome := -1
var granny := Granny.new()
var fyvfyv := Fyvfyv.new()
var autosave_requests := 0
var status := Label.new()
var choice_label := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_top = 26
	status.offset_bottom = 96
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 20)
	add_child(status)
	choice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	choice_label.offset_top = -120
	choice_label.offset_bottom = -40
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.add_theme_font_size_override("font_size", 22)
	add_child(choice_label)
	visible = false

func begin() -> void:
	# Перед началом — автосейв (канон). Сейвов в пробе ещё нет (К13), поэтому
	# мини-игра только отмечает запрос, как и ночной сон.
	opened = true
	paused = false
	phase = HIDDEN
	step = 0
	berries = 0
	outcome = -1
	granny.reset()
	fyvfyv.reset()
	player_position = BUSHES[0]
	dash_left = 0.0
	choice_left = 0.0
	choice_kind = ""
	autosave_requests += 1
	visible = true
	_refresh_labels()
	queue_redraw()

func target_position() -> Vector2:
	# Куда идёт текущая перебежка: последняя ведёт к грядке с корзиной.
	if step >= BUSHES.size() - 1:
		return BED
	return BUSHES[step + 1]

func can_dash() -> bool:
	return opened and not paused and phase == HIDDEN and step < BUSHES.size()

func dash() -> bool:
	if not can_dash():
		return false
	dash_from = player_position
	dash_to = target_position()
	dash_left = DASH_SECONDS
	phase = DASH
	_refresh_labels()
	return true

func advance(delta: float) -> void:
	if not opened or paused or delta <= 0:
		return
	granny.advance(delta)
	match phase:
		HIDDEN:
			# В укрытии бабушка не может заметить кота, даже если смотрит на куст,
			# но фейкнуть она может и тут — в этом и загадка.
			granny.update_vision(player_position)
			if granny.warned(player_position, true):
				_open_choice("fake")
		DASH:
			dash_left = maxf(0.0, dash_left - delta)
			var progress := 1.0 - dash_left / DASH_SECONDS
			player_position = dash_from.lerp(dash_to, progress)
			if granny.warned(player_position):
				# Крик ловит на перебежке: выбор из канона — остаться или бежать.
				_open_choice("caught")
				return
			if dash_left <= 0.0:
				_finish_dash()
		CHOICE:
			choice_left = maxf(0.0, choice_left - delta)
			if choice_left <= 0.0:
				# Молчание = остаться тихо: так подсказывает фывфыв.
				choose(true)
	queue_redraw()

func _finish_dash() -> void:
	step += 1
	berries = mini(BERRIES_TOTAL, berries + BERRIES_PER_DASH)
	granny.shouted = false
	granny.clear_fake()
	if berries >= BERRIES_TOTAL:
		_finish(SUCCESS)
		return
	phase = HIDDEN
	_refresh_labels()

func _open_choice(kind: String) -> void:
	phase = CHOICE
	choice_kind = kind
	choice_left = CHOICE_SECONDS
	if kind == "fake" or kind == "caught":
		fyvfyv.advice_for_fake()
	_refresh_labels()

func choose(stay: bool) -> void:
	# stay = «остаться тихо». Если бабушка правда видит, остаться не спасает —
	# даётся последний выбор: бежать или сдаться (канон).
	if phase != CHOICE:
		return
	if choice_kind == "surrender":
		# Сдался — бабушка кормит, потому что она добрая; побежал — ушёл без ягод.
		_finish(FED if stay else ESCAPED)
		return
	if not stay:
		_finish(ESCAPED)
		return
	if granny.sees_player:
		_open_choice("surrender")
		return
	# Это был фейк: кот остался, и перебежка продолжается.
	granny.clear_fake()
	granny.shouted = true
	phase = DASH if dash_left > 0.0 else HIDDEN
	_refresh_labels()

func refusal_to_escape() -> void:
	# Отдельный вход для ветки «провал перебежки → сдаться бабушке».
	if opened and not paused:
		_finish(FED)

func _finish(code: int) -> void:
	outcome = code
	phase = DONE
	# Экран остаётся: исход надо увидеть. Закрывает его игрок сам — A/E или B,
	# и только после этого кража действительно закончена.
	visible = true
	_refresh_labels()
	finished.emit(code)

func dismiss() -> bool:
	if phase != DONE or not visible:
		return false
	opened = false
	visible = false
	return true

func status_line() -> String:
	if phase == DONE:
		match outcome:
			SUCCESS:
				return "Корзина собрана: %d / %d клубничек" % [BERRIES_TOTAL, BERRIES_TOTAL]
			FED:
				return "Кот сдался · бабушка накормила"
			_:
				return "Побег без клубнички"
	return "Клубничек %d / %d · перебежка %.1f с" % [berries, BERRIES_TOTAL, dash_left]

func _refresh_labels() -> void:
	status.text = status_line()
	if phase != CHOICE:
		choice_label.text = "A / E — перебежать к следующему кусту" if phase == HIDDEN else ""
		return
	if choice_kind == "surrender":
		choice_label.text = "Бабушка подошла · A / E — сдаться (накормит)   B — бежать"
		return
	choice_label.text = "Бабушка: «%s» · совет фывфыва: %s\nA / E — остаться тихо   B — бежать" \
		% [granny.FAKE_LINE, fyvfyv.FAKE_ADVICE]

func set_paused(value: bool) -> void:
	paused = value

func reset() -> void:
	opened = false
	paused = false
	visible = false
	phase = HIDDEN
	step = 0
	berries = 0
	outcome = -1
	granny.reset()
	fyvfyv.reset()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d2a1bef"))
	var yard := Rect2(size * Vector2(0.06, 0.14), size * Vector2(0.88, 0.74))
	draw_rect(yard, Color("6f7d45"), true)
	# Зона взгляда: рисуется конусом, чтобы игрок сам решал, когда бежать.
	var granny_point := yard.position + granny.position * yard.size
	var reach := granny.VIEW_RANGE * yard.size.x
	var half := deg_to_rad(granny.VIEW_ANGLE)
	var left := granny_point + Vector2.from_angle(granny.facing - half) * reach
	var right := granny_point + Vector2.from_angle(granny.facing + half) * reach
	draw_colored_polygon(PackedVector2Array([granny_point, left, right]),
		Color("f0d27a55") if not granny.sees_player else Color("e06b4f77"))
	for bush in BUSHES:
		draw_circle(yard.position + bush * yard.size, 14.0, Color("3d6b34"))
	draw_rect(Rect2(yard.position + BED * yard.size - Vector2(18, 26), Vector2(36, 52)),
		Color("8a5a34"), true)
	draw_circle(yard.position + granny.position * yard.size, 13.0,
		Color("d9b7a0") if not granny.sees_player else Color("e06b4f"))
	draw_circle(yard.position + player_position * yard.size, 11.0, Color("e5a34f"))
