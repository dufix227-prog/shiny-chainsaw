class_name StintNPC
extends NPC

## Временная 3D-проба по утверждённой карточке внешности Стинта.

func _build_figure() -> void:
	var silver := Art.material(Color("aeb4bd"), true)
	var graphite := Art.material(Color("59616d"), true)
	var light := Art.material(Color("d9dde2"))
	var dark := Art.material(Color("181a20"), true)
	var clothes := Art.material(Color("20232b"), true)
	var shoes := Art.material(Color("737984"))
	var pink := Art.material(Color("c98291"))

	var hoodie := Art.box(self, Vector3(0, 1.02, 0), Vector3(0.48, 0.72, 0.32), clothes)
	hoodie.name = "DarkOversizeHoodie"
	Art.box(self, Vector3(0, 1.34, -0.12), Vector3(0.48, 0.2, 0.18), clothes)
	var head := Art.box(self, Vector3(0, 1.58, 0), Vector3(0.66, 0.52, 0.48), silver)
	head.name = "SilverHead"
	Art.box(self, Vector3(0, 1.77, -0.02), Vector3(0.64, 0.14, 0.46), graphite)
	Art.box(self, Vector3(0, 1.47, 0.25), Vector3(0.36, 0.2, 0.08), light)
	for side in [-1, 1]:
		var ear := Art.ear(self, Vector3(side * 0.22, 1.78, 0), Vector3(0.3, 0.35, 0.32), silver)
		ear.name = "TiltedEar" if side < 0 else "Ear"
		if side < 0:
			ear.rotation.z = -0.24
		Art.ear(self, Vector3(side * 0.22, 1.8, 0.18), Vector3(0.16, 0.22, 0.035), pink)
		Art.box(self, Vector3(side * 0.18, 1.61, 0.27), Vector3(0.1, 0.1, 0.04), dark)
		var leg := Art.box(self, Vector3(side * 0.13, 0.38, 0), Vector3(0.18, 0.76, 0.2), clothes)
		leg.set_meta("npc_leg", true)
		Art.box(self, Vector3(side * 0.13, 0.06, 0.06), Vector3(0.24, 0.12, 0.35), shoes)
		Art.box(self, Vector3(side * 0.32, 1.08, 0), Vector3(0.15, 0.66, 0.18), clothes)
	Art.box(self, Vector3(0, 1.51, 0.29), Vector3(0.08, 0.05, 0.05), pink)
	var pixel_sign := Art.box(self, Vector3(0, 1.13, 0.18), Vector3(0.1, 0.1, 0.03), light)
	pixel_sign.name = "PixelSign"

	var bag := Art.box(self, Vector3(0.3, 0.95, -0.1), Vector3(0.28, 0.42, 0.18), dark)
	bag.name = "ShoulderBag"
	Art.box(self, Vector3(-0.02, 1.25, 0.18), Vector3(0.06, 0.86, 0.05), dark).rotation.z = -0.5
	var headphones := Node3D.new()
	headphones.name = "Headphones"
	add_child(headphones)
	Art.box(headphones, Vector3(0, 1.3, 0.12), Vector3(0.48, 0.06, 0.08), dark)
	for side in [-1, 1]:
		Art.box(headphones, Vector3(side * 0.25, 1.27, 0.12), Vector3(0.1, 0.2, 0.1), dark)

	var tail := Node3D.new()
	tail.name = "RingedTail"
	tail.position = Vector3(0.22, 0.72, -0.24)
	add_child(tail)
	for index in 5:
		var segment_color := graphite if index in [1, 3] else silver
		var segment := Art.box(tail, Vector3(index * 0.09, index * 0.09, -index * 0.08), Vector3(0.14, 0.22, 0.18), segment_color)
		segment.rotation.x = -0.55

	var label := Label3D.new()
	label.text = speaker
	label.position = Vector3(0, 2.25, 0)
	label.font_size = 36
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
