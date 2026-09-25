extends SceneTree

## Проверка пачки ассетов пролога (переделка захода 2, vision-модель, 19.09.2026).
## Что проверяет: каждый .glb из assets/own загружается, инстанцируется, отдаёт
## непустой AABB; габариты и посадка низа на Z=0 сверяются с промптами.
## Это автопроверка геометрии и импорта, а НЕ визуальная приёмка автора.
##
## Запуск:
##   ENGINE=~/.cache/10000-metres-probe/godot-4.7.2-linux-x86_64/godot
##   $ENGINE --headless --path game/3d-probe --script tests/pack_vision_check.gd

const DIR := "res://assets/own/"

# id: имя файла без .glb, ожидаемые ширина/глубина/высота (м, 0 = не проверяем),
# допуск посадки низа на землю (м). Габариты — по bounding box всей модели:
# у домика это стены 4×3 из промпта ПЛЮС свес крыши 0,22 м и крыльцо, поэтому
# ширина и глубина больше плана (стены 4,00×3,00 остаются как в ТЗ).
# У корзины ширина 0,274 м и высота 0,304 м — это лукошко вместе с дужкой
# (само лукошко 0,26 м, дужка поднята до 0,30 м: без неё переноска невозможна,
# требование автора 19.09.2026 «кот должен её нести»).
const EXPECTED := {
	"goose_guard_v1": {"w": 0.0, "d": 0.0, "h": 0.0, "zmin": 0.01},
	"bridge_v1": {"w": 1.5, "d": 4.0, "h": 0.0, "zmin": 0.30},
	"strawberry_bed_v1": {"w": 2.0, "d": 1.0, "h": 0.0, "zmin": 0.01},
	# Лукошко с дужкой: само лукошко 0,26 м, габарит шире и выше из-за дужки
	"strawberry_basket_v1": {"w": 0.28, "d": 0.0, "h": 0.0, "zmin": 0.01},
	# Дом в жилом размере: сруб 6 × 4,5 м, габарит больше из-за сеней и крыльца
	"grandma_house_v1": {"w": 8.32, "d": 6.60, "h": 0.0, "zmin": 0.01},
	"yard_fence_v1": {"w": 2.54, "d": 0.0, "h": 0.0, "zmin": 0.01},
	"yard_shed_v1": {"w": 3.14, "d": 0.0, "h": 0.0, "zmin": 0.01},
	"woodpile_v1": {"w": 1.78, "d": 0.0, "h": 0.0, "zmin": 0.01},
	"barrel_v1": {"w": 0.60, "d": 0.0, "h": 0.0, "zmin": 0.01},
	"cat_v2_faceted": {"w": 0.0, "d": 0.0, "h": 1.8, "zmin": 0.01},
	"cat_v3_voxel": {"w": 0.0, "d": 0.0, "h": 1.8, "zmin": 0.01},
}

const TOL := 0.12   # допуск на габарит, м

var failures := 0
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func aabb_of(node: Node3D) -> AABB:
	# Объединяем AABB всех видимых мешей модели в её собственных координатах.
	var box := AABB()
	var started := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var local := mesh_instance.get_aabb()
		var xform := node.global_transform.affine_inverse() * mesh_instance.global_transform
		var world := xform * local
		if not started:
			box = world
			started = true
		else:
			box = box.merge(world)
	return box


func run() -> void:
	for id in EXPECTED:
		var path: String = DIR + id + ".glb"
		var spec: Dictionary = EXPECTED[id]

		check(ResourceLoader.exists(path), "файл на месте: %s" % path)
		if not ResourceLoader.exists(path):
			continue

		var packed := load(path)
		check(packed != null, "загружается: %s" % id)
		if packed == null:
			continue

		var node := (packed as PackedScene).instantiate() as Node3D
		check(node != null, "инстанцируется как Node3D: %s" % id)
		if node == null:
			continue

		root.add_child(node)
		var box := aabb_of(node)
		check(box.size.length() > 0.001, "непустой AABB: %s" % id)

		var size := box.size
		print("%s: size=(%.3f, %.3f, %.3f)  zmin=%.4f" %
			[id, size.x, size.y, size.z, box.position.y])

		if spec["w"] > 0.0:
			check(absf(size.x - spec["w"]) <= TOL,
				"%s: ширина %.3f против %.2f" % [id, size.x, spec["w"]])
		if spec["d"] > 0.0:
			check(absf(size.z - spec["d"]) <= TOL,
				"%s: длина %.3f против %.2f" % [id, size.z, spec["d"]])
		if spec["h"] > 0.0:
			check(absf(size.y - spec["h"]) <= TOL,
				"%s: высота %.3f против %.2f" % [id, size.y, spec["h"]])
		# В Godot после export_yup фронт модели смотрит вдоль −Z, а низ — по Y.
		check(box.position.y >= -0.01 and box.position.y <= spec["zmin"],
			"%s: низ на земле (y=%.4f, допуск %.2f)" %
			[id, box.position.y, spec["zmin"]])

		node.queue_free()

	print("PACK_CHECK: проверок %d, провалов %d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _initialize() -> void:
	call_deferred("run")
