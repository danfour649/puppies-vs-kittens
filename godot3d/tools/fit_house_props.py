"""Normalize a Hunyuan Rapid prop (OBJ + texture) into desktop and web GLBs.

The mesh is recentered, stood on y=0, and scaled so its height is 1.
Desktop keeps about 8000 triangles and a 1024 albedo. Web keeps about
2500 triangles and a 512 albedo. Godot then scales the prop by the
height it should occupy.

    blender -b -P godot3d/tools/fit_house_props.py -- --src /tmp/prop.obj --name boxes --out godot3d/house/props
"""
import os
import sys

import bpy


DESKTOP_TRIS = 8000
WEB_TRIS = 2500
DESKTOP_TEX = 1024
WEB_TEX = 512


def _args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    src = ""
    name = ""
    out = ""
    i = 0
    while i < len(argv):
        if argv[i] == "--src":
            src = argv[i + 1]
            i += 2
        elif argv[i] == "--name":
            name = argv[i + 1]
            i += 2
        elif argv[i] == "--out":
            out = argv[i + 1]
            i += 2
        else:
            i += 1
    return src, name, out


def _clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import(src):
    ext = os.path.splitext(src)[1].lower()
    if ext == ".obj":
        bpy.ops.wm.obj_import(filepath=src)
    else:
        bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no mesh in %s" % src)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def _normalize(obj):
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    # Rapid OBJ comes in Z-up from Hunyuan. Blender's importer usually
    # leaves it that way. Stand the prop on Blender Z, then the glTF
    # exporter turns that into Y-up for Godot.
    height = max(zs) - min(zs)
    if height < 1e-5:
        height = 1.0
    cx = (min(xs) + max(xs)) * 0.5
    cy = (min(ys) + max(ys)) * 0.5
    z0 = min(zs)
    scale = 1.0 / height
    for v in obj.data.vertices:
        v.co.x = (v.co.x - cx) * scale
        v.co.y = (v.co.y - cy) * scale
        v.co.z = (v.co.z - z0) * scale
    obj.data.update()


def _limit(obj, tris):
    face_count = len(obj.data.polygons)
    if face_count <= tris:
        return
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.ratio = max(0.01, float(tris) / float(face_count))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _resize_images(px):
    for im in list(bpy.data.images):
        if im.size[0] < 8:
            continue
        im.scale(px, px)


def _export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_image_format="JPEG",
        export_jpeg_quality=82,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
    )


def main():
    src, name, out = _args()
    if not src or not name or not out:
        raise SystemExit("need --src --name --out")
    _clear()
    obj = _import(src)
    _normalize(obj)
    desktop = obj
    _resize_images(DESKTOP_TEX)
    _limit(desktop, DESKTOP_TRIS)
    _export(desktop, os.path.join(out, "%s_lod0.glb" % name))
    _resize_images(WEB_TEX)
    _limit(desktop, WEB_TRIS)
    _export(desktop, os.path.join(out, "%s_lod2.glb" % name))
    print("FIT", name, "tris", len(desktop.data.polygons))


if __name__ == "__main__":
    main()
