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


static func _paint(mi: MeshInstance3D, name: String, rough: float) -> void:
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
	m.uv1_scale = Vector3(TILE, TILE, TILE)
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
