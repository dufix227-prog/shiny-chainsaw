extends NPC

## К4: исповедальня со священником за сплошной перегородкой. Пока открывает
## только технический диалог без сюжетного текста, кармы и награды.

const REACH_POINT := Vector3(-1.35, 0.0, 0.0)

func setup_booth(local_position: Vector3) -> void:
	npc_id = "church_confessional"
	speaker = "Священник"
	dialogue_id = "church_confession"
	position = local_position
	var wood := Art.material(Color("4e3628"), true)
	var wood_dark := Art.material(Color("2f2823"), true)
	var cloth := Art.material(Color("423e45"), true)
	Art.box(self, Vector3(0, 0.08, 0), Vector3(3.0, 0.16, 3.0), wood_dark, true)
	Art.box(self, Vector3(0, 1.4, -1.4), Vector3(3.0, 2.8, 0.2), wood, true)
	Art.box(self, Vector3(0, 1.4, 1.4), Vector3(3.0, 2.8, 0.2), wood, true)
	var divider := Art.box(self, Vector3(0, 1.4, 0), Vector3(0.22, 2.8, 2.8), wood, true)
	divider.name = "Divider"
	Art.box(self, Vector3(1.4, 1.4, 0), Vector3(0.2, 2.8, 2.8), wood, true)
	var priest := Node3D.new()
	priest.name = "HiddenPriest"
	priest.position = Vector3(0.72, 0, 0)
	add_child(priest)
	Art.box(priest, Vector3(0, 0.9, 0), Vector3(0.48, 1.5, 0.42), cloth)
	Art.box(priest, Vector3(0, 1.75, 0), Vector3(0.58, 0.55, 0.52), wood_dark)

func interaction_position() -> Vector3:
	return to_global(REACH_POINT)

func is_player_in_reach(player_position: Vector3) -> bool:
	return interaction_position().distance_to(player_position) <= REACH
