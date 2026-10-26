class_name CatBoneMap
extends RefCounted
## Maps a live skeleton onto the roles the manner poses use.
##
## The other agent owns the Hunyuan meshes and rigs. This does not
## rename or edit those files. It reads whatever bones are already
## there and picks a role by name.
##
## The house sculpt spells them spine1, upper_arm.L, paw_f.L,
## tail00. A Hunyuan or Mixamo rig more often says Spine, LeftArm,
## LeftHand, Tail, Tail1, mixamorig:Head. Both resolve. A missing
## role is simply skipped, so a partial rig still blinks and greets.


const ROLE_ALIASES := {
	"spine_a": ["spine1", "spine", "spine_01", "spine01", "chest"],
	"spine_b": ["spine2", "spine_02", "spine02", "spine1", "upperchest"],
	"spine_c": ["spine3", "spine_03", "spine03", "spine2"],
	"neck": ["neck", "neck_01"],
	"head": ["head"],
	"jaw": ["jaw", "mouth", "chin"],
	"ear_l": ["ear_l", "earleft", "leftear"],
	"ear_r": ["ear_r", "earright", "rightear"],
	"arm_l": ["upper_arm_l", "upperarm_l", "leftarm", "arm_l", "shoulder_l"],
	"arm_r": ["upper_arm_r", "upperarm_r", "rightarm", "arm_r", "shoulder_r"],
	"paw_l": ["paw_f_l", "hand_l", "lefthand", "forepaw_l", "paw_l"],
	"paw_r": ["paw_f_r", "hand_r", "righthand", "forepaw_r", "paw_r"],
	"thigh_l": ["thigh_l", "upleg_l", "leftupleg", "hip_l"],
	"thigh_r": ["thigh_r", "upleg_r", "rightupleg", "hip_r"],
	"shin_l": ["shin_l", "leg_l", "leftleg", "calf_l"],
	"shin_r": ["shin_r", "leg_r", "rightleg", "calf_r"],
	"tail": ["tail00", "tail", "tail_01", "tail01", "tail1", "tail_1"],
	"tail_tip": ["tail04", "tail06", "tail_04", "tail4", "tail_end"],
}


static func normalize(bone_name: String) -> String:
	var s := bone_name.to_lower().strip_edges()
	for prefix in ["mixamorig:", "mixamorig_", "bip001_", "bip01_", "def-", "org-", "armature_"]:
		if s.begins_with(prefix):
			s = s.substr(prefix.length())
	s = s.replace(".", "_").replace(" ", "").replace("-", "_")
	return s


static func resolve(sk: Skeleton3D) -> Dictionary:
	var norms: PackedStringArray = PackedStringArray()
	for i in sk.get_bone_count():
		norms.append(normalize(sk.get_bone_name(i)))
	var out := {}
	for role in ROLE_ALIASES.keys():
		var aliases: Array = ROLE_ALIASES[role]
		var idx := _exact(norms, aliases)
		if idx >= 0:
			out[role] = idx
	_fill_keywords(sk, norms, out)
	out["tail_chain"] = _chain(sk, norms, "tail")
	out["spine_chain"] = _chain(sk, norms, "spine")
	return out


static func _exact(norms: PackedStringArray, aliases: Array) -> int:
	for alias in aliases:
		var want := str(alias)
		for i in norms.size():
			if norms[i] == want:
				return i
	return -1


static func _fill_keywords(sk: Skeleton3D, norms: PackedStringArray, out: Dictionary) -> void:
	var front_l: Array[int] = []
	var front_r: Array[int] = []
	var hind_l: Array[int] = []
	var hind_r: Array[int] = []
	for i in norms.size():
		var n := str(norms[i])
		var side := _side(n)
		if _is_ear(n):
			_put_missing(out, "ear_l" if side == "l" else "ear_r", i)
			continue
		if n == "head" or n.ends_with("_head"):
			_put_missing(out, "head", i)
		elif "jaw" in n or "mouth" in n or n.ends_with("chin"):
			_put_missing(out, "jaw", i)
		elif "neck" in n:
			_put_missing(out, "neck", i)
		elif _is_front(n):
			if side == "l":
				front_l.append(i)
			elif side == "r":
				front_r.append(i)
		elif _is_hind(n):
			if side == "l":
				hind_l.append(i)
			elif side == "r":
				hind_r.append(i)
	_assign_limb(sk, out, front_l, "arm_l", "paw_l")
	_assign_limb(sk, out, front_r, "arm_r", "paw_r")
	_assign_limb(sk, out, hind_l, "thigh_l", "shin_l")
	_assign_limb(sk, out, hind_r, "thigh_r", "shin_r")
	var spines := _chain(sk, norms, "spine")
	var keys: Array[String] = ["spine_a", "spine_b", "spine_c"]
	for i in mini(spines.size(), keys.size()):
		_put_missing(out, keys[i], int(spines[i]))
	var tails := _chain(sk, norms, "tail")
	if not tails.is_empty():
		_put_missing(out, "tail", int(tails[0]))
		_put_missing(out, "tail_tip", int(tails[tails.size() - 1]))


static func _assign_limb(sk: Skeleton3D, out: Dictionary, bones: Array[int], root_role: String, tip_role: String) -> void:
	if bones.is_empty():
		return
	bones.sort_custom(func(a: int, b: int) -> bool:
		return _depth(sk, a) < _depth(sk, b)
	)
	_put_missing(out, root_role, bones[0])
	_put_missing(out, tip_role, bones[bones.size() - 1])


static func _chain(sk: Skeleton3D, norms: PackedStringArray, token: String) -> Array:
	var found: Array[int] = []
	for i in norms.size():
		var n := str(norms[i])
		if token == "spine" and _is_spine(n):
			found.append(i)
		elif token == "tail" and "tail" in n:
			found.append(i)
	found.sort_custom(func(a: int, b: int) -> bool:
		return _depth(sk, a) < _depth(sk, b)
	)
	var plain: Array = []
	for idx in found:
		plain.append(idx)
	return plain


static func _is_spine(n: String) -> bool:
	return n.begins_with("spine") or n.begins_with("chest") or n == "upperchest"


static func _is_ear(n: String) -> bool:
	return "ear" in n and "hear" not in n


static func _is_front(n: String) -> bool:
	if _is_ear(n) or "tail" in n:
		return false
	return "arm" in n or "fore" in n or "hand" in n or "paw_f" in n or "clavicle" in n


static func _is_hind(n: String) -> bool:
	if "arm" in n or "hand" in n or "tail" in n or "ear" in n:
		return false
	return "thigh" in n or "shin" in n or "hock" in n or "upleg" in n or "calf" in n or "foot" in n or "toe" in n or "paw_h" in n or n.ends_with("leg") or "leg_" in n


static func _side(n: String) -> String:
	if n.ends_with("_l") or n.ends_with("left") or n.begins_with("left") or ".l" in n:
		return "l"
	if n.ends_with("_r") or n.ends_with("right") or n.begins_with("right") or ".r" in n:
		return "r"
	return ""


static func _depth(sk: Skeleton3D, idx: int) -> int:
	var d := 0
	var p := sk.get_bone_parent(idx)
	while p >= 0 and d < 32:
		d += 1
		p = sk.get_bone_parent(p)
	return d


static func _put_missing(out: Dictionary, role: String, idx: int) -> void:
	if not out.has(role):
		out[role] = idx
