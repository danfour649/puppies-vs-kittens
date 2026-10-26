class_name CatMannerPose
extends RefCounted

## Local +Z lifts this rig's tail up and back. The old world-up bend
## swung it forward over the shoulders.
const TAIL_LIFT := Vector3.BACK
## Local +X cranes the head toward the ceiling. Stay inside a small range.
const SPINE_UP := Vector3(1, 0, 0)
## Radians on tail00..tail07 for a greeting. The rump bones lift the
## mesh's own tail; the tip stays nearly straight so it cannot twist
## into a stick.
const GREET_TAIL: Array[float] = [0.72, 0.42, 0.22, 0.1, 0.02, 0.0, -0.03, -0.05]
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
			_bend(sk, bones, "jaw", 0.7 * jab * k)
			_bend(sk, bones, "head", 0.1 * sin(time_s * 18.0) * k)
			_bend(sk, bones, "neck", 0.06 * sin(time_s * 18.0) * k)
			_ears(sk, bones, -0.22 * k, 0.05 * sin(time_s * 32.0) * k)
			_tail_curve(sk, bones, 0.08 * k, 0.22 * sin(time_s * 26.0) * k)
		"wiggle":
			var w := sin(time_s * 14.0) * k
			_curve_spin(sk, bones.get("spine_chain", []), w, 0.1, 0.03)
			_curve_spin(sk, bones.get("tail_chain", []), -w, 0.12, 0.45)
			_bend(sk, bones, "thigh_l", 0.16 * w)
			_bend(sk, bones, "thigh_r", -0.16 * w)
			_ears(sk, bones, -0.2 * k, 0.0)
		"zoomies":
			var run := time_s * 18.0
			_curve_bend(sk, bones.get("spine_chain", []), 0.04 * k, 0.02 * k)
			_tail_curve(sk, bones, -0.16 * k, 0.12 * sin(run) * k)
			_ears(sk, bones, 0.28 * k, 0.0)
			_bend(sk, bones, "arm_l", 0.6 * sin(run) * k)
			_bend(sk, bones, "arm_r", 0.6 * sin(run + PI) * k)
			_bend(sk, bones, "thigh_l", 0.55 * sin(run + PI) * k)
			_bend(sk, bones, "thigh_r", 0.55 * sin(run) * k)
		"blink":
			var pulse := pow(maxf(0.0, sin(time_s * 1.7)), 10.0) * k
			_bend(sk, bones, "head", 0.22 * pulse)
			_bend(sk, bones, "neck", 0.08 * pulse)
			_ears(sk, bones, 0.05 * pulse, 0.42 * pulse)
			_tail_curve(sk, bones, 0.12 * pulse, 0.18 * pulse)
		"groom":
			_spin(sk, bones, "head", 0.45 * k)
			_bend(sk, bones, "head", 0.16 * k)
			_bend(sk, bones, "neck", 0.08 * k)
			_bend(sk, bones, "arm_l", -0.5 * k)
			_bend(sk, bones, "paw_l", 0.4 * k)
			_ears(sk, bones, 0.06 * k, 0.22 * k)
			_tail_curve(sk, bones, 0.1 * k, 0.28 * k)
		"knead":
			var left := maxf(0.0, sin(time_s * 3.4))
			var right := maxf(0.0, sin(time_s * 3.4 + PI))
			_bend(sk, bones, "paw_l", 0.85 * left * k)
			_bend(sk, bones, "paw_r", 0.85 * right * k)
			_bend(sk, bones, "arm_l", 0.35 * left * k)
			_bend(sk, bones, "arm_r", 0.35 * right * k)
			_ears(sk, bones, 0.08 * k, 0.22 * k)
			_tail_curve(sk, bones, 0.15 * k, 0.4 * sin(time_s * 1.6) * k)
		"loaf":
			# Local +X folds the elbows and hocks on this rig. Local +Y
			# on the thigh brings the hind paw forward without lifting it.
			# The right thigh is mirrored, so its yaw flips.
			_local_named(sk, "upper_arm.L", Vector3.RIGHT, 0.5 * k)
			_local_named(sk, "upper_arm.R", Vector3.RIGHT, 0.5 * k)
			_local_named(sk, "forearm.L", Vector3.RIGHT, 0.65 * k)
			_local_named(sk, "forearm.R", Vector3.RIGHT, 0.65 * k)
			_local_named(sk, "thigh.L", Vector3.UP, 0.45 * k)
			_local_named(sk, "thigh.R", Vector3.UP, -0.45 * k)
			_local_named(sk, "shin.L", Vector3.RIGHT, -0.7 * k)
			_local_named(sk, "shin.R", Vector3.RIGHT, -0.7 * k)
			_local_named(sk, "hock.L", Vector3.RIGHT, -0.35 * k)
			_local_named(sk, "hock.R", Vector3.RIGHT, -0.35 * k)
			_curve_bend(sk, bones.get("spine_chain", []), -0.04 * k, -0.02 * k)
			_ears(sk, bones, 0.02 * k, 0.06 * k)
			_tail_curve(sk, bones, 0.1 * k, 0.16 * k)
		"greet":
			_tail_curve(sk, bones, 1.05 * k, 0.08 * k)
			_bend(sk, bones, "head", -0.03 * k)
			_ears(sk, bones, -0.18 * k, 0.0)
		"ambush":
			_curve_bend(sk, bones.get("spine_chain", []), -0.06 * k, -0.12 * k)
			_bend(sk, bones, "head", 0.1 * k)
			_bend(sk, bones, "neck", 0.05 * k)
			_bend(sk, bones, "arm_l", 0.28 * k)
			_bend(sk, bones, "arm_r", 0.28 * k)
			_bend(sk, bones, "thigh_l", -0.22 * k)
			_bend(sk, bones, "thigh_r", -0.22 * k)
			_ears(sk, bones, -0.18 * k, 0.0)
			_tail_curve(sk, bones, -0.1 * k, 0.04 * k)


## Breathing, a tail that is never quite still, ears toward a sound,
## and a head that follows something nearby. `ear_out` spreads the
## ears; manners that own the head pass zeros for the look.
static func apply_life(sk: Skeleton3D, bones: Dictionary, time_s: float, breath: float, tail_k: float, ear_yaw: float, ear_twitch: float, head_yaw: float, head_pitch: float) -> void:
	var inhale := sin(time_s * TAU * 0.42)
	_curve_bend(sk, bones.get("spine_chain", []), 0.02 * inhale * breath, 0.045 * inhale * breath)
	_bend(sk, bones, "head", -0.02 * inhale * breath + clampf(head_pitch, -0.05, 0.08))
	_spin(sk, bones, "head", clampf(head_yaw, -0.35, 0.35))
	_spin(sk, bones, "neck", head_yaw * 0.35)
	var sway := sin(time_s * 1.4) * 0.12 * tail_k
	var flick := pow(maxf(0.0, sin(time_s * 0.73)), 16.0) * sin(time_s * 23.0) * 0.55 * tail_k
	_curve_spin(sk, bones.get("tail_chain", []), sway, 0.25, 1.0)
	var chain: Array = bones.get("tail_chain", [])
	if chain.size() >= 2:
		_turn(sk, int(chain[chain.size() - 1]), flick, true)
		_turn(sk, int(chain[chain.size() - 2]), flick * 0.45, true)
	_ears(sk, bones, ear_twitch * 0.2, absf(ear_twitch) * 0.15)
	_spin(sk, bones, "ear_l", ear_yaw)
	_spin(sk, bones, "ear_r", ear_yaw)


static func _ears(sk: Skeleton3D, bones: Dictionary, pitch: float, spread: float) -> void:
	_bend(sk, bones, "ear_l", pitch)
	_bend(sk, bones, "ear_r", pitch)
	_spin(sk, bones, "ear_l", -spread)
	_spin(sk, bones, "ear_r", spread)


## `base` is the lift at the rump, `side` swings the tail off to one side.
## A positive base stands the chain into a question mark: up from the
## rump, then a hook at the tip. One bone alone left the tip hanging.
static func _tail_curve(sk: Skeleton3D, bones: Dictionary, base: float, side: float) -> void:
	var chain: Array = bones.get("tail_chain", [])
	if chain.is_empty():
		_local(sk, int(bones.get("tail", -1)), TAIL_LIFT, clampf(base, -0.5, 1.2))
		_local(sk, int(bones.get("tail", -1)), Vector3.UP, clampf(side, -0.3, 0.3))
		return
	var last := chain.size() - 1
	if absf(base) > 0.6:
		var sgn := signf(base)
		var scale := absf(base) / 1.05
		for i in chain.size():
			var u := float(i) / float(maxi(last, 1))
			var ang := sgn * GREET_TAIL[mini(i, GREET_TAIL.size() - 1)] * scale
			_local(sk, int(chain[i]), TAIL_LIFT, clampf(ang, -1.4, 1.4))
			_local(sk, int(chain[i]), Vector3.UP, clampf(side * u, -0.2, 0.2))
		return
	for i in chain.size():
		var u := float(i) / float(maxi(last, 1))
		var lift := base if i == 0 else (-absf(base) * 0.2 if i == last else 0.0)
		_local(sk, int(chain[i]), TAIL_LIFT, clampf(lift, -0.34, 0.55))
		_local(sk, int(chain[i]), Vector3.UP, clampf(side * u, -0.25, 0.25))


static func _curve_bend(sk: Skeleton3D, chain: Array, at_root: float, at_tip: float) -> void:
	if chain.is_empty():
		return
	var last := chain.size() - 1
	for i in chain.size():
		var u := float(i) / float(maxi(last, 1))
		_local(sk, int(chain[i]), SPINE_UP, clampf(lerpf(at_root, at_tip, u), -0.14, 0.14))


static func _curve_spin(sk: Skeleton3D, chain: Array, amount: float, at_root: float, at_tip: float) -> void:
	if chain.is_empty() or absf(amount) < 0.0001:
		return
	var last := chain.size() - 1
	for i in chain.size():
		var u := float(i) / float(maxi(last, 1))
		_local(sk, int(chain[i]), Vector3.UP, clampf(amount * lerpf(at_root, at_tip, u), -0.35, 0.35))


static func _local(sk: Skeleton3D, idx: int, axis: Vector3, radians: float) -> void:
	if idx < 0 or absf(radians) < 0.0001:
		return
	var q := sk.get_bone_pose_rotation(idx)
	q *= Quaternion(axis.normalized(), radians)
	sk.set_bone_pose_rotation(idx, q)


static func _local_named(sk: Skeleton3D, bone_name: String, axis: Vector3, radians: float) -> void:
	_local(sk, sk.find_bone(bone_name), axis, radians)


static func _bend(sk: Skeleton3D, bones: Dictionary, role: String, radians: float) -> void:
	if not bones.has(role):
		return
	if role == "head" or role == "neck":
		# Downward pitch tucks the skull into the shoulders. The upward
		# limit stays small so a greet cannot crane at the ceiling.
		radians = clampf(radians, -0.05, 0.1)
	elif role.begins_with("arm") or role.begins_with("thigh") or role.begins_with("paw"):
		radians = clampf(radians, -0.5, 0.5)
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
