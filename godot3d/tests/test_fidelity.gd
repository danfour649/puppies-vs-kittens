extends Node
## Fur, eyes, whiskers, and the gait blend. Headless, state only.
## Run: godot --headless --path godot3d res://tests/test_fidelity.tscn

const CatScript := preload("res://cat_kit/cat.gd")

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
	print("FIDELITY")
	check(VisualQuality.shell_count_for("high") > VisualQuality.shell_count_for("low"), "high tier grows more fur than low")
	check(VisualQuality.shell_count_for("low") >= 2, "low tier still has a coat (%d)" % VisualQuality.shell_count_for("low"))
	var cat = CatScript.new()
	add_child(cat)
	check(cat.fur_shells >= VisualQuality.fur_shells(), "willie wears a fur shell per layer (%d)" % cat.fur_shells)
	var sculpt = cat.get("_sculpt")
	check(sculpt != null and sculpt.body != null and sculpt.body.mesh is ArrayMesh, "willie wears the sculpted mesh")
	if sculpt != null and sculpt.body != null and sculpt.body.mesh != null:
		var verts: PackedVector3Array = sculpt.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		check(verts.size() > 1500, "sculpted cage is a real mesh (%d verts)" % verts.size())
		check(sculpt.skeleton != null and sculpt.skeleton.get_bone_count() >= 20, "skeleton has a spine, legs and tail (%d)" % sculpt.skeleton.get_bone_count())
		check(sculpt.tree != null, "animation blend tree is wired")
	check(cat.whisker_count >= 12, "willie has whiskers (%d)" % cat.whisker_count)
	var whiskers := cat.find_children("Whisker*", "MeshInstance3D", true, false)
	var longest := 0.0
	var on_head := true
	if sculpt != null and sculpt.skeleton != null:
		var sk: Skeleton3D = sculpt.skeleton
		var head_p: Vector3 = sk.to_global(sk.get_bone_global_rest(sk.find_bone("head")).origin)
		var tail_p: Vector3 = sk.to_global(sk.get_bone_global_rest(sk.find_bone("tail04")).origin)
		for w in whiskers:
			var mi := w as MeshInstance3D
			longest = maxf(longest, mi.get_aabb().size.length())
			if mi.global_position.distance_to(head_p) > mi.global_position.distance_to(tail_p):
				on_head = false
	check(longest > 0.05 and longest < 0.28, "whiskers are short strands (%.3f)" % longest)
	check(on_head, "whiskers sit on the head rather than the back")
	var stray := 0
	for node in cat.find_children("*", "MeshInstance3D", true, false):
		var bar := node as MeshInstance3D
		if bar.is_visible_in_tree() and bar.mesh is CylinderMesh and (bar.mesh as CylinderMesh).height > 0.08:
			stray += 1
	check(stray == 0, "no long cylinder is left visible (%d)" % stray)
	cat.play_meow()
	check(cat.meow_k > 0.9, "play_meow opens the jaw clip (%.2f)" % cat.meow_k)
	check(sculpt != null and sculpt._blends.has("meow_mix"), "meow jaw clip is wired into the blend tree")
	check(cat._pupils.size() == 2, "both eyes have a pupil")
	var corneas := 0
	for eye in cat._eyes:
		for child in (eye as Node).get_children():
			if str(child.name) == "Cornea":
				corneas += 1
	check(corneas == 2, "both eyes have a cornea")
	var ear_sss := true
	for ear in cat._inner_ears:
		var mat := (ear as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null or not mat.subsurf_scatter_enabled:
			ear_sss = false
	check(ear_sss, "inner ears use subsurface scatter")
	var torso := cat._torso.material_override as StandardMaterial3D
	check(torso.albedo_color.is_equal_approx(Color(1, 1, 1)), "fur pass left the torso albedo white")
	# Mid speed is the trot band of the blend (walk below ~0.34, bound above ~0.7).
	cat.anim_state = "walk"
	cat.velocity = Vector3(0, 0, cat.sprint_speed * 0.5)
	for i in 40:
		cat._update_pose(0.05)
	check(cat.gait_trot > 0.25, "trot weight is in the blend at mid speed (%.2f)" % cat.gait_trot)
	check(absf(cat.gait_walk + cat.gait_trot + cat.gait_bound - 1.0) < 0.05, "gait weights sum to one")
	cat.anim_state = "idle"
	var idle_pupil: float = (cat._pupils[0] as MeshInstance3D).scale.x
	cat.anim_state = "stalk"
	cat._update_pose(0.05)
	var stalk_pupil: float = (cat._pupils[0] as MeshInstance3D).scale.x
	check(idle_pupil > stalk_pupil + 0.1, "pupils tighten from idle (%.2f) to stalk (%.2f)" % [idle_pupil, stalk_pupil])
	var aggie = CatScript.new()
	aggie.set_character("aggie")
	add_child(aggie)
	check(aggie.fur_shells >= VisualQuality.fur_shells(), "aggie wears the same fur pass (%d)" % aggie.fur_shells)
	check(aggie.get("_sculpt") != null, "aggie wears the sculpted body")
	check(aggie.whisker_count == cat.whisker_count, "aggie has whiskers too")
	print("FIDELITY DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
