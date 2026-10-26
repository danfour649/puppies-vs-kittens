class_name CatSculpt
extends RefCounted

const PoseMod := preload("res://cat_kit/cat_pose_modifier.gd")
## Swaps the visible ellipsoid body for the skinned cat in
## cat_kit/meshes/cat.glb. The ellipsoid nodes stay in the tree so the
## palette and pose tests still have their handles; they are hidden.
## The AnimationTree is the blend the clips actually play through.

const MESH_SCENE := "res://cat_kit/meshes/cat.glb"
const WILLIE_ALBEDO := "res://cat_kit/meshes/willie_albedo.png"
const AGGIE_ALBEDO := "res://cat_kit/meshes/aggie_albedo.png"
const NORMAL_MAP := "res://cat_kit/meshes/cat_normal.png"
const ROUGH_MAP := "res://cat_kit/meshes/cat_roughness.png"

var tree: AnimationTree
var body: MeshInstance3D
var skeleton: Skeleton3D
var _blends: Dictionary = {}


static func attach(cat: Node) -> void:
	var sculpt := CatSculpt.new()
	if not sculpt._build(cat):
		return
	cat.set("_sculpt", sculpt)


func _build(cat: Node) -> bool:
	var packed := load(MESH_SCENE) as PackedScene
	if packed == null:
		push_error("cat mesh missing")
		return false
	var root := packed.instantiate()
	root.name = "Sculpt"
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
	body.material_override = _coat_material(str(cat.get("character_id")) == "aggie")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hide_primitives(cat)
	_loops(player)
	tree = _make_tree(player, root)
	_seat_eyes(cat)
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
		mat.normal_scale = 0.35
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


func _seat_eyes(cat: Node) -> void:
	var idx := skeleton.find_bone("head")
	if idx < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "HeadSocket"
	att.bone_name = "head"
	skeleton.add_child(att)
	# Head bone points from the neck toward the nose. The sockets sit
	# a little in front of and below the bone tail, one each side.
	var eyes: Array = cat.get("_eyes")
	var side := -1.0
	for eye in eyes:
		var mi := eye as MeshInstance3D
		if mi == null:
			continue
		var keep_pos := mi.position
		mi.get_parent().remove_child(mi)
		att.add_child(mi)
		mi.position = Vector3(side * 0.055, 0.02, -0.04)
		mi.rotation = Vector3.ZERO
		mi.visible = true
		side = 1.0
		if keep_pos == Vector3.ZERO:
			pass


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
	if meow > 0.0:
		cat.set("meow_k", maxf(0.0, meow - delta * 1.6))


func _set_blend(key: String, value: float) -> void:
	if not _blends.has(key):
		return
	tree.set(_blends[key], value)


func adopt_whiskers(cat: Node) -> void:
	var head := cat.get("_head") as Node3D
	if head == null or skeleton == null:
		return
	var att := skeleton.get_node_or_null("HeadSocket") as Node3D
	if att == null:
		return
	for child in head.get_children():
		if not str(child.name).begins_with("Whisker"):
			continue
		var mi := child as MeshInstance3D
		var rot := mi.rotation
		head.remove_child(mi)
		att.add_child(mi)
		# The old whiskers were posed on the ellipsoid muzzle.
		# Sit them on the sculpted muzzle instead.
		var side := -1.0 if mi.position.x < 0.0 else 1.0
		mi.position = Vector3(side * 0.045, -0.01, -0.07)
		mi.rotation = rot
