"""Fit the Hunyuan3D Willie mesh onto the existing cat skeleton.

The 18 MB generation (routeA/hunyuan31_willie.glb) stays out of the
repo and out of the web pack. This writes two skinned LODs:

  willie_lod0.glb  desktop, ~32k tris, 2048 JPEG albedo
  willie_lod2.glb  web,     ~12k tris, 1024 JPEG albedo

Both carry the 11 clips already on cat.glb, including the meow jaw.
Bone axes that the clips rotate (jaw local +X, leg chains) stay put.
The tail and the ears are moved onto the new surface. The head yaw is
straightened before the skin is bound.

  blender -b -P godot3d/tools/fit_willie_hunyuan.py -- \
      --src /path/hunyuan31_willie.glb --out godot3d/cat_kit/meshes
"""

import bpy
import math
import os
import sys

import numpy as np
from mathutils import Vector


DESKTOP_TRIS = 32000
WEB_TRIS = 12000
DESKTOP_TEX = 2048
WEB_TEX = 1024
CLIPS = (
    "idle", "walk", "trot", "sprint", "stalk",
    "pounce", "land", "swipe", "meow", "sit", "lounge",
)


def args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {"src": "", "out": "godot3d/cat_kit/meshes", "fit_only": False}
    i = 0
    while i < len(raw):
        if raw[i] == "--fit-only":
            out["fit_only"] = True
            i += 1
            continue
        if raw[i] in ("--src", "--out") and i + 1 < len(raw):
            out[raw[i][2:]] = raw[i + 1]
            i += 2
            continue
        i += 1
    if not out["src"]:
        raise SystemExit("pass --src hunyuan31_willie.glb")
    return out


def rot90z(x, y, z):
    return (-y, x, z)


def smoothstep(edge0, edge1, x):
    if abs(edge1 - edge0) < 1e-8:
        return 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def centroid(pts):
    if not pts:
        return None
    n = float(len(pts))
    return (
        sum(p[0] for p in pts) / n,
        sum(p[1] for p in pts) / n,
        sum(p[2] for p in pts) / n,
    )


def dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def load_hunyuan(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise SystemExit("expected one Hunyuan mesh, got %d" % len(meshes))
    obj = meshes[0]
    # glTF leaves a Y-up correction on matrix_world while rotation_euler
    # still reads as zero. Bake it so vertex edits share the armature's Z-up.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = obj.data
    pts = [(v.co.x, v.co.y, v.co.z) for v in me.vertices]
    print(
        "BOUNDS",
        round(min(p[0] for p in pts), 3), round(max(p[0] for p in pts), 3),
        round(min(p[1] for p in pts), 3), round(max(p[1] for p in pts), 3),
        round(min(p[2] for p in pts), 3), round(max(p[2] for p in pts), 3),
    )
    return obj, pts


def straighten_head(pts):
    """Original space: length along X, head toward -X, up is Z.

    The generation looks a little to one side. Rotate the head around
    the neck until its centroid sits on the centre line. UVs stay with
    the vertices, so the painted face turns with the skull.
    """
    upper = [p for p in pts if p[0] < -0.28 and p[2] > 0.42]
    if len(upper) < 50:
        upper = [p for p in pts if p[0] < -0.25]
    c = centroid(upper)
    pivot = (-0.18, 0.0, 0.50)
    dx = c[0] - pivot[0]
    dy = c[1] - pivot[1]
    ang = math.atan2(dy, dx)
    desired = math.pi if ang >= 0.0 else -math.pi
    delta = desired - ang
    while delta > math.pi:
        delta -= math.tau
    while delta < -math.pi:
        delta += math.tau
    print("HEAD yaw centroid", tuple(round(v, 4) for v in c), "delta_deg", round(math.degrees(delta), 2), "n", len(upper))
    if abs(delta) > math.radians(45) or len(upper) < 50:
        print("HEAD yaw skipped")
        return pts
    out = []
    for x, y, z in pts:
        w = smoothstep(-0.16, -0.36, x)
        a = delta * w
        ca, sa = math.cos(a), math.sin(a)
        rx = x - pivot[0]
        ry = y - pivot[1]
        out.append((pivot[0] + ca * rx - sa * ry, pivot[1] + sa * rx + ca * ry, z))
    upper2 = [p for p in out if p[0] < -0.28 and p[2] > 0.42]
    c2 = centroid(upper2) or (0, 0, 0)
    print("HEAD yaw after", tuple(round(v, 4) for v in c2))
    return out


def orient_to_skeleton(pts):
    """Match cat.glb: Blender Z up, nose toward -Y, feet on z=0."""
    turned = [rot90z(*p) for p in pts]
    minx = min(p[0] for p in turned)
    maxx = max(p[0] for p in turned)
    miny = min(p[1] for p in turned)
    maxy = max(p[1] for p in turned)
    minz = min(p[2] for p in turned)
    length = max(maxy - miny, 1e-4)
    scale = 1.072 / length
    cx = (minx + maxx) * 0.5
    placed = []
    for x, y, z in turned:
        placed.append((
            (x - cx) * scale,
            (y - miny) * scale - 0.49,
            (z - minz) * scale,
        ))
    mn = (
        min(p[0] for p in placed),
        min(p[1] for p in placed),
        min(p[2] for p in placed),
    )
    mx = (
        max(p[0] for p in placed),
        max(p[1] for p in placed),
        max(p[2] for p in placed),
    )
    print("PLACED size", tuple(round(mx[i] - mn[i], 3) for i in range(3)), "mn", tuple(round(v, 3) for v in mn), "mx", tuple(round(v, 3) for v in mx))
    return placed


def write_coords(obj, pts):
    for v, p in zip(obj.data.vertices, pts):
        v.co.x, v.co.y, v.co.z = p
    obj.data.update()


def recalc_normals(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except RuntimeError as exc:
        print("normals clear", exc)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = obj.data
    me.calc_loop_triangles()
    centre = Vector((0, 0, 0.35))
    outward = 0
    inward = 0
    for tri in me.loop_triangles[:4000]:
        c = (me.vertices[tri.vertices[0]].co + me.vertices[tri.vertices[1]].co + me.vertices[tri.vertices[2]].co) / 3.0
        if tri.normal.dot(c - centre) >= 0.0:
            outward += 1
        else:
            inward += 1
    print("NORMALS outward", outward, "inward", inward)
    if inward > outward:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.flip_normals()
        bpy.ops.object.mode_set(mode="OBJECT")
        print("NORMALS flipped")


def clean_albedo(image):
    """Fill thin dark cracks along UV borders. The paint stays."""
    w, h = image.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(buf)
    rgb = buf.reshape(h, w, 4)[:, :, :3].copy()
    lum = rgb.mean(axis=2)
    neigh = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
    filled = 0
    for _ in range(5):
        dark = lum < 0.16
        if int(dark.sum()) < 8:
            break
        best_l = np.zeros_like(lum)
        best_c = np.zeros_like(rgb)
        found = np.zeros(lum.shape, dtype=bool)
        for dy, dx in neigh:
            sl = np.roll(np.roll(lum, dy, axis=0), dx, axis=1)
            sc = np.roll(np.roll(rgb, dy, axis=0), dx, axis=1)
            take = dark & (sl > 0.22) & (sl > best_l)
            best_l = np.where(take, sl, best_l)
            best_c = np.where(take[:, :, None], sc, best_c)
            found |= take
        n = int(found.sum())
        filled += n
        if n == 0:
            break
        rgb[found] = best_c[found]
        lum = rgb.mean(axis=2)
    print("SEAMS filled", filled, "of", w * h)
    buf.reshape(h, w, 4)[:, :, :3] = rgb
    image.pixels.foreach_set(buf)
    image.update()


def import_armature(cat_glb):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=cat_glb)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for obj in list(bpy.data.objects):
        if obj in before or obj.type != "MESH":
            continue
        bpy.data.objects.remove(obj, do_unlink=True)
    # Importer names actions "<clip>_CatArmature". Godot matches the short name.
    for action in list(bpy.data.actions):
        for clip in CLIPS:
            if action.name == clip or action.name.lower().startswith(clip + "_"):
                action.name = clip
                break
    have = sorted(a.name for a in bpy.data.actions)
    print("CLIPS", have)
    missing = [c for c in CLIPS if c not in have]
    if missing:
        raise SystemExit("missing clips %s" % missing)
    return arm


def bone_world(arm, name):
    b = arm.data.bones[name]
    h = arm.matrix_world @ b.head_local
    t = arm.matrix_world @ b.tail_local
    return (h.x, h.y, h.z), (t.x, t.y, t.z)


def nearest(pts, target):
    best = pts[0]
    best_d = 1e9
    for p in pts:
        d = dist(p, target)
        if d < best_d:
            best_d = d
            best = p
    return best, best_d


def report_fit(pts, arm):
    names = (
        "head", "jaw", "neck", "spine1", "ear.L", "ear.R",
        "paw_f.L", "paw_f.R", "paw_h.L", "paw_h.R", "tail04", "tail07",
    )
    for name in names:
        head, tail = bone_world(arm, name)
        mid = tuple((head[i] + tail[i]) * 0.5 for i in range(3))
        p, d = nearest(pts, mid)
        print("FIT", name, "dist", round(d, 3), "bone", tuple(round(v, 3) for v in mid), "mesh", tuple(round(v, 3) for v in p))


def _edit(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    return arm.data.edit_bones


def slide_chain(arm, names, delta, factors):
    eb = _edit(arm)
    d = Vector(delta)
    for name, factor in zip(names, factors):
        bone = eb[name]
        bone.head += d * factor
        bone.tail += d * factor
    bpy.ops.object.mode_set(mode="OBJECT")


def shorten_bone(arm, name, factor):
    eb = _edit(arm)
    bone = eb[name]
    bone.tail = bone.head + (bone.tail - bone.head) * factor
    bpy.ops.object.mode_set(mode="OBJECT")


def refit_tail(arm, pts):
    ys = [p[1] for p in pts]
    y_max = max(ys)
    samples = []
    for i in range(9):
        y0 = 0.36 + (y_max - 0.36) * i / 8.0
        y1 = 0.36 + (y_max - 0.36) * (i + 1) / 8.0
        band = [p for p in pts if y0 <= p[1] < y1 + 1e-4 and p[2] > 0.22]
        if len(band) < 12:
            band = [p for p in pts if y0 <= p[1] < y1 + 1e-4]
        if not band:
            continue
        zcut = sorted(p[2] for p in band)[max(0, int(len(band) * 0.72))]
        top = [p for p in band if p[2] >= zcut - 1e-4]
        samples.append(centroid(top))
    print("TAIL samples", len(samples), [tuple(round(v, 3) for v in s) for s in samples])
    if len(samples) < 4:
        print("TAIL left on the original chain")
        return
    eb = _edit(arm)
    prev = eb["spine1"]
    for i in range(8):
        a = samples[min(i, len(samples) - 1)]
        b = samples[min(i + 1, len(samples) - 1)]
        if dist(a, b) < 0.012:
            b = (a[0], a[1] + 0.02, a[2] + 0.01)
        bone = eb["tail%02d" % i]
        bone.head = Vector(a)
        bone.tail = Vector(b)
        bone.parent = prev
        bone.use_connect = i > 0
        try:
            bone.align_roll(Vector((1.0, 0.0, 0.0)))
        except ValueError:
            pass
        prev = bone
    bpy.ops.object.mode_set(mode="OBJECT")


def seat_jaw(arm, pts):
    band = [p for p in pts if p[1] < -0.30 and 0.36 < p[2] < 0.58 and abs(p[0]) < 0.07]
    if len(band) < 30:
        band = [p for p in pts if p[1] < -0.28 and 0.32 < p[2] < 0.60 and abs(p[0]) < 0.1]
    c = centroid(band)
    if c is None:
        print("JAW no muzzle band")
        return
    head, tail = bone_world(arm, "jaw")
    mid = tuple((head[i] + tail[i]) * 0.5 for i in range(3))
    # Keep the hinge axis. Slide the bone onto the muzzle without rotating it.
    delta = tuple(c[i] - mid[i] for i in range(3))
    print("JAW slide", tuple(round(v, 3) for v in delta), "muzzle", tuple(round(v, 3) for v in c))
    slide_chain(arm, ["jaw"], delta, [1.0])


def _toes(pts, pred):
    found = [p for p in pts if pred(p) and p[2] < 0.04]
    if len(found) < 12:
        found = [p for p in pts if pred(p) and p[2] < 0.07]
    if len(found) < 8:
        return None
    found.sort(key=lambda p: p[2])
    return found[: max(8, len(found) // 3)]


def seat_paws(arm, pts):
    specs = (
        ("paw_f.L", ("shoulder.L", "upper_arm.L", "forearm.L", "paw_f.L"), (0.12, 0.4, 0.72, 1.0), lambda p: p[0] < -0.03 and p[1] < -0.02),
        ("paw_f.R", ("shoulder.R", "upper_arm.R", "forearm.R", "paw_f.R"), (0.12, 0.4, 0.72, 1.0), lambda p: p[0] > 0.03 and p[1] < -0.02),
        ("paw_h.L", ("thigh.L", "shin.L", "hock.L", "paw_h.L"), (0.05, 0.3, 0.65, 1.0), lambda p: p[0] < -0.03 and p[1] > 0.08),
        ("paw_h.R", ("thigh.R", "shin.R", "hock.R", "paw_h.R"), (0.05, 0.3, 0.65, 1.0), lambda p: p[0] > 0.03 and p[1] > 0.08),
    )
    for paw_name, chain, factors, pred in specs:
        found = _toes(pts, pred)
        if not found:
            print("PAW empty", paw_name)
            continue
        c = centroid(found)
        head, tail = bone_world(arm, paw_name)
        delta = tuple(c[i] - tail[i] for i in range(3))
        mag = dist(delta, (0, 0, 0))
        print("PAW", paw_name, "n", len(found), "slide", tuple(round(v, 3) for v in delta))
        if mag < 0.02:
            continue
        if mag > 0.12:
            scale = 0.12 / mag
            delta = tuple(v * scale for v in delta)
            print("PAW capped", paw_name, tuple(round(v, 3) for v in delta))
        slide_chain(arm, chain, delta, factors)


def _bone_family(name):
    if name.startswith(("upper_arm", "forearm", "paw_f", "shoulder")):
        return "fore" + name[-1]
    if name.startswith(("thigh", "shin", "hock", "paw_h")):
        return "hind" + name[-1]
    if name.startswith("tail"):
        return "tail"
    if name.startswith("ear"):
        return "ear" + name[-1]
    if name in ("head", "jaw", "neck"):
        return "head"
    return "body"


def _bone_radius(name, length):
    if name.startswith("paw"):
        return 0.07
    if name.startswith("ear"):
        return 0.05
    if name.startswith("tail"):
        return 0.045
    if name == "head":
        return 0.14
    if name == "jaw":
        return 0.07
    if name.startswith(("spine", "root", "neck")):
        return 0.14
    if name.startswith("thigh"):
        return 0.08
    if name.startswith("shoulder"):
        return 0.06
    return max(0.045, length * 0.55)


def bind(obj, arm):
    """Heat weighting did not solve this shell. Use the same envelopes as Aggie."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    segs = []
    for bone in arm.data.bones:
        if bone.name == "neutral_bone":
            continue
        obj.vertex_groups.new(name=bone.name)
        head = arm.matrix_world @ bone.head_local
        tail = arm.matrix_world @ bone.tail_local
        length = max((tail - head).length, 0.02)
        segs.append((bone.name, head, tail, _bone_radius(bone.name, length)))
    limb_owned = 0
    for vert in obj.data.vertices:
        co = obj.matrix_world @ vert.co
        scored = []
        for name, head, tail, radius in segs:
            ab = tail - head
            denom = ab.length_squared
            t = 0.0 if denom < 1e-8 else max(0.0, min(1.0, (co - head).dot(ab) / denom))
            d = (co - (head + ab * t)).length
            if d >= radius * 1.45:
                continue
            w = (1.0 - min(d / radius, 1.0)) ** 2
            if w > 0.001:
                scored.append((name, w))
        if not scored:
            best_name, best_d = segs[0][0], 1e9
            for name, head, tail, _radius in segs:
                ab = tail - head
                denom = ab.length_squared
                t = 0.0 if denom < 1e-8 else max(0.0, min(1.0, (co - head).dot(ab) / denom))
                d = (co - (head + ab * t)).length
                if d < best_d:
                    best_d = d
                    best_name = name
            scored = [(best_name, 1.0)]
        scored.sort(key=lambda it: -it[1])
        fam = _bone_family(scored[0][0])
        kept = []
        if fam.startswith(("fore", "hind")):
            limb_owned += 1
            for name, w in scored:
                other = _bone_family(name)
                if other == fam:
                    kept.append((name, w))
                elif other == "body" and w >= scored[0][1] * 0.55:
                    kept.append((name, w * 0.25))
        elif fam == "head":
            for name, w in scored:
                if _bone_family(name) in ("head", "body") or name.startswith("ear"):
                    kept.append((name, w if _bone_family(name) != "body" else w * 0.3))
        elif fam.startswith("ear"):
            for name, w in scored:
                if name == scored[0][0] or name in ("head", "neck"):
                    kept.append((name, w))
        elif fam == "tail":
            for name, w in scored:
                if _bone_family(name) == "tail" or name in ("spine1", "root"):
                    kept.append((name, w if _bone_family(name) == "tail" else w * 0.2))
        else:
            kept = list(scored)
        if not kept:
            kept = [(scored[0][0], 1.0)]
        kept = sorted(kept, key=lambda it: -it[1])[:4]
        total = sum(w for _n, w in kept) or 1.0
        for name, w in kept:
            obj.vertex_groups[name].add([vert.index], w / total, "REPLACE")
    print("WEIGHTS envelope", len(obj.vertex_groups), "limb verts", limb_owned)


def _groups(obj):
    return {g.name: g.index for g in obj.vertex_groups}


def lock_region(obj, indexes, weights):
    """Replace influences on these vertices. weights is name -> amount."""
    groups = _groups(obj)
    me = obj.data
    wanted = {}
    for name, amount in weights.items():
        if name not in groups:
            continue
        wanted[groups[name]] = amount
    if not wanted or not indexes:
        return
    keep = set(wanted)
    for index in indexes:
        v = me.vertices[index]
        for g in list(v.groups):
            if g.group not in keep:
                g.weight = 0.0
        have = {g.group: g for g in v.groups}
        total = sum(wanted.values()) or 1.0
        for gid, amount in wanted.items():
            if gid in have:
                have[gid].weight = amount / total
            else:
                obj.vertex_groups[gid].add([index], amount / total, "REPLACE")


def region_fixes(obj, arm):
    me = obj.data
    bones = {}
    for b in arm.data.bones:
        h = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        bones[b.name] = ((h.x, h.y, h.z), (t.x, t.y, t.z))

    def near_seg(p, name, radius):
        h, t = bones[name]
        ab = (t[0] - h[0], t[1] - h[1], t[2] - h[2])
        denom = ab[0] ** 2 + ab[1] ** 2 + ab[2] ** 2
        if denom < 1e-8:
            return dist(p, h) < radius
        u = max(0.0, min(1.0, ((p[0] - h[0]) * ab[0] + (p[1] - h[1]) * ab[1] + (p[2] - h[2]) * ab[2]) / denom))
        q = (h[0] + ab[0] * u, h[1] + ab[1] * u, h[2] + ab[2] * u)
        return dist(p, q) < radius

    ears_l, ears_r, tail, jaw, paws = [], [], [], [], {n: [] for n in ("paw_f.L", "paw_f.R", "paw_h.L", "paw_h.R")}
    paw_names = list(paws)
    tail_names = [n for n in bones if n.startswith("tail")]
    leg_names = [n for n in bones if n.startswith(("thigh", "shin", "hock", "paw_", "upper_arm", "forearm", "shoulder"))]

    def seg_dist(p, name):
        h, t = bones[name]
        ab = (t[0] - h[0], t[1] - h[1], t[2] - h[2])
        denom = ab[0] ** 2 + ab[1] ** 2 + ab[2] ** 2
        if denom < 1e-8:
            return dist(p, h)
        u = max(0.0, min(1.0, ((p[0] - h[0]) * ab[0] + (p[1] - h[1]) * ab[1] + (p[2] - h[2]) * ab[2]) / denom))
        q = (h[0] + ab[0] * u, h[1] + ab[1] * u, h[2] + ab[2] * u)
        return dist(p, q)

    for v in me.vertices:
        p = (v.co.x, v.co.y, v.co.z)
        if p[2] > 0.60 and p[1] < -0.18:
            if p[0] < -0.015:
                ears_l.append(v.index)
            elif p[0] > 0.015:
                ears_r.append(v.index)
        if tail_names and p[1] > 0.34:
            td = min(seg_dist(p, n) for n in tail_names)
            ld = min(seg_dist(p, n) for n in leg_names) if leg_names else 1.0
            if td < 0.055 and td + 0.01 < ld:
                tail.append(v.index)
        if p[1] < -0.32 and 0.34 < p[2] < 0.56 and abs(p[0]) < 0.07:
            jaw.append(v.index)
        if p[2] < 0.10:
            best = None
            best_d = 0.07
            for name in paw_names:
                h, t = bones[name]
                d = min(dist(p, h), dist(p, t))
                if d < best_d:
                    best_d = d
                    best = name
            if best:
                paws[best].append(v.index)
    lock_region(obj, ears_l, {"ear.L": 1.0})
    lock_region(obj, ears_r, {"ear.R": 1.0})
    # Tail: nearest tail bone only, so the chain can curl.
    if tail:
        groups = _groups(obj)
        tail_names = ["tail%02d" % i for i in range(8) if "tail%02d" % i in groups]
        for index in tail:
            p = me.vertices[index].co
            pt = (p.x, p.y, p.z)
            best = min(tail_names, key=lambda n: dist(pt, bones[n][0]))
            lock_region(obj, [index], {best: 1.0})
    lock_region(obj, jaw, {"jaw": 0.8, "head": 0.2})
    for name, indexes in paws.items():
        parent = {"paw_f.L": "forearm.L", "paw_f.R": "forearm.R", "paw_h.L": "hock.L", "paw_h.R": "hock.R"}[name]
        lock_region(obj, indexes, {name: 0.85, parent: 0.15})
    print("REGIONS ears", len(ears_l), len(ears_r), "tail", len(tail), "jaw", len(jaw), "paws", {k: len(v) for k, v in paws.items()})
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    cover_unweighted(obj, arm)


def cover_unweighted(obj, arm):
    """Vertices the heat solve skipped would export as a stray bone."""
    bones = []
    for b in arm.data.bones:
        if b.name == "neutral_bone":
            continue
        h = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        bones.append((b.name, ((h.x + t.x) * 0.5, (h.y + t.y) * 0.5, (h.z + t.z) * 0.5)))
    groups = {g.name: g for g in obj.vertex_groups}
    missed = 0
    for v in obj.data.vertices:
        total = sum(g.weight for g in v.groups)
        if total >= 0.05:
            continue
        p = (v.co.x, v.co.y, v.co.z)
        name = min(bones, key=lambda it: dist(p, it[1]))[0]
        if name not in groups:
            continue
        for g in list(v.groups):
            g.weight = 0.0
        groups[name].add([v.index], 1.0, "REPLACE")
        missed += 1
    print("UNWEIGHTED assigned", missed)


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def decimate_to(obj, target):
    current = tri_count(obj)
    if current <= target * 1.05:
        print("DECIMATE", obj.name, current, "already under", target)
        return
    ratio = target / float(current)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = max(0.01, min(1.0, ratio))
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="dec")
    got = tri_count(obj)
    print("DECIMATE", obj.name, current, "->", got, "target", target)
    if got > target * 1.25:
        mod = obj.modifiers.new("dec2", "DECIMATE")
        mod.ratio = target / float(got)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec2")
        print("DECIMATE second", obj.name, tri_count(obj))


def scaled_image(src, size):
    copy = src.copy()
    copy.scale(size, size)
    copy.name = "willie_albedo_%d" % size
    return copy


def assign_image(obj, image):
    mat = obj.data.materials[0].copy()
    obj.data.materials[0] = mat
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.72
    tex = next(n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE")
    tex.image = image


def duplicate(obj, name):
    dup = obj.copy()
    dup.data = obj.data.copy()
    dup.name = name
    dup.data.name = name
    bpy.context.scene.collection.objects.link(dup)
    return dup


def export(arm, mesh, path):
    for pose_bone in arm.pose.bones:
        pose_bone.custom_shape = None
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or obj is mesh:
            continue
        # The procedural file carries a bone-shape sphere. It is not Willie.
        if "LOD" in obj.name and obj.name != "Icosphere":
            continue
        bpy.data.objects.remove(obj, do_unlink=True)
    # Drop anything still parented that is not the skinned body.
    for child in list(arm.children):
        if child is not mesh and child.type == "MESH" and "LOD" not in child.name:
            bpy.data.objects.remove(child, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_skins=True,
        export_yup=True,
        export_materials="EXPORT",
        export_image_format="JPEG",
        export_jpeg_quality=85,
        export_draco_mesh_compression_enable=False,
    )
    print("EXPORTED", path, os.path.getsize(path), "tris", tri_count(mesh))


def main():
    opt = args()
    here = os.path.dirname(os.path.abspath(__file__))
    cat_glb = os.path.normpath(os.path.join(here, "..", "cat_kit", "meshes", "cat.glb"))
    out_dir = opt["out"]
    if not os.path.isabs(out_dir):
        out_dir = os.path.normpath(os.path.join(os.getcwd(), out_dir))
    obj, pts = load_hunyuan(opt["src"])
    print("SOURCE verts", len(pts))
    pts = straighten_head(pts)
    pts = orient_to_skeleton(pts)
    write_coords(obj, pts)
    recalc_normals(obj)
    arm = import_armature(cat_glb)
    report_fit(pts, arm)
    seat_paws(arm, pts)
    seat_jaw(arm, pts)
    # The generated ears are shorter than the procedural bones.
    shorten_bone(arm, "ear.L", 0.48)
    shorten_bone(arm, "ear.R", 0.48)
    slide_chain(arm, ["ear.L", "ear.R"], (0.0, -0.01, -0.035), [1.0, 1.0])
    refit_tail(arm, pts)
    report_fit([(v.co.x, v.co.y, v.co.z) for v in obj.data.vertices], arm)
    if opt["fit_only"]:
        print("FIT ONLY")
        return
    image = bpy.data.images[0]
    clean_albedo(image)
    bind(obj, arm)
    # Parenting may leave the armature unselected. Weights live on obj.
    region_fixes(obj, arm)
    # Preserve the jaw bone's local +X. seat_jaw only translates.
    jaw = arm.data.bones["jaw"]
    print("JAW axis", tuple(round(x, 3) for x in jaw.x_axis))
    desktop = duplicate(obj, "CatLOD0")
    web = duplicate(obj, "CatLOD2")
    obj.hide_set(True)
    decimate_to(desktop, DESKTOP_TRIS)
    decimate_to(web, WEB_TRIS)
    cover_unweighted(desktop, arm)
    cover_unweighted(web, arm)
    assign_image(desktop, scaled_image(image, DESKTOP_TEX))
    assign_image(web, scaled_image(image, WEB_TEX))
    export(arm, desktop, os.path.join(out_dir, "willie_lod0.glb"))
    export(arm, web, os.path.join(out_dir, "willie_lod2.glb"))
    print("DONE")


if __name__ == "__main__":
    main()
