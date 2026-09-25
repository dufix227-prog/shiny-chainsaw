extends RefCounted

static func material(color: Color, grain: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if grain:
		var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 84
		for y in 16:
			for x in 16:
				var value := rng.randf_range(0.94, 1.02)
				image.set_pixel(x, y, Color(value, value, value))
		result.albedo_texture = ImageTexture.create_from_image(image)
		result.uv1_triplanar = true
		result.uv1_scale = Vector3.ONE * 0.7
	return result

## Настоящая фото-текстура (CC0, ambientCG — реестр ассетов) вместо
## процедурной заливки цветом. folder — папка в assets/textures/ambientcg/
## с albedo.jpg/normal.jpg/roughness.jpg; uv_scale задаёт повтор текстуры
## по метру поверхности (triplanar — без ручной UV-развёртки примитивов).
## min_roughness подстраховывает от «мокрого» блика прямого света на траве/
## грунте, если их roughness-карта местами слишком тёмная (глянцевая).
static func textured_material(folder: String, uv_scale: float = 1.0, min_roughness: float = 0.6) -> StandardMaterial3D:
	var base := "res://assets/textures/ambientcg/%s/" % folder
	var result := StandardMaterial3D.new()
	result.albedo_texture = load(base + "albedo.jpg")
	if ResourceLoader.exists(base + "normal.jpg"):
		result.normal_enabled = true
		result.normal_texture = load(base + "normal.jpg")
		# Слабее эффект рельефа: на пологом свету полная сила карты нормалей
		# даёт резкие белые полосы-блики вместо мягкой фактуры.
		result.normal_scale = 0.35
	# Карта шероховатости ambientCG местами даёт «мокрый» блик под прямым
	# светом даже с приглушённым нормал-мэпом — плоское значение стабильнее.
	result.roughness = clampf(min_roughness, 0.0, 1.0)
	result.metallic_specular = 0.1
	result.uv1_triplanar = true
	result.uv1_scale = Vector3.ONE * uv_scale
	return result

static func box(parent: Node3D, pos: Vector3, size: Vector3,
		mat: Material, solid: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		instance.add_child(body)
		body.add_child(collision)
	return instance

static func ear(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var points := PackedVector3Array([
		Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0, 1, -0.5),
		Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0, 1, 0.5)])
	var indices := [0, 2, 1, 3, 4, 5, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 4, 0, 1, 4, 0, 4, 3]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.add_vertex(points[index] * size)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

static func batch_static(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if not instance.visible or instance.material_override is ShaderMaterial:
			continue
		var mat := instance.material_override
		if not groups.has(mat):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[mat] = surface
		var transform := parent.global_transform.affine_inverse() * instance.global_transform
		groups[mat].append_from(instance.mesh, 0, transform)
		# Keep the nodes carrying physics shapes; only their static rendering is merged.
		instance.mesh = null
	for mat: Material in groups:
		var merged := MeshInstance3D.new()
		merged.mesh = groups[mat].commit()
		merged.material_override = mat
		parent.add_child(merged)
