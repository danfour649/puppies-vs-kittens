class_name CatSculpt
extends RefCounted

const PoseMod := preload("res://cat_kit/cat_pose_modifier.gd")
## Swaps the visible ellipsoid body for the skinned cat in
## cat_kit/meshes/cat.glb. The ellipsoid nodes stay in the tree so the
## palette and pose tests still have their handles; they are hidden.
## The AnimationTree is the blend the clips actually play through.

const MESH_SCENE := "res://cat_kit/meshes/cat.glb"
const WILLIE_HIGH := "res://cat_kit/meshes/willie_lod0.glb"
const WILLIE_LOW := "res://cat_kit/meshes/willie_lod2.glb"
const WILLIE_ALBEDO := "res://cat_kit/meshes/willie_albedo.png"
const AGGIE_ALBEDO := "res://cat_kit/meshes/aggie_albedo.png"
const NORMAL_MAP := "res://cat_kit/meshes/cat_normal.png"
const ROUGH_MAP := "res://cat_kit/meshes/cat_roughness.png"

var tree: AnimationTree
var body: MeshInstance3D
var skeleton: Skeleton3D
var rig: Node3D
var _blends: Dictionary = {}
var _head_idx := -1
var _nose := Vector3.ZERO
var _head_origin := Vector3.ZERO
var _away := Vector3(0, 0, -1)
var _right := Vector3.RIGHT
var _up := Vector3.UP
var _hit_normal := Vector3(0, 0, -1)


static func attach(cat: Node) -> void:
	var sculpt := CatSculpt.new()
	if not sculpt._build(cat):
		return
	cat.set("_sculpt", sculpt)


func _mesh_path(cat: Node) -> String:
	if str(cat.get("character_id")) == "aggie":
		return MESH_SCENE
	return WILLIE_HIGH if VisualQuality.is_high() else WILLIE_LOW


func _build(cat: Node) -> bool:
	var willie := str(cat.get("character_id")) != "aggie"
	var packed := load(_mesh_path(cat)) as PackedScene
	if packed == null:
		push_error("cat mesh missing")
		return false
	var root := packed.instantiate()
	root.name = "Sculpt"
	rig = root
	var model := cat.get("_model") as Node3D
	var body_node := cat.get("_body") as Node3D
	# Under the body so stalk, sit, lounge and the hiss still move
	# the whole cat. The clips move the limbs inside that.
	(body_node if body_node != null else model).add_child(root)
	var meshes: Array[MeshInstance3D] = []
	var player: AnimationPlayer
	_walk(root, meshes, player)
	# _walk can't assign player through a typed local. Find it directly.
	player = _find_player(root)
	skeleton = _find_skeleton(root)
	if meshes.is_empty() or player == null or skeleton == null:
		push_error("cat mesh imported without a skin or a clip")
		return false
	var keep_low := not VisualQuality.is_high()
	var chosen: MeshInstance3D = null
	for mi in meshes:
		var low := str(mi.name).find("LOD2") >= 0 or str(mi.mesh.resource_name).find("LOD2") >= 0
		var high := str(mi.name).find("LOD0") >= 0 or str(mi.mesh.resource_name).find("LOD0") >= 0
		var want := low if keep_low else high
		if chosen == null and (want or meshes.size() == 1):
			chosen = mi
		elif not want:
			mi.visible = false
			mi.queue_free()
	if chosen == null:
		chosen = meshes[0]
	for mi in meshes:
		if mi != chosen and is_instance_valid(mi):
			mi.visible = false
	body = chosen
	body.name = "SculptBody"
	if willie:
		# The Hunyuan albedo is already on the mesh. A flat roughness
		# beats the procedural normal, which was drawn for the other UV.
		body.material_override = _baked_material(body)
		body.set_meta("baked_coat", true)
	else:
		body.material_override = _coat_material(true)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hide_primitives(cat)
	_loops(player)
	tree = _make_tree(player, root)
	_prepare_face(cat)
	var mod: SkeletonModifier3D = PoseMod.new()
	mod.name = "PoseModifier"
	mod.host = cat
	skeleton.add_child(mod)
	return true


func _walk(node: Node, meshes: Array[MeshInstance3D], _player: AnimationPlayer) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		meshes.append(node)
	for c in node.get_children():
		_walk(c, meshes, _player)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_player(c)
		if found != null:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null


func _hide_primitives(cat: Node) -> void:
	var keep := {}
	for eye in cat.get("_eyes"):
		keep[eye] = true
	var model := cat.get("_model") as Node
	if model == null:
		return
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if keep.has(mi) or mi == body or _under_sculpt(mi):
			continue
		# Spec-lock shells (torso, saddle, stripes, tail) stay for tests.
		mi.visible = false


func _under_sculpt(node: Node) -> bool:
	var p := node
	while p != null:
		if str(p.name) == "Sculpt" or str(p.name) == "SculptBody":
			return true
		p = p.get_parent()
	return false


func _baked_material(mi: MeshInstance3D) -> StandardMaterial3D:
	var src := mi.get_active_material(0) as StandardMaterial3D
	if src == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		src = mi.mesh.surface_get_material(0) as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	if src != null:
		mat = src.duplicate() as StandardMaterial3D
	mat.roughness = 0.72
	mat.roughness_texture = null
	mat.normal_enabled = false
	return mat


func _coat_material(aggie: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = load(AGGIE_ALBEDO if aggie else WILLIE_ALBEDO)
	mat.roughness_texture = load(ROUGH_MAP)
	mat.roughness = 1.0
	var normal := load(NORMAL_MAP) as Texture2D
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 0.12
	return mat


func _loops(player: AnimationPlayer) -> void:
	for key in ["idle", "walk", "trot", "sprint", "stalk"]:
		var anim := _find_anim(player, key)
		if anim == "":
			continue
		var res := player.get_animation(anim)
		if res != null:
			res.loop_mode = Animation.LOOP_LINEAR


func _find_anim(player: AnimationPlayer, key: String) -> String:
	for name in player.get_animation_list():
		var leaf := str(name).get_file().to_lower()
		if leaf == key or str(name).to_lower().ends_with("/" + key) or str(name).to_lower() == key:
			return name
		if str(name).to_lower().ends_with(key):
			return name
	return ""


func _clip(player: AnimationPlayer, key: String) -> AnimationNodeAnimation:
	var name := _find_anim(player, key)
	if name == "":
		return null
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


func _make_tree(player: AnimationPlayer, root: Node) -> AnimationTree:
	var blend := AnimationNodeBlendTree.new()
	var space := AnimationNodeBlendSpace1D.new()
	var placed := 0
	for pair in [["walk", 0.28], ["trot", 0.58], ["sprint", 1.0]]:
		var clip := _clip(player, str(pair[0]))
		if clip == null:
			continue
		space.add_blend_point(clip, float(pair[1]))
		placed += 1
	var current := ""
	if placed > 0:
		blend.add_node("gait", space)
		current = "gait"
		_blends["gait"] = "parameters/gait/blend_position"
	var idle := _clip(player, "idle")
	if idle != null and current != "":
		blend.add_node("idle_clip", idle)
		var mix := AnimationNodeBlend2.new()
		blend.add_node("idle_move", mix)
		blend.connect_node("idle_move", 0, "idle_clip")
		blend.connect_node("idle_move", 1, current)
		current = "idle_move"
		_blends["idle_move"] = "parameters/idle_move/blend_amount"
	elif idle != null:
		blend.add_node("idle_clip", idle)
		current = "idle_clip"
	for spec in [
		["stalk", "stalk_mix"],
		["sit", "sit_mix"],
		["lounge", "lounge_mix"],
		["swipe", "strike_mix"],
		["pounce", "pounce_mix"],
		["land", "land_mix"],
		["meow", "meow_mix"],
	]:
		if current == "":
			break
		var clip := _clip(player, str(spec[0]))
		if clip == null:
			continue
		blend.add_node(str(spec[0]) + "_clip", clip)
		var mix := AnimationNodeBlend2.new()
		blend.add_node(str(spec[1]), mix)
		blend.connect_node(str(spec[1]), 0, current)
		blend.connect_node(str(spec[1]), 1, str(spec[0]) + "_clip")
		current = str(spec[1])
		_blends[str(spec[1])] = "parameters/%s/blend_amount" % str(spec[1])
	for manner_name in CatManners.CLIP_NAMES:
		if current == "":
			break
		var manner_clip := _clip(player, manner_name)
		if manner_clip == null:
			continue
		blend.add_node(manner_name + "_clip", manner_clip)
		var manner_mix := AnimationNodeBlend2.new()
		var mix_name := manner_name + "_mix"
		blend.add_node(mix_name, manner_mix)
		blend.connect_node(mix_name, 0, current)
		blend.connect_node(mix_name, 1, manner_name + "_clip")
		current = mix_name
		_blends[mix_name] = "parameters/%s/blend_amount" % mix_name
	if current == "":
		return null
	blend.connect_node("output", 0, current)
	var at := AnimationTree.new()
	at.name = "SculptTree"
	at.tree_root = blend
	root.add_child(at)
	at.anim_player = at.get_path_to(player)
	at.active = true
	print("SCULPT anims ", player.get_animation_list(), " blends ", _blends.keys())
	return at


func _prepare_face(cat: Node) -> void:
	_orient_nose_forward()
	_measure_face()
	_seat_eyes(cat)
	_seat_nose(cat)
	if body != null and body.get_meta("baked_coat", false):
		# The generation already has eyes and a nose. The ellipsoid
		# stand-ins stay in the tree for the pupil tests.
		for eye in cat.get("_eyes"):
			var mi := eye as Node3D
			if mi != null:
				mi.visible = false
		var leather := skeleton.get_node_or_null("HeadSocket/NoseLeather") as Node3D
		if leather != null:
			leather.visible = false


func _orient_nose_forward() -> void:
	# Gameplay forward is -Z. Turn the rig so the head sits in front of
	# the tail on that axis. Yaw only, so the feet stay on the ground.
	if rig == null or skeleton == null:
		return
	var head_i := skeleton.find_bone("head")
	var tail_i := skeleton.find_bone("tail04")
	if head_i < 0 or tail_i < 0:
		return
	var head_p := skeleton.to_global(skeleton.get_bone_global_rest(head_i).origin)
	var tail_p := skeleton.to_global(skeleton.get_bone_global_rest(tail_i).origin)
	var flat := Vector3(head_p.x - tail_p.x, 0.0, head_p.z - tail_p.z)
	if flat.length() < 0.0001:
		return
	rig.rotate_y(PI - atan2(flat.x, flat.z))


func _measure_face() -> void:
	_head_idx = skeleton.find_bone("head")
	if _head_idx < 0 or body == null or body.mesh == null:
		return
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var to_skel := skeleton.global_transform.affine_inverse() * body.global_transform
	var head_o: Vector3 = skeleton.get_bone_global_rest(_head_idx).origin
	_head_origin = head_o
	var tail_i := skeleton.find_bone("tail04")
	var tail_o := skeleton.get_bone_global_rest(tail_i).origin if tail_i >= 0 else head_o + Vector3(0, 0, 1)
	_away = (head_o - tail_o)
	_away.y = 0.0
	if _away.length_squared() < 0.0001:
		_away = Vector3(0, 0, -1)
	else:
		_away = _away.normalized()
	_up = Vector3.UP
	_right = _up.cross(_away).normalized()
	if _right.length_squared() < 0.0001:
		_right = Vector3.RIGHT
	_up = _away.cross(_right).normalized()
	var baked: bool = bool(body.get_meta("baked_coat", false))
	var best := head_o
	var best_d := -1e9
	for v in verts:
		var p: Vector3 = to_skel * v
		var along := _away.dot(p - head_o)
		# Ears on the generated mesh reach past the nose. Keep the
		# muzzle point down at the skull instead of on an ear tip.
		var score := along
		if baked:
			score = along - maxf(0.0, p.y - head_o.y - 0.02) * 2.5
		if score > best_d:
			best_d = score
			best = p
	_nose = best
	print("FACE nose ", _nose, " away ", _away, " head ", head_o)


func _bone_point(skel_point: Vector3) -> Vector3:
	return skeleton.get_bone_global_rest(_head_idx).affine_inverse() * skel_point


func _bone_basis(skel_basis: Basis) -> Basis:
	return skeleton.get_bone_global_rest(_head_idx).basis.inverse() * skel_basis


func _head_socket() -> BoneAttachment3D:
	var existing := skeleton.get_node_or_null("HeadSocket") as BoneAttachment3D
	if existing != null:
		return existing
	var att := BoneAttachment3D.new()
	att.name = "HeadSocket"
	att.bone_name = "head"
	skeleton.add_child(att)
	return att


func _nearest(target: Vector3) -> Vector3:
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var to_skel := skeleton.global_transform.affine_inverse() * body.global_transform
	var best := target
	var best_n := _away
	var best_d := 1e9
	for i in verts.size():
		var p: Vector3 = to_skel * verts[i]
		var d := p.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best = p
			if i < normals.size():
				best_n = (to_skel.basis * normals[i]).normalized()
	if best_n.dot(_away) < 0.0:
		best_n = -best_n
	_hit_normal = best_n
	return best + best_n * 0.01


func _basis_facing(outward: Vector3) -> Basis:
	# The pupil sits on the eye's local -Z, so local Z points inward.
	var z := -outward.normalized()
	var up := _up
	if absf(z.dot(up)) > 0.95:
		up = _right
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _seat_eyes(cat: Node) -> void:
	if _head_idx < 0:
		return
	var att := _head_socket()
	var eyes: Array = cat.get("_eyes")
	var side := -1.0
	for eye in eyes:
		var mi := eye as MeshInstance3D
		if mi == null:
			continue
		mi.get_parent().remove_child(mi)
		att.add_child(mi)
		# Halfway from the skull to the nose, then sunk into the socket
		# so the sphere is not perched on the surface.
		var radius := 0.016
		var target := _head_origin.lerp(_nose, 0.58) + _up * 0.02 + _right * side * 0.05
		var center := _nearest(target) - _hit_normal * (0.01 + radius * 0.62)
		var outward := _hit_normal
		if outward.dot(_away) < 0.2:
			outward = (_away + _right * side * 0.35 + _up * 0.15).normalized()
		mi.transform = Transform3D(_bone_basis(_basis_facing(outward)).orthonormalized(), _bone_point(center))
		mi.scale = Vector3(radius * 2.1, radius * 1.9, radius * 1.25)
		mi.visible = true
		side = 1.0


func _seat_nose(cat: Node) -> void:
	if _head_idx < 0:
		return
	var att := _head_socket()
	var nose := MeshInstance3D.new()
	nose.name = "NoseLeather"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	nose.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cat.get("nose_color")
	mat.roughness = 0.42
	nose.material_override = mat
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	att.add_child(nose)
	# Wide and shallow, sitting on the muzzle rather than stuck out past it.
	var outward := _away
	var tip := _nose - _away * 0.008 + _up * -0.006
	nose.transform = Transform3D(_bone_basis(_basis_facing(outward)).orthonormalized(), _bone_point(tip))
	nose.scale = Vector3(0.022, 0.013, 0.009)


func apply_state(cat: Node, delta: float) -> void:
	if tree == null:
		return
	var spd := Vector2(cat.velocity.x, cat.velocity.z).length()
	var sf := clampf(spd / maxf(float(cat.get("sprint_speed")), 0.01), 0.0, 1.0)
	var state := str(cat.get("anim_state"))
	var moving := state in ["walk", "stalk", "sprint"]
	_set_blend("gait", sf)
	_set_blend("idle_move", 1.0 if moving and state != "stalk" else 0.0)
	_set_blend("stalk_mix", 1.0 if state == "stalk" else 0.0)
	_set_blend("sit_mix", float(cat.get("_sit_k")))
	_set_blend("lounge_mix", float(cat.get("_lounge_k")))
	_set_blend("strike_mix", 1.0 if state == "strike" else 0.0)
	_set_blend("pounce_mix", float(cat.get("pounce_amount")))
	_set_blend("land_mix", float(cat.get("land_amount")))
	var meow := float(cat.get("meow_k"))
	_set_blend("meow_mix", clampf(meow, 0.0, 1.0))
	var manner := str(cat.get("manner"))
	var manner_k := clampf(float(cat.get("manner_k")), 0.0, 1.0)
	for manner_name in CatManners.CLIP_NAMES:
		_set_blend(manner_name + "_mix", manner_k if manner == manner_name else 0.0)
	if meow > 0.0:
		cat.set("meow_k", maxf(0.0, meow - delta * 1.6))


func _set_blend(key: String, value: float) -> void:
	if not _blends.has(key):
		return
	tree.set(_blends[key], value)


func adopt_whiskers(cat: Node) -> void:
	var head := cat.get("_head") as Node3D
	if head == null or skeleton == null or _head_idx < 0:
		return
	var att := _head_socket()
	var found: Array[MeshInstance3D] = []
	for child in head.get_children():
		if str(child.name).begins_with("Whisker"):
			found.append(child as MeshInstance3D)
	var mesh := _whisker_mesh()
	if found.is_empty():
		_drop_head_cylinders(head)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.74, 0.66)
	mat.roughness = 0.55
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic_specular = 0.08
	var per_side := maxi(found.size() / 2, 1)
	for i in found.size():
		var mi := found[i]
		head.remove_child(mi)
		att.add_child(mi)
		var side := -1.0 if i < per_side else 1.0
		var k := i % per_side
		var t := float(k) / float(maxi(per_side - 1, 1))
		var fan := lerpf(-0.16, 0.14, t)
		var dir := (_right * side + _away * 0.18 + _up * fan).normalized()
		var root := _nose - _away * 0.02 + _right * side * 0.02 + _up * lerpf(-0.012, 0.008, t)
		var local_root := _bone_point(root)
		var local_dir := (_bone_point(root + dir) - local_root).normalized()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(_basis_from_x(local_dir), local_root)
	_drop_head_cylinders(head)


func _drop_head_cylinders(head: Node) -> void:
	# Anything still parented to the ellipsoid head is the legacy bar.
	# The sculpted whiskers live on HeadSocket.
	if head == null:
		return
	var doomed: Array[MeshInstance3D] = []
	for child in head.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is CylinderMesh or str(mi.name).begins_with("Whisker"):
			doomed.append(mi)
	for mi in doomed:
		mi.visible = false
		head.remove_child(mi)
		mi.queue_free()


func _basis_from_x(dir: Vector3) -> Basis:
	var x := dir.normalized()
	var up := Vector3.UP
	if absf(x.dot(up)) > 0.92:
		up = Vector3.FORWARD
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _whisker_mesh() -> ArrayMesh:
	# A short tapered curve along local +X. Thin enough to read as a
	# hair, long enough to see at the portrait distance.
	var rings := 7
	var segs := 5
	var length := 0.11
	var curl := 0.016
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for i in rings:
		var t := float(i) / float(rings - 1)
		var p := Vector3(t * length, sin(t * PI) * curl - t * t * 0.018, 0.0)
		centers.append(p)
		radii.append(lerpf(0.0024, 0.00055, t))
	for i in rings:
		var tangent: Vector3
		if i == 0:
			tangent = (centers[1] - centers[0]).normalized()
		elif i == rings - 1:
			tangent = (centers[i] - centers[i - 1]).normalized()
		else:
			tangent = (centers[i + 1] - centers[i - 1]).normalized()
		var side := Vector3.UP.cross(tangent)
		if side.length_squared() < 0.0001:
			side = Vector3.BACK.cross(tangent)
		side = side.normalized()
		var nup := tangent.cross(side).normalized()
		for s in segs:
			var a := TAU * float(s) / float(segs)
			var n := (side * cos(a) + nup * sin(a)).normalized()
			normals.append(n)
			positions.append(centers[i] + n * radii[i])
	for i in rings - 1:
		for s in segs:
			var a := i * segs + s
			var b := i * segs + ((s + 1) % segs)
			var c := (i + 1) * segs + s
			var d := (i + 1) * segs + ((s + 1) % segs)
			indices.append_array([a, c, d, a, d, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
