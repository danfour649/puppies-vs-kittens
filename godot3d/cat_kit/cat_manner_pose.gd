class_name CatMannerPose
extends RefCounted
## Procedural fallbacks for the nine manners. They run only when
## the rig has no clip of that name. Rotations are in the bone's
## own frame: bend lifts the bone toward world up, spin turns it
## around world up. A Hunyuan skeleton with a normal spine, head,
## tail and legs picks up the same poses as the house sculpt.


static func apply(sk: Skeleton3D, bones: Dictionary, manner: String, amount: float, time_s: float) -> void:
	var k := clampf(amount, 0.0, 1.0)
	if k <= 0.001:
		return
	match manner:
		"chatter":
			var jab := absf(sin(time_s * 28.0))
			_bend(sk, bones, "jaw", 0.62 * jab * k)
			_bend(sk, bones, "head", 0.14 * sin(time_s * 22.0) * k)
		"wiggle":
			var w := sin(time_s * 14.0) * 0.42 * k
			_spin(sk, bones, "spine_a", w)
			_spin(sk, bones, "spine_b", w * 0.65)
			_bend(sk, bones, "thigh_l", 0.18 * sin(time_s * 14.0) * k)
			_bend(sk, bones, "thigh_r", -0.18 * sin(time_s * 14.0) * k)
		"zoomies":
			var run := time_s * 18.0
			_bend(sk, bones, "spine_b", -0.28 * k)
			_bend(sk, bones, "arm_l", 0.55 * sin(run) * k)
			_bend(sk, bones, "arm_r", 0.55 * sin(run + PI) * k)
			_bend(sk, bones, "thigh_l", 0.5 * sin(run + PI) * k)
			_bend(sk, bones, "thigh_r", 0.5 * sin(run) * k)
		"blink":
			var pulse := pow(maxf(0.0, sin(time_s * 1.7)), 10.0)
			_bend(sk, bones, "head", 0.2 * pulse * k)
			_bend(sk, bones, "ear_l", -0.28 * pulse * k)
			_bend(sk, bones, "ear_r", -0.28 * pulse * k)
		"groom":
			_spin(sk, bones, "head", 0.75 * k)
			_bend(sk, bones, "head", 0.32 * k)
			_bend(sk, bones, "arm_l", -0.85 * k)
			_bend(sk, bones, "paw_l", 0.55 * k)
		"knead":
			var left := maxf(0.0, sin(time_s * 3.4))
			var right := maxf(0.0, sin(time_s * 3.4 + PI))
			_bend(sk, bones, "paw_l", 0.7 * left * k)
			_bend(sk, bones, "paw_r", 0.7 * right * k)
			_bend(sk, bones, "arm_l", 0.28 * left * k)
			_bend(sk, bones, "arm_r", 0.28 * right * k)
		"loaf":
			_bend(sk, bones, "arm_l", 0.95 * k)
			_bend(sk, bones, "arm_r", 0.95 * k)
			_bend(sk, bones, "paw_l", 0.65 * k)
			_bend(sk, bones, "paw_r", 0.65 * k)
			_bend(sk, bones, "thigh_l", 0.45 * k)
			_bend(sk, bones, "thigh_r", 0.45 * k)
			_spin(sk, bones, "tail", 0.9 * k)
		"greet":
			var chain: Array = bones.get("tail_chain", [])
			if chain.is_empty():
				_bend(sk, bones, "tail", 1.05 * k)
				_bend(sk, bones, "tail_tip", 0.4 * k)
			else:
				for idx in chain:
					_bend_index(sk, int(idx), 0.42 * k)
			_bend(sk, bones, "head", -0.1 * k)
		"ambush":
			_bend(sk, bones, "spine_a", 0.4 * k)
			_bend(sk, bones, "spine_b", 0.32 * k)
			_bend(sk, bones, "head", 0.22 * k)
			_bend(sk, bones, "arm_l", 0.4 * k)
			_bend(sk, bones, "arm_r", 0.4 * k)
			_bend(sk, bones, "thigh_l", 0.35 * k)
			_bend(sk, bones, "thigh_r", 0.35 * k)


static func _bend(sk: Skeleton3D, bones: Dictionary, role: String, radians: float) -> void:
	if not bones.has(role):
		return
	_bend_index(sk, int(bones[role]), radians)


static func _bend_index(sk: Skeleton3D, idx: int, radians: float) -> void:
	_turn(sk, idx, radians, false)


static func _spin(sk: Skeleton3D, bones: Dictionary, role: String, radians: float) -> void:
	if not bones.has(role):
		return
	_turn(sk, int(bones[role]), radians, true)


static func _turn(sk: Skeleton3D, idx: int, radians: float, around_up: bool) -> void:
	if idx < 0 or absf(radians) < 0.0001:
		return
	var rest := sk.get_bone_rest(idx)
	var parent := sk.get_bone_parent(idx)
	var parent_basis := Basis.IDENTITY
	if parent >= 0:
		parent_basis = sk.get_bone_global_rest(parent).basis
	var up_local: Vector3 = rest.basis.inverse() * parent_basis.inverse() * Vector3.UP
	if up_local.length() < 0.02:
		return
	up_local = up_local.normalized()
	var axis: Vector3
	if around_up:
		axis = up_local
	else:
		# UP × up_local rotates the bone away from world up on this
		# importer's pose multiply, so the cross is the other way.
		axis = up_local.cross(Vector3.UP)
		if axis.length() < 0.08:
			axis = Vector3.RIGHT
		axis = axis.normalized()
	var q := sk.get_bone_pose_rotation(idx)
	q *= Quaternion(axis, radians)
	sk.set_bone_pose_rotation(idx, q)
