@tool
extends Node

## Постановка стартовой катсцены С1: путь кота, камеры, затемнение — всё
## записывается в анимацию «intro» узла AnimationPlayer и сохраняется в intro.tscn.
## Сам мир (улица, лес, табличка) — общая сцена start_area_world.tscn: та же,
## где потом играет игрок. Поэтому управление начинается там, где кончилась катсцена.
##
## ВНИМАНИЕ: пересборка перезаписывает анимацию. Если правили ключи руками —
## перенесите правки сюда (в _cat_path() / shots), иначе они пропадут.
##
## Пересобрать: узел Builder → «Пересобрать катсцену» → Ctrl+S, или
## godot --headless --path game/3d-probe -s res://tools/build_intro.gd

const Terrain = preload("res://scenes/world/start_area_terrain.gd")
const StartArea = preload("res://scenes/world/start_area_builder.gd")

## Скорость кота в катсцене (единиц в секунду) — как обычный шаг в игре.
const CAT_SPEED := 2.2
## Сколько держится крупный план таблички — канон автора: 3 секунды.
const SIGN_CLOSEUP_SECONDS := 3.0

@export_tool_button("Пересобрать катсцену", "Reload") var rebuild_button := _rebuild_in_editor

var terrain := Terrain.new()


func _rebuild_in_editor() -> void:
	rebuild(get_tree().edited_scene_root)


func rebuild(scene_root: Node) -> void:
	_build_animation(scene_root)


# --- Постановка ------------------------------------------------------------------

## Путь кота: точки [позиция, «стоит ли здесь»]. Время считается по скорости.
func _cat_path() -> Array:
	var points: Array = [
		[Vector3(-40.0, 0.25, -6.5), false],
		[Vector3(-3.4, 0.25, -6.5), false],
		[Vector3(0.0, 0.25, -8.2), false],
		[Vector3(0.6, 0.25, -10.6), true],  # остановка у таблички
	]
	var z := -14.0
	while z > StartArea.SPAWN_Z + 1.0:
		points.append([Vector3(terrain.trail_center_x(z), 0.25, z), false])
		z -= 5.0
	# Последняя точка — ровно там, где игрок получит управление.
	points.append([StartArea.spawn_position_static(), false])
	return points


## Строит анимацию и возвращает точки, где стоит камера (чтобы там не росли деревья).
func _build_animation(scene_root: Node) -> Array[Vector3]:
	var player: AnimationPlayer = scene_root.get_node("AnimationPlayer")
	var animation := Animation.new()
	# Длина задаётся с запасом сразу: иначе (по умолчанию 1 с) position_track_interpolate
	# обрезает время, и камера «следит» за котом из первой секунды.
	animation.length = 600.0
	var cat_position := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(cat_position, "CatModel")
	var cat_rotation := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(cat_rotation, "CatModel")
	var cat_speed := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(cat_speed, "CatModel:move_speed")
	animation.value_track_set_update_mode(cat_speed, Animation.UPDATE_DISCRETE)
	var camera_position := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(camera_position, "ShotCamera")
	var camera_rotation := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(camera_rotation, "ShotCamera")
	var fade := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(fade, "Overlay/Fade:color")

	# Кот: идёт по точкам, у таблички стоит, поворачивается к ней и обратно.
	var path := _cat_path()
	var time := 0.0
	var yaw := -PI / 2.0
	var times := []
	var sign_look_start := 0.0
	for i in path.size():
		var point: Vector3 = path[i][0]
		if i > 0:
			var previous: Vector3 = path[i - 1][0]
			var step := point - previous
			yaw = atan2(-step.x, -step.z)
			time += step.length() / CAT_SPEED
		times.append(time)
		animation.position_track_insert_key(cat_position, time, point)
		animation.rotation_track_insert_key(cat_rotation, time, Quaternion(Vector3.UP, yaw))
		if i == 0:
			animation.track_insert_key(cat_speed, 0.0, CAT_SPEED)
		if path[i][1]:
			# Остановка: повернуться к табличке, постоять, пока идёт крупный план, развернуться.
			animation.track_insert_key(cat_speed, time, 0.0)
			var to_sign := Terrain.SIGN_POSITION - point
			var sign_yaw := atan2(-to_sign.x, -to_sign.z)
			animation.rotation_track_insert_key(cat_rotation, time + 0.6, Quaternion(Vector3.UP, sign_yaw))
			sign_look_start = time + 0.8
			var wait := 0.8 + SIGN_CLOSEUP_SECONDS + 0.8
			animation.rotation_track_insert_key(cat_rotation, time + wait - 0.4, Quaternion(Vector3.UP, sign_yaw))
			var next: Vector3 = path[i + 1][0]
			var onward := next - point
			animation.rotation_track_insert_key(cat_rotation, time + wait, Quaternion(Vector3.UP, atan2(-onward.x, -onward.z)))
			animation.position_track_insert_key(cat_position, time + wait, point)
			time += wait
			times[i] = time
			animation.track_insert_key(cat_speed, time, CAT_SPEED)
	var walk_end := time
	animation.track_insert_key(cat_speed, walk_end, 0.0)

	# Камеры: список планов [начало, откуда, куда смотрит]. Смена плана — резкая (кадр).
	var corner_time: float = times[2]
	var sign_normal := Vector3(sin(Terrain.SIGN_YAW), 0, cos(Terrain.SIGN_YAW))
	var sign_center := Terrain.SIGN_POSITION + Vector3(0, 2.05, 0)
	var shots: Array = []
	# 1. Общий план улицы: камера на южном тротуаре, панорама за котом.
	shots.append([[0.0, Vector3(-14.0, 5.5, 6.8), _cat_at(animation, cat_position, 0.0) + Vector3(0, 1.4, 0)],
		[7.0, Vector3(-14.0, 5.5, 6.8), _cat_at(animation, cat_position, 7.0) + Vector3(0, 1.4, 0)]])
	# 2. Кот идёт навстречу камере, за ним — поток машин.
	# Камера на тротуаре впереди кота и отъезжает перед ним.
	shots.append([[7.0, _cat_at(animation, cat_position, 7.0) + Vector3(6.5, 2.0, -1.0), _cat_at(animation, cat_position, 7.0) + Vector3(0, 1.6, 0)],
		[corner_time - 1.0, _cat_at(animation, cat_position, corner_time - 1.0) + Vector3(6.0, 2.2, -1.0),
			_cat_at(animation, cat_position, corner_time - 1.0) + Vector3(0, 1.6, 0)]])
	# 3. Со спины: кот сворачивает на бетонную тропу, впереди табличка.
	# Камера сзади справа, со стороны таблички: кот и табличка не заслоняют друг друга.
	shots.append([[corner_time - 1.0, Vector3(5.0, 4.2, -4.4), Vector3(1.2, 1.5, -11.0)],
		[sign_look_start, Vector3(4.5, 3.8, -5.2), Vector3(2.0, 1.8, -11.0)]])
	# 4. Крупный план таблички — ровно SIGN_CLOSEUP_SECONDS.
	shots.append([[sign_look_start, sign_center + sign_normal * 2.6 + Vector3(0, 0.15, 0), sign_center],
		[sign_look_start + SIGN_CLOSEUP_SECONDS, sign_center + sign_normal * 2.1 + Vector3(0, 0.1, 0), sign_center]])
	# 5. Камера за спиной кота: он уходит по плитам в лес.
	var follow: Array = []
	var t := sign_look_start + SIGN_CLOSEUP_SECONDS
	while t < walk_end - 6.0:
		var cat := _cat_at(animation, cat_position, t)
		follow.append([t, cat + Vector3(0.6, 3.6, 7.5), cat + Vector3(0, 1.6, -4.0)])
		t += 2.5
	shots.append(follow)
	# 6. Камера останавливается и поднимается, кот уходит вглубь леса.
	var last_cat := _cat_at(animation, cat_position, walk_end - 6.0)
	shots.append([[walk_end - 6.0, last_cat + Vector3(0.6, 3.6, 7.5), last_cat + Vector3(0, 1.6, -4.0)],
		[walk_end + 1.0, last_cat + Vector3(1.5, 7.5, 12.0), _cat_at(animation, cat_position, walk_end) + Vector3(0, 1.0, 0)]])

	var spots: Array[Vector3] = []
	for shot in shots:
		for i in shot.size():
			var key: Array = shot[i]
			# Первый ключ плана сдвинут на миг — так смена плана выглядит как склейка.
			var key_time: float = key[0] + (0.001 if i == 0 and key[0] > 0.0 else 0.0)
			animation.position_track_insert_key(camera_position, key_time, key[1])
			animation.rotation_track_insert_key(camera_rotation, key_time, _look_rotation(key[1], key[2]))
			spots.append(key[1])

	# Затемнение: из чёрного в начале, в чёрное в конце.
	var length := walk_end + 3.0
	animation.track_insert_key(fade, 0.0, Color(0, 0, 0, 1))
	animation.track_insert_key(fade, 1.5, Color(0, 0, 0, 0))
	animation.track_insert_key(fade, length - 2.2, Color(0, 0, 0, 0))
	animation.track_insert_key(fade, length, Color(0, 0, 0, 1))
	animation.length = length

	var library := AnimationLibrary.new()
	library.add_animation("intro", animation)
	for old in player.get_animation_library_list():
		player.remove_animation_library(old)
	player.add_animation_library("", library)
	return spots


func _cat_at(animation: Animation, track: int, time: float) -> Vector3:
	return animation.position_track_interpolate(track, time)


func _look_rotation(from: Vector3, to: Vector3) -> Quaternion:
	return Basis.looking_at(to - from, Vector3.UP).get_rotation_quaternion()
