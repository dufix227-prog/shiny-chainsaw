extends Node

## Сохранения игры. Автозагрузка SaveGame (project.godot).
##
## Канон автора (ideas/common/design/saves/plan.md): 20 слотов, у снимка дата,
## его можно удалить и переименовать; при выходе без сохранения — напоминание.
## Пока не сделано из канона: режимы сложности, грибы, сон, контрольные точки,
## папки снимков.
##
## Файл снимка — user://saves/slot_NN.json. В нём номер версии формата: если
## формат меняется, FORMAT_VERSION растёт и в _migrate() добавляется перевод
## старых снимков — старые сохранения игрока не должны ломаться.

const FORMAT_VERSION := 1
const SLOT_COUNT := 20
const SAVE_DIR := "user://saves/"
## Папку можно подменить (тесты пишут в отдельную, не трогая снимки игрока).
var save_dir := SAVE_DIR

## Имя героя вводит игрок перед катсценой.
var hero_name := ""
## true, если после последней записи/загрузки игрок что-то сделал.
var has_unsaved_progress := false

var _pending_state := {}


func slot_path(slot: int) -> String:
	return save_dir + "slot_%02d.json" % slot


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Краткое описание слота для меню или {} если слот пуст.
func read_slot(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Снимок %d повреждён и пропущен" % slot)
		return {}
	return _migrate(data)


## Номер последнего по времени снимка или -1.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in range(1, SLOT_COUNT + 1):
		var data := read_slot(slot)
		if not data.is_empty() and data.saved_at > best_time:
			best_time = data.saved_at
			best = slot
	return best


## Записать текущую игру в слот. title пустой — «Сохранение N».
func save_to_slot(slot: int, title: String = "") -> bool:
	var scene := get_tree().current_scene
	var player: Node3D = scene.get_node_or_null("CatPlayer") if scene else null
	if player == null:
		push_warning("Сохранять можно только в игре, где есть кот")
		return false
	var previous := read_slot(slot)
	if title.strip_edges().is_empty():
		title = previous.get("title", "Сохранение %d" % slot)
	var pivot: Node3D = player.get_node("CameraPivot")
	var data := {
		"version": FORMAT_VERSION,
		"title": title,
		"saved_at": Time.get_unix_time_from_system(),
		"hero_name": hero_name,
		"scene": scene.scene_file_path,
		"metres": _metres(scene, player),
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"camera_yaw": pivot.rotation.y,
			"camera_pitch": pivot.rotation.x,
			"stamina": player.stamina,
		},
	}
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Не удалось записать снимок %d" % slot)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	has_unsaved_progress = false
	return true


## Открыть сцену снимка; положение кота восстановится, когда сцена будет готова.
func load_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data.is_empty() or not ResourceLoader.exists(data.scene):
		return false
	hero_name = data.hero_name
	_pending_state = data.player
	has_unsaved_progress = false
	get_tree().paused = false
	get_tree().change_scene_to_file(data.scene)
	return true


## Вызывается игровой сценой в _ready(): применить загруженное состояние.
func restore_into(scene: Node) -> void:
	if _pending_state.is_empty():
		return
	var player: Node3D = scene.get_node_or_null("CatPlayer")
	if player:
		var position: Array = _pending_state.position
		player.global_position = Vector3(position[0], position[1], position[2])
		player.get_node("CameraPivot").rotation = Vector3(_pending_state.camera_pitch, _pending_state.camera_yaw, 0)
		player.stamina = _pending_state.stamina
	_pending_state = {}


func delete_slot(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))


func rename_slot(slot: int, title: String) -> void:
	var data := read_slot(slot)
	if data.is_empty() or title.strip_edges().is_empty():
		return
	data.title = title.strip_edges()
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))


## Новая игра: сброс всего, что относится к прохождению.
func start_new_game(new_hero_name: String) -> void:
	hero_name = new_hero_name
	_pending_state = {}
	has_unsaved_progress = false


func _metres(scene: Node, player: Node3D) -> float:
	if scene.has_method("metres_walked"):
		return scene.metres_walked()
	# 12,24 единицы мира на метр пути — общий темп маршрута.
	return maxf(-player.global_position.z / 12.24, 0.0)


## Перевод старых снимков в текущий формат. Сейчас формат один (версия 1).
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 1))
	if version > FORMAT_VERSION:
		push_warning("Снимок из более новой версии игры (формат %d)" % version)
	# Пример на будущее: if version < 2: data.new_field = значение_по_умолчанию
	data.version = FORMAT_VERSION
	return data
