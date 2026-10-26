extends SkeletonModifier3D
## Procedural layer on top of the AnimationTree: the hiss arch, and a
## share of the head look the pose system already computes for tests.

var host: Node


func _process_modification() -> void:
	if host == null:
		return
	var sk := get_skeleton()
	if sk == null:
		return
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


func _add(sk: Skeleton3D, bone: String, euler: Vector3) -> void:
	var idx := sk.find_bone(bone)
	if idx < 0 or euler.length_squared() < 0.000001:
		return
	var q := sk.get_bone_pose_rotation(idx)
	q *= Quaternion.from_euler(euler)
	sk.set_bone_pose_rotation(idx, q)
