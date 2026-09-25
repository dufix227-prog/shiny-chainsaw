class_name FishingData
extends RefCounted

const FISH := [
	{"name": "Плотва", "food": 5, "chance": 7},
	{"name": "Окунь", "food": 6, "chance": 7},
	{"name": "Карась", "food": 7, "chance": 7},
	{"name": "Пескарь", "food": 8, "chance": 7},
	{"name": "Уклейка", "food": 6, "chance": 7},
	{"name": "Карп", "food": 12, "chance": 4},
	{"name": "Линь", "food": 13, "chance": 4},
	{"name": "Лещ", "food": 14, "chance": 4},
	{"name": "Язь", "food": 15, "chance": 4},
	{"name": "Краснопёрка", "food": 12, "chance": 4},
	{"name": "Щука", "food": 20, "chance": 3},
	{"name": "Судак", "food": 22, "chance": 3},
	{"name": "Налим", "food": 18, "chance": 3},
	{"name": "Сом", "food": 25, "chance": 3},
	{"name": "Голавль", "food": 25, "chance": 3},
]
const TRASH := ["Сапог", "Банка", "Ветка"]
const COIN_CHANCE := 15
const TRASH_CHANCE := 15

static func total_chance() -> int:
	var total := COIN_CHANCE + TRASH_CHANCE
	for fish in FISH:
		total += int(fish.chance)
	return total

static func catch_for_roll(roll: int, coin_count: int = 1) -> Dictionary:
	var cursor := 0
	for fish in FISH:
		cursor += int(fish.chance)
		if roll < cursor:
			return {"kind": "fish", "name": fish.name, "food": fish.food}
	if roll < cursor + COIN_CHANCE:
		return {"kind": "coins", "count": clampi(coin_count, 1, 3)}
	var trash_index := clampi(floori(float(roll - cursor - COIN_CHANCE) / 5.0), 0, TRASH.size() - 1)
	return {"kind": "trash", "name": TRASH[trash_index]}
