class_name NPC
extends StaticBody3D

## К3: каркас стоящей фигуры НПС. Тело — временный силуэт (внешности отложены
## автором); данные реплик и вариантов — отдельно, в dialogue_data.gd.
## Время в диалогах идёт (канон): НПС ничего не ставит на паузу.

const Art = preload("res://scripts/geometry.gd")
const REACH := 2.2

var npc_id := ""
var speaker := "НПС"
var dialogue_id := ""

func setup(id: String, position_on_road: Vector3, data: Dictionary) -> void:
	npc_id = id
	speaker = String(data.get("speaker", "НПС"))
	dialogue_id = String(data.get("id", id))
	position = position_on_road
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	collision.shape = capsule
	collision.position.y = 0.7
	add_child(collision)
	_build_figure()

func _build_figure() -> void:
	var fur := Art.material(Color("b09a8a"), true)
	var dark := Art.material(Color("3b352c"))
	var cloth := Art.material(Color("5d6b58"), true)
	Art.box(self, Vector3(0, 0.95, 0), Vector3(0.5, 0.62, 0.34), cloth)
	Art.box(self, Vector3(0, 1.5, 0), Vector3(0.74, 0.58, 0.55), fur)
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 0.18, 1.68, 0), Vector3(0.3, 0.3, 0.32), fur)
		Art.box(self, Vector3(side * 0.2, 1.44, 0.26), Vector3(0.09, 0.11, 0.04), dark)
		var leg := Art.box(self, Vector3(side * 0.13, 0.32, 0), Vector3(0.2, 0.64, 0.2), cloth)
		leg.set_meta("npc_leg", true)
		Art.box(self, Vector3(side * 0.13, 0.05, 0.04), Vector3(0.22, 0.1, 0.28), dark)
	for side in [-1, 1]:
		Art.box(self, Vector3(side * 0.34, 1.1, 0), Vector3(0.16, 0.55, 0.2), cloth)
	var label := Label3D.new()
	label.text = speaker
	label.position = Vector3(0, 2.15, 0)
	label.font_size = 36
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func is_player_in_reach(player_position: Vector3) -> bool:
	return global_position.distance_to(player_position) <= REACH

func reset() -> void:
	# Сцены и разговоры ещё не реализованы; сброс пробы просто возвращает НПС
	# в строй — данные диалога не хранят одноразового состояния.
	pass
