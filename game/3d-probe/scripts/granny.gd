extends RefCounted
## К11: бабушка и её зона взгляда.
##
## Канон (решение автора 06.09.2026): у бабушки есть зона взгляда, она либо
## смотрит, либо фейкует — «Я вас вижу, выходите!»; игрок гадает, фейк это или
## нет. Бабушка на самом деле добрая, но поначалу кажется злой.
##
## Числа (угол обзора, дальность, как часто она поворачивается и фейкует) —
## технические, до решения автора: в плане помечены как правимые по ощущению.

const VIEW_ANGLE := 32.0        # половина угла обзора, градусы
const VIEW_RANGE := 0.34        # дальность взгляда в клетках двора
const TURN_EVERY := Vector2(2.8, 4.6)     # через сколько поворачивается
const FAKE_EVERY := Vector2(7.0, 13.0)    # как часто пробует фейк
## Фраза автора (канон): бабушка кричит её и когда видит, и когда блефует.
const FAKE_LINE := "Я вас вижу, выходите!"

var position := Vector2(0.74, 0.30)   # место во дворе, координаты 0…1
var facing := 0.0                     # куда смотрит, радианы
var sees_player := false              # видит прямо сейчас
var faking := false                   # крикнула без повода
var shouted := false                  # крик уже показан игроку
var turns := 0                        # счётчик поворотов (для теста)
## Автотестам нужен предсказуемый двор: фейки отключаются, как случайность
## погоды в weather.gd. В игре всегда включены.
var fakes_enabled := true
var rng := RandomNumberGenerator.new()
var _turn_timer := 0.0
var _fake_timer := 0.0

func _init() -> void:
	reset()

func reset(seed_value: int = 11092026) -> void:
	facing = 0.0
	sees_player = false
	faking = false
	shouted = false
	turns = 0
	rng.seed = seed_value
	_turn_timer = rng.randf_range(TURN_EVERY.x, TURN_EVERY.y)
	_fake_timer = rng.randf_range(FAKE_EVERY.x, FAKE_EVERY.y)

func advance(delta: float) -> void:
	if delta <= 0:
		return
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn()
	_fake_timer -= delta
	if _fake_timer <= 0.0:
		_fake_timer = rng.randf_range(FAKE_EVERY.x, FAKE_EVERY.y)
		if fakes_enabled:
			faking = true
			# Новый крик можно показывать снова — иначе бабушка кричит один раз
			# за всю кражу.
			shouted = false

func _turn() -> void:
	# Поворот на 45–135°: она обшаривает двор, а не смотрит в одну точку.
	turns += 1
	var step := rng.randf_range(0.785, 2.356) * (1.0 if rng.randf() < 0.5 else -1.0)
	facing = wrapf(facing + step, -PI, PI)
	_turn_timer = rng.randf_range(TURN_EVERY.x, TURN_EVERY.y)

func looks_at(point: Vector2) -> bool:
	# Зона взгляда: угол и дальность. Это и есть «зона взгляда» из канона.
	var offset := point - position
	if offset.length() > VIEW_RANGE:
		return false
	if offset.length() < 0.001:
		return true
	var angle := absf(rad_to_deg(wrapf(offset.angle() - facing, -PI, PI)))
	return angle <= VIEW_ANGLE

func update_vision(point: Vector2) -> bool:
	sees_player = looks_at(point)
	return sees_player

func clear_fake() -> void:
	faking = false

func warned(point: Vector2, hidden: bool = false) -> bool:
	# Крик показывается, когда она либо правда видит, либо фейкует — снаружи эти
	# два случая неразличимы, в этом и загадка (канон). Из укрытия кот не виден:
	# hidden передаётся, когда он сидит в кусте, и тогда крик может быть только
	# фейком.
	if shouted:
		return false
	var noticed := false if hidden else update_vision(point)
	if noticed or faking:
		shouted = true
		return true
	return false

func status_text() -> String:
	if faking and shouted:
		return FAKE_LINE
	if sees_player:
		return "Заметила кота!"
	return "Смотрит в сторону"
