extends SkeletonModifier3D
## Procedural layer on top of the AnimationTree: the hiss arch, the
## head look, and the manner fallbacks. A manner clip, when the rig
## has one, wins. Otherwise CatMannerPose drives the mapped bones.

var host: Node
var _bones: Dictionary = {}
var _mapped := false


func _process_modification() -> void:
	if host == null:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if not _mapped:
		_bones = CatBoneMap.resolve(sk)
		_mapped = true
	var hiss := float(host.get("_hiss_k"))
	if hiss > 0.01:
		_add(sk, "spine2", Vector3(-0.45 * hiss, 0.0, 0.0))
		_add(sk, "spine3", Vector3(-0.25 * hiss, 0.0, 0.0))
		_add(sk, "tail00", Vector3(-0.7 * hiss, 0.0, 0.0))
	var head := host.get("_head") as Node3D
	if head != null:
		var pitch := clampf(head.rotation.x * 0.45, -0.16, 0.16)
		var yaw := clampf(head.rotation.y * 0.55, -0.4, 0.4)
		_add(sk, "head", Vector3(pitch, yaw, 0.0))
	var ears: Array = host.get("_ears")
	if ears.size() == 2:
		for i in 2:
			var rot: Vector3 = ears[i][2] if false else (ears[i][0] as Node3D).rotation
			var bone := "ear.L" if i == 0 else "ear.R"
			_add(sk, bone, Vector3(rot.x * 0.35, 0.0, rot.z * 0.35))
	var manner := str(host.get("manner"))
	var amount := float(host.get("manner_k"))
	var phase := float(host.get("manner_phase"))
	var time_s := phase if phase >= 0.0 else Time.get_ticks_msec() / 1000.0
	_apply_life(sk, manner, time_s)
	if manner != "" and amount > 0.01 and not _clip_owns(manner):
		CatMannerPose.apply(sk, _bones, manner, amount, time_s)


func _apply_life(sk: Skeleton3D, manner: String, time_s: float) -> void:
	var cat := host as Node3D
	if cat == null:
		return
	var head_owned := manner in ["chatter", "groom", "greet", "blink", "ambush"]
	var tail_owned := manner in ["greet", "wiggle", "loaf", "groom"]
	var ear_owned := manner in ["chatter", "blink", "zoomies", "greet", "groom"]
	var breath := 0.3 if manner != "" else 1.0
	var tail_k := 0.0 if tail_owned else (0.35 if manner != "" else 1.0)
	var look := _look_target(cat) if not head_owned else Vector3.INF
	var heard := _heard_at(cat) if not ear_owned else Vector3.INF
	var head_yaw := 0.0
	var head_pitch := 0.0
	if look != Vector3.INF:
		var to := look - cat.global_position
		head_yaw = clampf(_signed_yaw(cat.forward_dir(), to), -0.65, 0.65)
		head_pitch = clampf(-to.y / maxf(to.length(), 0.25) * 0.45, -0.3, 0.2)
	elif manner == "":
		head_yaw = sin(time_s * 0.35) * 0.06
	var ear_yaw := 0.0
	var twitch := 0.0
	if heard != Vector3.INF:
		ear_yaw = clampf(_signed_yaw(cat.forward_dir(), heard - cat.global_position), -0.7, 0.7)
		twitch = 0.8
	elif manner == "":
		twitch = pow(maxf(0.0, sin(time_s * 0.9 + 1.3)), 20.0)
	CatMannerPose.apply_life(sk, _bones, time_s, breath, tail_k, ear_yaw, twitch, head_yaw, head_pitch)


func _look_target(cat: Node3D) -> Vector3:
	return _nearest(cat, "prey", 4.2)


func _heard_at(cat: Node3D) -> Vector3:
	var best := Vector3.INF
	var best_d := 6.5
	var tree := cat.get_tree()
	if tree == null:
		return best
	for n in tree.get_nodes_in_group("creature_voice"):
		var player := n as AudioStreamPlayer3D
		if player == null or not player.playing or _under(player, cat):
			continue
		var d := cat.global_position.distance_to(player.global_position)
		if d < best_d and d > 0.15:
			best_d = d
			best = player.global_position
	return best


func _nearest(cat: Node3D, group: String, reach: float) -> Vector3:
	var best := Vector3.INF
	var best_d := reach
	var tree := cat.get_tree()
	if tree == null:
		return best
	for n in tree.get_nodes_in_group(group):
		var node := n as Node3D
		if node == null or node == cat or _under(node, cat):
			continue
		if str(node.get("state")) == "caught":
			continue
		var d := cat.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node.global_position
	return best


func _under(node: Node, host_node: Node) -> bool:
	var cursor: Node = node
	while cursor != null:
		if cursor == host_node:
			return true
		cursor = cursor.get_parent()
	return false


func _signed_yaw(fwd: Vector3, to: Vector3) -> float:
	var flat_f := Vector3(fwd.x, 0.0, fwd.z)
	var flat_t := Vector3(to.x, 0.0, to.z)
	if flat_f.length() < 0.01 or flat_t.length() < 0.05:
		return 0.0
	flat_f = flat_f.normalized()
	flat_t = flat_t.normalized()
	return atan2(flat_f.cross(flat_t).y, flat_f.dot(flat_t))


func _clip_owns(manner: String) -> bool:
	var clips: Variant = host.get("manner_clips")
	return clips is Dictionary and bool((clips as Dictionary).get(manner, false))


func _add(sk: Skeleton3D, bone: String, euler: Vector3) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0 or euler.length_squared() < 0.000001:
		return
	var q := sk.get_bone_pose_rotation(idx)
	q *= Quaternion.from_euler(euler)
	sk.set_bone_pose_rotation(idx, q)
