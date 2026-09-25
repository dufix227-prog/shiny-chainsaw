# Собственная модель кота-кандидата: stylized антро-кот по палитре текущего
# кодового кота (cat.gd). Запуск: blender -b --python build_cat.py -- <out.glb>
import bpy
import sys

FUR = (0.847, 0.569, 0.231, 1.0)      # d8913b
CREAM = (0.961, 0.863, 0.655, 1.0)    # f5dca7
STRIPE = (0.569, 0.318, 0.161, 1.0)   # 915129
COAT = (0.255, 0.408, 0.471, 1.0)     # 416878
LEATHER = (0.439, 0.329, 0.231, 1.0)  # 70543b
PINK = (0.851, 0.627, 0.549, 1.0)     # d9a08c
DARK = (0.188, 0.165, 0.149, 1.0)     # 302a26
WHITE = (0.95, 0.95, 0.95, 1.0)

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def material(name, color, roughness=0.75):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

def sphere(name, location, radius, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=24, ring_count=16)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj

def capsule(name, location, radius, depth, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, vertices=24)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    for z in (depth / 2, -depth / 2):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=(location[0], location[1], location[2] + z), segments=24, ring_count=16)
        cap = bpy.context.active_object
        cap.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        cap.parent = obj
    return obj

def cone(name, location, radius, depth, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=radius, depth=depth, location=location, vertices=24)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj

def box(name, location, size, mat):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(mat)
    return obj

def main():
    clear_scene()
    m_fur = material("Fur", FUR)
    m_cream = material("Cream", CREAM)
    m_stripe = material("Stripe", STRIPE)
    m_coat = material("Coat", COAT)
    m_leather = material("Leather", LEATHER)
    m_pink = material("Pink", PINK)
    m_dark = material("Dark", DARK)
    m_white = material("White", WHITE)

    # Ноги в сапогах (антро-кот стоит на двух лапах)
    for side in (-1, 1):
        x = side * 0.16
        capsule(f"Leg.{side}", (x, 0, 0.36), 0.075, 0.5, m_fur)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=0.12, location=(x, 0.01, 0.06), vertices=24)
        boot = bpy.context.active_object
        boot.name = f"Boot.{side}"
        boot.data.materials.append(m_leather)
        bpy.ops.object.shade_smooth()

    # Куртка и торс
    capsule("Torso", (0, 0, 0.92), 0.19, 0.55, m_coat)
    sphere("Belly", (0, 0.05, 0.78), 0.16, m_cream, scale=(1, 0.7, 1))

    # Руки в рукавах, лапы — мех
    for side in (-1, 1):
        x = side * 0.28
        arm = capsule(f"Arm.{side}", (x, 0, 1.12), 0.065, 0.42, m_coat)
        arm.rotation_euler = (0, 0, side * 0.08)
        sphere(f"Paw.{side}", (x + side * 0.02, 0.0, 0.85), 0.08, m_fur)

    # Палка в правой лапе
    bpy.ops.mesh.primitive_cylinder_add(radius=0.028, depth=0.95, location=(0.34, 0.06, 1.0), vertices=16)
    stick = bpy.context.active_object
    stick.name = "Stick"
    stick.rotation_euler = (0.12, 0, 0)
    stick.data.materials.append(m_leather)

    # Рюкзак с ремнями
    box("Backpack", (0, -0.23, 1.02), (0.34, 0.16, 0.44), m_leather)
    for side in (-1, 1):
        box(f"Strap.{side}", (side * 0.11, 0.14, 1.08), (0.05, 0.02, 0.3), m_cream)

    # Голова с мордой
    sphere("Head", (0, 0, 1.44), 0.23, m_fur, scale=(1, 0.92, 0.95))
    sphere("Muzzle", (0, 0.16, 1.38), 0.11, m_cream, scale=(1.15, 0.8, 0.7))
    sphere("Nose", (0, 0.2, 1.43), 0.032, m_dark)
    for side in (-1, 1):
        # Милые треугольные ушки: внешняя охра + розовая внутренняя
        cone(f"Ear.{side}", (side * 0.15, 0, 1.72), 0.085, 0.24, m_fur)
        cone(f"EarInner.{side}", (side * 0.15, 0.02, 1.7), 0.05, 0.14, m_pink)
        # Глаза: белок + зрачок, взгляд вперёд
        sphere(f"EyeWhite.{side}", (side * 0.1, 0.17, 1.5), 0.055, m_white)
        sphere(f"EyePupil.{side}", (side * 0.1, 0.215, 1.5), 0.028, m_dark)
        # Полоски на щеках
        box(f"CheekStripe.{side}", (side * 0.2, 0.1, 1.36), (0.015, 0.06, 0.09), m_stripe)

    # Хвост с тёмными полосами (цепочка сфер, сужение)
    tail_points = [(0.0, -0.3, 0.86), (0.02, -0.46, 0.98), (0.0, -0.5, 1.16), (0.03, -0.4, 1.3)]
    for i, (x, y, z) in enumerate(tail_points):
        r = 0.075 - i * 0.013
        sphere(f"Tail.{i}", (x, y, z), r, m_stripe if i % 2 else m_fur)

    # Экспортируем только кота
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=sys.argv[-1], export_format="GLB", export_yup=True)

main()
print("CAT_BUILD_OK")
