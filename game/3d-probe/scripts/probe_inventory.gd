class_name ProbeInventory
extends RefCounted

const MAX_WEIGHT_KG := 80.0
const HOTBAR_SIZE := 5
const POCKET_SIZE := 5
const BACKPACK_PAGE_SIZE := 15

var hotbar: Array = []
var pockets: Array = []
var backpack_pages: Array = []
var backpack := "none"
var current_page := 0

func _init() -> void:
	reset()

func reset() -> void:
	hotbar = [food_stack(2), stick_stack(), null, null, null]
	pockets = [water_stack(), map_stack(), null, null, null]
	backpack_pages = []
	backpack = "none"
	current_page = 0

static func food_stack(count: int = 1) -> Dictionary:
	return {"id": "food", "name": "Еда", "count": count, "weight": 0.4, "food": true, "use": true, "drop": true}

static func water_stack() -> Dictionary:
	return {"id": "water", "name": "Вода", "count": 1, "weight": 0.7, "use": false, "drop": true}

static func map_stack() -> Dictionary:
	return {"id": "map", "name": "Карта", "count": 1, "weight": 0.2, "use": false, "drop": true}

static func coffee_stack() -> Dictionary:
	return {"id": "coffee", "name": "Ускоряющий кофе", "count": 1, "weight": 0.3, "use": true, "drop": true}

static func stick_stack() -> Dictionary:
	return {"id": "stick", "name": "Палка", "count": 1, "weight": 0.8, "use": false, "drop": true}

static func fishing_rod_stack() -> Dictionary:
	return {"id": "fishing_rod", "name": "Удочка", "count": 1, "weight": 1.2, "use": false, "drop": true}

static func fish_stack(name: String, food_value: int) -> Dictionary:
	return {"id": "food", "name": name, "count": 1, "weight": 0.4,
		"food": true, "food_value": food_value, "use": true, "drop": true}

static func trash_stack(name: String) -> Dictionary:
	return {"id": "fishing_trash", "name": name, "count": 1, "weight": 0.4,
		"use": false, "drop": true}

static func road_item_stack(id: String, name: String, use := false) -> Dictionary:
	return {"id": id, "name": name, "count": 1, "weight": 0.4, "use": use, "drop": true}

func equip_test_backpack(kind: String) -> void:
	backpack = kind
	backpack_pages = []
	if kind != "none":
		backpack_pages.append(_empty_page())
	if kind.begins_with("level_10"):
		backpack_pages.append(_empty_page())
	current_page = 0

func has_backpack() -> bool:
	return backpack != "none"

func page_count() -> int:
	return backpack_pages.size()

func _empty_page() -> Array:
	var page: Array = []
	page.resize(BACKPACK_PAGE_SIZE)
	return page

func slot(address: String) -> Variant:
	var parsed := address.split(":")
	if parsed.size() != 2:
		return null
	var index := int(parsed[1])
	match parsed[0]:
		"hotbar": return hotbar[index] if index >= 0 and index < hotbar.size() else null
		"pocket": return pockets[index] if index >= 0 and index < pockets.size() else null
		"backpack":
			return backpack_pages[current_page][index] if current_page < backpack_pages.size() and index >= 0 and index < BACKPACK_PAGE_SIZE else null
	return null

func set_slot(address: String, value) -> bool:
	var parsed := address.split(":")
	if parsed.size() != 2:
		return false
	var index := int(parsed[1])
	match parsed[0]:
		"hotbar":
			if index >= 0 and index < hotbar.size(): hotbar[index] = value; return true
		"pocket":
			if index >= 0 and index < pockets.size(): pockets[index] = value; return true
		"backpack":
			if current_page < backpack_pages.size() and index >= 0 and index < BACKPACK_PAGE_SIZE: backpack_pages[current_page][index] = value; return true
	return false

func transfer(source: String, target: String) -> bool:
	var item = slot(source)
	if item == null or source == target:
		return false
	var occupant = slot(target)
	if occupant == null:
		if not set_slot(target, item):
			return false
		set_slot(source, null)
		return true
	# Перестановка как в Minecraft: два занятых слота меняются стеками.
	if not set_slot(source, occupant):
		return false
	set_slot(target, item)
	return true

func remove_one(address: String) -> Variant:
	var raw: Variant = slot(address)
	if raw == null:
		return null
	var item: Dictionary = raw as Dictionary
	var dropped: Dictionary = item.duplicate(true)
	dropped["count"] = 1
	if int(item["count"]) > 1:
		item["count"] = int(item["count"]) - 1
	else:
		set_slot(address, null)
	return dropped

func restore_one(address: String, item: Dictionary) -> bool:
	var raw: Variant = slot(address)
	if raw == null:
		return set_slot(address, item)
	var current: Dictionary = raw as Dictionary
	if current["id"] == item["id"]:
		current["count"] = int(current["count"]) + int(item["count"] )
		return true
	return false

func food_count() -> int:
	var total := 0
	for group in [hotbar, pockets] + backpack_pages:
		for item in group:
			if item != null and (item.id == "food" or item.get("food", false)):
				total += item.count
	return total

func first_food_slot() -> String:
	for prefix in ["hotbar", "pocket", "backpack"]:
		var size := BACKPACK_PAGE_SIZE if prefix == "backpack" else (HOTBAR_SIZE if prefix == "hotbar" else POCKET_SIZE)
		if prefix == "backpack" and backpack_pages.is_empty():
			continue
		for index in size:
			var address := "%s:%d" % [prefix, index]
			var item = slot(address)
			if item != null and (item.id == "food" or item.get("food", false)):
				return address
	return ""

func first_slot_with_id(id: String) -> String:
	for prefix in ["hotbar", "pocket", "backpack"]:
		var size := BACKPACK_PAGE_SIZE if prefix == "backpack" else (HOTBAR_SIZE if prefix == "hotbar" else POCKET_SIZE)
		if prefix == "backpack" and backpack_pages.is_empty():
			continue
		for index in size:
			var address := "%s:%d" % [prefix, index]
			var item = slot(address)
			if item != null and item.id == id:
				return address
	return ""

func first_droppable_slot() -> String:
	for prefix in ["hotbar", "pocket", "backpack"]:
		var size := BACKPACK_PAGE_SIZE if prefix == "backpack" else (HOTBAR_SIZE if prefix == "hotbar" else POCKET_SIZE)
		if prefix == "backpack" and backpack_pages.is_empty():
			continue
		for index in size:
			var address := "%s:%d" % [prefix, index]
			var item = slot(address)
			if item != null and item.get("drop", false):
				return address
	return ""

func total_weight() -> float:
	var total := 0.0
	for group in [hotbar, pockets] + backpack_pages:
		for item in group:
			if item != null:
				total += item.weight * item.count
	return total

func add_to_first_free(item: Dictionary) -> bool:
	if total_weight() + item.weight * item.count > MAX_WEIGHT_KG:
		return false
	for prefix in ["hotbar", "pocket", "backpack"]:
		var size := BACKPACK_PAGE_SIZE if prefix == "backpack" else (HOTBAR_SIZE if prefix == "hotbar" else POCKET_SIZE)
		if prefix == "backpack" and backpack_pages.is_empty():
			continue
		for index in size:
			var address := "%s:%d" % [prefix, index]
			if slot(address) == null:
				return set_slot(address, item)
	return false
