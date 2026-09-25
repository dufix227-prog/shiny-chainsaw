extends RefCounted

const Profile = preload("res://scripts/needs_profile.gd")
const Inventory = preload("res://scripts/food_inventory.gd")
const Route = preload("res://scripts/route.gd")
var profile: Profile = preload("res://data/needs_probe.tres")
var inventory := Inventory.new()
var enabled := false
var resting := false
var food := 0.0
var stamina := 0.0
# Keep the original laboratory API backed by the same inventory stack.
var portions: int:
	get:
		return inventory.portions
	set(value):
		inventory.portions = maxi(0, value)

func _init() -> void:
	reset()

func reset() -> void:
	food = profile.starting_food
	stamina = profile.starting_stamina
	portions = profile.portions
	resting = false

func toggle() -> void:
	enabled = not enabled
	resting = false

func can_move() -> bool:
	return not enabled or (not resting and food > 0 and stamina > 0)

func can_eat() -> bool:
	return enabled and portions > 0 and food < 100

func eat() -> bool:
	if not can_eat():
		return false
	inventory.consume_portion()
	food = minf(100, food + profile.food_per_portion)
	return true

func toggle_rest() -> void:
	if enabled:
		resting = not resting

func apply_fatigue(amount: float) -> void:
	# Усталость от дождя (К10): только расход сил, без восстановления.
	# Выключенные нужды не трогаем — «чистая ходьба» остаётся чистой.
	if not enabled or amount <= 0:
		return
	stamina = clampf(stamina - amount, 0, 100)

func advance(delta: float, distance: float, running: bool = false) -> void:
	if not enabled or delta <= 0:
		return
	var moving := distance > 0.001 and not resting
	var food_rate := profile.food_walking_per_second if moving else profile.food_idle_per_second
	food = clampf(food - food_rate * delta, 0, 100)
	var recovery := 0.0
	if resting:
		recovery = profile.stamina_rest_per_second
	elif not moving:
		recovery = profile.stamina_standing_per_second
	if recovery > 0:
		if food < profile.warning_threshold:
			recovery *= profile.hungry_recovery_factor
		stamina = minf(100, stamina + recovery * delta)
	elif moving:
		var multiplier := profile.stamina_run_multiplier if running else 1.0
		if food < profile.warning_threshold:
			multiplier *= profile.hungry_stamina_multiplier
		stamina = maxf(0, stamina - profile.stamina_per_metre * multiplier * distance / Route.WORLD_UNITS_PER_METRE)

func status() -> String:
	if not enabled:
		return "Чистая ходьба · нужды заморожены"
	if food <= 0:
		return "Нет еды · E — поесть" if portions > 0 else "Запас исчерпан · R — новая проба"
	if resting:
		return "Сидим · Space — продолжить путь"
	if stamina <= 0:
		return "Сил нет · Space — отдохнуть"
	if food < profile.warning_threshold:
		return "Кот голоден · E — поесть"
	if stamina < profile.warning_threshold:
		return "Кот устал · Space — отдохнуть"
	return "Иди, следи за едой и отдыхай"
