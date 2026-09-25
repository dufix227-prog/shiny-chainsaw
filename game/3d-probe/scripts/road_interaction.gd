class_name RoadInteraction
extends RefCounted

const NOTE_TEXT := "Если лес шепчет — это ветер. Если молчит — это я сплю. Персик."

var completed := {}
var kitten_choice := ""

func reset() -> void:
	completed.clear()
	kitten_choice = ""

func is_completed(id: String) -> bool:
	return bool(completed.get(id, false))

func mark_completed(id: String) -> void:
	completed[id] = true

func resolve(id: String, option: int, has_food: bool, has_coin: bool, has_wheel: bool,
		has_note := false, has_bandage := false, has_apple := false, injured := true) -> Dictionary:
	if is_completed(id):
		return {"close": true}
	match id:
		"postcat":
			if option == 0:
				return _reward("pie", "Пирожок", "О! Точно! Держи пирожок — и подсказку на дорожку...")
		"kitten_a", "kitten_b":
			if option < 2:
				kitten_choice = "kitten_a" if option == 0 else "kitten_b"
				return {"complete": true, "close": true}
		"bridge_goose":
			if option == 0:
				return _cost_result(has_food, "food")
			if option == 1 or option == 2:
				return {"complete": true, "close": true}
		"lamplighter":
			if option == 0:
				return _purchase(has_coin, "bandage", "Пластырь")
		"sleepy_cat":
			if option == 0:
				return {"complete": true, "close": true}
			if option == 1:
				return _reward("mysterious_note", "Записка", NOTE_TEXT)
		"hedgehog":
			if option == 0:
				if not has_wheel:
					return {"message": "Сначала нужно найти колесо."}
				return {"consume": "wheel", "item_id": "speed_apple", "item_name": "Яблоко +5 скорости · 3 минуты", "complete": true, "close": true}
		"quiet_cat", "ditch_onlooker", "ball_kitten", "neighbor_dog", "fence_chicken":
			if option == 0:
				return {"complete": true, "close": true}
		"pigeon_grandma":
			if option == 0:
				return _reward("bread", "Хлеб", "")
		"alarm_dog":
			if option == 0:
				return _cost_result(has_food, "food")
		"lemonade_merchant":
			if option == 0:
				return _purchase(has_coin, "lemonade", "Стакан бодрости")
		"road_bandit":
			if option == 0:
				return _cost_result(has_food, "food")
			if option == 1:
				return _cost_result(has_coin, "coin")
			if option == 2:
				return {"fight": true, "close": true}
			if option == 3:
				return {"close": true}
		"road_rucksack":
			if option == 0:
				return _reward("road_fish", "Рыбка", "")
			if option == 1:
				return _reward("small_rucksack", "Рюкзачок", "")
		"herbalist":
			if option < 2 and not injured:
				return {"message": "Лечение не требуется."}
			if option == 0:
				return _healing(has_coin, "coin")
			if option == 1:
				return _healing(has_food, "food")
		"farm_guard":
			if option == 0 or option == 1:
				var has_sign := has_note if option == 0 else has_bandage
				if not has_sign:
					return {"message": "Ворота — только со знаком. Нет знака — беги, догоню."}
				return {"message": "А... проходи. Бабушка ждёт. Наверное.", "speaker": "Сторож фермы",
					"complete": true, "close": true}
		"guardian_goose":
			if option == 0:
				return {"fight": true, "close": true}
			if option == 1:
				if not has_apple:
					return {"message": "Нет яблока."}
				return {"consume": "apple", "damage": 15, "complete": true, "close": true}
	return {"close": true}

func _reward(id: String, name: String, message: String) -> Dictionary:
	return {"item_id": id, "item_name": name, "message": message, "complete": true, "close": true}

func _purchase(available: bool, id: String, name: String) -> Dictionary:
	if not available:
		return {"message": "Нет монетки."}
	return {"consume": "coin", "item_id": id, "item_name": name, "complete": true, "close": true}

func _cost_result(available: bool, cost: String) -> Dictionary:
	if not available:
		return {"message": "Нечего отдать."}
	return {"consume": cost, "complete": true, "close": true}

func _healing(available: bool, cost: String) -> Dictionary:
	if not available:
		return {"message": "Нечего отдать." if cost == "food" else "Нет монетки."}
	return {"consume": cost, "heal": true, "complete": true, "close": true}
