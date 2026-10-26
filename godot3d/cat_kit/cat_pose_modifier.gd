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
		_add(sk, "head", Vector3(head.rotation.x * 0.45, head.rotation.y * 0.55, 0.0))
	var ears: Array = host.get("_ears")
	if ears.size() == 2:
		for i in 2:
			var rot: Vector3 = ears[i][2] if false else (ears[i][0] as Node3D).rotation
			var bone := "ear.L" if i == 0 else "ear.R"
			_add(sk, bone, Vector3(rot.x * 0.35, 0.0, rot.z * 0.35))
	var manner := str(host.get("manner"))
	var amount := float(host.get("manner_k"))
	if manner != "" and amount > 0.01 and not _clip_owns(manner):
		var phase := float(host.get("manner_phase"))
		var time_s := phase if phase >= 0.0 else Time.get_ticks_msec() / 1000.0
		CatMannerPose.apply(sk, _bones, manner, amount, time_s)


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
