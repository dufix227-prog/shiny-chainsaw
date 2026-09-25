class_name BratishkinNPC
extends NPC

func _build_figure() -> void:
	var graphite := Art.material(Color("4d4b4e"), true)
	var light := Art.material(Color("9b9690"), true)
	var dark := Art.material(Color("17181b"), true)
	var pink := Art.material(Color("b97580"))
	var amber := Art.material(Color("9b6b30"))
	var body := Art.box(self, Vector3(0, 0.98, 0), Vector3(0.72, 0.72, 0.48), dark)
	body.name = "OversizeShirt"
	var head := Art.box(self, Vector3(0, 1.55, 0), Vector3(0.82, 0.62, 0.58), graphite)
	head.name = "GraphiteHead"
	Art.box(self, Vector3(0, 1.42, 0.3), Vector3(0.48, 0.24, 0.08), light)
	for side in [-1, 1]:
		var ear := Art.ear(self, Vector3(side * 0.28, 1.8, 0), Vector3(0.34, 0.34, 0.34), graphite)
		if side > 0:
			ear.rotation.z = 0.22
		Art.ear(self, Vector3(side * 0.28, 1.82, 0.19), Vector3(0.18, 0.21, 0.035), pink)
		Art.box(self, Vector3(side * 0.23, 1.58, 0.33), Vector3(0.13, 0.09, 0.04), amber)
		var leg := Art.box(self, Vector3(side * 0.16, 0.35, 0), Vector3(0.25, 0.7, 0.25), graphite)
		leg.set_meta("npc_leg", true)
		Art.box(self, Vector3(side * 0.16, 0.08, 0.06), Vector3(0.3, 0.16, 0.34), dark)
		Art.box(self, Vector3(side * 0.4, 1.0, 0), Vector3(0.18, 0.56, 0.22), graphite)
	var sign := Art.box(self, Vector3(0, 1.08, 0.26), Vector3(0.16, 0.16, 0.03), light)
	sign.name = "StreamerSign"
	var bag := Art.box(self, Vector3(0.38, 0.92, -0.12), Vector3(0.3, 0.42, 0.2), dark)
	bag.name = "ShoulderBag"
	var tail := Node3D.new()
	tail.name = "StripedTail"
	add_child(tail)
	for index in 5:
		Art.box(tail, Vector3(0.3 + index * 0.1, 0.55 + index * 0.08, -0.22 - index * 0.08),
			Vector3(0.2, 0.22, 0.2), light if index in [1, 3] else graphite)
	var label := Label3D.new()
	label.text = speaker
	label.position = Vector3(0, 2.22, 0)
	label.font_size = 36
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
