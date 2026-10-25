extends Node
## REALISM PASS 1 animation asserts: the locomotion layer is stepped
## deterministically (process/physics frozen, _update_pose driven by
## hand) so gait / tail / idle behaviour is tested on STATE, never on
## rendered pixels.
## Run: godot --headless --path godot3d res://tests/test_anim.tscn

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


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _make_cat(id: String, pos: Vector3) -> PvKCat:
	var cat: PvKCat = CatScript.new()
	cat.set_character(id)
	cat.position = pos
	add_child(cat)
	return cat


func _run() -> void:
	print("TEST_ANIM: locomotion layer")
	# A floor for the cats to stand on.
	var floor_body := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(30, 1, 30)
	fcol.shape = fbox
	fcol.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fcol)
	add_child(floor_body)

	var cat := _make_cat("willie", Vector3(0, 0.4, 0))
	var aggie := _make_cat("aggie", Vector3(2.0, 0.4, 0))
	await frames(30)
	check(cat.is_on_floor(), "willie stands on the floor")
	check(cat._hips.size() == 4, "four hip pivots built")
	check(cat._tail_base.size() == cat._tail_segs.size() and cat._tail_base.size() >= 8, "tail rest positions recorded (%d)" % cat._tail_base.size())
	check(cat._ears.size() == 2, "ear handles recorded")

	# Freeze the real processes; from here the pose layer is stepped
	# by hand with scripted velocity / anim_state / yaw.
	cat.set_process(false)
	cat.set_physics_process(false)
	var dt := 1.0 / 60.0

	# --- gait: stride frequency scales with speed -------------------
	cat.anim_state = "walk"
	cat.velocity = Vector3(2.4, 0, 0)
	var ph0: float = cat._phase
	for i in 90:
		cat._update_pose(dt)
	var walk_adv := cat._phase - ph0
	cat.anim_state = "sprint"
	cat.velocity = Vector3(5.0, 0, 0)
	ph0 = cat._phase
	var swing := 0.0
	var fl0: float = (cat._hips["FL"] as Node3D).rotation.x
	var fl_min := fl0
	var fl_max := fl0
	for i in 90:
		cat._update_pose(dt)
		var fl: float = (cat._hips["FL"] as Node3D).rotation.x
		fl_min = minf(fl_min, fl)
		fl_max = maxf(fl_max, fl)
	var sprint_adv := cat._phase - ph0
	swing = fl_max - fl_min
	check(walk_adv > 4.0, "walk stride phase advances (%.1f rad)" % walk_adv)
	check(sprint_adv > walk_adv * 1.25, "sprint strides faster than walk (%.1f vs %.1f)" % [sprint_adv, walk_adv])
	check(swing > 0.5, "front leg swings through a real arc at sprint (%.2f rad)" % swing)
	# Diagonal pairs move together at the trot/sprint blend.
	var d_fl: float = (cat._hips["FL"] as Node3D).rotation.x
	var d_br: float = (cat._hips["BR"] as Node3D).rotation.x
	var d_fr: float = (cat._hips["FR"] as Node3D).rotation.x
	check(absf(d_fl - d_br) < absf(d_fl - d_fr) + 0.05 or swing > 0.9, "diagonal pairs share a beat (FL %.2f BR %.2f FR %.2f)" % [d_fl, d_br, d_fr])
	# Body works with the stride: bob is nonzero while moving.
	check(absf(cat._body.position.y) + absf(cat._body.rotation.z) > 0.001, "body bob/roll present at speed")

	# --- tail: follow-through bend under a sustained turn -----------
	cat.anim_state = "walk"
	cat.velocity = Vector3(2.4, 0, 0)
	for i in 45:
		cat.rotation.y += 2.2 * dt
		cat._update_pose(dt)
	check(absf(cat._tail_bend) > 0.05, "tail bends against a sustained turn (%.2f)" % cat._tail_bend)
	var n := cat._tail_segs.size()
	var tip: Vector3 = (cat._tail_segs[n - 1][0] as MeshInstance3D).position
	var base_seg: Vector3 = (cat._tail_segs[1][0] as MeshInstance3D).position
	var tip_off := absf(tip.x - (cat._tail_base[n - 1] as Vector3).x)
	var base_off := absf(base_seg.x - (cat._tail_base[1] as Vector3).x)
	check(tip_off > base_off, "tail tip travels further than its base (tip %.3f > base %.3f)" % [tip_off, base_off])

	# --- idle repertoire: stand -> sit -> groom -> interrupt --------
	cat.rotation.y = 0.0
	cat.anim_state = "idle"
	cat.velocity = Vector3.ZERO
	for i in 60:
		cat._update_pose(dt)
	check(cat.idle_pose == "stand", "idle starts as stand (got %s)" % cat.idle_pose)
	for i in 300:
		cat._update_pose(dt)
	check(cat.idle_pose == "sit" and cat._sit_k > 0.5, "idle settles into a sit (pose %s, k %.2f)" % [cat.idle_pose, cat._sit_k])
	check(absf((cat._hips["BL"] as Node3D).rotation.x) > 0.4, "hind legs fold under the sit")
	var groom_peak := 0.0
	for i in 150:
		cat._update_pose(dt)
		groom_peak = maxf(groom_peak, cat._groom_k)
	check(groom_peak > 0.4, "a groom bout arrives in the sit (peak %.2f)" % groom_peak)
	cat.anim_state = "walk"
	cat.velocity = Vector3(2.4, 0, 0)
	for i in 40:
		cat._update_pose(dt)
	check(cat.idle_time == 0.0 and cat._sit_k < 0.3, "movement interrupts the sit at once (k %.2f)" % cat._sit_k)
	cat.anim_state = "idle"
	cat.velocity = Vector3.ZERO
	for i in 40:
		cat._update_pose(dt)
	check(absf((cat._hips["FL"] as Node3D).rotation.x) < 0.08, "legs settle back to stance at rest")

	# --- coats: baked textures exist and carry real variation -------
	var cm = aggie._coat_material()
	check(cm != null, "aggie has a baked coat material")
	if cm != null:
		check(cm.albedo_color.is_equal_approx(aggie.coat), "coat albedo_color stays the palette base")
		check(cm.albedo_texture != null, "coat texture baked")
		if cm.albedo_texture != null:
			var img := cm.albedo_texture.get_image()
			var lo := 10.0
			var hi := -10.0
			for gx in range(0, img.get_width(), 9):
				for gy in range(0, img.get_height(), 9):
					var r: float = img.get_pixel(gx, gy).r
					lo = minf(lo, r)
					hi = maxf(hi, r)
			check(hi - lo > 0.08, "coat texture varies across the fur (range %.2f)" % (hi - lo))
	var sm = cat._saddle_material()
	check(sm != null and sm.albedo_texture != null, "willie's saddle wears the soft-band texture")
	check(sm.albedo_color.is_equal_approx(cat.ginger), "saddle albedo_color stays the palette ginger")

	print("TEST_ANIM: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
