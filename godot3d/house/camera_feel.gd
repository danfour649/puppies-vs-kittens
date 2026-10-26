class_name CameraFeel
extends Node
## Keeps the third-person camera inside a room.
##
## The spring arm collides with the house (mask 1) and ignores the
## cats. A doorway is a hole, so the arm will happily sit out on the
## porch and look back through the gap; when the cat is indoors the
## arm shortens until the lens is inside the shell. Anything still
## between the lens and Willie fades, so a stack never becomes a
## white slit.


const MASK := 1
const MIN_LENGTH := 0.85
const INSET := 0.55

var _game: Node = null
var _arm: SpringArm3D = null
var _cam: Camera3D = null
var _meshes: Array[MeshInstance3D] = []
var _faded: Array[MeshInstance3D] = []
var _zone := ""
var _excluded := false


func bind(game: Node, arm: SpringArm3D, cam: Camera3D) -> void:
	_game = game
	_arm = arm
	_cam = cam
	arm.collision_mask = MASK
	arm.margin = 0.22


## House-local point, y up from that floor. True when it has left
## the shell (inset so the lens is not buried in the wall).
static func outside_footprint(local_pos: Vector3, ceil_h: float) -> bool:
	var hx := HouseSpec.FOOTPRINT_W * 0.5 - INSET
	var hz := HouseSpec.FOOTPRINT_D * 0.5 - INSET
	if absf(local_pos.x) > hx or absf(local_pos.z) > hz:
		return true
	if local_pos.y < -0.35 or local_pos.y > ceil_h - 0.25:
		return true
	return false


func apply(want_length: float) -> void:
	if _arm == null or _game == null:
		return
	_exclude_cats()
	var length := want_length
	var zone := _current_zone()
	if zone != HouseSpec.OUTSIDE and zone != "":
		_ensure_meshes(zone)
		length = _clear_length(want_length, zone)
	else:
		_restore_all()
	_arm.spring_length = length
	if zone != HouseSpec.OUTSIDE and zone != "":
		_fade_between()


func _exclude_cats() -> void:
	if _excluded or _arm == null or _game == null:
		return
	var cat: Node = _game.get("cat")
	if cat != null and cat is CollisionObject3D:
		_arm.add_excluded_object((cat as CollisionObject3D).get_rid())
	var duo: Node = _game.get("duo")
	if duo != null:
		var aggie: Node = duo.get("aggie_cat")
		if aggie != null and aggie is CollisionObject3D:
			_arm.add_excluded_object((aggie as CollisionObject3D).get_rid())
	_excluded = cat != null


func _current_zone() -> String:
	var zones: Node = _game.get("zones")
	if zones == null:
		return ""
	return String(zones.get("current_zone"))


func _ensure_meshes(zone: String) -> void:
	if zone == _zone and not _meshes.is_empty():
		return
	_restore_all()
	_meshes.clear()
	_zone = zone
	var zones: Node = _game.get("zones")
	if zones == null:
		return
	var book: Dictionary = zones.get("zones")
	var root: Node = book.get(zone)
	if root == null:
		return
	_walk_meshes(root)


func _walk_meshes(n: Node) -> void:
	if n is MeshInstance3D and _fade_candidate(n as MeshInstance3D):
		_meshes.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		_walk_meshes(c)


func _fade_candidate(mi: MeshInstance3D) -> bool:
	var sz := mi.get_aabb().size
	if sz.x * sz.y * sz.z < 0.04:
		return false
	# Floors and ceilings. Fading those opens a hole under Willie.
	if sz.y < 0.4 and sz.x > 3.0 and sz.z > 3.0:
		return false
	return true


func _clear_length(want: float, zone: String) -> float:
	var origin := _arm.global_position
	var dir := _arm.global_basis.y
	if dir.length() < 0.01:
		return want
	dir = dir.normalized()
	var length := want
	var hit := _ray_distance(origin, dir, want)
	if hit >= 0.0:
		length = clampf(hit - 0.32, MIN_LENGTH, want)
	var guard := 0
	while guard < 14 and length > MIN_LENGTH and _tip_buried(origin + dir * length):
		length = maxf(MIN_LENGTH, length - 0.3)
		guard += 1
	var cat: Node3D = _game.get("cat")
	if cat != null and _cat_inside(cat, zone):
		var tip := origin + dir * length
		if _outside_world(tip, zone):
			var lo := MIN_LENGTH
			var hi := length
			for _i in 8:
				var mid := (lo + hi) * 0.5
				if _outside_world(origin + dir * mid, zone):
					hi = mid
				else:
					lo = mid
			length = lo
	return length


func _ray_distance(origin: Vector3, dir: Vector3, reach: float) -> float:
	var cat: Node3D = _game.get("cat")
	if cat == null or cat.get_world_3d() == null:
		return -1.0
	var space := cat.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
	q.collision_mask = MASK
	q.exclude = _exclude_rids()
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -1.0
	var n: Vector3 = hit.normal
	if absf(n.y) > 0.72:
		return -1.0
	return origin.distance_to(hit.position)


func _exclude_rids() -> Array[RID]:
	var out: Array[RID] = []
	var cat: Node = _game.get("cat")
	if cat != null and cat is CollisionObject3D:
		out.append((cat as CollisionObject3D).get_rid())
	var duo: Node = _game.get("duo")
	if duo != null:
		var aggie: Node = duo.get("aggie_cat")
		if aggie != null and aggie is CollisionObject3D:
			out.append((aggie as CollisionObject3D).get_rid())
	return out


func _tip_buried(point: Vector3) -> bool:
	var cat: Node3D = _game.get("cat")
	var chest := point
	if cat != null:
		chest = cat.global_position + Vector3(0, 0.3, 0)
	for mi: MeshInstance3D in _meshes:
		var box := _world_aabb(mi)
		if box.has_point(point) and not box.has_point(chest):
			return true
	return false


func _cat_inside(cat: Node3D, zone: String) -> bool:
	var local := cat.global_position - HouseSpec.zone_origin(zone)
	local.y = 0.4
	return not outside_footprint(local, HouseSpec.ceil_h(zone))


func _outside_world(world: Vector3, zone: String) -> bool:
	var local := world - HouseSpec.zone_origin(zone)
	return outside_footprint(local, HouseSpec.ceil_h(zone))


func _fade_between() -> void:
	if _cam == null:
		return
	var cat: Node3D = _game.get("cat")
	if cat == null or cat.get_world_3d() == null:
		_restore_all()
		return
	var keep: Array[MeshInstance3D] = []
	var chest: Vector3 = cat.global_position + Vector3(0, 0.32, 0)
	var from: Vector3 = _cam.global_position
	var space := cat.get_world_3d().direct_space_state
	for off: Vector3 in [Vector3.ZERO, Vector3(0.18, 0.12, 0.0), Vector3(-0.16, 0.2, 0.08)]:
		var q := PhysicsRayQueryParameters3D.create(from, chest + off)
		q.collision_mask = MASK
		q.exclude = _exclude_rids()
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if absf(n.y) > 0.72:
			continue
		var mi := _smallest_covering(hit.position)
		if mi != null and not keep.has(mi):
			keep.append(mi)
	var lens := _world_aabb_point_meshes(from, chest)
	for mi: MeshInstance3D in lens:
		if not keep.has(mi):
			keep.append(mi)
	var still: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in _faded:
		if not is_instance_valid(mi):
			continue
		if keep.has(mi):
			still.append(mi)
		else:
			_fade_off(mi)
	for mi: MeshInstance3D in keep:
		if not still.has(mi):
			_fade_on(mi)
			still.append(mi)
	_faded = still


func _world_aabb_point_meshes(point: Vector3, chest: Vector3) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in _meshes:
		var box := _world_aabb(mi)
		if box.has_point(point) and not box.has_point(chest):
			out.append(mi)
	return out


func _smallest_covering(point: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_vol := 1.0e12
	for mi: MeshInstance3D in _meshes:
		var box := _world_aabb(mi)
		if not box.grow(0.04).has_point(point):
			continue
		var sz := box.size
		var vol := sz.x * sz.y * sz.z
		if vol < best_vol:
			best_vol = vol
			best = mi
	return best


func _world_aabb(mi: MeshInstance3D) -> AABB:
	return mi.global_transform * mi.get_aabb()


func _fade_on(mi: MeshInstance3D) -> void:
	if mi.has_meta("occlude_on"):
		return
	var base: Material = mi.material_override
	mi.set_meta("occlude_base", base)
	var fade := StandardMaterial3D.new()
	if base is StandardMaterial3D:
		fade = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := fade.albedo_color
	c.a = 0.14
	fade.albedo_color = c
	mi.material_override = fade
	mi.set_meta("occlude_on", true)


func _fade_off(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or not mi.has_meta("occlude_on"):
		return
	var base: Variant = mi.get_meta("occlude_base")
	mi.material_override = base as Material
	mi.remove_meta("occlude_on")
	mi.remove_meta("occlude_base")


func _restore_all() -> void:
	for mi: MeshInstance3D in _faded:
		_fade_off(mi)
	_faded.clear()
