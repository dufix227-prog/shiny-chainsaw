extends SceneTree

## Проверки кота: четыре модели, мимика, моргание, неподвижность стоя (канон),
## шаги со звуком, виды камеры и приближение, сценка у завала (один раз).
## godot --headless --fixed-fps 60 --path game/3d-probe -s res://tests/cat.gd

const CatModel = preload("res://scenes/player/cat_model.gd")
const StartArea = preload("res://scenes/world/start_area_builder.gd")
const TEST_SETTINGS := "user://test_cat_settings.cfg"

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("НЕ ПРОШЛО: ", message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	var settings: Node = root.get_node("GameSettings")
	settings.settings_path = TEST_SETTINGS
	settings.reset_to_defaults()
	await _check_variants()
	await _check_camera_and_reaction(settings)
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)
	print("Кот: проверок ", checks, ", провалено ", failures)
	quit(1 if failures > 0 else 0)


func _check_variants() -> void:
	var heights := {}
	var head_sizes := {}
	for id in CatModel.VARIANT_NAMES:
		var cat: Node3D = load(CatModel.scene_path(id)).instantiate()
		root.add_child(cat)
		await frames(1)
		check(cat.variant_id == id, "модель %s знает свой вариант" % id)
		heights[id] = cat.eye_height
		head_sizes[id] = cat.get_node("Head").mesh.get_aabb().size
		for mood in CatModel.EMOTION_NAMES:
			cat.emotion = mood
			check(cat.get_node("Head/Eyes").mesh.resource_path.ends_with("eyes_%s.res" % mood), "%s: глаза «%s»" % [id, mood])
			check(cat.get_node("Head/Mouth").mesh.resource_path.ends_with("mouth_%s.res" % mood), "%s: рот «%s»" % [id, mood])
		cat.emotion = "непонятно"
		check(cat.emotion == "neutral", "неизвестная эмоция — спокойное лицо")
		# Стоя кот не двигается (канон): части тела на месте.
		var before: Vector3 = cat.get_node("LegLeft").rotation + cat.get_node("Body").position
		await frames(30)
		var after: Vector3 = cat.get_node("LegLeft").rotation + cat.get_node("Body").position
		check(before.is_equal_approx(after), "%s: стоя не двигается" % id)
		# Моргание: глаза закрываются и открываются.
		cat._next_blink = 0.0
		cat._blink(0.016)
		check(cat.get_node("Head/Eyes").mesh.resource_path.ends_with("eyes_closed.res"), "%s: моргает" % id)
		cat._blink(0.2)
		check(cat.get_node("Head/Eyes").mesh.resource_path.ends_with("eyes_neutral.res"), "%s: открывает глаза" % id)
		# Шаги: при ходьбе звучат.
		cat.move_speed = 3.4
		var played := false
		for i in 60:
			await process_frame
			played = played or cat.get_node("Footsteps").playing
		check(played, "%s: при ходьбе звучат шаги" % id)
		cat.queue_free()
	var distinct_heads := {}
	for id in head_sizes:
		distinct_heads[str(head_sizes[id])] = true
	check(distinct_heads.size() == 4, "у четырёх моделей разные головы (не перекраска)")
	check(heights.b < heights.a and heights.c > heights.b, "чиби ниже, стройный выше (разный рост)")


func _check_camera_and_reaction(settings: Node) -> void:
	root.get_node("SaveGame").start_new_game("Тест", "b")
	change_scene_to_file("res://scenes/world/start_area.tscn")
	await frames(3)
	var scene := current_scene
	var player: CharacterBody3D = scene.get_node("CatPlayer")
	check(player.model.variant_id == "b", "в игре выбранная модель")
	var arm: SpringArm3D = player.spring_arm
	check(player.camera_mode == settings.CameraMode.THIRD_PERSON, "по умолчанию — третье лицо")
	var far: float = arm.spring_length
	player.zoom(-2.0)
	check(arm.spring_length < far, "приближение уменьшает расстояние")
	player.zoom(4.0)
	check(arm.spring_length > far, "отдаление увеличивает расстояние")
	settings.set_value("camera_distance", player.ZOOM_MIN)
	player.zoom(-1.0)
	check(player.camera_mode == settings.CameraMode.FIRST_PERSON, "ближе минимума — первое лицо")
	check(arm.spring_length == 0.0, "в первом лице камера в голове")
	var part: GeometryInstance3D = player.model.get_node("Body")
	check(part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "в первом лице кот не заслоняет, тень есть")
	player.zoom(1.0)
	check(player.camera_mode == settings.CameraMode.THIRD_PERSON, "отдаление из первого лица — обратно")
	check(part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "кот снова виден")
	settings.set_value("camera_side", 1.5)
	settings.set_value("camera_height", 5.0)
	player.set_camera_mode(settings.CameraMode.CUSTOM)
	check(is_equal_approx(arm.position.x, 1.5) and is_equal_approx(player.camera_pivot.position.y, 5.0), "своя камера: сдвиг и высота")
	player.set_camera_mode(settings.CameraMode.BEHIND)
	var yaw_before: float = player.visual.rotation.y
	Input.action_press("move_left")
	await frames(30)
	Input.action_release("move_left")
	check(player.visual.rotation.y > yaw_before + 0.3, "«за спиной»: влево поворачивает кота")
	check(absf(angle_difference(player.camera_pivot.rotation.y, player.visual.rotation.y)) < 0.5, "«за спиной»: камера следует за котом")
	player.set_camera_mode(settings.CameraMode.THIRD_PERSON)
	settings.reset_to_defaults()
	settings.apply()

	# Сценка у завала — один раз за прохождение.
	var end_zone: Area3D = scene.get_node("EndZone")
	player.global_position = end_zone.global_position - Vector3(0, 2.2, 0)
	await frames(4)
	check(player.is_in_closeup(), "у завала — сценка крупным планом")
	check(player.model.emotion == "sad", "в сценке грустная мордочка")
	check(player.face_camera.current, "камера смотрит на мордочку")
	check(not scene.get_node("HUD").visible, "во время сценки интерфейс спрятан")
	check(root.get_node("SaveGame").has_flag("barrier_reaction_seen"), "сценка отмечена в сохранении")
	await frames(60 * 3)
	check(not player.is_in_closeup() and player.camera.current, "после сценки управление вернулось")
	check(player.model.emotion == "neutral", "мордочка снова спокойная")
	player.global_position = end_zone.global_position + Vector3(0, -2.2, 12.0)
	await frames(4)
	player.global_position = end_zone.global_position - Vector3(0, 2.2, 0)
	await frames(4)
	check(not player.is_in_closeup(), "второй раз сценка не повторяется")

	# Выдохся — грусть.
	player.stamina = 0.5
	player._update_stamina(true, 0.1)
	check(player.model.emotion == "sad", "выдохся — грустная мордочка")
