extends Node
## In-game Hunyuan cat against the raw GLB. Headless.
## The bind mesh, the skin weights, and a posed silhouette have to
## match. A visible primitive (the old ellipsoid tail or a leg cone)
## fails the run.
##   godot --headless --path godot3d res://tests/test_silhouette.tscn

const CatScript := preload("res://cat_kit/cat.gd")
const GRID := 64

var _pass := 0
var _fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func _ready() -> void:
	_run()


func _run() -> void:
	print("SILHOUETTE")
	for spec in [
		{"id": "willie", "path": CatSculpt.WILLIE_HIGH},
		{"id": "aggie", "path": CatSculpt.AGGIE_HIGH},
	]:
		await _one(str(spec["id"]), str(spec["path"]))
	print("SILHOUETTE DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _one(who: String, glb_path: String) -> void:
	var cat = CatScript.new()
	cat.name = who
	if who == "aggie":
		cat.set_character("aggie")
	add_child(cat)
	await _frames(2)
	var sculpt = cat.get("_sculpt")
	check(sculpt != null and sculpt.body != null and sculpt.skeleton != null, "%s has a skinned body" % who)
	if sculpt == null or sculpt.body == null:
		return
	sculpt.tree.active = false
	var mod := sculpt.skeleton.get_node_or_null("PoseModifier") as SkeletonModifier3D
	if mod != null:
		mod.active = false
	await _frames(1)
	sculpt.skeleton.reset_bone_poses()
	var raw := (load(glb_path) as PackedScene).instantiate()
	raw.name = who + "Raw"
	add_child(raw)
	var raw_mi := _biggest_mesh(raw)
	var raw_sk := _find_skeleton(raw)
	check(raw_mi != null and raw_sk != null, "%s raw GLB has a mesh and a skeleton" % who)
	if raw_mi == null or raw_sk == null:
		return
	raw_sk.reset_bone_poses()
	var game_mesh: Mesh = sculpt.body.mesh
	var raw_mesh: Mesh = raw_mi.mesh
	var vert_delta := _array_delta(game_mesh, raw_mesh, Mesh.ARRAY_VERTEX)
	var weight_delta := _array_delta(game_mesh, raw_mesh, Mesh.ARRAY_WEIGHTS)
	check(vert_delta < 0.0001, "%s cage matches the GLB (delta %.5f)" % [who, vert_delta])
	check(weight_delta < 0.0001, "%s skin weights match the GLB (delta %.5f)" % [who, weight_delta])
	var extra := _extra_visible(cat)
	check(extra == 0, "%s draws no leftover body mesh (%d)" % [who, extra])
	var tail_owned := _tail_owned(sculpt.body, sculpt.skeleton)
	check(tail_owned > 0.85, "%s tail vertices follow the tail bones (%.2f)" % [who, tail_owned])
	var bones := CatBoneMap.resolve(sculpt.skeleton)
	var raw_bones := CatBoneMap.resolve(raw_sk)
	CatMannerPose.apply(sculpt.skeleton, bones, "greet", 1.0, 0.0)
	CatMannerPose.apply(raw_sk, raw_bones, "greet", 1.0, 0.0)
	var game_pts := _skinned(sculpt.body, sculpt.skeleton)
	var raw_pts := _skinned(raw_mi, raw_sk)
	var side := _iou(game_pts, raw_pts, false)
	var front := _iou(game_pts, raw_pts, true)
	check(side > 0.9 and front > 0.9, "%s posed silhouette matches the GLB (side %.3f front %.3f)" % [who, side, front])
	cat.queue_free()
	raw.queue_free()


func _extra_visible(cat: Node) -> int:
	var n := 0
	for node in cat.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var mesh_name := str(mi.name)
		if mesh_name == "SculptBody" or mesh_name.begins_with("Whisker"):
			continue
		n += 1
	return n


func _tail_owned(mi: MeshInstance3D, sk: Skeleton3D) -> float:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones_a: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if verts.is_empty() or weights.is_empty():
		return 0.0
	var stride := int(weights.size() / verts.size())
	var owned := 0
	var total := 0
	for v in verts.size():
		var p: Vector3 = verts[v]
		if not (p.z < -0.5 and absf(p.x) < 0.14 and p.y < 0.45):
			continue
		total += 1
		var best_w := 0.0
		var best := ""
		for k in stride:
			var w := weights[v * stride + k]
			if w <= best_w:
				continue
			var b := bones_a[v * stride + k]
			best_w = w
			best = sk.get_bone_name(b) if b >= 0 and b < sk.get_bone_count() else ""
		if best.begins_with("tail"):
			owned += 1
	if total == 0:
		return 0.0
	return float(owned) / float(total)


func _array_delta(a: Mesh, b: Mesh, channel: int) -> float:
	var aa: Array = a.surface_get_arrays(0)
	var bb: Array = b.surface_get_arrays(0)
	var left: Variant = aa[channel]
	var right: Variant = bb[channel]
	if left is PackedVector3Array and right is PackedVector3Array:
		var va: PackedVector3Array = left
		var vb: PackedVector3Array = right
		if va.size() != vb.size():
			return 999.0
		var worst := 0.0
		for i in va.size():
			worst = maxf(worst, va[i].distance_to(vb[i]))
		return worst
	if left is PackedFloat32Array and right is PackedFloat32Array:
		var fa: PackedFloat32Array = left
		var fb: PackedFloat32Array = right
		if fa.size() != fb.size():
			return 999.0
		var worst_w := 0.0
		for i in fa.size():
			worst_w = maxf(worst_w, absf(fa[i] - fb[i]))
		return worst_w
	return 999.0


func _skinned(mi: MeshInstance3D, sk: Skeleton3D) -> PackedVector3Array:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones_a: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var out := PackedVector3Array()
	out.resize(verts.size())
	if weights.is_empty() or mi.skin == null:
		return verts
	var stride := int(weights.size() / verts.size())
	var binds: Array[Transform3D] = []
	var pose: Array[Transform3D] = []
	for b in sk.get_bone_count():
		pose.append(sk.get_bone_global_pose(b))
	var bind_bone: Array[int] = []
	for b in mi.skin.get_bind_count():
		binds.append(mi.skin.get_bind_pose(b))
		bind_bone.append(mi.skin.get_bind_bone(b))
	for v in verts.size():
		var acc := Vector3.ZERO
		var sum := 0.0
		for k in stride:
			var w := weights[v * stride + k]
			if w <= 0.0001:
				continue
			var b := bones_a[v * stride + k]
			if b < 0 or b >= binds.size():
				continue
			var bone_i := bind_bone[b]
			if bone_i < 0:
				bone_i = b
			if bone_i < 0 or bone_i >= pose.size():
				continue
			acc += (pose[bone_i] * binds[b]) * verts[v] * w
			sum += w
		out[v] = acc if sum > 0.1 else verts[v]
	return out


func _iou(game_pts: PackedVector3Array, raw_pts: PackedVector3Array, use_front: bool) -> float:
	if game_pts.is_empty() or raw_pts.is_empty():
		return 0.0
	var bounds := _bounds(raw_pts)
	var pad := bounds.size * 0.04 + Vector3(0.01, 0.01, 0.01)
	bounds.position -= pad
	bounds.size += pad * 2.0
	var a := _mask(game_pts, bounds, use_front)
	var b := _mask(raw_pts, bounds, use_front)
	var inter := 0
	var union_n := 0
	for i in a.size():
		var on_a := a[i] != 0
		var on_b := b[i] != 0
		if on_a or on_b:
			union_n += 1
		if on_a and on_b:
			inter += 1
	if union_n == 0:
		return 0.0
	return float(inter) / float(union_n)


func _mask(pts: PackedVector3Array, bounds: AABB, use_front: bool) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(GRID * GRID)
	var size := bounds.size
	for p in pts:
		var u := (p.x - bounds.position.x) / maxf(size.x, 0.0001) if use_front else (p.z - bounds.position.z) / maxf(size.z, 0.0001)
		var v := (p.y - bounds.position.y) / maxf(size.y, 0.0001)
		var x := clampi(int(u * float(GRID)), 0, GRID - 1)
		var y := clampi(int(v * float(GRID)), 0, GRID - 1)
		mask[y * GRID + x] = 1
	return mask


func _bounds(pts: PackedVector3Array) -> AABB:
	var b := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		b = b.expand(p)
	return b


func _biggest_mesh(root: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_n := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() < 1:
			continue
		var n: int = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		if n > best_n:
			best_n = n
			best = mi
	return best


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
