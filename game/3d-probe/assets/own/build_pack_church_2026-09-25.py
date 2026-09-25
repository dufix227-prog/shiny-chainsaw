# Пачка церкви — заход 2 (25.09.2026)
#
# Собрано по промптам захода 1
# (implementation-plan/prologue/control/ПРОМПТЫ-ЦЕРКОВЬ-ЗАХОД-1-2026-09-19.md).
# Промпты не правились: высоты, размеры и палитра взяты из их таблиц.
#
# Почему отдельный скрипт, а не общий с пачкой пролога: у церкви своя палитра
# (белый камень, золото) и свои ракурсы — 36-метровую церковь, интерьер и
# надгробие нельзя снимать одним кадром. Превью-риг взят из
# build_pack_vision_2026-09-19.py: view transform Standard (на AgX плоские цвета
# выходят бежевыми), солнце-ключ и холодный заполняющий свет, земля с контактной
# тенью. Добавлена капсула-эталон «рост кота 1,8 м» и колокол в ярусе звонницы
# (только для рендера): без них размер 36-метровой церкви и место колокола
# на картинке не проверить.
#
# Запуск: blender -b -P build_pack_church_2026-09-19.py -- <каталог-вывода> [только-имя]
#   Blender 5.2.1. Каталог вывода — game/3d-probe/assets/own.
# Конвенции как у cat_hoplite_v1.glb: низ на Z=0 (исключение — колокол: origin
# в точке подвеса), фронт вдоль Blender −Y, экспорт GLB с export_yup=True
# (в Godot фронт −Z).
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

EVID = "church-2026-09-25"


# ---------------------------------------------------------------- палитра ---
# Новые цвета церкви — из промптов захода 1; четвёрка = hex/255, как в пачке
# пролога. Дерево, кирпич и кремовый берутся из пачки пролога, чтобы церковь
# не оторвалась от остальных моделей.
STONE_W = (0.914, 0.902, 0.859, 1.0)    # #e9e6db белый камень, стены
STONE_D = (0.796, 0.780, 0.725, 1.0)    # #cbc7b9 лопатки, карниз, наличники
STONE_G = (0.663, 0.647, 0.608, 1.0)    # #a9a59b цоколь, пол, столбики, надгробия
STONE_GD = (0.514, 0.502, 0.478, 1.0)   # #83807a основание, швы, особая могила
GOLD = (0.878, 0.663, 0.169, 1.0)       # #e0a92b луковицы, кресты, оклады
GOLD_D = (0.690, 0.490, 0.086, 1.0)     # #b07d16 низ луковицы, юбка колокола
GLASS = (0.275, 0.329, 0.369, 1.0)      # #46545e окна
BELL = (0.541, 0.455, 0.251, 1.0)       # #8a7440 бронза колокола
ICON_BG = (0.290, 0.208, 0.141, 1.0)    # #4a3524 доска иконы
ICON_L = (0.851, 0.804, 0.706, 1.0)     # #d9cdb4 светлый лик на иконе
WAX = (0.937, 0.906, 0.824, 1.0)        # #efe7d2 свечка
FLAME = (1.000, 0.824, 0.353, 1.0)      # #ffd25a огонёк свечи (с излучением)

BRICK = (0.510, 0.451, 0.427, 1.0)      # крыша притвора (цвет из пачки пролога)
WOOD_A = (0.451, 0.306, 0.196, 1.0)
WOOD_B = (0.318, 0.208, 0.129, 1.0)
WOOD_C = (0.549, 0.388, 0.251, 1.0)
CREAM = (0.961, 0.863, 0.655, 1.0)      # воск темнее свечки
DARK = (0.188, 0.165, 0.149, 1.0)
GROUND = (0.408, 0.427, 0.353, 1.0)     # земля превью (только рендер)

TRI = {}
_MATS = {}


def mat(name, rgb, rough=0.85):
    """Плоский материал: без металла и бликов — цвет как в промпте. Второй раз
    цвет задаётся в diffuse_color: это цвет для окна Blender (Solid-режим),
    чтобы модель можно было смотреть прямо в вьюпорте, а не только на рендере."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Specular IOR Level"].default_value = 0.12
    m.diffuse_color = rgb
    _MATS[name] = m
    return m


def mat_emit(name, rgb, strength=3.0):
    """Материал с излучением — только огонёк свечи. В GLB уходит emission,
    и в Godot к нему потом привяжется свет."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Emission Color"].default_value = rgb
    b.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = rgb
    _MATS[name] = m
    return m


def M():
    return {
        "w": mat("StoneWhite", STONE_W), "d": mat("StoneLight", STONE_D),
        "g": mat("StoneGrey", STONE_G), "gd": mat("StoneDark", STONE_GD),
        "gold": mat("Gold", GOLD), "gold_d": mat("GoldDark", GOLD_D),
        "glass": mat("Glass", GLASS), "bell": mat("BellBronze", BELL),
        "icon": mat("IconBoard", ICON_BG), "icon_l": mat("IconLight", ICON_L),
        "wax": mat("Wax", WAX), "cream": mat("Cream", CREAM),
        "flame": mat_emit("Flame", FLAME, 3.0),
        "brick": mat("Brick", BRICK),
        "wood_a": mat("WoodA", WOOD_A), "wood_b": mat("WoodB", WOOD_B),
        "wood_c": mat("WoodC", WOOD_C), "dark": mat("Dark", DARK),
        "ground": mat("PreviewGround", GROUND),
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


def cone(name, loc, r, h, m, n=8, rot=(0, 0, 0), r2=0.0):
    return cyl(name, loc, r, h, m, n=n, rot=rot, r2=r2)


def sphere(name, loc, r, m, seg=10, ring=6, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring,
                                         radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    return _finish(o, m, name)


def ico(name, loc, r, m, sub=1, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    o.rotation_euler = rot
    return _finish(o, m, name)


def mesh_obj(name, verts, faces, m):
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
    """Труба переменного радиуса по ломаной: луковицы, шейка, профиль колокола.
    Цельная сетка вместо набора цилиндров — силуэт не рассыпается (на бочке
    уже наступали: набор цилиндров читался стопкой)."""
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


def rot_x(ang, p, pivot):
    """Точка, повёрнутая вокруг оси X относительно pivot: у покосившегося креста
    все части наклоняются вместе, а не разъезжаются."""
    dy, dz = p[1] - pivot[1], p[2] - pivot[2]
    c, s = math.cos(ang), math.sin(ang)
    return (p[0], pivot[1] + dy * c - dz * s, pivot[2] + dy * s + dz * c)


# -------------------------------------------------------- стены и проёмы ---
def wall(name, axis, v, u0, u1, z0, z1, thick, m, holes=(), prefix=""):
    """Стена полосами: сплошные простенки на всю высоту плюс полосы над и под
    проёмами. Окно выходит настоящим проёмом в толще стены, а не наклейкой на
    плоскости, и простенки между окнами получаются сами.

    axis — ось, вдоль которой тянется стена ("x" или "y"); v — координата по
    другой оси; thick — толщина стены; holes — (центр, ширина, низ, верх).
    """
    def panel(u_left, u_right, zb, zt, tag):
        if u_right - u_left < 0.001 or zt - zb < 0.001:
            return
        cu = (u_left + u_right) / 2
        cz = (zb + zt) / 2
        if axis == "x":
            loc, size = (cu, v, cz), (u_right - u_left, thick, zt - zb)
        else:
            loc, size = (v, cu, cz), (thick, u_right - u_left, zt - zb)
        box(f"{prefix}{name}.{tag}", loc, size, m)

    cursor = u0
    for i, (cu, w, zb, zt) in enumerate(sorted(holes, key=lambda h: h[0] - h[1] / 2)):
        left, right = cu - w / 2, cu + w / 2
        panel(cursor, left, z0, z1, f"Pier{i}")
        panel(left, right, z0, zb, f"Under{i}")
        panel(left, right, zt, z1, f"Over{i}")
        cursor = right
    panel(cursor, u1, z0, z1, "PierEnd")


def window(name, axis, v, u, w, zb, zt, ms, thick):
    """Окно: наличник светлого камня по краям проёма и тёмное стекло с
    переплётом в толще стены."""
    fr = 0.16
    for k, du in (("a", -w / 2 - fr / 2), ("b", w / 2 + fr / 2)):
        if axis == "x":
            box(f"{name}.Frame.{k}", (u + du, v, (zb + zt) / 2),
                (fr, thick, zt - zb), ms["d"])
        else:
            box(f"{name}.Frame.{k}", (v, u + du, (zb + zt) / 2),
                (thick, fr, zt - zb), ms["d"])
    if axis == "x":
        box(f"{name}.Lintel", (u, v, zt + fr / 2), (w + 2 * fr, thick, fr), ms["d"])
        box(f"{name}.Glass", (u, v, (zb + zt) / 2), (w - 0.06, thick * 0.2, zt - zb - 0.06),
            ms["glass"])
        box(f"{name}.Mullion", (u, v, (zb + zt) / 2),
            (0.06, thick * 0.26, zt - zb - 0.06), ms["d"])
    else:
        box(f"{name}.Lintel", (v, u, zt + fr / 2), (thick, w + 2 * fr, fr), ms["d"])
        box(f"{name}.Glass", (v, u, (zb + zt) / 2), (thick * 0.2, w - 0.06, zt - zb - 0.06),
            ms["glass"])
        box(f"{name}.Mullion", (v, u, (zb + zt) / 2),
            (thick * 0.26, 0.06, zt - zb - 0.06), ms["d"])


# -------------------------------------------------------------- каркас ---
def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)


def meshes():
    """Меши модели — только в текущей сцене. Обходить bpy.data.objects нельзя:
    в живом Blender рядом лежат чужие сцены и объекты (в сессии автора лежал
    тестовый куб и раздувал габарит ровно на метр), а в экспорт они попасть
    не должны. Объекты превью-рига (земля, капсула-эталон, колокол для рендера)
    тоже исключаются."""
    return [o for o in bpy.context.scene.objects if o.type == "MESH"
            and not o.name.startswith(("Preview", "Key", "Fill"))]


def tri_count():
    n = 0
    for o in meshes():
        for p in o.data.polygons:
            n += len(p.vertices) - 2
    return n


def bbox():
    """Габариты по вершинам, а не по bound_box: bound_box локальный, и у
    повёрнутых объектов он завышает габарит (четырёхгранный шатёр, повёрнутый
    на 45°, мерился вдвое шире, чем он есть)."""
    bpy.context.view_layer.update()
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in meshes():
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    return Vector(lo), Vector(hi)


def framing():
    """Габариты для камеры: модель вместе с объектами превью, кроме земли.
    Без этого капсула-эталон уезжает за кадр (на корзине так и вышло)."""
    lo, hi = bbox()
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith("Preview") \
                and o.name != "PreviewGround":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                for i in range(3):
                    lo[i] = min(lo[i], w[i])
                    hi[i] = max(hi[i], w[i])
    return lo, hi


def export_glb(path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes():
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              export_yup=True, use_selection=True)


def move_all(dz):
    """Сдвиг всей модели по Z: колоколу нужен origin в точке подвеса, а собрать
    его удобнее от юбки на нуле."""
    for o in meshes():
        o.location = o.location + Vector((0, 0, dz))


# --------------------------------------------------------- превью-рендер ---
VIEWS = {
    "34": {"dir": (1.0, -1.25, 0.62)},
    "34l": {"dir": (-1.0, -1.25, 0.62)},
    "front": {"dir": (0.06, -1.0, 0.20)},
    "side": {"dir": (1.0, -0.06, 0.20)},
    "back": {"dir": (-0.35, 1.0, 0.30)},
    "far": {"dir": (1.15, -1.55, 0.34), "scale": 1.55},
    "low": {"dir": (0.9, -1.3, 0.14)},
}


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 960
    sc.render.resolution_y = 960
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.render.image_settings.compression = 100
    # Standard вместо AgX: на AgX плоские цвета выходят бежевыми
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.eevee.taa_render_samples = 48
    sc.eevee.use_shadows = True
    sc.eevee.use_raytracing = True
    sc.eevee.shadow_ray_count = 2
    sc.eevee.shadow_step_count = 6


def build_rig(radius):
    """Свет, фон и земля — только для рендера: в .blend и .glb не входят."""
    sc = bpy.context.scene
    if sc.world is None:
        sc.world = bpy.data.worlds.new("PreviewWorld")
    sc.world.use_nodes = True
    tree = sc.world.node_tree
    # В новой сцене мир приходит без готовых нод — фон и выход создаём сами,
    # иначе nodes["Background"] не находится (в headless сцена была не новая).
    bg = tree.nodes.get("Background")
    if bg is None:
        bg = tree.nodes.new("ShaderNodeBackground")
    out = tree.nodes.get("World Output")
    if out is None:
        out = tree.nodes.new("ShaderNodeOutputWorld")
    if not out.inputs["Surface"].links:
        tree.links.new(bg.outputs["Background"], out.inputs["Surface"])
    bg.inputs[0].default_value = (0.62, 0.70, 0.82, 1.0)
    bg.inputs[1].default_value = 0.28

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

    bpy.ops.mesh.primitive_plane_add(size=max(6.0, radius * 9),
                                     location=(0, 0, -0.002))
    ground = bpy.context.active_object
    ground.name = "PreviewGround"
    ground.data.materials.append(M()["ground"])


def cat_reference(ms, loc):
    """Капсула-эталон «рост кота 1,8 м». Имя начинается с Preview: в габариты
    модели и в экспорт она не попадает, а в кадр — попадает."""
    m = mat("PreviewCatMat", (0.93, 0.35, 0.15, 1.0))
    cyl("PreviewCat", (loc[0], loc[1], 0.90), 0.28, 1.80, m, n=12)


def teardown_rig():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(("Preview", "Key", "Fill")):
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        if m.name == "PreviewCatMat":
            bpy.data.materials.remove(m)
    # Материал эталона удалён — убираем и ссылку на него из кэша, иначе
    # следующий объект пачки получит мёртвую структуру (ReferenceError).
    _MATS.pop("PreviewCatMat", None)


def render_views(asset, shots, fov=0.72, margin=1.18, dirpath=None):
    """Ракурсы. shots — словари: tag (ключ VIEWS) и необязательные aim
    (абсолютная точка в метрах), dist, scale."""
    lo, hi = framing()
    center = (lo + hi) / 2
    radius = max(hi[i] - lo[i] for i in range(3)) / 2
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.angle = fov
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    os.makedirs(dirpath, exist_ok=True)
    for shot in shots:
        spec = VIEWS[shot["tag"]]
        aim = Vector(shot["aim"]) if "aim" in shot else Vector(center)
        dist = shot.get("dist")
        if dist is None:
            dist = radius / math.tan(fov / 2) * margin * spec.get("scale", 1.0)
        d = Vector(spec["dir"]).normalized()
        cam.location = aim + d * dist
        cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
        # label нужен, когда у объекта два кадра одного ракурса (общий и крупный):
        # без него второй кадр перезаписывает первый, и «крупный вид входа»
        # остаётся вместо общего вида спереди
        name = shot.get("label", shot["tag"])
        bpy.context.scene.render.filepath = os.path.join(dirpath, f"{asset}-{name}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)


def views(*tags):
    return [dict(tag=t) for t in tags]


# =========================================================================
# 1. church_v1 — церковь снаружи, 36 м
# =========================================================================
# Раскладка высот из промптов: цоколь 0,8 → стены 15,0 → карниз 15,5 → переход →
# барабан до 20,5 → золотая луковица до 30,0 → крест до 36,0. Притвор 8 × 6 м,
# ярус звонницы над ним до 15,5 м, малая луковица до 21,0, малый крест 23,4.
CH_HALF = 7.0        # четверик 14 × 14 м
CH_CY = 3.0          # центр четверика: притвор занимает Y −10…−4
PLINTH = 0.8
WALL_TOP = 15.0
CORN_TOP = 15.5
DRUM_BASE = 17.2
DRUM_TOP = 20.5
DRUM_R = 4.20        # восьмигранник: 7,8 м по грани
ONION_TOP = 30.5
BALL_TOP = 31.1
CROSS_TOP = 36.0
TH = 0.8             # толщина стен четверика
FLOOR_Z = 0.45       # пол церкви и площадка крыльца — один уровень
P_Y0, P_Y1 = -10.0, -4.0
P_HALF = 4.0         # притвор 8 м по X
P_TOP = 7.0
P_TH = 0.25
TIER_TOP = 15.5
BELL_BASE = 11.26    # низ колокола в ярусе звонницы (для рендера)


def build_church(ms):
    reset_scene()

    # Цоколь — выступающий поясок по периметру. Сплошной плитой его делать
    # нельзя: она перекрыла бы проход в дверь на уровне пола.
    for s in (-1, 1):
        box(f"Plinth.Side.{s}", (s * (CH_HALF + 0.10), CH_CY, PLINTH / 2),
            (0.20, CH_HALF * 2 + 0.4, PLINTH), ms["g"])
    box("Plinth.East", (0, CH_CY + CH_HALF + 0.10, PLINTH / 2),
        (CH_HALF * 2 + 0.4, 0.20, PLINTH), ms["g"])
    for s in (-1, 1):     # западный поясок разорван проходом
        box(f"Plinth.West.{s}", (s * 4.35, CH_CY - CH_HALF - 0.10, PLINTH / 2),
            (5.3, 0.20, PLINTH), ms["g"])

    # Стены четверика: четыре стены с проёмами. Окна только на трёх свободных
    # стенах, западная несёт проход из притвора.
    win_z0, win_z1 = 5.0, 8.4
    holes = [(CH_CY - 2.8, 1.4, win_z0, win_z1), (CH_CY + 2.8, 1.4, win_z0, win_z1)]
    for s in (-1, 1):
        wall("Wall", "y", s * CH_HALF, CH_CY - CH_HALF, CH_CY + CH_HALF,
             FLOOR_Z, WALL_TOP, TH, ms["w"], holes=holes,
             prefix=f"{'S' if s < 0 else 'N'}-")
        for u, tag in ((CH_CY - 2.8, "a"), (CH_CY + 2.8, "b")):
            window(f"{'S' if s < 0 else 'N'}Win.{tag}", "y", s * CH_HALF, u,
                   1.4, win_z0, win_z1, ms, TH)
    wall("WallE", "x", CH_CY + CH_HALF, -CH_HALF, CH_HALF, FLOOR_Z, WALL_TOP, TH,
         ms["w"], holes=[(-2.8, 1.4, win_z0, win_z1), (2.8, 1.4, win_z0, win_z1)],
         prefix="E-")
    for u, tag in ((-2.8, "a"), (2.8, "b")):
        window(f"EWin.{tag}", "x", CH_CY + CH_HALF, u, 1.4, win_z0, win_z1, ms, TH)
    wall("WallW", "x", CH_CY - CH_HALF, -CH_HALF, CH_HALF, FLOOR_Z, WALL_TOP, TH,
         ms["w"], holes=[(0.0, 1.5, FLOOR_Z, FLOOR_Z + 2.7)], prefix="W-")

    # Лопатки по углам: без них стена читается коробкой
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"Pilaster.{sx}.{sy}",
                (sx * (CH_HALF + 0.05), CH_CY + sy * (CH_HALF + 0.05),
                 (FLOOR_Z + WALL_TOP) / 2),
                (0.60, 0.60, WALL_TOP - FLOOR_Z), ms["d"])

    # Карниз и четырёхскатный переход к барабану: из него растёт барабан
    box("Cornice", (0, CH_CY, (WALL_TOP + CORN_TOP) / 2),
        (14.7, 14.7, CORN_TOP - WALL_TOP), ms["d"])
    # Шатёр-переход: четырёхгранный конус Blender строит ромбом (вершины по
    # осям), поэтому поворот на 45° ставит его углы по углам четверика.
    cone("RoofTransition", (0, CH_CY, (CORN_TOP + DRUM_BASE) / 2), 10.4,
         DRUM_BASE - CORN_TOP, ms["brick"], n=4, rot=(0, 0, math.radians(45)),
         r2=3.9)

    # Барабан: восьмигранник с восемью узкими окнами, по одному на грань
    cyl("Drum", (0, CH_CY, (DRUM_BASE + DRUM_TOP) / 2), DRUM_R,
        DRUM_TOP - DRUM_BASE, ms["w"], n=8)
    apothem = DRUM_R * math.cos(math.pi / 8)
    for k in range(8):
        ang = math.radians(22.5 + 45 * k)
        loc = (math.cos(ang) * (apothem - 0.03), CH_CY + math.sin(ang) * (apothem - 0.03),
               DRUM_BASE + (DRUM_TOP - DRUM_BASE) / 2)
        box(f"DrumWin.{k}", loc, (0.9, 0.16, 2.2), ms["glass"],
            rot=(0, 0, ang - math.pi / 2))

    # Золотая луковица: цельная труба по профилю. Профиль подобран по рендеру:
    # первый заход давал шар (11,6 м ширины при 9,5 м высоты) — луковица шире,
    # чем высокая, читается яйцом. Здесь 9,0 м ширины на 10,0 м высоты, самый
    # широкий пояс на 2,1 м от основания и длинное сужение к острию.
    low = [(DRUM_TOP, 3.5), (21.4, 4.2), (22.6, 4.5)]
    top = [(22.6, 4.5), (24.2, 4.3), (26.0, 3.5), (27.6, 2.4), (29.0, 1.3),
           (ONION_TOP, 0.35)]
    tube("Onion.Low", [(0, CH_CY, z) for z, _ in low], [r for _, r in low],
         ms["gold_d"], n=8)
    tube("Onion.Top", [(0, CH_CY, z) for z, _ in top], [r for _, r in top],
         ms["gold"], n=8)
    sphere("Ball", (0, CH_CY, (ONION_TOP + BALL_TOP) / 2), 0.3, ms["gold"],
           seg=10, ring=6)
    build_cross(ms, (0, CH_CY, BALL_TOP), 1.8, CROSS_TOP - BALL_TOP, ms, "Cross.Main")

    # Притвор: полый, с настоящим проёмом — кот заходит внутрь и садится
    py_mid = (P_Y0 + P_Y1) / 2
    wall("Porch.Front", "x", P_Y0 + P_TH / 2, -P_HALF, P_HALF, 0.0, P_TOP, P_TH,
         ms["w"], holes=[(0.0, 1.5, FLOOR_Z, FLOOR_Z + 2.7)], prefix="PF-")
    for s in (-1, 1):
        wall("Porch.Side", "y", s * (P_HALF - P_TH / 2), P_Y0 + P_TH, P_Y1,
             0.0, P_TOP, P_TH, ms["w"], holes=[(py_mid, 0.9, 3.0, 4.6)],
             prefix=f"P{'W' if s < 0 else 'E'}-")
        window(f"PorchWin.{s}", "y", s * (P_HALF - P_TH / 2), py_mid, 0.9, 3.0,
               4.6, ms, P_TH)
    box("Porch.Floor", (0, py_mid, FLOOR_Z / 2),
        (P_HALF * 2 - P_TH * 2, (P_Y1 - P_Y0) - P_TH, FLOOR_Z), ms["g"])
    # Балки вместо потолка: сплошная плита в витрине закрыла бы весь интерьер
    for k in range(4):
        box(f"Porch.Beam.{k}", (0, P_Y0 + 1.2 + k * 1.2, 6.5),
            (P_HALF * 2, 0.18, 0.22), ms["wood_c"])

    # Двери открытыми створками: кот должен входить, а закрытые створки в модели
    # читались бы наклейкой на проёме
    for s in (-1, 1):
        leaf = box(f"Door.Leaf.{s}", (s * 0.78, P_Y0 - 0.60, FLOOR_Z + 2.7 / 2),
                   (1.44 / 2, 0.08, 2.7), ms["wood_a"])
        leaf.rotation_euler = (0, 0, -s * math.radians(72))
        box(f"Door.Gold.{s}", (s * 0.80, P_Y0 - 0.56, FLOOR_Z + 1.05),
            (0.08, 0.05, 0.16), ms["gold"])
    box("Door.Arch", (0, P_Y0 - 0.02, FLOOR_Z + 2.7 + 0.16),
        (2.0, 0.22, 0.30), ms["d"])

    # Крыльцо: площадка и две ступени — вместе с площадкой три уровня по 0,15 м
    box("Porch.Platform", (0, P_Y0 - 0.72, FLOOR_Z / 2), (2.4, 1.0, FLOOR_Z),
        ms["g"])
    for i, z in enumerate((0.30, 0.15)):
        box(f"Porch.Step{i}", (0, P_Y0 - 1.22 - i * 0.35, z / 2),
            (2.4, 0.35, z), ms["g"])
    for s in (-1, 1):
        box(f"Porch.Parapet.{s}", (s * 1.15, P_Y0 - 0.72, 0.62),
            (0.12, 0.95, 0.40), ms["d"])

    # Крыша притвора: конёк по Y, скаты на север и юг
    ridge_z = 8.8
    ang = math.atan2(ridge_z - P_TOP, P_HALF + 0.2)
    slope = math.hypot(P_HALF + 0.2, ridge_z - P_TOP) + 0.2
    for s in (-1, 1):
        p = box(f"Porch.Roof.{s}", (s * 2.1, py_mid, P_TOP + (ridge_z - P_TOP) / 2),
                (slope, 6.4, 0.12), ms["brick"])
        p.rotation_euler = (0, s * ang, 0)
    box("Porch.Ridge", (0, py_mid, ridge_z - 0.02), (0.3, 6.44, 0.12), ms["brick"])

    # Ярус звонницы: четыре стены с проёмами звона по 1,8 × 2,6 м. Проёмы
    # сквозные (как в промпте) — через них виден колокол.
    box("Tier.Base", (0, py_mid, 8.2), (5.6, 5.6, 1.2), ms["w"])
    # Стена яруса вдоль X стоит на фиксированном Y и наоборот: у axis="x"
    # u — это X, v — координата Y (перепутать легко, и тогда ярус уезжает вбок)
    for k, spec in enumerate((("x", py_mid - 2.7), ("x", py_mid + 2.7),
                              ("y", -2.7), ("y", 2.7))):
        axis, v = spec
        u0, u1 = (-2.7, 2.7) if axis == "x" else (py_mid - 2.7, py_mid + 2.7)
        wall("Tier", axis, v, u0, u1, 8.8, TIER_TOP, 0.5, ms["w"],
             holes=[((u0 + u1) / 2, 1.8, 10.4, 13.0)], prefix=f"Tier{k}-")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"Tier.Corner.{sx}.{sy}", (sx * 2.45, py_mid + sy * 2.45,
                                           (8.8 + TIER_TOP) / 2),
                (0.7, 0.7, TIER_TOP - 8.8), ms["w"])
    box("Tier.Beam", (0, py_mid, 12.2), (4.6, 0.25, 0.25), ms["wood_b"])

    # Шейка, малая луковица и малый крест над ярусом
    cone("Tier.Cap", (0, py_mid, TIER_TOP + 0.25), 3.82, 0.5, ms["brick"], n=8,
         r2=1.8)
    cyl("Tier.Neck", (0, py_mid, 16.5), 1.8, 1.0, ms["w"], n=8)
    small = [(17.0, 0.9), (17.5, 1.6), (18.0, 2.3), (18.8, 2.1), (19.4, 1.6),
             (20.0, 0.9), (21.0, 0.25)]
    tube("Tier.Onion", [(0, py_mid, z) for z, _ in small], [r for _, r in small],
         ms["gold"], n=8)
    build_cross(ms, (0, py_mid, 21.0), 0.9, 2.4, ms, "Cross.Small")


def build_cross(ms, base, span, height, materials, name):
    """Восьмиконечный крест: вертикаль, малое титло, основная перекладина и
    нижняя косая. Коробками — на 5,4 м резьба не читается, а силуэт читается."""
    x, y, z0 = base
    box(f"{name}.Shaft", (x, y, z0 + height / 2), (0.24, 0.24, height),
        materials["gold"])
    box(f"{name}.Title", (x, y, z0 + height * 0.78), (span * 0.55, 0.16, 0.16),
        materials["gold"])
    box(f"{name}.Bar", (x, y, z0 + height * 0.62), (span, 0.20, 0.20),
        materials["gold"])
    bar = box(f"{name}.Slant", (x, y, z0 + height * 0.24),
              (span * 0.55, 0.16, 0.16), materials["gold_d"])
    bar.rotation_euler = (0, math.radians(20), 0)


# =========================================================================
# 2. church_interior_v1 — интерьер четверика
# =========================================================================
# Комната открыта сверху и по стенам: стены и потолок в сцене даёт сама церковь,
# а в витрине закрытая коробка показала бы только крышку. Балки оставлены.
IN_HALF = 6.2      # внутренний размер четверика 12,4 × 12,4 м
CEIL = 7.0


def build_interior(ms):
    reset_scene()
    cols, rows = 8, 10
    pw, pd = IN_HALF * 2 / cols, IN_HALF * 2 / rows
    for i in range(cols):
        for j in range(rows):
            x = -IN_HALF + pw * (i + 0.5)
            y = -IN_HALF + pd * (j + 0.5)
            box(f"FloorTile.{i}.{j}", (x, y, 0.03), (pw - 0.02, pd - 0.02, 0.06),
                ms["g"] if (i + j) % 2 else ms["d"])
    for k in range(8):
        y = -IN_HALF + 0.9 + k * (IN_HALF * 2 - 1.8) / 7
        box(f"Beam.{k}", (0, y, CEIL - 0.30), (IN_HALF * 2, 0.22, 0.28), ms["wood_b"])
    # Обвязка по краям: без неё балки читаются досками, висящими в воздухе
    for s in (-1, 1):
        box(f"Beam.Edge.{s}", (0, s * (IN_HALF - 0.12), CEIL - 0.30),
            (IN_HALF * 2, 0.26, 0.32), ms["wood_b"])

    # Солея с алтарём: приподнятая площадка на востоке, алтарь впереди
    box("Solea", (0, IN_HALF - 1.5, 0.15), (IN_HALF * 2, 3.0, 0.30), ms["g"])
    box("Solea.Step", (0, IN_HALF - 3.15, 0.075), (IN_HALF * 2, 0.35, 0.15), ms["d"])
    build_iconostasis(ms, IN_HALF - 1.2)

    # Скамьи в два ряда по обе стороны от прохода 2,4 м (канон автора): сиденье
    # 0,50 м, спинка 1,0 м, шаг 1,10 м — кот 1,80 м садится, не задевая переднюю
    for side in (-1, 1):
        for k in range(5):
            build_pew(ms, side * 3.7, -4.4 + k * 1.10,
                      f"{'S' if side < 0 else 'N'}{k}")

    # Иконы на стенах: подложка-«кусок стены» от пола вверх, иначе икона висит
    # в воздухе на обрубке (в сцене стены даёт сама церковь, но витрина смотрит
    # интерьер отдельно и он должен читаться сам)
    for side in (-1, 1):
        for k in range(3):
            y = -3.4 + k * 3.4
            box(f"WallPiece.{side}.{k}", (side * (IN_HALF + 0.06), y, 1.25),
                (0.12, 1.6, 2.50), ms["w"])
            build_icon(ms, f"WallIcon.{side}.{k}",
                       (side * (IN_HALF - 0.02), y, 1.90), (0.8, 1.1),
                       facing=("x", side), plane=0.12)


def build_icon(ms, name, loc, size, facing, plane=0.10):
    """Икона: тёмная доска, золотой оклад, светлое пятно лика."""
    w, h = size
    axis, sign = facing
    d = plane * sign
    if axis == "x":
        box(f"{name}.Board", loc, (0.06, w, h), ms["icon"])
        box(f"{name}.Oklad", (loc[0] + d * 0.5, loc[1], loc[2]),
            (0.05, w + 0.10, h + 0.10), ms["gold"])
        box(f"{name}.Face", (loc[0] + d * 0.8, loc[1], loc[2] + h * 0.06),
            (0.04, w * 0.55, h * 0.60), ms["icon_l"])
    else:
        box(f"{name}.Board", loc, (w, 0.06, h), ms["icon"])
        box(f"{name}.Oklad", (loc[0], loc[1] + d * 0.5, loc[2]),
            (w + 0.10, 0.05, h + 0.10), ms["gold"])
        box(f"{name}.Face", (loc[0], loc[1] + d * 0.8, loc[2] + h * 0.06),
            (w * 0.55, 0.04, h * 0.60), ms["icon_l"])


def build_iconostasis(ms, y):
    """Иконостас 8,0 × 4,6 м: панели, врата в центре, три ряда икон."""
    w, h, t = 8.0, 4.6, 0.25
    for s in (-1, 1):
        box(f"Iconostasis.Panel.{s}", (s * 3.35, y, h / 2),
            (w / 2 - 0.65, t, h), ms["wood_a"])
        box(f"Iconostasis.Cornice.{s}", (s * 3.35, y - 0.03, h - 0.05),
            (w / 2 - 0.65, t + 0.10, 0.16), ms["gold"])
    box("Iconostasis.Lintel", (0, y, h - 0.30), (w, t, 0.60), ms["wood_b"])
    box("Iconostasis.Sill", (0, y, 0.42), (w, t, 0.24), ms["wood_b"])
    for s in (-1, 1):
        box(f"Iconostasis.Post.{s}", (s * 0.78, y, h / 2 - 0.20),
            (0.18, t + 0.06, h - 0.40), ms["wood_b"])
        box(f"RoyalDoors.{s}", (s * 0.37, y - 0.02, 1.55),
            (0.70, t * 0.8, 2.50), ms["wood_c"])
        box(f"RoyalDoors.Gold.{s}", (s * 0.37, y - 0.06, 1.55),
            (0.55, 0.04, 2.20), ms["gold"])
    for i, x in enumerate((-2.6, 2.6)):
        build_icon(ms, f"Icon.Low.{i}", (x, y - 0.16, 1.70), (0.9, 1.6),
                   ("y", -1), plane=0.09)
        build_icon(ms, f"Icon.Mid.{i}", (x, y - 0.16, 3.20), (0.7, 1.0),
                   ("y", -1), plane=0.09)
    build_icon(ms, "Icon.Top", (0, y - 0.16, 4.10), (0.6, 0.9), ("y", -1),
               plane=0.09)


def build_pew(ms, x_center, y_center, tag):
    """Скамья: сиденье, спинка за спиной, стойки и подставка для колен."""
    length = 3.2
    box(f"Pew.{tag}.Seat", (x_center, y_center, 0.50), (length, 0.45, 0.08),
        ms["wood_c"])
    box(f"Pew.{tag}.Back", (x_center, y_center - 0.26, 0.78),
        (length, 0.07, 0.56), ms["wood_c"])
    box(f"Pew.{tag}.Rail", (x_center, y_center - 0.26, 0.50), (length, 0.09, 0.10),
        ms["wood_a"])
    for s in (-1, 1):
        box(f"Pew.{tag}.Leg.{s}", (x_center + s * (length / 2 - 0.18), y_center, 0.25),
            (0.10, 0.40, 0.50), ms["wood_b"])
    box(f"Pew.{tag}.Kneeler", (x_center, y_center + 0.55, 0.10),
        (length, 0.30, 0.20), ms["wood_a"])


# =========================================================================
# 3. church_fence_v1 — секция каменной ограды кладбища, 2,40 м
# =========================================================================
def build_fence_church(ms):
    reset_scene()
    length = 2.4
    for s in (-1, 1):
        box(f"Post.{s}", (s * (length / 2 - 0.15), 0, 0.725), (0.30, 0.30, 1.45),
            ms["g"])
        cone(f"PostCap.{s}", (s * (length / 2 - 0.15), 0, 1.51), 0.212, 0.12,
             ms["g"], n=4, rot=(0, 0, math.radians(45)), r2=0.02)
    box("Base", (0, 0, 0.06), (length, 0.26, 0.12), ms["gd"])
    box("Parapet", (0, 0, 0.56), (length, 0.22, 0.88), ms["w"])
    box("Capstone", (0, 0, 1.05), (length, 0.30, 0.10), ms["d"])


# =========================================================================
# 4. grave_cross_v1 — надгробие-крест, 1,50 м
# =========================================================================
def build_grave_cross(ms):
    reset_scene()
    box("Base", (0, 0, 0.125), (0.55, 0.40, 0.25), ms["g"])
    box("Base.Top", (0, 0, 0.28), (0.50, 0.36, 0.06), ms["d"])
    cyl("Shaft", (0, 0, 0.25 + 0.625), 0.085, 1.25, ms["g"], n=4,
        rot=(0, 0, math.radians(45)), r2=0.070)
    box("Bar", (0, 0, 1.10), (0.62, 0.14, 0.14), ms["g"])
    for s in (-1, 1):
        box(f"BarTip.{s}", (s * 0.27, 0, 1.10), (0.08, 0.10, 0.10), ms["gd"])


# =========================================================================
# 5. grave_slab_v1 — надгробие-плита
# =========================================================================
def build_grave_slab(ms):
    reset_scene()
    box("Base", (0, 0, 0.11), (1.15, 0.55, 0.22), ms["g"])
    box("Base.Top", (0, 0, 0.24), (1.10, 0.50, 0.06), ms["gd"])
    plate = box("Plate", (0, 0, 0.36), (1.15, 0.60, 0.14), ms["g"])
    plate.rotation_euler = (math.radians(12), 0, 0)
    lip = box("Plate.Lip", (0, -0.26, 0.44), (1.15, 0.12, 0.16), ms["d"])
    lip.rotation_euler = (math.radians(12), 0, 0)


# =========================================================================
# 6. grave_special_v1 — особая заброшенная могила со свечкой
# =========================================================================
def build_grave_special(ms):
    """Единственный объект пачки «с настроением»: покосившийся крест, осевшая
    плита, обломок ограды и горящая свечка. Надписей нет — за автором."""
    reset_scene()
    tilt = math.radians(14)
    pivot = (0, 0, 0.22)
    box("Mound", (0, 0.10, 0.06), (1.10, 1.60, 0.12), ms["gd"])
    box("Slab", (0, 0.15, 0.10), (0.60, 0.90, 0.08), ms["g"])
    crack = box("Slab.Crack", (0.10, 0.30, 0.145), (0.05, 0.62, 0.02), ms["gd"])
    crack.rotation_euler = (0, 0, math.radians(18))
    # Крест с наклоном 14°: части повёрнуты вокруг общего pivot, поэтому наклон
    # цельный, а не разъехавшийся по деталям. Одна лопасть надломлена — короче.
    parts = [("Shaft", (0, 0.14, 0.22 + 0.46), (0.13, 0.15, 0.92)),
             ("Bar.L", (-0.17, 0.14, 0.90), (0.20, 0.14, 0.14)),
             ("Bar.R", (0.21, 0.14, 0.90), (0.22, 0.14, 0.14)),
             ("Foot", (0, 0.18, 0.30), (0.34, 0.30, 0.18))]
    for nm, p, size in parts:
        box(f"Cross.{nm}", rot_x(tilt, p, pivot), size, ms["gd"], rot=(tilt, 0, 0))
    # Обломок ограды: два кривых столбика и провисшая прожилина. Столбики
    # приподняты на 0,04 м: наклонённый столбик иначе уходит углом ниже земли
    # и ломает конвенцию «низ на Z=0».
    for s, ang in ((-1, math.radians(10)), (1, math.radians(-10))):
        p = (s * 0.78, -0.45, 0.29)
        box(f"Ruin.Post.{s}", rot_x(ang, p, (p[0], p[1], 0)), (0.25, 0.25, 0.50),
            ms["g"], rot=(ang, 0, 0))
    rail = box("Ruin.Rail", (0, -0.45, 0.36), (1.70, 0.14, 0.14), ms["g"])
    rail.rotation_euler = (0, math.radians(8), 0)
    # Свечка на плите. Огонёк — отдельный объект: в Godot к нему привяжется
    # свет и мерцание, не трогая саму свечку.
    box("Candle", (0.16, 0.02, 0.22), (0.055, 0.055, 0.16), ms["wax"])
    box("Candle.Drip", (0.19, 0.02, 0.19), (0.03, 0.06, 0.14), ms["cream"])
    cyl("Candle.Wick", (0.16, 0.02, 0.31), 0.008, 0.03, ms["dark"], n=4)
    cone("CandleFlame", (0.16, 0.02, 0.335), 0.018, 0.05, ms["flame"], n=6)


# =========================================================================
# 7. bell_v1 — колокол, origin в точке подвеса
# =========================================================================
def bell_parts(ms, base, prefix):
    """Профиль колокола от юбки вверх. base — низ юбки; для отдельного ассета
    он на нуле, для колокола в ярусе (только рендер) — на высоте яруса."""
    x, y, z0 = base
    profile = [(0.00, 0.310), (0.12, 0.300), (0.30, 0.240), (0.46, 0.180),
               (0.58, 0.145), (0.66, 0.130)]
    tube(f"{prefix}Body", [(x, y, z0 + z) for z, _ in profile],
         [r for _, r in profile], ms["bell"], n=12)
    cyl(f"{prefix}Hem", (x, y, z0 + 0.03), 0.315, 0.06, ms["gold_d"], n=12)
    box(f"{prefix}Crown", (x, y, z0 + 0.70), (0.16, 0.16, 0.10), ms["bell"])
    for s in (-1, 1):
        box(f"{prefix}Crown.Lug.{s}", (x, y + s * 0.05, z0 + 0.78),
            (0.10, 0.05, 0.14), ms["bell"])
    cyl(f"{prefix}Crown.Axis", (x, y, z0 + 0.84), 0.022, 0.22, ms["dark"], n=6,
        rot=(math.pi / 2, 0, 0))
    cyl(f"{prefix}Clapper", (x, y, z0 + 0.34), 0.035, 0.34, ms["dark"], n=6)
    ico(f"{prefix}Clapper.Ball", (x, y, z0 + 0.16), 0.055, ms["dark"], sub=1)


def build_bell(ms):
    """Единственный объект пачки, у которого origin не на низу: колокол висит,
    и в сцене его удобнее вешать, а не ставить."""
    reset_scene()
    bell_parts(ms, (0, 0, 0), "")
    move_all(-0.84)     # origin в ось подвеса: низ уходит под Z=0, это норма


# =========================================================================
ASSETS = [
    {"name": "church_v1", "build": build_church, "cat": (1.3, -12.0),
     "bell": BELL_BASE,
     "shots": [dict(tag="34"), dict(tag="34l"), dict(tag="front"), dict(tag="far"),
               dict(tag="front", label="door", aim=(0, -10.6, 1.4), dist=7.0)]},
    {"name": "church_interior_v1", "build": build_interior, "cat": (0.6, -3.6),
     "bell": None,
     "shots": [dict(tag="34"), dict(tag="front"), dict(tag="34l", scale=0.9),
               dict(tag="front", label="inside", aim=(0, -1.0, 2.0), dist=11.0)]},
    {"name": "church_fence_v1", "build": build_fence_church, "cat": (0.9, -1.1),
     "bell": None, "shots": views("34", "front")},
    {"name": "grave_cross_v1", "build": build_grave_cross, "cat": (0.7, -0.6),
     "bell": None, "shots": views("34", "front")},
    {"name": "grave_slab_v1", "build": build_grave_slab, "cat": (0.9, -0.6),
     "bell": None, "shots": views("34", "front")},
    {"name": "grave_special_v1", "build": build_grave_special, "cat": (1.0, -0.9),
     "bell": None, "shots": views("34", "front")},
    {"name": "bell_v1", "build": build_bell, "cat": None, "bell": None,
     "shots": views("34", "front")},
]


def main():
    ms = M()
    setup_render()
    proj = os.path.dirname(os.path.dirname(OUT))
    evid = os.path.join(proj, "evidence", EVID)
    os.makedirs(os.path.join(OUT, "sources"), exist_ok=True)
    for spec in ASSETS:
        name = spec["name"]
        if ONLY and name != ONLY:
            continue
        spec["build"](ms)
        lo, hi = bbox()
        tris = tri_count()
        radius = max(hi[i] - lo[i] for i in range(3)) / 2
        glb = os.path.join(OUT, name + ".glb")
        export_glb(glb)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "sources", name + ".blend"))
        build_rig(radius)
        if spec["cat"]:
            cat_reference(ms, spec["cat"])
        if spec["bell"]:
            # колокол в ярусе — только для рендера (имя Preview: в .glb не идёт)
            bell_parts(ms, (0, -7.0, spec["bell"]), "PreviewBell.")
        render_views(name, spec["shots"], dirpath=evid)
        teardown_rig()
        print(f"ASSET_OK {name} tris={tris} "
              f"whd=({hi[0]-lo[0]:.3f},{hi[1]-lo[1]:.3f},{hi[2]-lo[2]:.3f}) "
              f"zmin={lo[2]:.4f} zmax={hi[2]:.4f} glb={os.path.getsize(glb)}")


main()
print("CHURCH_PACK_BUILD_OK")
