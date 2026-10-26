class_name HouseProps
extends RefCounted
## Hunyuan hoarder props. Collision stays the boxes already built.
## One shared scene per kind, instanced on every floor. A missing
## mesh leaves the flat box in place.


## Mesh size after fit_house_props.py (height is 1, feet at y=0).
const MESH_SIZE := {
	"boxes": Vector3(0.636, 1.0, 0.611),
	"papers": Vector3(2.075, 0.958, 1.733),
	"recliner": Vector3(0.966, 1.0, 0.998),
}

const HEIGHT := {
	"boxes": 1.0,
	"papers": 0.22,
	"recliner": 0.82,
	"lamp": 1.35,
	"jars": 0.28,
	"laundry": 0.32,
	"fridge": 1.7,
	"tv": 0.7,
}


static var _scenes := {}


static func dress(root: Node3D, floor_id: String) -> void:
	_swap_clutter(root)
	_swap_tagged(root)
	_scatter(root, floor_id)


static func _swap_clutter(root: Node3D) -> void:
	if _scene("boxes") == null:
		return
	var groups := {}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not _is_clutter(mi):
			continue
		var gp := mi.global_position
		var key := "%d:%d" % [int(round(gp.x / 0.45)), int(round(gp.z / 0.45))]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(mi)
	for key: String in groups:
		_fill(root, groups[key], "boxes")


static func _is_clutter(mi: MeshInstance3D) -> bool:
	if mi.get_meta("house_prop", "") != "":
		return false
	if not mi.visible or not (mi.mesh is BoxMesh):
		return false
	var kind := String(mi.name)
	if kind == "step":
		return false
	if kind == "stack" or kind == "wall":
		return true
	var size := (mi.mesh as BoxMesh).size
	if size.x < 0.35 or size.y < 0.25 or size.z < 0.35:
		return false
	if size.x > 1.45 or size.y > 1.45 or size.z > 1.45:
		return false
	var longest := maxf(size.x, maxf(size.y, size.z))
	var shortest := minf(size.x, minf(size.y, size.z))
	if longest > shortest * 2.6:
		return false
	var mat := mi.material_override as StandardMaterial3D
	if mat == null or mat.albedo_texture != null:
		return false
	var c := mat.albedo_color
	return c.r > 0.48 and c.r < 0.82 and c.g > 0.32 and c.g < 0.68 and c.b < 0.48 and c.r > c.b + 0.12


static func _swap_tagged(root: Node3D) -> void:
	var groups := {}
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not mi.has_meta("house_prop"):
			continue
		var id := String(mi.get_meta("house_prop"))
		if _scene(id) == null:
			continue
		if not groups.has(id):
			groups[id] = []
		(groups[id] as Array).append(mi)
	for id: String in groups:
		_fill(root, groups[id], id)


static func _fill(root: Node3D, meshes: Array, id: String) -> void:
	var packed := _scene(id)
	if packed == null or meshes.is_empty():
		return
	var bounds: Vector3 = MESH_SIZE.get(id, Vector3(0.7, 1.0, 0.7))
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for item: Variant in meshes:
		var mi := item as MeshInstance3D
		var he := (mi.mesh as BoxMesh).size * 0.5
		var xf := mi.global_transform
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var p := xf * Vector3(he.x * sx, he.y * sy, he.z * sz)
					lo = lo.min(p)
					hi = hi.max(p)
		mi.visible = false
	var ext := hi - lo
	if ext.y < 0.18 or ext.x < 0.05 or ext.z < 0.05:
		return
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return
	root.add_child(inst)
	inst.global_position = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	# Box stacks fill the flat box they replace. A generated chair or
	# appliance keeps its own proportions and stands at the group's height.
	if id == "boxes":
		inst.scale = Vector3(ext.x / bounds.x, ext.y / bounds.y, ext.z / bounds.z)
	else:
		var s := ext.y / bounds.y
		inst.scale = Vector3(s, s, s)


static func _scatter(root: Node3D, floor_id: String) -> void:
	var spots: Array = []
	match floor_id:
		HouseSpec.GROUND_FLOOR:
			spots = [
				["lamp", Vector3(6.4, 0.0, 1.6), 0.4],
				["papers", Vector3(2.2, 0.0, 0.4), 0.2],
				["jars", Vector3(-6.4, 0.9, -4.35), 1.1],
				["laundry", Vector3(7.2, 0.0, 2.4), -0.3],
				["papers", Vector3(-3.4, 0.0, 3.2), 0.8],
			]
		HouseSpec.BASEMENT:
			spots = [
				["lamp", Vector3(2.4, 0.0, -2.2), 0.6],
				["papers", Vector3(-1.2, 0.0, 1.4), -0.4],
				["jars", Vector3(4.2, 0.85, 1.1), 0.2],
				["laundry", Vector3(-3.5, 0.0, 3.4), 1.0],
				["papers", Vector3(6.2, 0.0, -1.6), 0.5],
			]
		HouseSpec.ATTIC:
			spots = [
				["lamp", Vector3(-1.4, 0.0, -2.4), 0.9],
				["papers", Vector3(1.6, 0.0, -1.2), 0.1],
				["jars", Vector3(-3.6, 0.0, 2.2), -0.5],
				["laundry", Vector3(2.8, 0.0, 2.6), 0.4],
				["papers", Vector3(-4.8, 0.0, 0.6), 1.2],
			]
	for spot: Array in spots:
		var id := String(spot[0])
		var packed := _scene(id)
		if packed == null:
			continue
		var bounds: Vector3 = MESH_SIZE.get(id, Vector3(0.7, 1.0, 0.7))
		var h := float(HEIGHT.get(id, 1.0))
		var inst := packed.instantiate() as Node3D
		root.add_child(inst)
		var pos: Vector3 = spot[1]
		inst.position = pos
		inst.rotation.y = float(spot[2])
		var s := h / bounds.y
		inst.scale = Vector3(s, s, s)


static func _scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var tier := "lod0" if VisualQuality.is_high() else "lod2"
	var path := "res://house/props/%s_%s.glb" % [id, tier]
	if not ResourceLoader.exists(path):
		_scenes[id] = null
		return null
	var packed := load(path) as PackedScene
	_scenes[id] = packed
	return packed
