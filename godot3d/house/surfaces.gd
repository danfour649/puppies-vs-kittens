class_name HouseSurfaces
extends RefCounted
## PBR floor and wall textures for the three interior floors.
## Collision stays the boxes already built. A missing texture leaves
## the flat colour in place.


const TILE := 1.0


static func dress(root: Node, floor_id: String) -> void:
	var root3 := root as Node3D
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		if mi.get_meta("house_prop", "") != "":
			continue
		var size := (mi.mesh as BoxMesh).size
		var pos := mi.position
		if root3 != null:
			pos = root3.to_local(mi.global_position)
		if size.y <= 0.016 and size.x < 14.0:
			mi.visible = false
			continue
		if _is_floor(size, pos):
			var which := _floor_tex(floor_id, pos)
			_paint(mi, which, 0.86)
			continue
		if _is_wall(size):
			var wall := "concrete" if floor_id == HouseSpec.BASEMENT else "wallpaper"
			_paint(mi, wall, 0.9)


static func _is_floor(size: Vector3, pos: Vector3) -> bool:
	return size.y >= 0.12 and size.y <= 0.45 and size.x >= 3.0 and size.z >= 2.0 and pos.y < 0.55 and pos.y > -0.8


static func _is_wall(size: Vector3) -> bool:
	var thin := minf(size.x, size.z)
	var wide := maxf(size.x, size.z)
	return thin <= 0.45 and size.y >= 0.8 and wide >= 3.0


static func _floor_tex(floor_id: String, pos: Vector3) -> String:
	if floor_id == HouseSpec.BASEMENT:
		return "concrete"
	if floor_id == HouseSpec.ATTIC:
		return "attic"
	if pos.x < HouseSpec.DIVIDER_X:
		return "linoleum"
	return "hardwood"


static func _paint(mi: MeshInstance3D, name: String, rough: float, scale := Vector3(TILE, TILE, TILE)) -> void:
	var albedo := _load_tex(name, "albedo")
	if albedo == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.roughness = rough
	var normal := _load_tex(name, "normal")
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 0.55
	var rough_tex := _load_tex(name, "rough")
	if rough_tex != null:
		m.roughness_texture = rough_tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m


static func _load_tex(name: String, role: String) -> Texture2D:
	var tier := "lod0" if VisualQuality.is_high() else "lod2"
	var path := "res://house/textures/%s_%s_%s.jpg" % [name, role, tier]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## A thin linoleum sheet over the kitchen, with a hole for the stairs.
## The slab underneath stays the collision.
static func lay_kitchen(root: Node3D) -> void:
	if _load_tex("linoleum", "albedo") == null:
		return
	var hole := HouseSpec.STAIRWELL
	var room := HouseSpec.KITCHEN
	var strips: Array[Rect2] = [
		Rect2(room.position.x, room.position.y, hole.position.x - room.position.x, room.size.y),
		Rect2(hole.end.x, room.position.y, room.end.x - hole.end.x, room.size.y),
		Rect2(hole.position.x, hole.end.y, hole.size.x, room.end.y - hole.end.y),
		Rect2(hole.position.x, room.position.y, hole.size.x, hole.position.y - room.position.y),
	]
	for strip: Rect2 in strips:
		if strip.size.x < 0.2 or strip.size.y < 0.2:
			continue
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(strip.size.x, 0.012, strip.size.y)
		mi.mesh = bm
		mi.position = Vector3(strip.get_center().x, 0.008, strip.get_center().y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		_paint(mi, "linoleum", 0.72)


## Slabs the floor and wall pass leaves alone. Floor photos stay on
## horizontal faces. Anything standing up gets plaster, wallpaper,
## kraft, or vertical-grain beam wood.
static func dress_rest(root: Node, floor_id: String = "") -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or not mi.visible or not (mi.mesh is BoxMesh):
			continue
		if mi.get_meta("house_prop", "") != "":
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat != null and mat.albedo_texture != null:
			continue
		var c := mat.albedo_color if mat != null else Color(0.55, 0.45, 0.35)
		if c.b > c.r + 0.08 and c.b > 0.55:
			continue
		if c.r < 0.16 and c.g < 0.16 and c.b < 0.18:
			continue
		var ext := _world_extent(mi)
		var flat := ext.y <= minf(ext.x, ext.z)
		var which := "plaster"
		var rough := 0.9
		var scale := Vector3(0.7, 0.7, 0.7)
		if flat:
			var pos := mi.global_position
			if ext.y < 0.08 and ext.x > 1.0 and ext.z > 0.8 and c.r > c.b + 0.08 and c.r < 0.7:
				which = "rug"
				rough = 0.92
				scale = Vector3(0.8, 0.8, 0.8)
			else:
				which = _floor_tex(floor_id, pos)
				rough = 0.84
				scale = Vector3(TILE, TILE, TILE)
		elif _cardboard(c):
			which = "kraft"
			rough = 0.96
			scale = Vector3(1.5, 1.5, 1.5)
		elif c.r > 0.72 and c.g > 0.68:
			which = "wallpaper"
			rough = 0.9
			scale = Vector3(0.65, 0.65, 0.65)
		elif _wood(c) or floor_id == HouseSpec.ATTIC:
			which = "beam"
			rough = 0.88
			# Grain in the beam map runs with image V, which triplanar
			# lays along world Y on a side face.
			scale = Vector3(1.1, 1.6, 1.1)
		elif floor_id == HouseSpec.BASEMENT:
			which = "concrete"
			rough = 0.92
			scale = Vector3(0.8, 0.8, 0.8)
		_paint(mi, which, rough, scale)


static func _world_extent(mi: MeshInstance3D) -> Vector3:
	var size := (mi.mesh as BoxMesh).size
	var he := size * 0.5
	var xf := mi.global_transform
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := xf * Vector3(he.x * sx, he.y * sy, he.z * sz)
				lo = lo.min(p)
				hi = hi.max(p)
	return hi - lo


static func _wood(c: Color) -> bool:
	return c.r > c.g and c.g + 0.02 > c.b and c.r > 0.28 and c.r < 0.82 and c.b < 0.55


static func _cardboard(c: Color) -> bool:
	return c.r > 0.45 and c.r < 0.86 and c.g > 0.28 and c.g < 0.72 and c.b < 0.5 and c.r > c.b + 0.1
