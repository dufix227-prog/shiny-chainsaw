class_name RoadEncounterData
extends RefCounted

const RANDOM_NPCS := [
	{"id": "postcat", "name": "Кот-почтальон", "species": "cat"},
	{"id": "kitten_a", "name": "Котёнок А", "species": "cat"},
	{"id": "kitten_b", "name": "Котёнок Б", "species": "cat"},
	{"id": "bridge_goose", "name": "Гусь-постовой", "species": "goose"},
	{"id": "lamplighter", "name": "Фонарщик-котоаптекарь", "species": "cat"},
	{"id": "sleepy_cat", "name": "Сонный кот", "species": "cat"},
	{"id": "hedgehog", "name": "Ёж без велосипеда", "species": "hedgehog"},
	{"id": "quiet_cat", "name": "Тихий кот", "species": "cat"},
	{"id": "pigeon_grandma", "name": "Бабуля с голубями", "species": "cat"},
	{"id": "alarm_dog", "name": "Пёс-будильщик", "species": "dog"},
	{"id": "ditch_onlooker", "name": "Зевака у канавы", "species": "cat"},
	{"id": "ball_kitten", "name": "Мальчишка-котёнок", "species": "cat"},
	{"id": "neighbor_dog", "name": "Сосед-пёс", "species": "dog"},
	{"id": "fence_chicken", "name": "Курица на чужом заборе", "species": "chicken"},
	{"id": "lemonade_merchant", "name": "Торговец лимонадом", "species": "cat"},
]

const BANDIT := {"id": "road_bandit", "name": "Бандит", "species": "cat", "hp": 15}
const STORY_NPCS := [
	{"id": "herbalist", "name": "Травник-лекарь", "species": "cat", "accessory": "herb_bag"},
	{"id": "farm_guard", "name": "Сторож фермы", "species": "cat", "accessory": "lantern"},
	{"id": "guardian_goose", "name": "Гусь-охранник", "species": "goose", "accessory": "scar",
		"visual_scale": 1.35, "hp": 15},
]

const INTERACTIONS := {
	"postcat": {"line": "Стоять!.. Ты не видел — где тут пахнет клубникой? У меня письмо, а адрес — „туда“.",
		"options": ["Показать в сторону фермы", "Не знаю", "Промолчать", "Не знаю языка", "Сбежать"]},
	"kitten_a": {"line": "Котята спорят, чей Братишкин круче.",
		"options": ["Кивнуть котёнку А", "Кивнуть котёнку Б", "Уйти"]},
	"kitten_b": {"line": "Котята спорят, чей Братишкин круче.",
		"options": ["Кивнуть котёнку А", "Кивнуть котёнку Б", "Уйти"]},
	"bridge_goose": {"line": "Ш-ш-ш-ш!", "options": ["Дать еду", "Обойти вброд", "Прогнать", "Уйти"]},
	"lamplighter": {"line": "Фонарщик-котоаптекарь продаёт пластырь за монетку.",
		"options": ["Купить пластырь", "Уйти"]},
	"sleepy_cat": {"line": "Сонный кот спит на заборе.",
		"options": ["Разбудить", "Украсть записку", "Уйти"]},
	"hedgehog": {"line": "Ёж остался без колеса.", "options": ["Вернуть колесо", "Уйти"]},
	"quiet_cat": {"line": "Тихий кот молчит.", "options": ["Постоять рядом", "Уйти"]},
	"pigeon_grandma": {"line": "Бабуля кормит голубей и делится хлебом.",
		"options": ["Принять хлеб", "Уйти"]},
	"alarm_dog": {"line": "Пёс-будильщик лает на прохожих.", "options": ["Угостить", "Уйти"]},
	"ditch_onlooker": {"line": "Зевака хвастается бродом.", "options": ["Послушать", "Уйти"]},
	"ball_kitten": {"line": "Мальчишка-котёнок гоняет мяч.", "options": ["Погонять мяч", "Уйти"]},
	"neighbor_dog": {"line": "Сосед-пёс всё видел.", "options": ["Послушать", "Уйти"]},
	"fence_chicken": {"line": "Курица сидит на чужом заборе.", "options": ["Загнать к хозяину", "Уйти"]},
	"lemonade_merchant": {"line": "Торговец предлагает стакан бодрости за монетку.",
		"options": ["Купить лимонад", "Уйти"]},
	"road_bandit": {"line": "Стой. Еда или монетки. Выбирай — кошелёк или лоб.",
		"options": ["Отдать еду", "Отдать монетку", "Драться", "Убежать"]},
	"road_rucksack": {"line": "В рюкзачке лежит рыбка.",
		"options": ["Взять рыбку", "Взять весь рюкзачок", "Уйти"]},
	"herbalist": {"line": "Ох, потрепало тебя... Садись. Монетка — и как новенький.",
		"options": ["Отдать монетку", "Отдать еду", "Уйти"]},
	"farm_guard": {"line": "Стой. Кто идёт?",
		"options": ["Показать записку", "Показать пластырь", "Уйти"]},
	"guardian_goose": {"line": "Ш-ш-ш-ш!",
		"options": ["Драться", "Отдать яблоко", "Уйти"]},
}

const ROBBERY_LOOT := {
	"postcat": "Письма", "kitten_a": "Конфеты", "kitten_b": "Конфеты",
	"bridge_goose": "Перья", "lamplighter": "Мелочь из кассы", "hedgehog": "Иголки",
	"pigeon_grandma": "Крошки", "alarm_dog": "Кость", "ball_kitten": "Мяч",
	"road_bandit": "Заначка",
}

static func random_ids() -> Array[String]:
	var ids: Array[String] = []
	for data in RANDOM_NPCS:
		ids.append(String(data.id))
	return ids

static func interaction(id: String) -> Dictionary:
	return INTERACTIONS.get(id, {})

static func robbery_loot(id: String) -> String:
	return String(ROBBERY_LOOT.get(id, ""))
