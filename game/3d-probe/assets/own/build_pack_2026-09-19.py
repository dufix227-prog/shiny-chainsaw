# Пачка ассетов пролога — заход 2 (19.09.2026)
# Сборка семи объектов по ПРОМПТЫ-АССЕТОВ-2026-09-19.md.
# Запуск: blender -b -P build_pack_2026-09-19.py -- <каталог-вывода>
#   (Blender 5.2.1, glTF-аддон включён в настройках пользователя).
# Конвенции, как у cat_hoplite_v1.glb (build_cat.py): экспорт GLB c export_yup,
# фронт объекта — вдоль Blender −Y (в Godot после экспорта это −Z = вперёд),
# подошвы/низ на Z=0, origin между ступнями (в центре проекции на землю).
import bpy
from mathutils import Vector
import os
import sys
import math

# Headless-запуски не несут пользовательских настроек — включаем glTF-экспорт явно.
import addon_utils
addon_utils.enable("io_scene_gltf2", default_set=True)

if "--" in sys.argv:
    OUT = sys.argv[sys.argv.index("--") + 1]
else:
    OUT = "/tmp"
EVIDENCE = os.path.join(OUT, "previews")
os.makedirs(EVIDENCE, exist_ok=True)

# --- Палитра (та же, что у текущего кота build_cat.py) и материалы ---
FUR = (0.847, 0.569, 0.231, 1.0)      # рыжий мех      #d8913b
CREAM = (0.961, 0.863, 0.655, 1.0)    # кремовый       #f5dca7
STRIPE = (0.569, 0.318, 0.161, 1.0)   # тёмные полосы  #915129
COAT = (0.255, 0.408, 0.471, 1.0)     # бирюзовая куртка #416878
LEATHER = (0.439, 0.329, 0.231, 1.0)  # коричневая кожа #70543b
PINK = (0.851, 0.627, 0.549, 1.0)     # розовый        #d9a08c
DARK = (0.188, 0.165, 0.149, 1.0)     # тёмный         #302a26
WHITE = (0.95, 0.95, 0.95, 1.0)

WOOD_A = (0.604, 0.478, 0.353, 1.0)   # тёплое серо-коричневое дерево
WOOD_B = (0.549, 0.424, 0.302, 1.0)   # чуть темнее
WOOD_C = (0.663, 0.541, 0.412, 1.0)   # чуть светлее
LEAF = (0.176, 0.376, 0.196, 1.0)     # тёмно-зелёная листва
BERRY = (0.824, 0.102, 0.145, 1.0)    # ярко-красная клубника
BERRY_GREEN = (0.729, 0.267, 0.196, 1.0)
SOIL = (0.267, 0.196, 0.133, 1.0)     # земля в грядке
YELLOW = (0.851, 0.776, 0.514, 1.0)   # светло-жёлтые стены домика
YELLOW_D = (0.741, 0.663, 0.427, 1.0) # венец бревна чуть темнее
ROOF = (0.824, 0.353, 0.212, 1.0)     # оранжево-красная крыша
GOOSE_WHITE = (0.937, 0.937, 0.937, 1.0)
GOOSE_GRAY = (0.788, 0.788, 0.788, 1.0)
ORANGE = (0.937, 0.49, 0.11, 1.0)


def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Roughness"].default_value = rough
    return m


def flat(obj):
    bpy.ops.object.shade_flat()
    return obj


def box(name, loc, size, m):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.data.materials.append(m)
    return flat(o)


def cyl(name, loc, r, h, m, n=8, rot=(0, 0, 0), r2=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=n)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    if r2 is not None:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.transform.resize(value=(r2 / r, r2 / r, 1))
        bpy.ops.object.mode_set(mode="OBJECT")
    o.data.materials.append(m)
    return flat(o)


def ico(name, loc, r, m, sub=1, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    o.data.materials.append(m)
    return flat(o)


def pyramid(name, loc, r, h, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(m)
    return flat(o)


def tri_prism(name, loc, w, d, h, m):
    # Треугольная призма вдоль X: для фронтона дома (треугольник высотой h,
    # шириной w по Y, толщиной d по X).
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.transform.resize(value=(d / 2, w / 2, h / 2))
    bpy.ops.mesh.select_all(action="DESELECT")
    # верхние четыре вершины свести в конёк (треугольник)
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh = o.data
    top = [v for v in mesh.vertices if v.co.z > 0.001]
    bottom = [v for v in mesh.vertices if v.co.z <= 0.001]
    # центр верхней грани — конёк
    cx = sum(v.co.x for v in top) / len(top)
    cz = h / 2
    for v in top:
        v.co.x = cx
        v.co.z = cz
    mesh.update()
    o.data.materials.append(m)
    return flat(o)


def reset_scene():
    # Удаляем объекты, но НЕ сбрасываем bpy.data: материалы живут всю пачку.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)


def select_all_meshes():
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.select_set(True)


def tri_count():
    n = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            for p in o.data.polygons:
                n += len(p.vertices) - 2
    return n


def export_glb(path):
    select_all_meshes()
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, use_selection=True
    )


def render_preview(path, fov=0.9):
    # Доказательный рендер: Eevee, солнце + серый фон, камера по габаритам сцены.
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 900
    bpy.context.scene.render.resolution_y = 900
    world = bpy.data.worlds[0]
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.68, 0.74, 1.0)
    bg.inputs[1].default_value = 1.0
    bpy.ops.object.light_add(type="SUN", location=(4, 3, 7))
    sun = bpy.context.active_object
    sun.rotation_euler = (math.radians(45), 0, math.radians(35))
    # габариты всех мешей
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for o in bpy.data.objects:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                for i in range(3):
                    lo[i] = min(lo[i], w[i])
                    hi[i] = max(hi[i], w[i])
    center = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    radius = max(hi[i] - lo[i] for i in range(3)) / 2
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.angle = fov
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = center + Vector((radius * 2.6, -radius * 2.6, radius * 1.7))
    cam.rotation_euler = (0, 0, 0)
    bpy.context.scene.camera = cam
    # направить камеру в центр
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(cam_data)


# --------------------------------------------------------------------------
# 1. Гусь-охранник
# --------------------------------------------------------------------------
def build_goose(ms):
    reset_scene()
    # Тело: грушевидное из двух икосфер
    ico("Body", (0, 0.03, 0.42), 0.30, ms["white"], sub=2, scale=(0.95, 1.15, 1.0))
    ico("Chest", (0, -0.10, 0.56), 0.19, ms["white"], sub=2, scale=(1.0, 1.1, 1.05))
    # Шея S-образная: два наклонных сегмента, фронт −Y
    cyl("Neck1", (0, -0.10, 0.68), 0.070, 0.28, ms["white"], n=10, rot=(0.30, 0, 0), r2=0.055)
    cyl("Neck2", (0, -0.17, 0.86), 0.055, 0.22, ms["white"], n=10, rot=(-0.18, 0, 0), r2=0.045)
    ico("Head", (0, -0.19, 0.98), 0.095, ms["white"], sub=2)
    # Клюв: открытый сердитый гогот — верхняя и откинутая нижняя челюсти
    box("BeakUp", (0, -0.29, 0.985), (0.055, 0.17, 0.045), ms["orange"])
    box("BeakDown", (0, -0.27, 0.925), (0.05, 0.13, 0.04), ms["orange"], )
    o = bpy.data.objects["BeakDown"]
    o.rotation_euler = (0.55, 0, 0)
    # Глаза и насупленные брови
    for side in (-1, 1):
        ico(f"Eye.{side}", (side * 0.055, -0.23, 1.02), 0.018, ms["dark"])
        box(f"Brow.{side}", (side * 0.055, -0.24, 1.055), (0.04, 0.028, 0.01), ms["dark"])
        bpy.data.objects[f"Brow.{side}"].rotation_euler = (0, 0, side * 0.5)
    # Хвост-клинышек вверх
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.07, depth=0.24, location=(0, 0.36, 0.56))
    tail = bpy.context.active_object
    tail.name = "Tail"
    tail.rotation_euler = (-0.75, 0, 0)
    tail.data.materials.append(ms["white"])
    flat(tail)
    # Крылья: сложены, левое чуть приподнято в жесте «ш-ш-ш!»
    box("WingL", (0.32, 0.05, 0.47), (0.06, 0.42, 0.17), ms["gray"])
    bpy.data.objects["WingL"].rotation_euler = (0.08, 0, 0.1)
    box("WingR", (-0.32, 0.0, 0.50), (0.06, 0.36, 0.15), ms["gray"])
    bpy.data.objects["WingR"].rotation_euler = (-0.55, 0, -0.16)
    # Лапы-клинья
    for side in (-1, 1):
        box(f"Foot.{side}", (side * 0.13, 0.02, 0.05), (0.07, 0.20, 0.11), ms["orange"])


# --------------------------------------------------------------------------
# 2. Деревянный мостик ~4 м
# --------------------------------------------------------------------------
def build_bridge(ms):
    reset_scene()
    tones = [ms["wood_a"], ms["wood_b"], ms["wood_c"], ms["wood_b"], ms["wood_a"]]
    for i in range(5):
        x = -0.6 + i * 0.3
        z = 0.42
        if i in (0, 4):
            z -= 0.02  # лёгкий прогиб к краям
        box(f"Plank.{i}", (x, 0, z), (0.30, 4.0, 0.07), tones[i])
        if i in (0, 4):
            bpy.data.objects[f"Plank.{i}"].rotation_euler = (0.012 if i == 4 else -0.012, 0, 0)
    # Перила из жердей и столбики с округлыми навершиями
    for side in (-1, 1):
        cyl(f"Rail.{side}", (side * 0.74, 0, 0.80), 0.045, 4.0, ms["wood_b"], n=8,
            rot=(math.pi / 2, 0, 0))
        for dy in (-1.5, 1.5):
            cyl(f"Post.{side}.{dy}", (side * 0.74, dy, 0.55), 0.05, 0.45, ms["wood_a"], n=8)
            ico(f"Knob.{side}.{dy}", (side * 0.74, dy, 0.80), 0.055, ms["wood_a"], sub=1)


# --------------------------------------------------------------------------
# 3. Клубничная грядка бабушки 2×1 м
# --------------------------------------------------------------------------
def build_bed(ms):
    reset_scene()
    # Короб из серых досок
    box("SideFront", (0, -0.44, 0.16), (2.0, 0.12, 0.32), ms["wood_c"])
    box("SideBack", (0, 0.44, 0.16), (2.0, 0.12, 0.32), ms["wood_c"])
    box("SideLeft", (-0.94, 0, 0.16), (0.12, 1.0, 0.32), ms["wood_c"])
    box("SideRight", (0.94, 0, 0.16), (0.12, 1.0, 0.32), ms["wood_c"])
    box("Soil", (0, 0, 0.33), (1.9, 0.9, 0.06), ms["soil"])
    # 7 кустиков листвы
    spots = [(-0.55, -0.2), (-0.2, 0.25), (0.3, -0.3), (0.6, 0.1), (0.0, -0.1),
             (-0.6, 0.3), (0.5, -0.05)]
    for i, (x, y) in enumerate(spots):
        ico(f"Leaf.{i}", (x, y, 0.42), 0.16, ms["leaf"], sub=1, scale=(1, 0.8, 0.5))
    # 11 ягод ~4 см, пара помельче/позеленее, с чашелистиками
    berries = [(-0.55, -0.18, 0.5), (-0.48, -0.32, 0.47), (-0.2, 0.28, 0.5),
               (-0.12, 0.15, 0.45), (0.3, -0.28, 0.5), (0.38, -0.38, 0.46),
               (0.6, 0.12, 0.5), (0.52, 0.0, 0.46), (0.0, -0.08, 0.48),
               (-0.62, 0.32, 0.48), (0.52, -0.12, 0.44)]
    for i, (x, y, z) in enumerate(berries):
        col = ms["berry_green"] if i in (9, 10) else ms["berry"]
        r = 0.016 if i in (9, 10) else 0.02
        ico(f"Berry.{i}", (x, y, z), r, col, sub=1)
        box(f"Calyx.{i}", (x, y, z + r + 0.004), (0.012, 0.012, 0.008), ms["leaf"])


# --------------------------------------------------------------------------
# 4. Корзина клубники
# --------------------------------------------------------------------------
def build_basket(ms):
    reset_scene()
    cyl("Basket", (0, 0, 0.08), 0.125, 0.16, ms["wood_b"], n=8)
    cyl("Base", (0, 0, 0.015), 0.14, 0.03, ms["wood_a"], n=8)
    cyl("Ring1", (0, 0, 0.045), 0.133, 0.02, ms["wood_c"], n=8)
    cyl("Ring2", (0, 0, 0.115), 0.133, 0.02, ms["wood_c"], n=8)
    cyl("Rim", (0, 0, 0.175), 0.128, 0.03, ms["wood_a"], n=8)
    # Горка ягод поверх
    berries = [(0.0, 0.0, 0.21), (-0.06, 0.02, 0.20), (0.06, -0.02, 0.20),
               (-0.02, 0.06, 0.19), (0.04, 0.05, 0.18), (-0.05, -0.05, 0.18),
               (0.0, -0.07, 0.19)]
    for i, (x, y, z) in enumerate(berries):
        ico(f"Berry.{i}", (x, y, z), 0.021, ms["berry"], sub=1)
        box(f"Calyx.{i}", (x, y, z + 0.025), (0.014, 0.014, 0.008), ms["leaf"])


# --------------------------------------------------------------------------
# 5. Домик бабушки ~4×3 м
# --------------------------------------------------------------------------
def build_house(ms):
    reset_scene()
    # Стены с венцами (полосы бревна на фасаде и задней стене)
    box("Walls", (0, 0, 1.05), (4.0, 3.0, 2.1), ms["yellow"])
    for i in range(5):
        z = 0.3 + i * 0.32
        box(f"LogBand.{i}", (0, -1.52, z), (4.04, 0.07, 0.18), ms["yellow_d"])
        box(f"LogBandB.{i}", (0, 1.52, z), (4.04, 0.07, 0.18), ms["yellow_d"])
    # Фронтоны (треугольные призмы) на восток/запад
    tri_prism("GableE", (2.0, 0, 2.42), 3.0, 0.12, 0.66, ms["yellow"])
    tri_prism("GableW", (-2.0, 0, 2.42), 3.0, 0.12, 0.66, ms["yellow"])
    # Крыша двускатная со свесом и коньком
    for side in (-1, 1):
        panel = box(f"Roof.{side}", (0, side * 0.78, 2.45), (4.7, 1.78, 0.10), ms["roof"])
        panel.rotation_euler = (-side * 0.41, 0, 0)
    box("Ridge", (0, 0, 2.82), (4.7, 0.26, 0.12), ms["roof"])
    # Труба
    box("Chimney", (0.9, 0.55, 2.65), (0.28, 0.28, 0.55), ms["wood_c"])
    # Дверь с круглым окошком (южный фасад)
    box("Door", (0, -1.55, 0.75), (0.72, 0.12, 1.4), ms["wood_a"])
    cyl("DoorWindowRing", (0, -1.52, 1.35), 0.14, 0.06, ms["cream"], n=12, rot=(math.pi / 2, 0, 0))
    cyl("DoorWindowGlass", (0, -1.56, 1.35), 0.09, 0.06, ms["dark"], n=12, rot=(math.pi / 2, 0, 0))
    # Два окна с наличниками: левое на южном фасаде, правое на северном
    for side in (-1, 1):
        x = side * 1.1
        y = side * 1.55
        box(f"WinFrame.{side}", (x, y, 1.3), (0.85, 0.08, 0.75), ms["white"])
        box(f"WinGlass.{side}", (x, y + side * 0.04, 1.3), (0.62, 0.05, 0.52), ms["dark"])
        box(f"WinSill.{side}", (x, y, 0.93), (0.95, 0.1, 0.06), ms["white"])
        box(f"WinTop.{side}", (x, y, 1.7), (0.95, 0.1, 0.06), ms["white"])
        for dx in (-0.8, 0.8):
            box(f"WinSide.{side}.{dx}", (x + dx * 0.43, y, 1.3), (0.09, 0.08, 0.82), ms["white"])
    # Крылечко из двух досок
    box("Porch1", (0, -1.7, 0.04), (0.95, 0.4, 0.08), ms["wood_b"])
    box("Porch2", (0, -2.05, 0.03), (1.0, 0.45, 0.06), ms["wood_a"])


# --------------------------------------------------------------------------
# 6. Кот v2 — гранёный low-poly (кандидат)
# --------------------------------------------------------------------------
def build_cat_v2(ms):
    reset_scene()
    # Ноги и ботинки
    for side in (-1, 1):
        cyl(f"Leg.{side}", (side * 0.14, 0, 0.36), 0.075, 0.52, ms["fur"], n=6)
        box(f"Boot.{side}", (side * 0.14, 0.01, 0.06), (0.17, 0.25, 0.12), ms["leather"])
    # Торс и живот
    ico("Torso", (0, 0, 0.95), 0.24, ms["coat"], sub=1, scale=(1.25, 0.85, 0.95))
    ico("Belly", (0, -0.06, 0.85), 0.16, ms["cream"], sub=1, scale=(1.1, 0.8, 0.8))
    # Руки и лапы (лёгкая A-поза)
    for side in (-1, 1):
        arm = cyl(f"Arm.{side}", (side * 0.30, 0.02, 1.0), 0.06, 0.45, ms["coat"], n=6,
                  rot=(0, 0, side * 0.12))
        ico(f"Paw.{side}", (side * 0.32, 0.0, 0.77), 0.075, ms["fur"], sub=1)
    # Палка в правой лапе
    cyl("Stick", (0.38, -0.05, 1.0), 0.03, 0.9, ms["leather"], n=6, rot=(0.15, 0, 0))
    # Рюкзак с ремнями (спина — +Y)
    box("Backpack", (0, 0.18, 1.0), (0.30, 0.14, 0.42), ms["leather"])
    for side in (-1, 1):
        box(f"Strap.{side}", (side * 0.12, 0.03, 1.05), (0.05, 0.03, 0.28), ms["cream"])
    # Голова: крупная, гранёная, с мордочкой-блоком
    ico("Head", (0, 0, 1.5), 0.27, ms["fur"], sub=1, scale=(1.0, 0.95, 0.95))
    box("Muzzle", (0, -0.23, 1.42), (0.17, 0.13, 0.11), ms["cream"])
    box("Nose", (0, -0.30, 1.45), (0.05, 0.035, 0.035), ms["dark"])
    # Глаза тёмные, без белков
    for side in (-1, 1):
        ico(f"Eye.{side}", (side * 0.11, -0.24, 1.56), 0.045, ms["dark"], sub=1)
        # Треугольные уши: внешняя грань + розовая внутренняя
        pyramid(f"Ear.{side}", (side * 0.18, 0.0, 1.76), 0.11, 0.26, ms["fur"],
                rot=(0.12, 0, side * -0.28))
        pyramid(f"EarInner.{side}", (side * 0.18, 0.03, 1.73), 0.06, 0.14, ms["pink"],
                rot=(0.15, 0, side * -0.28))
    # Полосы на голове и спине
    for i in range(2):
        box(f"HeadStripe.{i}", (0, 0.0, 1.72 - i * 0.05), (0.06, 0.11, 0.02), ms["stripe"])
        box(f"BackStripe.{i}", (0, 0.1, 1.05 - i * 0.05), (0.05, 0.05, 0.02), ms["stripe"])
    # Хвост: цепочка гранёных сфер с полосами
    tail = [(0, 0.22, 0.8, 0.075), (0.02, 0.33, 0.95, 0.06), (0.0, 0.35, 1.1, 0.05),
            (0.0, 0.29, 1.24, 0.04)]
    for i, (x, y, z, r) in enumerate(tail):
        ico(f"Tail.{i}", (x, y, z), r, ms["stripe"] if i % 2 else ms["fur"], sub=1)


# --------------------------------------------------------------------------
# 7. Кот v3 — ступенчатый voxel/пиксельный (кандидат)
# --------------------------------------------------------------------------
def build_cat_v3(ms):
    reset_scene()
    # Ботинки и ноги по модульной сетке 0,07 м
    for side in (-1, 1):
        for k in range(3):
            box(f"Boot.{side}.{k}", (side * 0.18, 0, 0.035 + k * 0.07), (0.15, 0.21, 0.07), ms["leather"])
        for k in range(4):
            box(f"Leg.{side}.{k}", (side * 0.14, 0, 0.245 + k * 0.07), (0.15, 0.15, 0.07), ms["fur"])
    # Торс, живот
    box("Torso", (0, 0.0, 0.95), (0.49, 0.35, 0.49), ms["coat"])
    box("Belly", (0, -0.05, 0.9), (0.28, 0.28, 0.21), ms["cream"])
    # Руки и лапы
    for side in (-1, 1):
        box(f"Arm.{side}", (side * 0.33, 0, 1.0), (0.14, 0.14, 0.49), ms["coat"])
        box(f"Paw.{side}", (side * 0.33, 0.0, 0.7), (0.15, 0.15, 0.14), ms["fur"])
    # Палка (длинный модуль) и рюкзак
    box("Stick", (0.42, -0.06, 1.0), (0.08, 0.08, 0.84), ms["leather"])
    box("Backpack", (0, 0.26, 0.92), (0.28, 0.21, 0.42), ms["leather"])
    # Голова-квадрат со ступенчатыми щеками
    box("Head", (0, 0, 1.58), (0.35, 0.35, 0.35), ms["fur"])
    for side in (-1, 1):
        box(f"Cheek.{side}", (side * 0.16, -0.19, 1.42), (0.08, 0.08, 0.16), ms["cream"])
    box("Muzzle", (0, -0.21, 1.38), (0.21, 0.07, 0.14), ms["cream"])
    box("Nose", (0, -0.22, 1.47), (0.05, 0.04, 0.04), ms["dark"])
    # Глаза-блоки
    for side in (-1, 1):
        box(f"Eye.{side}", (side * 0.11, -0.205, 1.51), (0.08, 0.035, 0.08), ms["dark"])
    # Уши из кубиков
    for side in (-1, 1):
        box(f"EarBase.{side}", (side * 0.15, 0.0, 1.68), (0.09, 0.09, 0.12), ms["fur"])
        box(f"EarTop.{side}", (side * 0.15, 0.0, 1.78), (0.07, 0.07, 0.08), ms["fur"])
        box(f"EarIn.{side}", (side * 0.15, -0.035, 1.7), (0.05, 0.03, 0.08), ms["pink"])
    # Хвост — цепочка кубиков
    tail = [(0, 0.30, 0.75), (0, 0.38, 0.86), (0, 0.42, 0.98), (0, 0.38, 1.09)]
    for i, (x, y, z) in enumerate(tail):
        box(f"Tail.{i}", (x, y, z), (0.08, 0.08, 0.08), ms["stripe"] if i % 2 else ms["fur"])


# --------------------------------------------------------------------------
def main():
    ms = {
        "fur": mat("Fur", FUR), "cream": mat("Cream", CREAM), "stripe": mat("Stripe", STRIPE),
        "coat": mat("Coat", COAT), "leather": mat("Leather", LEATHER), "pink": mat("Pink", PINK),
        "dark": mat("Dark", DARK), "white": mat("White", WHITE),
        "wood_a": mat("WoodA", WOOD_A), "wood_b": mat("WoodB", WOOD_B),
        "wood_c": mat("WoodC", WOOD_C), "leaf": mat("Leaf", LEAF),
        "berry": mat("Berry", BERRY), "berry_green": mat("BerryGreen", BERRY_GREEN),
        "soil": mat("Soil", SOIL), "yellow": mat("Yellow", YELLOW),
        "yellow_d": mat("YellowD", YELLOW_D), "roof": mat("Roof", ROOF),
        "gray": mat("GooseGray", GOOSE_GRAY), "orange": mat("Orange", ORANGE),
    }
    assets = [
        ("goose_guard_v1", build_goose),
        ("bridge_v1", build_bridge),
        ("strawberry_bed_v1", build_bed),
        ("strawberry_basket_v1", build_basket),
        ("grandma_house_v1", build_house),
        ("cat_v2_faceted", build_cat_v2),
        ("cat_v3_voxel", build_cat_v3),
    ]
    for name, fn in assets:
        fn(ms)
        tris = tri_count()
        glb = os.path.join(OUT, name + ".glb")
        export_glb(glb)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))
        render_preview(os.path.join(EVIDENCE, name + ".png"))
        print(f"ASSET_OK {name} tris={tris} glb={os.path.getsize(glb)}")


main()
print("PACK_BUILD_OK")
