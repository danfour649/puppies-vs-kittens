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
	"box_open": Vector3(1.683, 1.0, 1.595),
	"box_crush": Vector3(0.824, 1.0, 1.303),
	"box_tape": Vector3(1.187, 1.0, 1.397),
	"box_label": Vector3(1.126, 1.0, 1.124),
	"bags": Vector3(0.898, 1.0, 0.778),
	"bins": Vector3(1.08, 1.0, 0.838),
	"books": Vector3(0.753, 1.0, 0.907),
	"lamp": Vector3(0.602, 1.0, 0.346),
	"jars": Vector3(2.354, 1.0, 1.045),
	"laundry": Vector3(2.723, 1.0, 2.858),
	"fridge": Vector3(0.492, 1.0, 0.514),
	"tv": Vector3(1.28, 1.0, 1.238),
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

## Closed box plus the generated variants. Missing files drop out.
const CLUTTER := [
	"boxes", "box_open", "box_crush", "box_tape", "box_label", "bags", "bins", "books",
]

const KRAFT := {
	"boxes": true,
	"box_open": true,
	"box_crush": true,
	"box_tape": true,
	"box_label": true,
	"bags": true,
	"papers": true,
}


static var _scenes := {}


static func dress(root: Node3D, _floor_id: String) -> void:
	_swap_clutter(root)
	_swap_books(root)
	_swap_tagged(root)
	_scatter(root, _floor_id)


static func _swap_clutter(root: Node3D) -> void:
	var kinds := _clutter_kinds()
	if kinds.is_empty():
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
		_fill_clutter(root, groups[key], key, kinds)


static func _clutter_kinds() -> Array:
	var kinds: Array = []
	for id: String in CLUTTER:
		if _scene(id) != null:
			kinds.append(id)
	return kinds


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
	# A free-standing block, not a wall or a counter. Swap it for a
	# pile so a tall slab does not stay one featureless face.
	if size.y > 0.65 and size.y >= maxf(size.x, size.z) * 0.72:
		var wide := maxf(size.x, size.z)
		var thin := minf(size.x, size.z)
		if thin > 0.32 and wide < 1.75 and wide < thin * 3.4:
			return true
	if size.x < 0.28 or size.y < 0.22 or size.z < 0.28:
		return false
	if size.x > 1.6 or size.y > 1.6 or size.z > 1.6:
		return false
	var longest := maxf(size.x, maxf(size.y, size.z))
	var shortest := minf(size.x, minf(size.y, size.z))
	if longest > shortest * 3.2:
		return false
	return _cardboard_color(_albedo(mi))


static func _cardboard_color(c: Color) -> bool:
	return c.r > 0.45 and c.r < 0.86 and c.g > 0.28 and c.g < 0.72 and c.b < 0.5 and c.r > c.b + 0.1


static func _albedo(mi: MeshInstance3D) -> Color:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return Color(0.6, 0.48, 0.32)
	return mat.albedo_color


static func _fill_clutter(root: Node3D, meshes: Array, key: String, kinds: Array) -> void:
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
	if ext.y < 0.16 or ext.x < 0.12 or ext.z < 0.12:
		return
	var seed := absi(key.hash())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var layers := 1
	if ext.y > 0.55:
		layers = 2
	if ext.y > 1.15:
		layers = 3
	var footprint := minf(ext.x, ext.z)
	var count := layers
	if footprint > 0.75 and kinds.size() > 1:
		count += 1
	count = mini(count, 4)
	var cx := (lo.x + hi.x) * 0.5
	var cz := (lo.z + hi.z) * 0.5
	var y := lo.y
	for i in count:
		var id := String(kinds[(seed + i * 3) % kinds.size()])
		if i == count - 1 and kinds.size() > 5:
			id = String(kinds[kinds.size() - 1 - (seed + i) % 3])
		var bounds: Vector3 = MESH_SIZE.get(id, Vector3(0.7, 1.0, 0.7))
		var layer_h := ext.y / float(layers)
		var fit_h := layer_h / bounds.y
		var fit_xz := footprint / maxf(bounds.x, bounds.z)
		var s := minf(fit_h, fit_xz) * rng.randf_range(0.88, 1.08)
		s = clampf(s, 0.2, 1.45)
		var inst := _place(root, id)
		if inst == null:
			continue
		var side := i == layers
		var jx := rng.randf_range(-0.08, 0.08) * footprint
		var jz := rng.randf_range(-0.08, 0.08) * footprint
		if side:
			jx += footprint * 0.28 * (1.0 if (seed + i) % 2 == 0 else -1.0)
			y = lo.y
		var sag := rng.randf() < 0.36
		var sy := s * (rng.randf_range(0.76, 0.88) if sag else rng.randf_range(0.94, 1.05))
		var sx := s * rng.randf_range(0.9, 1.1)
		var sz := s * rng.randf_range(0.9, 1.1)
		inst.global_position = Vector3(cx + jx, y, cz + jz)
		inst.rotation.y = rng.randf() * TAU
		if rng.randf() < 0.42:
			inst.rotation.x = rng.randf_range(-0.06, 0.06)
			inst.rotation.z = rng.randf_range(-0.1, 0.1)
		inst.scale = Vector3(sx, sy, sz)
		_tint(inst, rng, id)
		if not side:
			y += bounds.y * sy * 0.92


static func _swap_books(root: Node3D) -> void:
	if _scene("books") == null:
		return
	var n := 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or not mi.visible or not (mi.mesh is BoxMesh):
			continue
		if mi.get_meta("house_prop", "") != "":
			continue
		var size := (mi.mesh as BoxMesh).size
		if size.x > 0.16 or size.y < 0.2 or size.y > 0.5 or size.z < 0.7:
			continue
		var c := _albedo(mi)
		var sat := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
		if sat < 0.15:
			continue
		mi.visible = false
		var inst := _place(root, "books")
		if inst == null:
			mi.visible = true
			continue
		var bounds: Vector3 = MESH_SIZE.get("books", Vector3(0.8, 1.0, 0.65))
		var s := clampf(size.y / bounds.y, 0.18, 0.55)
		inst.global_position = mi.global_position - Vector3(0, size.y * 0.5, 0)
		inst.rotation.y = mi.global_rotation.y + float(n) * 0.4
		inst.scale = Vector3(s, s, s)
		n += 1


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
	inst.set_meta("hunyuan", id)
	root.add_child(inst)
	inst.global_position = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	# A generated chair or appliance keeps its own proportions.
	# The television mesh is deep; matching the thin screen slab
	# would squash it, so it uses its own height.
	var s := ext.y / bounds.y
	if HEIGHT.has(id) and id != "recliner" and id != "fridge":
		s = float(HEIGHT[id]) / bounds.y
	inst.scale = Vector3(s, s, s)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(id.hash())
	_tint(inst, rng, id)


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
		var inst := _place(root, id)
		if inst == null:
			continue
		var bounds: Vector3 = MESH_SIZE.get(id, Vector3(0.7, 1.0, 0.7))
		var h := float(HEIGHT.get(id, 1.0))
		var pos: Vector3 = spot[1]
		inst.position = pos
		inst.rotation.y = float(spot[2])
		var s := h / bounds.y
		inst.scale = Vector3(s, s, s)
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(id.hash() + int(pos.x * 10.0))
		_tint(inst, rng, id)


static func _place(root: Node3D, id: String) -> Node3D:
	var packed := _scene(id)
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.set_meta("hunyuan", id)
	root.add_child(inst)
	return inst


const _SHADE := preload("res://house/cardboard_shade.gdshader")


static func _shade_ids() -> Dictionary:
	return {
		"boxes": true, "box_open": true, "box_crush": true, "box_tape": true,
		"box_label": true, "bags": true, "bins": true, "books": true, "papers": true,
	}


static func _tint(inst: Node3D, rng: RandomNumberGenerator, id: String) -> void:
	var kraft := bool(KRAFT.get(id, false))
	# A light multiply keeps the photo's own stains. A heavy kraft
	# multiply turned every box into one flat colour.
	var tint := Color(0.9, 0.84, 0.74) if kraft else Color(1.0, 0.98, 0.96)
	tint.r = clampf(tint.r + rng.randf_range(-0.1, 0.08), 0.4, 1.0)
	tint.g = clampf(tint.g + rng.randf_range(-0.08, 0.07), 0.35, 1.0)
	tint.b = clampf(tint.b + rng.randf_range(-0.06, 0.06), 0.28, 1.0)
	var rough := rng.randf_range(0.82, 0.98) if kraft else rng.randf_range(0.7, 0.9)
	var shade := bool(_shade_ids().get(id, false))
	if inst is MeshInstance3D:
		_tint_mesh(inst as MeshInstance3D, tint, rough, shade)
	for node: Node in inst.find_children("*", "MeshInstance3D", true, false):
		_tint_mesh(node as MeshInstance3D, tint, rough, shade)


static func _tint_mesh(mi: MeshInstance3D, tint: Color, rough: float, shade: bool) -> void:
	if mi == null:
		return
	var src := mi.get_active_material(0) as StandardMaterial3D
	var tex: Texture2D = src.albedo_texture if src != null else null
	if shade and tex != null:
		var sm := ShaderMaterial.new()
		sm.shader = _SHADE
		sm.set_shader_parameter("albedo_tex", tex)
		sm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		sm.set_shader_parameter("rough", rough)
		sm.set_shader_parameter("edge", 0.2)
		mi.material_override = sm
		return
	var m := src.duplicate() as StandardMaterial3D if src != null else StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	mi.material_override = m


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
