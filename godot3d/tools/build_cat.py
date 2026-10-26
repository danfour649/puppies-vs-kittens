"""Original domestic-cat mesh for Willie and Aggie.

Built in Blender 4.2 from measured cross-sections (no downloaded model).
Run:
  blender -b -P godot3d/tools/build_cat.py -- --out godot3d/cat_kit/meshes
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

N_RING = 16
GINGER = (0.9098, 0.6863, 0.3294)
GINGER_DARK = (0.682, 0.515, 0.237)
WHITE = (1.0, 1.0, 1.0)
NOSE = (0.851, 0.549, 0.478)
PAD = (0.72, 0.40, 0.42)
AGGIE_BASE = (0.16, 0.10, 0.07)
AGGIE_ORANGE = (0.690, 0.431, 0.173)
AGGIE_CREAM = (0.749, 0.659, 0.478)
INNER_EAR = (0.89, 0.65, 0.56)


def out_dir() -> str:
    args = sys.argv
    if "--" in args:
        args = args[args.index("--") + 1 :]
    for i, a in enumerate(args):
        if a == "--out" and i + 1 < len(args):
            return args[i + 1]
    return os.path.join(os.path.dirname(__file__), "..", "cat_kit", "meshes")


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def new_mesh(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate(verbose=False)
    me.update()
    obj = bpy.data.objects.new(name, me)
    return link(obj)


def _frame(tangent: Vector):
    t = tangent.normalized()
    up = Vector((0.0, 0.0, 1.0))
    if abs(t.dot(up)) > 0.92:
        up = Vector((0.0, 1.0, 0.0))
    x = up.cross(t).normalized()
    z = t.cross(x).normalized()
    return x, z


def tube(name, stations, n=N_RING, cap=True):
    """stations: (Vector center, rx, rz). Path order is the tube axis."""
    frames = []
    for i, (c, rx, rz) in enumerate(stations):
        if i < len(stations) - 1:
            t = stations[i + 1][0] - c
        else:
            t = c - stations[i - 1][0]
        if t.length < 1e-6:
            t = Vector((0.0, 1.0, 0.0))
        frames.append(_frame(t))
    verts = []
    for (c, rx, rz), (xaxis, zaxis) in zip(stations, frames):
        for i in range(n):
            a = 2.0 * math.pi * i / n
            # Slightly squared so the chest and paws don't read as sausages.
            ca = math.copysign(abs(math.cos(a)) ** 0.85, math.cos(a))
            sa = math.copysign(abs(math.sin(a)) ** 0.85, math.sin(a))
            p = c + xaxis * (ca * rx) + zaxis * (sa * rz)
            verts.append(p)
    faces = []
    rings = len(stations)
    for r in range(rings - 1):
        for i in range(n):
            j = (i + 1) % n
            a = r * n + i
            b = r * n + j
            c = (r + 1) * n + j
            d = (r + 1) * n + i
            faces.append((a, b, c, d))
    if cap:
        faces.append(tuple(range(n - 1, -1, -1)))
        base = (rings - 1) * n
        faces.append(tuple(range(base, base + n)))
    return new_mesh(name, verts, faces)


def body_stations():
    # Blender: Z up, -Y is the nose (glTF/Godot forward).
    # (y, center_z, rx, rz) — a shoulder, a waist, a haunch, a muzzle.
    spec = [
        (-0.62, 0.50, 0.028, 0.024),
        (-0.55, 0.49, 0.055, 0.042),
        (-0.48, 0.51, 0.088, 0.062),
        (-0.40, 0.56, 0.112, 0.096),
        (-0.33, 0.58, 0.108, 0.100),
        (-0.26, 0.54, 0.078, 0.080),
        (-0.18, 0.48, 0.070, 0.078),
        (-0.10, 0.40, 0.118, 0.132),
        (-0.02, 0.42, 0.132, 0.128),
        (0.08, 0.43, 0.108, 0.110),
        (0.16, 0.44, 0.096, 0.100),
        (0.26, 0.46, 0.128, 0.118),
        (0.36, 0.47, 0.148, 0.128),
        (0.46, 0.43, 0.092, 0.082),
    ]
    out = []
    for y, z, rx, rz in spec:
        out.append((Vector((0.0, y, z)), rx, rz))
    return out


def leg_stations(side, kind):
    s = 1.0 if side == "L" else -1.0
    if kind == "front":
        pts = [
            (s * 0.09, -0.06, 0.40, 0.050, 0.046),
            (s * 0.10, -0.08, 0.30, 0.040, 0.036),
            (s * 0.105, -0.09, 0.18, 0.030, 0.028),
            (s * 0.108, -0.10, 0.09, 0.026, 0.024),
            (s * 0.11, -0.11, 0.045, 0.038, 0.028),
        ]
    else:
        pts = [
            (s * 0.10, 0.30, 0.42, 0.062, 0.055),
            (s * 0.115, 0.22, 0.30, 0.042, 0.038),
            (s * 0.10, 0.30, 0.16, 0.030, 0.028),
            (s * 0.095, 0.24, 0.07, 0.026, 0.024),
            (s * 0.09, 0.20, 0.042, 0.040, 0.030),
        ]
    return [(Vector((x, y, z)), rx, rz) for x, y, z, rx, rz in pts]


def tail_stations():
    pts = []
    for i in range(10):
        t = i / 9.0
        y = 0.48 + t * 0.42
        z = 0.42 + math.sin(t * 1.1) * 0.16 + t * 0.08
        r = 0.046 * (1.0 - t * 0.72)
        pts.append((Vector((0.0, y, z)), r, r * 0.92))
    return pts


def ear_stations(side):
    s = 1.0 if side == "L" else -1.0
    pts = [
        (s * 0.055, -0.36, 0.64, 0.038, 0.020),
        (s * 0.062, -0.37, 0.70, 0.030, 0.014),
        (s * 0.066, -0.375, 0.76, 0.016, 0.008),
    ]
    return [(Vector((x, y, z)), rx, rz) for x, y, z, rx, rz in pts]


def toe_blob(name, co, r):
    # A short tube so the remesh keeps a toe instead of a sphere.
    c = Vector(co)
    stations = [
        (c + Vector((0, 0.01, 0.01)), r, r * 0.7),
        (c, r * 1.15, r * 0.85),
        (c + Vector((0, -0.02, -0.005)), r * 0.7, r * 0.5),
    ]
    return tube(name, stations, n=8, cap=True)


def build_parts():
    parts = [tube("body", body_stations(), cap=True)]
    for side in ("L", "R"):
        parts.append(tube(f"leg_f_{side}", leg_stations(side, "front"), n=12, cap=True))
        parts.append(tube(f"leg_h_{side}", leg_stations(side, "hind"), n=12, cap=True))
        parts.append(tube(f"ear_{side}", ear_stations(side), n=8, cap=True))
        s = 1.0 if side == "L" else -1.0
        for i, dx in enumerate((-0.018, -0.006, 0.008, 0.018)):
            parts.append(toe_blob(f"toe_f_{side}_{i}", (s * 0.11 + dx, -0.145, 0.028), 0.012))
            parts.append(toe_blob(f"toe_h_{side}_{i}", (s * 0.09 + dx, 0.165, 0.026), 0.012))
    parts.append(tube("tail", tail_stations(), n=10, cap=True))
    return parts


def join_objects(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def apply_modifier(obj, mod_name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod_name)


def fuse(obj):
    mod = obj.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = 0.0065
    mod.adaptivity = 0.0
    apply_modifier(obj, "remesh")
    sm = obj.modifiers.new("smooth", "SMOOTH")
    sm.iterations = 8
    sm.factor = 0.45
    apply_modifier(obj, "smooth")
    # Quadriflow gives the cage a usable quad layout for skinning.
    print("voxel verts", len(obj.data.vertices), "faces", len(obj.data.polygons))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        try:
            bpy.ops.object.quadriflow_remesh(target_faces=7000, use_mesh_symmetry=True)
        except Exception as exc:
            print("symmetric quadriflow skipped", exc)
            bpy.ops.object.quadriflow_remesh(target_faces=7000, use_mesh_symmetry=False)
        print("quadriflow verts", len(obj.data.vertices))
    except Exception as exc:
        print("quadriflow skipped:", exc)
        dec = obj.modifiers.new("dec", "DECIMATE")
        dec.ratio = 0.25
        apply_modifier(obj, "dec")
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.update()


def shape_details(obj):
    """Pinch the muzzle, tuck the waist, lift the shoulder line."""
    me = obj.data
    for v in me.vertices:
        x, y, z = v.co
        # Muzzle: the nose is the -Y end. Narrow it and drop it a touch.
        if y < -0.42:
            k = (-0.42 - y) / 0.22
            k = max(0.0, min(1.0, k))
            v.co.x *= 1.0 - 0.28 * k
            v.co.z -= 0.035 * k
        # Pull the ear tips up into points.
        if z > 0.68 and y < -0.28:
            v.co.z += 0.045
            v.co.x *= 0.72
            v.co.y -= 0.01
        # Waist tuck just behind the ribs.
        if 0.08 < y < 0.20 and z > 0.36:
            v.co.x *= 0.92
        # Shoulder blades: a ridge on the upper sides of the chest.
        if -0.08 < y < 0.06 and z > 0.48 and abs(x) > 0.04:
            v.co.z += 0.012
            v.co.x += math.copysign(0.01, x)
        # Haunch muscle.
        if 0.28 < y < 0.42 and z > 0.42 and abs(x) > 0.05:
            v.co.x += math.copysign(0.012, x)
    me.update()


def smart_uv(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def _bary(p, a, b, c):
    v0 = b - a
    v1 = c - a
    v2 = p - a
    den = v0.x * v1.y - v1.x * v0.y
    if abs(den) < 1e-12:
        return None
    u = (v2.x * v1.y - v1.x * v2.y) / den
    v = (v0.x * v2.y - v2.x * v0.y) / den
    w = 1.0 - u - v
    if u < -0.02 or v < -0.02 or w < -0.02:
        return None
    return w, u, v


def raster_textures(obj, size, willie_path, aggie_path, normal_path, rough_path):
    me = obj.data
    uv_layer = me.uv_layers.active.data
    pixels_w = [(0.0, 0.0, 0.0)] * (size * size)
    pixels_a = [(0.0, 0.0, 0.0)] * (size * size)
    pixels_n = [(0.5, 0.5, 1.0)] * (size * size)
    pixels_r = [0.82] * (size * size)
    covered = [False] * (size * size)

    def paint_tri(i0, i1, i2):
        uv0 = uv_layer[i0].uv
        uv1 = uv_layer[i1].uv
        uv2 = uv_layer[i2].uv
        p0 = Vector((uv0.x * (size - 1), uv0.y * (size - 1)))
        p1 = Vector((uv1.x * (size - 1), uv1.y * (size - 1)))
        p2 = Vector((uv2.x * (size - 1), uv2.y * (size - 1)))
        minx = max(0, int(min(p0.x, p1.x, p2.x)) - 1)
        maxx = min(size - 1, int(max(p0.x, p1.x, p2.x)) + 1)
        miny = max(0, int(min(p0.y, p1.y, p2.y)) - 1)
        maxy = min(size - 1, int(max(p0.y, p1.y, p2.y)) + 1)
        c0 = me.vertices[me.loops[i0].vertex_index].co
        c1 = me.vertices[me.loops[i1].vertex_index].co
        c2 = me.vertices[me.loops[i2].vertex_index].co
        n = (c1 - c0).cross(c2 - c0)
        if n.length < 1e-10:
            return
        n.normalize()
        # Tangent from the UV so the normal map is tangent-space.
        duv1 = Vector((uv1.x - uv0.x, uv1.y - uv0.y))
        duv2 = Vector((uv2.x - uv0.x, uv2.y - uv0.y))
        den = duv1.x * duv2.y - duv2.x * duv1.y
        if abs(den) < 1e-8:
            tangent = Vector((1.0, 0.0, 0.0))
            bitangent = Vector((0.0, 0.0, 1.0))
        else:
            r = 1.0 / den
            tangent = ((c1 - c0) * duv2.y - (c2 - c0) * duv1.y) * r
            bitangent = ((c2 - c0) * duv1.x - (c1 - c0) * duv2.x) * r
            if tangent.length > 1e-8:
                tangent.normalize()
            if bitangent.length > 1e-8:
                bitangent.normalize()
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                bc = _bary(Vector((x + 0.5, y + 0.5)), p0, p1, p2)
                if bc is None:
                    continue
                w0, w1, w2 = bc
                co = c0 * w0 + c1 * w1 + c2 * w0 * 0.0 + c2 * w2
                idx = y * size + x
                covered[idx] = True
                pixels_w[idx] = willie_color(co, n)
                pixels_a[idx] = aggie_color(co, n)
                pixels_n[idx] = fur_normal(n, tangent, bitangent, co)
                pixels_r[idx] = roughness_at(co, n)

    for poly in me.polygons:
        ids = list(poly.loop_indices)
        if len(ids) < 3:
            continue
        for k in range(1, len(ids) - 1):
            paint_tri(ids[0], ids[k], ids[k + 1])

    def save_rgb(path, pix, alpha=False):
        img = bpy.data.images.new(os.path.basename(path), size, size, alpha=alpha)
        buf = []
        for r, g, b in pix:
            buf.extend((r, g, b, 1.0))
        img.pixels.foreach_set(buf) if hasattr(img.pixels, "foreach_set") else img.pixels.foreach_set(buf)
        # foreach_set needs a flat buffer the size of pixels
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        print("wrote", path, "covered", sum(covered))

    # bpy image pixels assignment via foreach_set wants a sequence of floats.
    def save(path, flat):
        img = bpy.data.images.new(os.path.basename(path), size, size, alpha=True)
        img.pixels.foreach_set(flat)
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()

    flat_w, flat_a, flat_n, flat_r = [], [], [], []
    for i in range(size * size):
        r, g, b = pixels_w[i]
        flat_w.extend((r, g, b, 1.0))
        r, g, b = pixels_a[i]
        flat_a.extend((r, g, b, 1.0))
        r, g, b = pixels_n[i]
        flat_n.extend((r, g, b, 1.0))
        rough = pixels_r[i]
        flat_r.extend((rough, rough, rough, 1.0))
    save(willie_path, flat_w)
    save(aggie_path, flat_a)
    save(normal_path, flat_n)
    save(rough_path, flat_r)
    print("textures covered", sum(1 for c in covered if c), "of", size * size)


def willie_color(co, n):
    x, y, z = co
    # Belly, chest, muzzle blaze, and paws stay white. The saddle is ginger.
    saddle = y > -0.34 and y < 0.46 and z > 0.46 and n.z > -0.15
    cap = y < -0.28 and y > -0.46 and z > 0.58
    cheek = y < -0.30 and y > -0.50 and abs(x) > 0.04 and z > 0.50 and z < 0.62
    tail = y > 0.46
    tail_under = tail and n.z < 0.15
    stripe = False
    if saddle:
        band = math.sin((y + 0.05) * 28.0) 
        stripe = band > 0.55 and z > 0.50
    if y < -0.56:
        return NOSE
    if z < 0.055 and y < 0.25 and abs(x) < 0.16 and y > -0.16:
        return PAD
    if tail_under:
        return GINGER
    if tail:
        return WHITE
    if stripe:
        return GINGER_DARK
    if saddle or cap or cheek:
        return GINGER
    # Inner ear: high, thin, facing somewhat forward.
    if z > 0.66 and y < -0.30 and n.y < -0.2:
        return INNER_EAR
    return WHITE


def aggie_color(co, n):
    x, y, z = co
    if y < -0.56:
        return (0.55, 0.32, 0.30)
    if z < 0.055 and abs(x) < 0.16 and -0.16 < y < 0.25:
        return PAD
    # Deterministic patches. Same function every run.
    h = math.sin(x * 17.0 + y * 9.0) + math.sin(z * 13.0 - y * 6.0) + math.sin(x * 4.0 - z * 8.0)
    if z > 0.66 and y < -0.30 and n.y < -0.2:
        return INNER_EAR
    if h > 0.85:
        return AGGIE_ORANGE
    if h > 0.25:
        return AGGIE_CREAM
    return AGGIE_BASE


def fur_normal(n, tangent, bitangent, co):
    # Lie the coat slightly up and back, then store it in tangent space.
    fur = (n + Vector((0.0, 0.25, 0.55))).normalized()
    ts = Vector((fur.dot(tangent), fur.dot(bitangent), fur.dot(n)))
    if ts.length < 1e-6:
        ts = Vector((0.0, 0.0, 1.0))
    else:
        ts.normalize()
    return (ts.x * 0.5 + 0.5, ts.y * 0.5 + 0.5, max(0.0, ts.z) * 0.5 + 0.5)


def roughness_at(co, n):
    x, y, z = co
    if y < -0.55:
        return 0.38
    if z < 0.05 and abs(x) < 0.16:
        return 0.42
    if z > 0.66 and y < -0.30:
        return 0.55
    return 0.78


def add_bone(edit, name, head, tail, parent=None, connect=False):
    b = edit.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent is not None:
        b.parent = parent
        b.use_connect = connect
    return b


def build_armature():
    arm_data = bpy.data.armatures.new("CatArmature")
    arm = bpy.data.objects.new("CatArmature", arm_data)
    link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    root = add_bone(eb, "root", (0, 0.05, 0.36), (0, 0.12, 0.36))
    sp1 = add_bone(eb, "spine1", (0, 0.36, 0.44), (0, 0.22, 0.44), root)
    sp2 = add_bone(eb, "spine2", (0, 0.22, 0.43), (0, 0.05, 0.42), sp1, True)
    sp3 = add_bone(eb, "spine3", (0, 0.05, 0.42), (0, -0.12, 0.42), sp2, True)
    neck = add_bone(eb, "neck", (0, -0.12, 0.46), (0, -0.24, 0.54), sp3)
    head = add_bone(eb, "head", (0, -0.24, 0.54), (0, -0.46, 0.58), neck, True)
    add_bone(eb, "jaw", (0, -0.40, 0.50), (0, -0.56, 0.48), head)
    add_bone(eb, "ear.L", (-0.05, -0.36, 0.64), (-0.065, -0.38, 0.76), head)
    add_bone(eb, "ear.R", (0.05, -0.36, 0.64), (0.065, -0.38, 0.76), head)
    for side, s in (("L", -1.0), ("R", 1.0)):
        sho = add_bone(eb, f"shoulder.{side}", (s * 0.06, -0.04, 0.42), (s * 0.10, -0.06, 0.38), sp3)
        up = add_bone(eb, f"upper_arm.{side}", (s * 0.10, -0.06, 0.38), (s * 0.105, -0.09, 0.20), sho, True)
        fr = add_bone(eb, f"forearm.{side}", (s * 0.105, -0.09, 0.20), (s * 0.11, -0.11, 0.06), up, True)
        add_bone(eb, f"paw_f.{side}", (s * 0.11, -0.11, 0.06), (s * 0.11, -0.15, 0.02), fr, True)
        th = add_bone(eb, f"thigh.{side}", (s * 0.08, 0.32, 0.42), (s * 0.11, 0.24, 0.26), sp1)
        sh = add_bone(eb, f"shin.{side}", (s * 0.11, 0.24, 0.26), (s * 0.10, 0.30, 0.12), th, True)
        hk = add_bone(eb, f"hock.{side}", (s * 0.10, 0.30, 0.12), (s * 0.09, 0.22, 0.05), sh, True)
        add_bone(eb, f"paw_h.{side}", (s * 0.09, 0.22, 0.05), (s * 0.09, 0.16, 0.02), hk, True)
    parent = sp1
    prev = (0.0, 0.46, 0.42)
    for i in range(9):
        t = (i + 1) / 9.0
        nxt = (0.0, 0.48 + t * 0.40, 0.42 + math.sin(t * 1.1) * 0.16 + t * 0.06)
        bone = add_bone(eb, f"tail{i:02d}", prev, nxt, parent, i > 0)
        parent = bone
        prev = nxt
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(mesh, arm):
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        print("auto weights ok", len(mesh.vertex_groups))
    except Exception as exc:
        print("auto weights failed", exc)
        distance_weights(mesh, arm)


def distance_weights(mesh, arm):
    if mesh.parent != arm:
        mesh.parent = arm
        mesh.parent_type = "ARMATURE"
        mesh.modifiers.new("Armature", "ARMATURE").object = arm
    bones = [b for b in arm.data.bones]
    for b in bones:
        mesh.vertex_groups.new(name=b.name)
    for v in mesh.data.vertices:
        weights = []
        for b in bones:
            # Distance to the bone segment.
            head = arm.matrix_world @ b.head_local
            tail = arm.matrix_world @ b.tail_local
            co = mesh.matrix_world @ v.co
            ab = tail - head
            t = 0.0 if ab.length < 1e-6 else max(0.0, min(1.0, (co - head).dot(ab) / ab.length_squared))
            d = (co - (head + ab * t)).length
            weights.append((b.name, d))
        weights.sort(key=lambda it: it[1])
        chosen = weights[:3]
        inv = []
        for name, d in chosen:
            inv.append((name, 1.0 / max(0.004, d) ** 2))
        s = sum(w for _, w in inv) or 1.0
        for name, w in inv:
            mesh.vertex_groups[name].add([v.index], w / s, "REPLACE")
    print("distance weights", len(mesh.vertex_groups))


def action_for(arm, name, keys):
    """keys: list of (frame, {bone: (rx, ry, rz) degrees})."""
    if name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[name])
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    # Clear to rest at every authored frame first.
    frames = sorted({f for f, _ in keys})
    bones = list(arm.pose.bones)
    for pb in bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    for frame, pose in keys:
        bpy.context.scene.frame_set(frame)
        for pb in bones:
            if pb.name in pose:
                rx, ry, rz = pose[pb.name]
                pb.rotation_euler = (
                    math.radians(rx),
                    math.radians(ry),
                    math.radians(rz),
                )
            pb.keyframe_insert("rotation_euler", frame=frame)
    act.frame_range = (frames[0], frames[-1])
    bpy.ops.object.mode_set(mode="OBJECT")
    return act


def deg_leg(swing_f, swing_h, lift=0.0):
    """A simple digitigrade pose. swing > 0 reaches forward (-Y)."""
    return {
        "upper_arm.L": (swing_f, 0, lift),
        "upper_arm.R": (swing_f, 0, -lift),
        "forearm.L": (max(0.0, -swing_f) * 0.8, 0, 0),
        "forearm.R": (max(0.0, -swing_f) * 0.8, 0, 0),
        "thigh.L": (swing_h, 0, lift * 0.3),
        "thigh.R": (swing_h, 0, -lift * 0.3),
        "shin.L": (max(0.0, swing_h) * 0.7, 0, 0),
        "shin.R": (max(0.0, swing_h) * 0.7, 0, 0),
        "spine2": (swing_f * 0.05, 0, lift * 0.15),
    }


def build_actions(arm):
    idle = []
    for f, ph in ((1, 0.0), (16, 1.0), (32, 0.0)):
        idle.append((f, {
            "spine2": (2.0 * math.sin(ph * math.pi), 0, 0),
            "spine3": (1.2 * math.sin(ph * math.pi), 0, 0),
            "head": (4.0 * math.sin(ph * math.pi * 0.5), 8.0 * math.sin(ph * math.pi), 0),
            "tail00": (8, 6 * math.sin(ph * math.pi), 0),
            "tail04": (10, 10 * math.sin(ph * math.pi), 0),
            "jaw": (0, 0, 0),
        }))
    action_for(arm, "idle", idle)

    def gait(name, frames, amp_f, amp_h, bob):
        keys = []
        for i, f in enumerate(frames):
            phase = i / max(1, len(frames) - 1)
            s = math.sin(phase * 2.0 * math.pi)
            c = math.cos(phase * 2.0 * math.pi)
            pose = {
                "upper_arm.L": (amp_f * s, 0, 0),
                "upper_arm.R": (-amp_f * s, 0, 0),
                "forearm.L": (max(0.0, -amp_f * s) * 0.85, 0, 0),
                "forearm.R": (max(0.0, amp_f * s) * 0.85, 0, 0),
                "thigh.L": (-amp_h * s, 0, 0),
                "thigh.R": (amp_h * s, 0, 0),
                "shin.L": (max(0.0, -amp_h * s) * 0.6, 0, 0),
                "shin.R": (max(0.0, amp_h * s) * 0.6, 0, 0),
                "spine2": (bob * c, 0, 3 * s),
                "spine3": (bob * 0.5 * c, 0, 0),
                "head": (-bob * c, 0, -1.5 * s),
                "tail00": (6, 14 * s, 0),
                "tail03": (8, 18 * s, 0),
                "tail06": (6, 12 * s, 0),
            }
            keys.append((f, pose))
        # Close the loop on the first pose.
        keys.append((frames[-1] + (frames[1] - frames[0]), keys[0][1]))
        action_for(arm, name, keys)

    gait("walk", [1, 7, 13, 19], 28, 24, 3)
    gait("trot", [1, 5, 9, 13], 36, 32, 4)
    # Bound: fronts together, hinds together.
    sprint = []
    for i, f in enumerate((1, 4, 7, 10)):
        phase = i / 3.0
        s = math.sin(phase * 2.0 * math.pi)
        pose = {
            "upper_arm.L": (34 * s, 0, 4),
            "upper_arm.R": (34 * s, 0, -4),
            "forearm.L": (max(0, -30 * s), 0, 0),
            "forearm.R": (max(0, -30 * s), 0, 0),
            "thigh.L": (-32 * s, 0, 3),
            "thigh.R": (-32 * s, 0, -3),
            "shin.L": (max(0, -28 * s), 0, 0),
            "shin.R": (max(0, -28 * s), 0, 0),
            "spine1": (-8 * s, 0, 0),
            "spine2": (10 * s, 0, 0),
            "head": (-6 * s, 0, 0),
            "tail00": (-20, 0, 0),
            "tail04": (-10, 8 * s, 0),
        }
        sprint.append((f, pose))
    sprint.append((13, sprint[0][1]))
    action_for(arm, "sprint", sprint)

    stalk = []
    for i, f in enumerate((1, 9, 17, 25)):
        s = math.sin(i / 3.0 * 2.0 * math.pi)
        stalk.append((f, {
            "spine1": (14, 0, 0),
            "spine2": (18, 0, 0),
            "spine3": (10, 0, 0),
            "head": (-6, 0, 0),
            "upper_arm.L": (16 * s, 0, 6),
            "upper_arm.R": (-16 * s, 0, -6),
            "thigh.L": (-14 * s, 0, 4),
            "thigh.R": (14 * s, 0, -4),
            "tail00": (22, 4 * s, 0),
            "tail04": (16, 6 * s, 0),
            "ear.L": (-18, 0, -8),
            "ear.R": (-18, 0, 8),
        }))
    stalk.append((33, stalk[0][1]))
    action_for(arm, "stalk", stalk)

    action_for(arm, "pounce", [
        (1, {"spine2": (8, 0, 0), "upper_arm.L": (20, 0, 0), "upper_arm.R": (20, 0, 0), "thigh.L": (-10, 0, 0), "thigh.R": (-10, 0, 0)}),
        (6, {"spine1": (-12, 0, 0), "spine2": (-16, 0, 0), "head": (8, 0, 0),
             "upper_arm.L": (-40, 0, 8), "upper_arm.R": (-40, 0, -8),
             "thigh.L": (30, 0, 0), "thigh.R": (30, 0, 0),
             "tail00": (-30, 0, 0), "tail04": (-20, 0, 0)}),
        (12, {"spine2": (-6, 0, 0), "upper_arm.L": (-10, 0, 0), "upper_arm.R": (-10, 0, 0)}),
    ])
    action_for(arm, "land", [
        (1, {"spine2": (-4, 0, 0)}),
        (5, {"spine1": (16, 0, 0), "spine2": (18, 0, 0), "spine3": (8, 0, 0),
             "upper_arm.L": (24, 0, 6), "upper_arm.R": (24, 0, -6),
             "forearm.L": (20, 0, 0), "forearm.R": (20, 0, 0),
             "thigh.L": (18, 0, 0), "thigh.R": (18, 0, 0)}),
        (12, {"spine2": (2, 0, 0)}),
    ])
    action_for(arm, "swipe", [
        (1, {"upper_arm.R": (30, 0, -10), "forearm.R": (10, 0, 0), "head": (4, -6, 0)}),
        (6, {"upper_arm.R": (-55, 20, -25), "forearm.R": (-15, 0, 0), "spine3": (0, -8, 0), "head": (6, -10, 0)}),
        (12, {"upper_arm.R": (10, 0, 0), "head": (0, 0, 0)}),
    ])
    action_for(arm, "meow", [
        (1, {"jaw": (0, 0, 0), "head": (-4, 0, 0)}),
        (8, {"jaw": (28, 0, 0), "head": (-10, 0, 0)}),
        (14, {"jaw": (8, 0, 0), "head": (-6, 0, 0)}),
        (20, {"jaw": (0, 0, 0), "head": (0, 0, 0)}),
    ])
    action_for(arm, "sit", [
        (1, {}),
        (8, {"spine1": (22, 0, 0), "spine2": (8, 0, 0), "head": (-6, 0, 0),
             "thigh.L": (70, 0, 8), "thigh.R": (70, 0, -8),
             "shin.L": (-40, 0, 0), "shin.R": (-40, 0, 0),
             "hock.L": (30, 0, 0), "hock.R": (30, 0, 0),
             "tail00": (10, 40, 0), "tail03": (0, 30, 0), "tail06": (0, 20, 0)}),
        (16, {"spine1": (22, 0, 0), "thigh.L": (70, 0, 8), "thigh.R": (70, 0, -8),
              "shin.L": (-40, 0, 0), "shin.R": (-40, 0, 0),
              "tail00": (10, 40, 0)}),
    ])
    action_for(arm, "lounge", [
        (1, {}),
        (10, {"spine1": (0, 0, 48), "spine2": (10, 0, 30), "spine3": (6, 0, 12),
              "head": (12, 0, -10),
              "upper_arm.L": (20, 0, 30), "upper_arm.R": (10, 0, -20),
              "thigh.L": (15, 0, 25), "thigh.R": (-10, 0, -15),
              "tail00": (0, 50, 10), "tail04": (0, 30, 0)}),
        (18, {"spine1": (0, 0, 48), "spine2": (10, 0, 30), "head": (14, 4, -8),
              "tail00": (0, 55, 8)}),
    ])


def make_lod(src, name, ratio):
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    obj.data.name = name
    link(obj)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    # Armature modifier is first; decimate after it in the stack deforms
    # the already-skinned evaluated mesh. Put decimate first.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # Move decimate above the armature modifier.
    guard = 0
    while obj.modifiers and obj.modifiers[0].name != "dec" and guard < 8:
        bpy.ops.object.modifier_move_up(modifier="dec")
        guard += 1
    apply_modifier(obj, "dec")
    # Re-add armature if apply removed only decimate. Armature stays.
    return obj


def export(arm, meshes, path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_skins=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("exported", path, os.path.getsize(path))


def preview(obj, path):
    bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
    bpy.context.scene.render.resolution_x = 960
    bpy.context.scene.render.resolution_y = 540
    bpy.context.scene.render.filepath = path
    bpy.context.scene.display.shading.light = "STUDIO"
    bpy.context.scene.display.shading.color_type = "TEXTURE" if obj.data.vertex_colors else "MATERIAL"
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    link(cam)
    cam.location = (1.15, -1.35, 0.72)
    cam.rotation_euler = (math.radians(72), 0, math.radians(38))
    bpy.context.scene.camera = cam
    world = bpy.data.worlds.new("w")
    bpy.context.scene.world = world
    world.color = (0.16, 0.17, 0.19)
    try:
        bpy.ops.render.render(write_still=True)
        print("preview", path)
    except Exception as exc:
        print("preview failed", exc)


def main():
    dest = os.path.abspath(out_dir())
    os.makedirs(dest, exist_ok=True)
    clear_scene()
    parts = build_parts()
    body = join_objects(parts, "CatLOD0")
    print("joined verts", len(body.data.vertices))
    fuse(body)
    print("fused verts", len(body.data.vertices), "faces", len(body.data.polygons))
    shape_details(body)
    sub = body.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    apply_modifier(body, "sub")
    print("subdiv verts", len(body.data.vertices))
    smart_uv(body)
    raster_textures(
        body,
        512,
        os.path.join(dest, "willie_albedo.png"),
        os.path.join(dest, "aggie_albedo.png"),
        os.path.join(dest, "cat_normal.png"),
        os.path.join(dest, "cat_roughness.png"),
    )
    arm = build_armature()
    skin(body, arm)
    build_actions(arm)
    lod1 = make_lod(body, "CatLOD1", 0.45)
    lod2 = make_lod(body, "CatLOD2", 0.18)
    body.name = "CatLOD0"
    body.data.name = "CatLOD0"
    export(arm, [body, lod1, lod2], os.path.join(dest, "cat.glb"))
    print("DONE", dest)


if __name__ == "__main__":
    main()
