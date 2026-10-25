extends Node
## Headless smoke test for Willie and Aggie.
## Run: godot --headless --path godot3d res://tests/smoke.tscn
## Drives the real game through its input_override seam and asserts on
## STATE only — never on rendered pixels (headless readbacks lie).

const CatScript := preload("res://cat_kit/cat.gd")

var _pass := 0
var _fail := 0
var _game = null


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


func _run() -> void:
	print("SMOKE: loading main scene")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(10)
	var cat = _game.cat
	check(cat != null, "cat exists")
	check(_game.mice.size() == 7, "7 mice spawned (got %d)" % _game.mice.size())
	check(cat.anim_state == "idle", "cat starts idle (got %s)" % cat.anim_state)
	check(cat.is_on_floor(), "cat stands on the ground")
	check(cat.global_position.y > -0.1 and cat.global_position.y < 0.2, "cat at ground height (y=%.2f)" % cat.global_position.y)
	check(cat.species_name == "Willie", "cat is Willie (got %s)" % cat.species_name)
	# Willie's ruled palette (Daniel, 2026-10-25), asserted on the
	# values fed into the materials (data level only — rendered
	# readbacks lie headless). The SPEC LOCK checks below pin the
	# JSON itself to Daniel's constants, so the palette cannot
	# silently drift back to the photo-tuned defect values.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://cat_kit/cat_species.json"))
	var chars: Dictionary = data.get("characters", {})
	var willie: Dictionary = chars.get("willie", {})
	var pal: Dictionary = willie.get("palette", {})
	var j_coat: Array = pal.get("coat", [])
	var j_ginger: Array = pal.get("ginger", [])
	var j_eye: Array = pal.get("eye", [])
	var j_dark: Array = pal.get("ginger_dark", [])
	var want_dark := Color(float(j_dark[0]), float(j_dark[1]), float(j_dark[2]))
	var want_coat := Color(float(j_coat[0]), float(j_coat[1]), float(j_coat[2]))
	var want_ginger := Color(float(j_ginger[0]), float(j_ginger[1]), float(j_ginger[2]))
	var want_eye := Color(float(j_eye[0]), float(j_eye[1]), float(j_eye[2]))
	check(cat.coat.is_equal_approx(want_coat), "coat colour comes from Willie's ruled palette (got %s)" % cat.coat)
	var torso_mat := (cat._torso.material_override as StandardMaterial3D).albedo_color
	check(torso_mat.is_equal_approx(want_coat), "torso material albedo is the palette white (got %s)" % torso_mat)
	var saddle_mat := (cat._saddle_patch.material_override as StandardMaterial3D).albedo_color
	check(saddle_mat.is_equal_approx(want_ginger), "saddle patch albedo is the ruled ginger (got %s)" % saddle_mat)
	# SPEC LOCK — Daniel's ruling, 2026-10-25: his recorded values
	# are canonical; the photo-tuned values were a spec defect.
	check(want_ginger.is_equal_approx(Color(0.9098, 0.6863, 0.3294)), "SPEC LOCK: ginger is #E8AF54 (got %s)" % want_ginger)
	check(want_dark.is_equal_approx(Color(0.682, 0.515, 0.237)), "SPEC LOCK: ginger_dark is #AE833C, derived from #E8AF54 (got %s)" % want_dark)
	check(want_eye.is_equal_approx(Color(0.10, 0.08, 0.07)), "SPEC LOCK: Willie's eyes are dark (got %s)" % want_eye)
	check(cat.eye_color.is_equal_approx(want_eye), "eyes are the palette dark (got %s)" % cat.eye_color)
	var eye_mat := (cat._eyes[0].material_override as StandardMaterial3D).albedo_color
	check(eye_mat.is_equal_approx(want_eye), "eye material albedo is dark (got %s)" % eye_mat)
	var stripe_mat := (cat._stripes[0].material_override as StandardMaterial3D).albedo_color
	check(stripe_mat.is_equal_approx(want_dark), "stripe albedo is the derived ginger_dark (got %s)" % stripe_mat)
	check(absf(cat.model_scale - 0.35) < 0.001, "Willie scale is 0.35 (got %.3f)" % cat.model_scale)
	check(cat.stripe_count >= 6, "tabby striping present (%d stripes)" % cat.stripe_count)
	# Tail, spec-locked (ruling 2026-10-25): white segments with a
	# ginger underside — no rings, no ginger segment bodies.
	check(cat._tail_segs.size() == 9, "tail has 9 segments (got %d)" % cat._tail_segs.size())
	var tail_all_white := true
	for seg in cat._tail_segs:
		var seg_mat := (seg[0].material_override as StandardMaterial3D).albedo_color
		if not seg_mat.is_equal_approx(want_coat):
			tail_all_white = false
	check(tail_all_white, "SPEC LOCK: every tail segment is white — no ginger rings")
	check(cat._tail_underside.size() == cat._tail_segs.size(), "ginger tail-underside shells built (%d)" % cat._tail_underside.size())
	var under_all_ginger := true
	for shell in cat._tail_underside:
		var sh_mat := (shell.material_override as StandardMaterial3D).albedo_color
		if not sh_mat.is_equal_approx(want_ginger):
			under_all_ginger = false
	check(under_all_ginger, "SPEC LOCK: tail underside is the ruled ginger")
	var wchar: Dictionary = willie.get("character", {})
	check(String(wchar.get("meowing", "")) == "constant", "character data: Willie meows constantly")
	# Scripted walk.
	var start_pos: Vector3 = cat.global_position
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": false}
	await frames(60)
	var moved := Vector2(cat.global_position.x - start_pos.x, cat.global_position.z - start_pos.z).length()
	check(moved > 0.8, "cat moved %.2f m under scripted input" % moved)
	check(cat.anim_state == "walk", "cat walks (got %s)" % cat.anim_state)
	# Sprint drains stamina.
	var st0: float = cat.stamina
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": true, "stalk": false}
	await frames(45)
	check(cat.anim_state == "sprint", "cat sprints (got %s)" % cat.anim_state)
	check(cat.stamina < st0 - 3.0, "stamina drains (%.1f -> %.1f)" % [st0, cat.stamina])
	# Stalk is slow and low.
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": true}
	await frames(20)
	check(cat.anim_state == "stalk", "cat stalks (got %s)" % cat.anim_state)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	await frames(10)
	# Lounge on command.
	cat.set_lounge(true)
	await frames(5)
	check(cat.anim_state == "lounge", "cat lounges (got %s)" % cat.anim_state)
	cat.set_lounge(false)
	await frames(5)
	# Freeze the mice (cut their cat reference) so the catch checks are
	# about the strike mechanic, not about flee timing.
	for m in _game.mice:
		m.cat = null
	await _catch_one(cat, _game.mice[0])
	check(_game.caught_count == 1, "strike caught a mouse (caught=%d)" % _game.caught_count)
	# Catch the rest -> win state.
	for i in range(1, _game.mice.size()):
		await _catch_one(cat, _game.mice[i])
	check(_game.won, "win state reached after all mice caught")
	check((_game.get("_banner") as Label).visible, "win banner visible")
	# --- Aggie: the calico sister, lounging on the garden chair. ---
	var aggie = _game.aggie
	check(aggie != null, "aggie exists")
	check(aggie.species_name == "Aggie", "second cat is Aggie (got %s)" % aggie.species_name)
	check(absf(aggie.model_scale - 0.25) < 0.001 and aggie.model_scale < cat.model_scale, "Aggie scale 0.25 < Willie 0.35 (got %.3f)" % aggie.model_scale)
	var ag: Dictionary = chars.get("aggie", {})
	var apal: Dictionary = ag.get("palette", {})
	var j_base: Array = apal.get("base", [])
	var want_base := Color(float(j_base[0]), float(j_base[1]), float(j_base[2]))
	var a_torso := (aggie._torso.material_override as StandardMaterial3D).albedo_color
	check(a_torso.is_equal_approx(want_base), "aggie torso is the calico base (got %s)" % a_torso)
	var j_orange: Array = apal.get("mottle_orange", [])
	var want_orange := Color(float(j_orange[0]), float(j_orange[1]), float(j_orange[2]))
	var j_cream: Array = apal.get("mottle_cream", [])
	var want_cream := Color(float(j_cream[0]), float(j_cream[1]), float(j_cream[2]))
	var j_aeye: Array = apal.get("eye", [])
	var want_aeye := Color(float(j_aeye[0]), float(j_aeye[1]), float(j_aeye[2]))
	check(aggie.eye_color.is_equal_approx(want_aeye), "aggie eyes green-gold from her own palette (got %s)" % aggie.eye_color)
	# PASS 3 contract: the mottle lives in the baked coat texture and
	# mottle_count is its pattern coverage in permille — substantial
	# mottling, but the dark base must still show through.
	check(aggie.mottle_count >= 200 and aggie.mottle_count <= 800, "aggie coat texture carries the mottle (coverage %d permille)" % aggie.mottle_count)
	# The texture must actually REACH the locked tones. Pass 2's 8-bit
	# bake clamped its multipliers at 1.0 and could render nothing
	# brighter than the base — dark brown pretending to be orange
	# (the scatter shells carried the colour). Reconstruct texel
	# albedos and demand a near-match to each locked tone.
	var atex := ((aggie._torso.material_override as StandardMaterial3D).albedo_texture as ImageTexture).get_image()
	var best_o := 10.0
	var best_c := 10.0
	for gx in range(0, atex.get_width(), 3):
		for gy in range(0, atex.get_height(), 3):
			var tx := atex.get_pixel(gx, gy)
			var alb := Color(want_base.r * tx.r, want_base.g * tx.g, want_base.b * tx.b)
			best_o = minf(best_o, Vector3(alb.r - want_orange.r, alb.g - want_orange.g, alb.b - want_orange.b).length())
			best_c = minf(best_c, Vector3(alb.r - want_cream.r, alb.g - want_cream.g, alb.b - want_cream.b).length())
	check(best_o < 0.12, "aggie coat texture reaches her locked orange (closest %.3f)" % best_o)
	check(best_c < 0.15, "aggie coat texture reaches her locked cream (closest %.3f)" % best_c)
	check(aggie.torso_dia.x < cat.torso_dia.x * 0.8, "aggie build is wiry, not a scaled Willie (torso %.2f vs %.2f)" % [aggie.torso_dia.x, cat.torso_dia.x])
	# --- Aggie's lounge system, driven deterministically. ---
	# RULING (coordinator, PR #13): this replaces the old one-shot
	# sample of aggie.is_lounging. That sample passed pre-fix only
	# because of the lounge-lock bug (playtest bug 4: Aggie stayed
	# parked forever after her first lounge); post-fix she lounges
	# ~55-60% of the time on SiblingAI's own 4-9 s timer, so a
	# single sample is flaky by construction. Drive the system
	# instead, duo-suite style: park her on the garden chair (the
	# game's own spawn point for her — she cannot walk up to it,
	# the chair's collision wedges her ~0.5 m out, short of the
	# 0.45 m arrival radius), command the lounge, and assert she
	# settles; then send her off and assert the flag clears and
	# she moves again, which also regression-guards the bug-4
	# un-lounge fix inside smoke.
	var sib = _game.duo.sibling
	sib.autonomous = false
	aggie.velocity = Vector3.ZERO
	aggie.global_position = Vector3(4.5, 0.52, 4.5) # her spawn: on the chair
	sib.go_lounge(Vector3(4.5, 0.46, 4.5)) # the chair seat (CHAIR_SEAT)
	var settled := false
	for i in 120:
		await get_tree().physics_frame
		if sib.mode == "lounge" and aggie.is_lounging:
			settled = true
			break
	check(settled and aggie.is_lounging, "aggie lounges on the chair")
	var seat_d: float = aggie.global_position.distance_to(Vector3(4.5, 0.46, 4.5))
	check(seat_d < 0.1, "aggie settled on the chair seat (dist %.2f m)" % seat_d)
	# Exit lounge mode: the flag must clear and she must move.
	var chair_pos: Vector3 = aggie.global_position
	sib.go_lounge(Vector3(-10.5, 0.0, 7.5)) # fence corner, far away
	await frames(5)
	check(not aggie.is_lounging, "aggie un-lounges when sent off the chair (no lounge-lock)")
	await frames(60)
	var moved_again := Vector2(aggie.global_position.x - chair_pos.x, aggie.global_position.z - chair_pos.z).length()
	check(moved_again > 0.3, "aggie moves again after un-lounging (moved %.2f m)" % moved_again)
	var achar: Dictionary = ag.get("character", {})
	check(String(achar.get("fight_style", "")) == "burst_and_flee", "character data: aggie fights burst-and-flee")
	check(String(achar.get("provocation_trigger", "")) == "willie_meowing", "character data: willie meowing provokes aggie")
	check(bool(achar.get("wins_vs_willie", false)), "character data: aggie always beats willie")
	check(absf(float(achar.get("weight_vs_willie", 0.0)) - 0.5) < 0.001, "character data: aggie weighs half of willie")
	# Determinism: a fresh Aggie build bakes identically (same seed,
	# same coat field — the pass-3 successor of the scatter signature).
	var ag2 = CatScript.new()
	ag2.set_character("aggie")
	add_child(ag2)
	await frames(3)
	check(ag2.mottle_count == aggie.mottle_count, "aggie mottle coverage deterministic (%d vs %d)" % [ag2.mottle_count, aggie.mottle_count])
	var img1 := ((aggie._torso.material_override as StandardMaterial3D).albedo_texture as ImageTexture).get_image()
	var img2 := ((ag2._torso.material_override as StandardMaterial3D).albedo_texture as ImageTexture).get_image()
	var sig1 := 0.0
	var sig2 := 0.0
	for gx in range(0, img1.get_width(), 7):
		for gy in range(0, img1.get_height(), 7):
			var p1 := img1.get_pixel(gx, gy)
			var p2 := img2.get_pixel(gx, gy)
			sig1 += p1.r * 3.0 + p1.g * 5.0 + p1.b * 7.0
			sig2 += p2.r * 3.0 + p2.g * 5.0 + p2.b * 7.0
	check(absf(sig1 - sig2) < 0.001, "aggie coat texture identical across builds")
	ag2.queue_free()
	print("SMOKE DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _catch_one(cat, mouse) -> void:
	# Stand the cat half a metre behind the mouse, facing it (-Z fwd).
	cat.velocity = Vector3.ZERO
	cat.global_position = Vector3(mouse.global_position.x, 0.05, mouse.global_position.z + 0.5)
	cat.rotation.y = 0.0
	await frames(3)
	var ok: bool = cat.strike()
	check(ok, "strike started")
	await frames(4)
	check(cat.anim_state == "strike", "strike anim plays (got %s)" % cat.anim_state)
	# paw_swiped fires from the animation timeline (~0.10 s in); give it
	# real frames, then the cooldown, before the next catch.
	await frames(45)
