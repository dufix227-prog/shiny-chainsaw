# Пачка ассетов пролога — переделка захода 2 vision-моделью (19.09.2026)
#
# Почему новый скрипт, а не правка build_pack_2026-09-19.py: черновик провалился
# не по геометрии, а по картинке. Две причины, обе здесь устранены:
#   1. Blender 5.x по умолчанию рендерит в AgX — он «съедает» насыщенность, из-за
#      чего рыжий кот выходил бежевым, а оранжево-красная крыша — бледно-розовой.
#      Здесь view transform = Standard (плоский мультяшный цвет без перекоса).
#   2. В превью не было земли, контрастного света и ракурсов: объект висел серым
#      пятном на сером фоне без теней, поэтому силуэт не читался. Здесь солнце-ключ,
#      холодный заполняющий свет, земля с контактной тенью и 3 ракурса на объект.
# Геометрия тоже переработана: шея гуся и хвост кота — единой трубой по кривой,
# крыша дома — треугольные фронтоны построены явными вершинами (в черновике
# они торчали за скаты), у кота v3 появились читаемые ступенчатые уши.
#
# Запуск: blender -b -P build_pack_vision_2026-09-19.py -- <каталог-вывода> [только-имя]
#   (Blender 5.2.1). Каталог вывода — game/3d-probe/assets/own.
#   Необязательный второй аргумент собирает и рендерит один объект — для правок.
# Конвенции как у cat_hoplite_v1.glb (build_cat.py): подошвы/низ на Z=0,
# фронт вдоль Blender −Y, экспорт GLB с export_yup=True (в Godot фронт −Z).
import bpy
import addon_utils
from mathutils import Vector
import math
import os
import sys

addon_utils.enable("io_scene_gltf2", default_set=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp"
ONLY = argv[1] if len(argv) > 1 else None


# ---------------------------------------------------------------- палитра ---
# Те же hex, что в промптах и build_cat.py. Значения линейные (Blender).
FUR = (0.847, 0.569, 0.231, 1.0)       # рыжий мех      #d8913b
CREAM = (0.961, 0.863, 0.655, 1.0)     # кремовый       #f5dca7
STRIPE = (0.569, 0.318, 0.161, 1.0)    # тёмные полосы  #915129
COAT = (0.255, 0.408, 0.471, 1.0)      # бирюзовая куртка #416878
LEATHER = (0.439, 0.329, 0.231, 1.0)   # кожа, рюкзак   #70543b
PINK = (0.851, 0.627, 0.549, 1.0)      # розовый        #d9a08c
DARK = (0.188, 0.165, 0.149, 1.0)      # тёмный         #302a26
WHITE = (0.93, 0.93, 0.92, 1.0)

WOOD_A = (0.451, 0.306, 0.196, 1.0)    # тёплое серо-коричневое дерево
WOOD_B = (0.318, 0.208, 0.129, 1.0)    # темнее (тень в щелях, торцы)
WOOD_C = (0.549, 0.388, 0.251, 1.0)    # светлее (солнечная доска)
WOOD_G = (0.400, 0.365, 0.322, 1.0)    # серые доски короба грядки
WOOD_GD = (0.286, 0.259, 0.227, 1.0)   # тёмно-серые стойки грядки
LEAF = (0.129, 0.310, 0.153, 1.0)      # тёмно-зелёная листва
LEAF_L = (0.208, 0.420, 0.180, 1.0)    # светлее — верх листвы
BERRY = (0.788, 0.078, 0.110, 1.0)     # ярко-красная клубника
BERRY_D = (0.604, 0.078, 0.086, 1.0)   # тёмный бок ягоды
BERRY_G = (0.639, 0.196, 0.145, 1.0)   # зелёно-бурая недозрелая
SOIL = (0.212, 0.145, 0.094, 1.0)      # земля в грядке
YELLOW = (0.827, 0.702, 0.404, 1.0)    # светло-жёлтые брёвна
YELLOW_D = (0.647, 0.522, 0.278, 1.0)  # тень между венцами
ROOF = (0.694, 0.271, 0.157, 1.0)      # оранжево-красная крыша
ROOF_D = (0.522, 0.184, 0.110, 1.0)    # тёмный скат
BRICK = (0.510, 0.451, 0.427, 1.0)     # серый кирпич трубы
GOOSE_W = (0.925, 0.925, 0.910, 1.0)   # белое тело гуся
GOOSE_G = (0.757, 0.769, 0.780, 1.0)   # серый отлив на крыльях
ORANGE = (0.898, 0.404, 0.075, 1.0)    # клюв и лапы гуся
GROUND = (0.408, 0.427, 0.353, 1.0)    # земля в превью (только рендер)

TRI = {}  # имя объекта -> число треугольников (для отчёта)

_MATS = {}


def mat(name, rgb, rough=0.85):
    """Простой плоский материал: без бликов и металла — цвет как в промпте."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Specular IOR Level"].default_value = 0.12
    _MATS[name] = m
    return m


def M():
    """Все материалы пачки одним словарём (создаются один раз)."""
    return {
        "fur": mat("Fur", FUR), "cream": mat("Cream", CREAM),
        "stripe": mat("Stripe", STRIPE), "coat": mat("Coat", COAT),
        "leather": mat("Leather", LEATHER), "pink": mat("Pink", PINK),
        "dark": mat("Dark", DARK), "white": mat("White", WHITE),
        "wood_a": mat("WoodA", WOOD_A), "wood_b": mat("WoodB", WOOD_B),
        "wood_c": mat("WoodC", WOOD_C), "wood_g": mat("WoodGrey", WOOD_G),
        "wood_gd": mat("WoodGreyDark", WOOD_GD), "leaf": mat("Leaf", LEAF),
        "leaf_l": mat("LeafLight", LEAF_L), "berry": mat("Berry", BERRY),
        "berry_d": mat("BerryDark", BERRY_D), "berry_g": mat("BerryGreen", BERRY_G),
        "soil": mat("Soil", SOIL), "yellow": mat("Yellow", YELLOW),
        "yellow_d": mat("YellowDark", YELLOW_D), "roof": mat("Roof", ROOF),
        "roof_d": mat("RoofDark", ROOF_D), "brick": mat("Brick", BRICK),
        "goose_w": mat("GooseWhite", GOOSE_W), "goose_g": mat("GooseGray", GOOSE_G),
        "orange": mat("Orange", ORANGE), "ground": mat("PreviewGround", GROUND),
    }


# ------------------------------------------------------------ примитивы ---
def _finish(o, m, name):
    o.name = name
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_flat()
    return o


def box(name, loc, size, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.rotation_euler = rot
    return _finish(o, m, name)


def cyl(name, loc, r, h, m, n=10, rot=(0, 0, 0), r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r,
                                    radius2=r if r2 is None else r2,
                                    depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    return _finish(o, m, name)


def ico(name, loc, r, m, sub=1, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    return _finish(o, m, name)


def sphere(name, loc, r, m, seg=10, ring=6, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring,
                                         radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    return _finish(o, m, name)


def cone(name, loc, r, h, m, n=8, rot=(0, 0, 0), r2=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r2,
                                    depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    return _finish(o, m, name)


def mesh_obj(name, verts, faces, m):
    """Объект из явных вершин — для фигур, которые примитивами даются криво
    (фронтоны дома, клинья). Нормали приводятся наружу, шейдинг плоский."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.select_set(False)
    o.data.materials.append(m)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.shade_flat()
    return o


def tube(name, pts, radii, m, n=8, caps=True):
    """Труба переменного радиуса по ломаной — шея гуся, хвост кота, жерди.
    Одна цельная сетка вместо набора цилиндров: силуэт не «рассыпается»."""
    verts, faces = [], []
    for i, p in enumerate(pts):
        p = Vector(p)
        if i == 0:
            t = Vector(pts[1]) - Vector(pts[0])
        elif i == len(pts) - 1:
            t = Vector(pts[-1]) - Vector(pts[-2])
        else:
            t = Vector(pts[i + 1]) - Vector(pts[i - 1])
        t.normalize()
        up = Vector((0, 0, 1))
        if abs(t.dot(up)) > 0.98:
            up = Vector((0, 1, 0))
        b1 = t.cross(up).normalized()
        b2 = t.cross(b1).normalized()
        r = radii[i]
        for k in range(n):
            a = 2 * math.pi * k / n
            off = b1 * (math.cos(a) * r) + b2 * (math.sin(a) * r)
            verts.append((p.x + off.x, p.y + off.y, p.z + off.z))
    for i in range(len(pts) - 1):
        for k in range(n):
            a = i * n + k
            b = i * n + (k + 1) % n
            c = (i + 1) * n + (k + 1) % n
            d = (i + 1) * n + k
            faces.append((a, b, c, d))
    if caps:
        faces.append(tuple(range(n - 1, -1, -1)))
        base = (len(pts) - 1) * n
        faces.append(tuple(range(base, base + n)))
    return mesh_obj(name, verts, faces, m)


def tri_prism_x(name, x, y_mid, base_y, height, thick, z0, m):
    """Треугольная призма вдоль X — фронтон дома. Основание по Y, вершина вверх."""
    h = thick / 2
    y0, y1 = y_mid - base_y / 2, y_mid + base_y / 2
    v = [(x - h, y0, z0), (x - h, y1, z0), (x - h, y_mid, z0 + height),
         (x + h, y0, z0), (x + h, y1, z0), (x + h, y_mid, z0 + height)]
    f = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    return mesh_obj(name, v, f, m)


def wing(name, loc, length, thick, sh_z, tip_z, m, rot=(0, 0, 0), s=1):
    """Сложенное крыло: у плеча широкая лопасть, к концу сходит на клин.
    Плоская плита-параллелепипед здесь не годится — читается фанеркой."""
    t = thick / 2
    y0, y1 = -length * 0.42, length * 0.58
    v = [(-t, y0, sh_z / 2), (t, y0, sh_z / 2), (-t, y0, -sh_z / 2), (t, y0, -sh_z / 2),
         (-t, y1, tip_z / 2), (t, y1, tip_z / 2)]
    f = [(0, 1, 5, 4), (2, 3, 5, 4), (0, 1, 3, 2), (0, 2, 4), (1, 3, 5)]
    o = mesh_obj(name, v, f, m)
    o.location = loc
    o.rotation_euler = rot
    o.scale = (1, 1, 1)
    if s < 0:
        o.scale.x = -1
    return o


# -------------------------------------------------------------- каркас ---
def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)


def meshes(exclude_preview=True):
    """Меши модели. Объекты превью-рига (земля) в габариты и экспорт не входят."""
    return [o for o in bpy.data.objects if o.type == "MESH"
            and not (exclude_preview and o.name.startswith(("Preview", "Key", "Fill")))]



def tri_count():
    n = 0
    for o in meshes():
        for p in o.data.polygons:
            n += len(p.vertices) - 2
    return n


def bbox():
    # matrix_world после правки location/scale обновляется только при апдейте
    # сцены — без него габариты читаются от прошлого состояния.
    bpy.context.view_layer.update()
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in meshes():
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return Vector(lo), Vector(hi)


def scale_all(f):
    """Однородный масштаб всей модели относительно мировой точки (0,0,0).
    Низ на Z=0 при этом остаётся на месте — годится для приведения к росту."""
    for o in meshes():
        o.location = o.location * f
        o.scale = o.scale * f


def normalize_height(target):
    """Привести общий рост модели к целевому из промпта (коты — 1,8 м)."""
    lo, hi = bbox()
    h = hi[2] - lo[2]
    if h > 0:
        scale_all(target / h)


def export_glb(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes():
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              export_yup=True, use_selection=True)


# --------------------------------------------------------- превью-рендер ---
VIEWS = {
    "34": Vector((1.0, -1.25, 0.62)),      # три четверти спереди-слева
    "34l": Vector((-1.0, -1.25, 0.62)),    # три четверти спереди-справа (пристройки)
    "front": Vector((0.06, -1.0, 0.20)),   # спереди
    "side": Vector((1.0, -0.06, 0.20)),    # сбоку
    "back": Vector((-0.35, 1.0, 0.30)),    # сзади (проверка полос/рюкзака)
}


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 960
    sc.render.resolution_y = 960
    sc.render.film_transparent = False
    # PNG сжимаем сразу: 22 рендера без этого весили 20 МБ вместо 8 МБ.
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.render.image_settings.compression = 100
    # Ключевая правка: Standard вместо AgX — плоские цвета остаются насыщенными.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.eevee.taa_render_samples = 48
    sc.eevee.use_shadows = True
    sc.eevee.use_raytracing = True
    sc.eevee.shadow_ray_count = 2
    sc.eevee.shadow_step_count = 6


def build_rig(radius):
    """Свет, фон и земля только для рендера: в .blend и .glb не попадают.
    Размер земли — по габаритам объекта, чтобы кадр не тонул в пустом поле."""
    sc = bpy.context.scene
    if sc.world is None:
        sc.world = bpy.data.worlds.new("PreviewWorld")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.70, 0.82, 1.0)
    bg.inputs[1].default_value = 0.28          # мягкая подсветка тени, не засвет

    key = bpy.data.lights.new("Key", "SUN")
    key.energy = 3.2
    key.color = (1.0, 0.96, 0.88)
    key.angle = math.radians(12)
    ko = bpy.data.objects.new("Key", key)
    bpy.context.collection.objects.link(ko)
    ko.rotation_euler = (math.radians(52), 0, math.radians(38))

    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.9
    fill.color = (0.78, 0.86, 1.0)
    fill.angle = math.radians(45)
    fo = bpy.data.objects.new("Fill", fill)
    bpy.context.collection.objects.link(fo)
    fo.rotation_euler = (math.radians(62), 0, math.radians(-125))

    bpy.ops.mesh.primitive_plane_add(size=max(4.0, radius * 9),
                                     location=(0, 0, -0.002))
    ground = bpy.context.active_object
    ground.name = "PreviewGround"
    ground.data.materials.append(M()["ground"])


def teardown_rig():
    for n in ("Key", "Fill", "PreviewGround"):
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)


def render_views(asset, views, fov=0.72, margin=1.18, dirpath=None):
    """Рендер объекта с нескольких ракурсов. Камера наводится по габаритам."""
    lo, hi = bbox()
    center = (lo + hi) / 2
    radius = max(hi[i] - lo[i] for i in range(3)) / 2
    dist = radius / math.tan(fov / 2) * margin
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.angle = fov
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    os.makedirs(dirpath, exist_ok=True)
    for tag in views:
        d = VIEWS[tag].normalized()
        cam.location = center + d * dist
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.render.filepath = os.path.join(dirpath, f"{asset}-{tag}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)


# =========================================================================
# 1. Гусь-охранник (0,7 м телом, ~0,9 м в длину, 200–400 треуг.)
# =========================================================================
def build_goose(ms):
    reset_scene()
    # Лапы: короткие цевки + оранжевые перепончатые «клинья» на Z=0
    for s in (-1, 1):
        cyl(f"Shank.{s}", (s * 0.085, -0.02, 0.11), 0.034, 0.22, ms["orange"], n=6,
            r2=0.026)
        box(f"Foot.{s}", (s * 0.085, -0.08, 0.022), (0.10, 0.19, 0.045), ms["orange"])
    # Тело: груша — широкая и низкая сзади, грудь поднята спереди
    sphere("Body", (0, 0.04, 0.45), 0.30, ms["goose_w"], seg=9, ring=5,
           scale=(0.86, 1.10, 1.00))
    sphere("Chest", (0, -0.17, 0.51), 0.22, ms["goose_w"], seg=6, ring=3,
           scale=(0.90, 0.95, 0.95))
    # Шея — цельная S-образная труба: вперёд-вверх, затем изгиб назад и голова
    neck_pts = [(0, -0.13, 0.48), (0, -0.24, 0.60), (0, -0.32, 0.73),
                (0, -0.35, 0.86), (0, -0.33, 0.98), (0, -0.28, 1.05)]
    tube("Neck", neck_pts, [0.10, 0.085, 0.072, 0.062, 0.054, 0.048],
         ms["goose_w"], n=6)
    # Крылья: сложены по бокам и вжаты в тело, чтобы читались как крыло,
    # а не как приставная панель. Правое отведено наружу — жест «ш-ш-ш!».
    for s, roll in ((-1, -0.10), (1, 0.34)):
        w = wing(f"Wing.{s}", (s * 0.20, 0.03, 0.49), 0.38, 0.05, 0.22, 0.06,
                 ms["goose_g"], s=s)
        w.rotation_euler = (0.07, roll, s * 0.13)
    # Голова: небольшая, вытянутая вперёд
    sphere("Head", (0, -0.28, 1.07), 0.085, ms["goose_w"], seg=8, ring=4,
           scale=(0.95, 1.15, 0.95))
    # Клюв: плоский ярко-оранжевый, открытый в гоготе (нижняя челюсть откинута)
    box("BeakUp", (0, -0.40, 1.075), (0.062, 0.17, 0.042), ms["orange"])
    lower = box("BeakDown", (0, -0.375, 1.005), (0.056, 0.15, 0.036), ms["orange"])
    lower.rotation_euler = (0.62, 0, 0)
    # Глаза-бусины и насупленные брови: утоплены в череп, не висят в воздухе
    for s in (-1, 1):
        ico(f"Eye.{s}", (s * 0.048, -0.345, 1.095), 0.019, ms["dark"], sub=1)
        b = box(f"Brow.{s}", (s * 0.048, -0.335, 1.112), (0.056, 0.050, 0.015),
                ms["dark"])
        b.rotation_euler = (0, 0, s * 0.5)
    # Хвост-клинышек вверх
    cone("Tail", (0, 0.35, 0.63), 0.075, 0.24, ms["goose_w"], n=6,
         rot=(-1.05, 0, 0))


# =========================================================================
# 2. Деревянный мостик 4×1,5 м
# =========================================================================
def build_bridge(ms):
    reset_scene()
    deck_z = 0.42
    tones = [ms["wood_b"], ms["wood_c"], ms["wood_a"], ms["wood_c"], ms["wood_b"]]
    # Пять досок настила с зазором: щели читаются тенью, крайние чуть ниже.
    # Шаг подобран так, чтобы ширина моста была ровно 1,5 м из промпта.
    for i in range(5):
        x = -0.60 + i * 0.30
        sag = 0.022 if i in (0, 4) else 0.0
        p = box(f"Plank.{i}", (x, 0, deck_z - sag), (0.285, 4.0, 0.065), tones[i])
        p.rotation_euler = ((0.014 if i == 4 else -0.014) if i in (0, 4) else 0, 0, 0)
    # Поперечные лаги под настилом — видно, что мост, а не пол
    for dy in (-1.35, 0.0, 1.35):
        box(f"Joist.{dy}", (0, dy, deck_z - 0.09), (1.50, 0.16, 0.10), ms["wood_b"])
    # Перила из жердей, четыре столбика с округлыми навершьями
    for s in (-1, 1):
        tube(f"Rail.{s}", [(s * 0.70, -2.0, 0.86), (s * 0.70, 0.0, 0.88),
                           (s * 0.70, 2.0, 0.86)], [0.05, 0.05, 0.05],
             ms["wood_a"], n=8)
        for dy in (-1.45, 1.45):
            cyl(f"Post.{s}.{dy}", (s * 0.70, dy, 0.60), 0.055, 0.56, ms["wood_a"], n=8)
            ico(f"Knob.{s}.{dy}", (s * 0.70, dy, 0.88), 0.062, ms["wood_a"], sub=1)


# =========================================================================
# 3. Клубничная грядка 2×1 м, борт 0,3 м
# =========================================================================
def build_bed(ms):
    reset_scene()
    # Короб из отдельных серых досок в два венца
    for z in (0.10, 0.25):
        box(f"BoardF.{z}", (0, -0.44, z), (2.0, 0.10, 0.15), ms["wood_g"])
        box(f"BoardB.{z}", (0, 0.44, z), (2.0, 0.10, 0.15), ms["wood_g"])
        box(f"BoardL.{z}", (-0.95, 0, z), (0.10, 1.0, 0.15), ms["wood_g"])
        box(f"BoardR.{z}", (0.95, 0, z), (0.10, 1.0, 0.15), ms["wood_g"])
    # Угловые стойки — держат короб (низ ровно на Z=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"Post.{sx}.{sy}", (sx * 0.95, sy * 0.44, 0.175),
                (0.11, 0.11, 0.35), ms["wood_gd"])
    box("Soil", (0, 0, 0.315), (1.86, 0.86, 0.06), ms["soil"])
    # 7 кустиков тёмной листвы; верх светлее — объём
    spots = [(-0.62, -0.20), (-0.25, 0.26), (0.28, -0.30), (0.62, 0.10),
             (0.0, -0.06), (-0.68, 0.30), (0.44, 0.30)]
    for i, (x, y) in enumerate(spots):
        ico(f"Leaf.{i}", (x, y, 0.40), 0.155, ms["leaf"], sub=1,
            scale=(1.05, 1.05, 0.62))
        ico(f"LeafTop.{i}", (x, y, 0.455), 0.10, ms["leaf_l"], sub=1,
            scale=(1.0, 1.0, 0.5))
    # 12 ягод ~4 см. Ягода садится НА листву своего куста, а не на общую высоту
    # грядки: высота считается по поверхности куста в точке ягоды (иначе у края
    # куст ниже, и ягода висит в воздухе — автор это и заметил 19.09.2026).
    # Смещение берётся от центра своего куста, а не произвольно по грядке.
    berry_offsets = [(0.00, 0.00), (-0.07, 0.06), (0.07, -0.05), (0.04, 0.07),
                     (-0.05, -0.07), (0.09, 0.02), (-0.09, 0.01), (0.02, -0.09),
                     (-0.02, 0.09), (0.06, 0.05), (-0.06, -0.04), (0.00, 0.10)]
    for i, (dx, dy) in enumerate(berry_offsets):
        bx, by = spots[i % len(spots)]
        x, y = bx + dx, by + dy
        small = i >= 9
        col = ms["berry_g"] if i == 11 else (ms["berry_d"] if i == 10 else ms["berry"])
        r = 0.015 if small else 0.021
        z = bush_surface(bx, by, dx, dy) - r * 0.25
        ico(f"Berry.{i}", (x, y, z), r, col, sub=1)
        # Чашелистик лежит на самой ягоде: просвет между ним и ягодой читался
        # как вторая висящая деталь.
        box(f"Calyx.{i}", (x, y, z + r + 0.003), (0.024, 0.024, 0.010), ms["leaf"])


def bush_surface(bx, by, dx, dy):
    """Верх листвы куста в точке со смещением (dx, dy) от его центра.
    Куст — два сплюснутых шарика (Leaf и LeafTop); берём верхний из них."""
    top = 0.40 + 0.155 * 0.62 * _dome(dx, dy, 0.155 * 1.05)
    top = max(top, 0.455 + 0.10 * 0.5 * _dome(dx, dy, 0.10))
    return top


def _dome(dx, dy, radius):
    """Высота шапки шара радиуса radius над точкой (dx, dy); за краем — ноль."""
    return math.sqrt(max(0.0, 1.0 - (dx * dx + dy * dy) / (radius * radius)))


# =========================================================================
# 4. Корзина клубники (0,25 м ширина, 0,15 м высота, горка ягод)
# =========================================================================
def build_basket(ms):
    reset_scene()
    # Плетёное лукошко: много тонких прутьев-поясов и тонкие стойки. Широкие
    # кольца делали из корзины бочку, поэтому плетение мелкое и низкое.
    # Пропорция из промпта — 0,25 м ширины на ~0,15 м высоты, то есть приземисто.
    rings = [(0.008, 0.118), (0.036, 0.121), (0.064, 0.123), (0.092, 0.125),
             (0.118, 0.126)]
    for i, (z, r) in enumerate(rings):
        tone = ms["wood_c"] if i % 2 else ms["wood_a"]
        cyl(f"Ring.{i}", (0, 0, z), r, 0.014, tone, n=12)
    for k in range(14):
        a = 2 * math.pi * k / 14
        box(f"Stake.{k}", (math.cos(a) * 0.121, math.sin(a) * 0.121, 0.066),
            (0.011, 0.011, 0.135), ms["wood_b"], rot=(0, 0, a))
    cyl("Base", (0, 0, 0.007), 0.115, 0.018, ms["wood_b"], n=12)
    # Обод — кольцо из коротких прутьев, а не сплошной диск: сплошной цилиндр
    # накрывал устье крышкой, и корзина читалась как кадка с горкой сверху
    for k in range(16):
        a = 2 * math.pi * k / 16
        box(f"RimBar.{k}", (math.cos(a) * 0.124, math.sin(a) * 0.124, 0.138),
            (0.042, 0.015, 0.016), ms["wood_a"], rot=(0, 0, a + math.pi / 2))
    # Горка из 42 ягод: точки берём по треугольной сетке внутри устья и поднимаем
    # куполом. Ряды «по кругу» оставляли дыру в середине — здесь ягоды перекрывают
    # друг друга сплошным слоем, как в настоящем лукошке.
    pts = []
    step = 0.030
    for row in range(-9, 10):
        for col in range(-9, 10):
            x = col * step + (step / 2 if row % 2 else 0.0)
            y = row * step * 0.87
            r = math.hypot(x, y)
            if r <= 0.103:
                pts.append((r, x, y))
    pts.sort(reverse=True)          # от края к центру — купол нарастает к середине
    while len(pts) < 42:            # сетка недобрала — досыпаем к вершине
        r, x, y = pts[-1]
        pts.append((r * 0.5, x * 0.5, y * 0.5))
    pts = pts[:42]                  # перебор убираем от центра: края видны, верх — нет
    for i, (r, x, y) in enumerate(pts):
        z = 0.092 + 0.086 * (1.0 - (r / 0.103) ** 2)
        ico(f"Berry.{i}", (x, y, z), 0.019, ms["berry"], sub=1)
    # Чашелистики — мелкие и только у самых верхних ягод: крупные плиты сверху
    # читались как зелёная черепица, а не как чашелистик
    for i in range(30, min(42, len(pts))):
        o = bpy.data.objects.get(f"Berry.{i}")
        if o:
            box(f"Calyx.{i}", (o.location.x, o.location.y, o.location.z + 0.023),
                (0.016, 0.016, 0.008), ms["leaf"])
    # Дужка. Автор 19.09.2026: корзину кот должен НЕСТИ, а не просто «иметь как
    # объект» — без дужки переноска невозможна. Витьём из двух прутьев: цельный
    # прут читается как ручка ведра, перевитый — как плетёная корзина.
    arc = [(-math.cos(math.pi * i / 14) * 0.126, 0,
            0.132 + math.sin(math.pi * i / 14) * 0.160) for i in range(15)]
    for k, dz in enumerate((-0.010, 0.010)):
        tube(f"HandleBar.{k}",
             [(x, y + dz, z) for x, y, z in arc], [0.011] * len(arc),
             ms["wood_b" if k else "wood_a"], n=5)


# =========================================================================
# 5. Домик бабушки — жилой масштаб (решение автора 19.09.2026)
# =========================================================================
def build_house(ms):
    """Дом бабушки, только снаружи (внутрь никто не заходит — «как в ГТА»).

    Размер переделан 19.09.2026: прежние стены 2,1 м и дверь 1,44 м не пропускали
    кота 1,80 м в рост, и дом читался будкой. Теперь план 6,0 × 4,5 м, стены 3,2 м,
    конёк 4,2 м, дверь 2,10 м в свету. Плюс объём и двор (выбор автора: «1 и 3»):
    пристройка-сени, крыльцо в ступеньках, ставни на окнах."""
    reset_scene()
    wall_h = 3.2
    ridge_z = 4.2
    half_x = 3.0              # по X — 6,0 м
    half_y = 2.25             # по Y — 4,5 м
    # Стены: 9 венцов брёвен, каждый чуть выступает — читаются горизонтальные ряды
    course = wall_h / 9
    for i in range(9):
        z = course * (i + 0.5)
        tone = ms["yellow"] if i % 2 == 0 else ms["yellow_d"]
        box(f"Course.{i}", (0, 0, z), (6.0, 4.5, course * 0.94), tone)
        # торцы брёвен на углах — «видные венцы»
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(f"LogEnd.{i}.{sx}.{sy}",
                    (sx * (half_x + 0.03), sy * (half_y + 0.03), z),
                    (0.18, 0.18, course * 0.80), ms["yellow_d"])
    # Фронтоны по торцам: треугольник точно по скату крыши
    gable_h = ridge_z - wall_h
    for sx in (-1, 1):
        tri_prism_x(f"Gable.{sx}", sx * (half_x - 0.01), 0, 4.5, gable_h, 0.16,
                    wall_h, ms["yellow"])
    # Крыша: два ската, конёк по X, свес 0,30
    over = 0.30
    slope_len = math.hypot(half_y + over, gable_h) + 0.18
    ang = math.atan2(gable_h, half_y + over)
    for s in (-1, 1):
        cy = s * (half_y + over) / 2
        cz = wall_h + gable_h / 2
        p = box(f"Roof.{s}", (0, cy, cz), (6.4, slope_len, 0.10),
                ms["roof"] if s < 0 else ms["roof_d"])
        p.rotation_euler = (-s * ang, 0, 0)
    box("Ridge", (0, 0, ridge_z - 0.01), (6.46, 0.30, 0.12), ms["roof"])
    # Труба серого кирпича: поднята вместе с домом, иначе тонула в крыше
    box("Chimney", (1.7, 0.9, 3.62), (0.38, 0.38, 1.72), ms["brick"])
    box("ChimneyCap", (1.7, 0.9, 4.51), (0.46, 0.46, 0.10), ms["brick"])
    # Дверь 2,10 м в свету — кот 1,80 м проходит в рост (передний фасад, −Y)
    box("DoorFrame", (0.4, -2.31, 1.18), (1.30, 0.14, 2.34), ms["yellow_d"])
    box("Door", (0.4, -2.36, 1.16), (1.06, 0.10, 2.10), ms["wood_a"])
    cyl("DoorWinRing", (0.4, -2.42, 1.72), 0.17, 0.05, ms["cream"], n=12,
        rot=(math.pi / 2, 0, 0))
    cyl("DoorWinGlass", (0.4, -2.44, 1.72), 0.115, 0.05, ms["dark"], n=12,
        rot=(math.pi / 2, 0, 0))
    box("Handle", (0.75, -2.45, 1.02), (0.06, 0.06, 0.22), ms["dark"])
    # Окна с наличниками и ставнями по бокам двери
    for x, w in ((-1.7, 1.30), (2.15, 1.05)):
        box(f"WinFrame.{x}", (x, -2.31, 1.60), (w, 0.12, 1.34), ms["white"])
        box(f"WinGlass.{x}", (x, -2.36, 1.60), (w - 0.24, 0.06, 1.10), ms["dark"])
        box(f"WinCross.{x}", (x, -2.38, 1.60), (0.07, 0.04, 1.10), ms["white"])
        box(f"WinCrossH.{x}", (x, -2.38, 1.60), (w - 0.24, 0.04, 0.07), ms["white"])
        box(f"WinTop.{x}", (x, -2.33, 2.37), (w + 0.24, 0.14, 0.12), ms["white"])
        box(f"WinSill.{x}", (x, -2.33, 0.86), (w + 0.24, 0.14, 0.12), ms["white"])
        # Ставни: без них окна выглядели наклейками на коробе
        for s in (-1, 1):
            sx = x + s * (w / 2 + 0.26)
            box(f"Shutter.{x}.{s}", (sx, -2.33, 1.60), (0.44, 0.09, 1.30),
                ms["wood_c"])
            for k in (-0.30, 0.0, 0.30):
                box(f"ShutterSlat.{x}.{s}.{k}", (sx, -2.38, 1.60 + k),
                    (0.36, 0.03, 0.09), ms["wood_b"])
    # Пристройка-сени слева под односкатным навесом: дом перестаёт быть коробом
    box("Seny", (-3.85, 0, 1.25), (1.80, 3.00, 2.50), ms["yellow"])
    # Тесины на сенях: без них пристройка читалась гладким ящиком рядом со срубом
    for k in (-0.65, -0.10, 0.55, 1.15):
        box(f"SenyPlank.{k}", (-3.85, -1.51, 1.25 + k), (1.70, 0.05, 0.10),
            ms["yellow_d"])
    seny_roof = box("SenyRoof", (-3.95, 0, 2.62), (2.30, 3.30, 0.10), ms["roof_d"])
    seny_roof.rotation_euler = (0, math.radians(11), 0)
    box("SenyDoor", (-3.85, -1.53, 1.00), (0.95, 0.10, 1.95), ms["wood_a"])
    box("SenyStep", (-3.85, -1.70, 0.05), (1.10, 0.36, 0.10), ms["wood_b"])
    # Крыльцо перед дверью: площадка и две ступени
    box("Porch", (0.4, -2.95, 0.30), (1.90, 1.15, 0.12), ms["wood_b"])
    box("PorchStep1", (0.4, -3.45, 0.18), (1.90, 0.36, 0.12), ms["wood_a"])
    box("PorchStep2", (0.4, -3.78, 0.06), (1.90, 0.34, 0.12), ms["wood_a"])
    for s in (-1, 1):
        box(f"PorchPost.{s}", (0.4 + s * 1.20, -2.95, 0.85), (0.12, 0.12, 1.10),
            ms["wood_b"])


# =========================================================================
# 6. Двор: забор, сарай, поленница, бочка (выбор автора 19.09.2026)
# =========================================================================
def build_fence(ms):
    """Секция деревенского забора ~2,4 м: два столба, две слеги, штакетник."""
    reset_scene()
    length = 2.4
    for s in (-1, 1):
        box(f"Post.{s}", (s * length / 2, 0, 0.60), (0.14, 0.14, 1.20),
            ms["wood_b"])
    for z in (0.42, 0.92):
        box(f"Rail.{z}", (0, 0, z), (length, 0.07, 0.11), ms["wood_c"])
    board = 0.12
    count = int(length / (board * 1.55))
    for i in range(count):
        x = -length / 2 + 0.20 + i * (length - 0.40) / (count - 1)
        box(f"Picket.{i}", (x, 0.005, 0.62), (board, 0.04, 1.08), ms["wood_a"])


def build_shed(ms):
    """Сарай 2,8 × 2,2 м под двускатной крышей, дверь на переднем фасаде."""
    reset_scene()
    wall_h = 2.0
    ridge_z = 2.6
    half_x = 1.4
    half_y = 1.1
    course = wall_h / 5
    for i in range(5):
        z = course * (i + 0.5)
        # Тёплое и светлое дерево вперемешку: wood_a/wood_b давали полосатость
        tone = ms["wood_c"] if i % 2 == 0 else ms["wood_a"]
        box(f"Course.{i}", (0, 0, z), (2.8, 2.2, course * 0.94), tone)
    gable_h = ridge_z - wall_h
    for sx in (-1, 1):
        tri_prism_x(f"Gable.{sx}", sx * (half_x - 0.01), 0, 2.2, gable_h, 0.14,
                    wall_h, ms["wood_a"])
    over = 0.22
    slope_len = math.hypot(half_y + over, gable_h) + 0.16
    ang = math.atan2(gable_h, half_y + over)
    for s in (-1, 1):
        p = box(f"Roof.{s}", (0, s * (half_y + over) / 2, wall_h + gable_h / 2),
                (3.1, slope_len, 0.09), ms["roof_d"] if s < 0 else ms["roof"])
        p.rotation_euler = (-s * ang, 0, 0)
    box("Ridge", (0, 0, ridge_z - 0.01), (3.14, 0.26, 0.10), ms["roof_d"])
    box("DoorFrame", (0.45, -1.13, 0.97), (1.15, 0.12, 1.94), ms["wood_b"])
    box("Door", (0.45, -1.17, 0.93), (0.95, 0.10, 1.70), ms["wood_c"])
    box("Handle", (0.80, -1.24, 0.90), (0.06, 0.06, 0.20), ms["dark"])


def build_woodpile(ms):
    """Поленница: колотые поленья в три ряда, торцы смотрят на зрителя (−Y)."""
    reset_scene()
    length = 1.8
    depth = 0.7
    radius = 0.095
    log_len = depth
    for row in range(4):
        z = radius + row * radius * 1.85
        offset = (length - 0.30) / (length / (radius * 2.05))
        count = int(length / (radius * 2.05))
        step = (length - 0.24) / max(count - 1, 1)
        for i in range(count):
            x = -length / 2 + 0.12 + i * step
            tone = ms["wood_c"] if (i + row) % 3 else ms["wood_a"]
            cyl(f"Log.{row}.{i}", (x, 0, z), radius, log_len, tone, n=8,
                rot=(math.pi / 2, 0, 0), r2=radius * 0.86)
    # Подкладки-жерди по краям, чтобы поленница стояла (низ ровно на земле)
    for s in (-1, 1):
        box(f"Skid.{s}", (s * (length / 2 - 0.06), 0, radius * 0.8),
            (0.10, depth, radius * 1.6), ms["wood_b"])


def build_barrel(ms):
    """Бочка деревянная, ~0,8 м высотой.

    Силуэт делается одной трубой по вертикали (пузатый профиль), а не набором
    цилиндров: отдельные цилиндры разного радиуса читались стопкой, а не бочкой.
    """
    reset_scene()
    profile = [(0.00, 0.225), (0.20, 0.285), (0.40, 0.300),
               (0.58, 0.285), (0.74, 0.215)]
    tube("Body", [(0, 0, z) for z, _ in profile], [r for _, r in profile],
         ms["wood_a"], n=14)
    # Обручи: чуть больше радиуса бочки на своей высоте и темнее
    for z, r in ((0.20, 0.285), (0.60, 0.285)):
        cyl(f"Hoop.{z}", (0, 0, z), r + 0.012, 0.055, ms["dark"], n=14)


# =========================================================================
# 6. Кот v2 — гранёный low-poly, 1,8 м, 800–1200 треуг.
# =========================================================================
def build_cat_v2(ms):
    reset_scene()
    # Ноги: бедро + голень + крупные лапы. Ноги — цельные трубы, верх уходит
    # в торс (иначе между телом и ногой виден разрыв)
    for s in (-1, 1):
        tube(f"Thigh.{s}", [(s * 0.16, 0.0, 0.78), (s * 0.15, 0.0, 0.42)],
             [0.125, 0.095], ms["fur"], n=6)
        tube(f"Shin.{s}", [(s * 0.15, 0.0, 0.42), (s * 0.15, -0.01, 0.15)],
             [0.088, 0.075], ms["fur"], n=6)
        box(f"Boot.{s}", (s * 0.15, -0.03, 0.055), (0.20, 0.30, 0.11), ms["fur"])
        box(f"Paw.{s}", (s * 0.15, -0.16, 0.06), (0.17, 0.12, 0.09), ms["cream"])
    # Торс — мех, а не куртка: решение автора 19.09.2026 — герой БЕЗ одежды,
    # на нём только мех, полоски и браслет. Кремовая грудь остаётся окрасом.
    ico("Torso", (0, 0, 1.02), 0.30, ms["fur"], sub=1, scale=(1.12, 0.86, 1.05))
    ico("Chest", (0, -0.14, 1.06), 0.16, ms["cream"], sub=1,
        scale=(0.95, 0.75, 0.85))
    box("Collar", (0, -0.01, 1.25), (0.30, 0.26, 0.06), ms["cream"])
    # Руки — трубы от плеча вниз-наружу: прижаты к телу, не «фанерки» вбок
    for s in (-1, 1):
        tube(f"Arm.{s}", [(s * 0.28, 0.0, 1.18), (s * 0.38, -0.01, 0.98),
                          (s * 0.43, -0.02, 0.84)],
             [0.10, 0.085, 0.075], ms["fur"], n=6)
        ico(f"Hand.{s}", (s * 0.44, -0.02, 0.78), 0.085, ms["fur"], sub=1)
    # Красный браслет героя (канон) — единственное, что на нём есть
    cyl("Bracelet", (0.43, -0.02, 0.88), 0.098, 0.035, ms["berry"], n=8)
    # Палки и рюкзака на модели героя нет (решение автора 19.09.2026): это
    # предметы, а не часть кота — делаются отдельными ассетами и берутся в игре.
    # Голова: крупная, гранёная икосафера, чуть сплюснутая
    ico("Head", (0, 0, 1.53), 0.30, ms["fur"], sub=2, scale=(1.0, 0.94, 0.96))
    for s in (-1, 1):
        ico(f"Cheek.{s}", (s * 0.17, -0.15, 1.44), 0.11, ms["fur"], sub=1,
            scale=(0.9, 0.8, 0.8))
    box("Muzzle", (0, -0.25, 1.45), (0.19, 0.13, 0.13), ms["cream"])
    box("Nose", (0, -0.32, 1.49), (0.055, 0.04, 0.038), ms["stripe"])
    # Глаза большие, тёмные, без белков — плоские гранёные
    for s in (-1, 1):
        ico(f"Eye.{s}", (s * 0.12, -0.255, 1.58), 0.048, ms["dark"], sub=1)
        ico(f"Glint.{s}", (s * 0.14, -0.29, 1.60), 0.013, ms["white"], sub=1)
    # Уши: крупные треугольные, с розовой внутренней гранью
    for s in (-1, 1):
        cone(f"Ear.{s}", (s * 0.19, -0.02, 1.82), 0.115, 0.26, ms["fur"], n=4,
             rot=(0.10, 0, s * -0.30), r2=0.01)
        cone(f"EarIn.{s}", (s * 0.19, -0.07, 1.79), 0.065, 0.16, ms["pink"], n=4,
             rot=(0.14, 0, s * -0.30), r2=0.008)
    # Полосы: лоб, спина, руки
    for i, dz in enumerate((0.0, 0.05)):
        box(f"HeadStripe.{i}", (0, -0.02, 1.74 - dz), (0.07, 0.13, 0.022), ms["stripe"])
    for i in range(3):
        box(f"BackStripe.{i}", (0, 0.22 + i * 0.03, 1.14 - i * 0.10),
            (0.06, 0.06, 0.022), ms["stripe"])
    # Хвост: полосатый, из коротких сегментов, чередующих мех и полосу. Прежняя
    # версия шла «за рюкзак» и несла полосы отдельными кольцами — с убранным
    # рюкзаком кольца торчали и хвост читался поломанным.
    tail_pts = [(0, 0.20, 0.92), (0.02, 0.42, 0.88), (0.04, 0.60, 1.00),
                (0.05, 0.66, 1.24), (0.03, 0.56, 1.44)]
    tail_r = [0.100, 0.090, 0.078, 0.062, 0.044]
    for i in range(len(tail_pts) - 1):
        tube(f"Tail.{i}", [tail_pts[i], tail_pts[i + 1]],
             [tail_r[i], tail_r[i + 1]],
             ms["stripe"] if i % 2 else ms["fur"], n=6)


# =========================================================================
# 7. Кот v3 — ступенчатый voxel/pixel, 1,8 м, 500–900 треуг.
# =========================================================================
def build_cat_v3(ms):
    reset_scene()
    g = 0.09   # модуль сетки
    # Ноги: ступени из кубиков + лапы (без одежды — решение автора 19.09.2026)
    for s in (-1, 1):
        for k in range(4):
            box(f"Leg.{s}.{k}", (s * 0.16, 0, 0.20 + k * g),
                (0.20, 0.20, g * 0.92), ms["fur"])
        for k in range(2):
            box(f"Boot.{s}.{k}", (s * 0.16, -0.03, 0.041 + k * g),
                (0.24, 0.32, g * 0.92), ms["fur"])
    # Торс мехом ступенями: плечи шире, талия уже (куртки нет)
    box("TorsoLow", (0, 0, 0.72), (0.50, 0.34, g * 2), ms["fur"])
    box("TorsoMid", (0, 0, 0.93), (0.56, 0.38, g * 2), ms["fur"])
    box("TorsoUp", (0, 0, 1.14), (0.62, 0.40, g * 2), ms["fur"])
    box("Belly", (0, -0.215, 1.20), (0.24, 0.06, 0.26), ms["cream"])
    box("Collar", (0, 0, 1.32), (0.26, 0.26, 0.10), ms["cream"])
    # Руки ступенями и лапы + красный браслет героя (канон)
    for s in (-1, 1):
        box(f"ArmUp.{s}", (s * 0.39, 0, 1.10), (0.19, 0.24, g * 2), ms["fur"])
        box(f"ArmLo.{s}", (s * 0.39, 0, 0.90), (0.19, 0.24, g * 2), ms["fur"])
        box(f"Paw.{s}", (s * 0.39, -0.02, 0.73), (0.20, 0.26, g * 1.4), ms["fur"])
    cyl("Bracelet", (0.39, 0, 0.86), 0.145, 0.05, ms["berry"], n=8)
    # Палка и рюкзак на модели героя не рисуются (решение автора 19.09.2026):
    # это предметы, которые он берёт в игре, а не часть кота.
    # Голова-квадрат со ступенчатыми щеками
    box("Head", (0, 0, 1.62), (0.42, 0.42, g * 4.6), ms["fur"])
    for s in (-1, 1):
        box(f"Cheek.{s}", (s * 0.24, -0.06, 1.55), (0.14, 0.30, g * 2), ms["fur"])
    box("Muzzle", (0, -0.26, 1.55), (0.26, 0.12, g * 1.8), ms["cream"])
    box("Nose", (0, -0.28, 1.61), (0.12, 0.06, g), ms["stripe"])
    # Глаза-блоки
    for s in (-1, 1):
        box(f"Eye.{s}", (s * 0.13, -0.23, 1.67), (0.13, 0.05, g * 1.6), ms["dark"])
    # Уши: ступенчатый треугольник из трёх сужающихся кубиков. Ступени стоят
    # на одной оси — иначе вместо уха выходит гребёнка со ступеньками в стороны.
    for s in (-1, 1):
        ex = s * 0.15
        for k, (w, h) in enumerate(((0.22, 0.09), (0.16, 0.085), (0.10, 0.075))):
            box(f"Ear.{s}.{k}", (ex, -0.02, 1.845 + k * 0.068), (w, w, h),
                ms["fur"])
        box(f"EarIn.{s}", (ex, -0.115, 1.87), (0.10, 0.03, 0.10), ms["pink"])
    # Полосы на лбу и спине
    for k in range(2):
        box(f"HeadStripe.{k}", (0, -0.02, 1.78 - k * g * 0.8),
            (0.09, 0.16, 0.022), ms["stripe"])
    for k in range(3):
        box(f"BackStripe.{k}", (0, 0.17 + k * 0.04, 1.18 - k * g),
            (0.07, 0.06, 0.022), ms["stripe"])
    # Хвост — ломаная цепочка кубиков вверх-назад
    tail = [(0, 0.30, 0.80), (0, 0.40, 0.90), (0.02, 0.48, 1.03),
            (0.02, 0.50, 1.17), (0, 0.47, 1.30)]
    for i, (x, y, z) in enumerate(tail):
        box(f"Tail.{i}", (x, y, z), (0.10, 0.10, 0.10),
            ms["stripe"] if i % 2 else ms["fur"])


# =========================================================================
ASSETS = [
    ("goose_guard_v1", build_goose, ("34", "front", "side"), None),
    ("bridge_v1", build_bridge, ("34", "front", "side"), None),
    ("strawberry_bed_v1", build_bed, ("34", "front", "side"), None),
    ("strawberry_basket_v1", build_basket, ("34", "front"), None),
    ("grandma_house_v1", build_house, ("34", "34l", "front", "side"), None),
    ("yard_fence_v1", build_fence, ("34", "front"), None),
    ("yard_shed_v1", build_shed, ("34", "front"), None),
    ("woodpile_v1", build_woodpile, ("34", "front"), None),
    ("barrel_v1", build_barrel, ("34", "front"), None),
    ("cat_v2_faceted", build_cat_v2, ("34", "front", "side", "back"), 1.80),
    ("cat_v3_voxel", build_cat_v3, ("34", "front", "side", "back"), 1.80),
]


def main():
    ms = M()
    setup_render()
    # OUT = <проект>/assets/own -> доказательства лежат в <проект>/evidence/
    proj = os.path.dirname(os.path.dirname(OUT))
    evid = os.path.join(proj, "evidence", "pack-2026-09-19")
    os.makedirs(os.path.join(OUT, "sources"), exist_ok=True)
    for name, fn, views, target_h in ASSETS:
        if ONLY and name != ONLY:
            continue
        fn(ms)
        if target_h:
            normalize_height(target_h)   # рост котов из промпта — 1,8 м
        lo, hi = bbox()
        tris = tri_count()
        radius = max(hi[i] - lo[i] for i in range(3)) / 2
        glb = os.path.join(OUT, name + ".glb")
        export_glb(glb)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "sources", name + ".blend"))
        build_rig(radius)
        render_views(name, views, dirpath=evid)
        teardown_rig()
        print(f"ASSET_OK {name} tris={tris} "
              f"whd=({hi[0]-lo[0]:.3f},{hi[1]-lo[1]:.3f},{hi[2]-lo[2]:.3f}) "
              f"zmin={lo[2]:.4f} glb={os.path.getsize(glb)}")


main()
print("PACK_BUILD_OK")
