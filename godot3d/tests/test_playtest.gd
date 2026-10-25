extends Node
## PLAYTEST REGRESSION tests — Daniel's four 2026-10-24 playtest
## bugs, every one reproduced in the integrated scene pre-fix.
## Run: godot --headless --path godot3d res://tests/test_playtest.tscn
## All standalone suites were green while these shipped, because
## they lived in cross-system wiring — so this suite drives the
## REAL integrated main scene and asserts on world state:
##  1. mice uncatchable (swipe resolves 0.10 s after the press
##     against a fleeing mouse; the press window was a sliver)
##  2. the outside sibling fence clamped the sibling's z in EVERY
##     zone (interior stack lives at z ~ -200 -> stranded sibling)
##  2b. the attic hatch shaft was z-flipped vs the ground floor
##  3. the raccoon family spawned in the yard (local/global mixup)
##  4. Aggie lounge-locked: provocation built to 100 and she
##     never moved, so the flurry never happened

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


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ready() -> void:
	_run()


func _run() -> void:
	print("PLAYTEST TESTS: loading main scene")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(20)
	_game.duo.choose("willie")
	await frames(5)
	var cat = _game.cat
	var duo = _game.duo
	var aggie = duo.aggie_cat
	var attic = _game._zone_roots[HouseSpec.ATTIC]

	# --- bug 3: the raccoon family lives in the attic ----------------
	var mother = attic.mother
	check(mother != null, "raccoon mother exists")
	if mother != null:
		var m_local: Vector3 = attic.to_local(mother.global_position)
		check(mother.global_position.z < -190.0,
			"mother spawns in the attic stack, not the yard (world z %.1f)" % mother.global_position.z)
		check(_flat(m_local, Vector3(-4.5, 0.0, -3.0)) < 0.6 and absf(m_local.y) < 0.4,
			"mother at the nest corner (attic-local %s)" % m_local)
	check(attic.kits.size() == 3, "three raccoon kits")
	var kits_ok := true
	var refuges_ok := true
	for k in attic.kits:
		var kl: Vector3 = attic.to_local((k as Node3D).global_position)
		if mother != null and _flat(kl, attic.to_local(mother.global_position)) > 1.7:
			kits_ok = false
		for r in (k as PvKRaccoon).refuges:
			var rl: Vector3 = attic.to_local(r)
			if absf(rl.x) > 6.2 or absf(rl.z) > 4.7 or absf(rl.y) > 0.6:
				refuges_ok = false
	check(kits_ok, "kits spawn clustered at the nest, inside the attic")
	check(refuges_ok, "kit refuges are world points inside the attic footprint")

	# --- bug 2b: the hatch shaft is on one side, both floors --------
	check(PvKAttic.HATCH_POS.z < 0.0, "attic HATCH_POS on the -z side (z %.2f)" % PvKAttic.HATCH_POS.z)
	var att_conn: Array = HouseSpec.connectors(HouseSpec.ATTIC)
	check(float((att_conn[0] as Dictionary)["at"].z) < 0.0, "attic return connector on the -z side")
	var att_entry: Transform3D = HouseSpec.entries(HouseSpec.ATTIC)["EntryHatch"]
	check(att_entry.origin.z < 0.0, "attic EntryHatch landing on the -z side")
	var gf_hatch_z := 99.0
	for cfg in HouseSpec.connectors(HouseSpec.GROUND_FLOOR):
		if String((cfg as Dictionary)["target_zone"]) == HouseSpec.ATTIC:
			gf_hatch_z = float((cfg as Dictionary)["at"].z)
	check(gf_hatch_z < 0.0, "ground-floor hatch connector on the same (-z) side (z %.2f)" % gf_hatch_z)
	var anchor_pvk: Vector3 = HouseSpec.anchor("attic_entry", "pvk")
	check(_flat(anchor_pvk, att_entry.origin) < 0.35,
		"attic_entry anchor resolves to the entry landing (got %s)" % anchor_pvk)

	# --- bug 2: the fence must not clamp the sibling indoors --------
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(30)
	check(String(_game.zones.current_zone) == HouseSpec.ATTIC, "travel reached the attic")
	check(aggie.global_position.z < -190.0,
		"sibling stays in the attic after travel (world z %.1f)" % aggie.global_position.z)
	var cat_local: Vector3 = attic.to_local(cat.global_position)
	check(_flat(cat_local, PvKAttic.HATCH_POS) < 1.6,
		"attic landing within 1.6 m of HATCH_POS (local %s)" % cat_local)
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryHatchBottom", true)
	await frames(30)
	check(aggie.global_position.z < -190.0,
		"sibling stays in the ground floor after travel (world z %.1f)" % aggie.global_position.z)
	_game.zones.travel(HouseSpec.OUTSIDE, "EntryFrontDoor", true)
	await frames(30)
	check(String(_game.zones.current_zone) == HouseSpec.OUTSIDE, "travel returned outside")

	# --- bug 4: provocation on the REAL path (no manual un-lounge) --
	# NOTE: this suite never calls set_lounge — that manual step is
	# exactly what masked the lounge-lock in the duo suite.
	var settle := 0
	while settle < 900 and not (String(duo.sibling.mode) == "lounge" and bool(aggie.is_lounging)):
		await frames(1)
		settle += 1
	check(bool(aggie.is_lounging) and String(duo.sibling.mode) == "lounge",
		"Aggie settled into a yard lounge (real-path precondition, %d frames)" % settle)
	var ap: Vector3 = aggie.global_position
	cat.global_position = ap + Vector3(2.0, 0.0, 0.0)
	cat.velocity = Vector3.ZERO
	aggie.velocity = Vector3.ZERO
	await frames(10)
	check(bool(aggie.is_lounging), "Aggie still lounging when the meows start")
	var aggie_start: Vector3 = aggie.global_position
	for i in 4:
		duo.player_meow()
		await frames(50)
	var max_hits := 0
	var watch := 0
	while watch < 600:
		await frames(1)
		watch += 1
		max_hits = maxi(max_hits, int(duo.prov.get("_hits")))
		if String(duo.prov.state) == "cooldown" and watch > 120:
			break
	check(max_hits >= 1, "provoked Aggie lands flurry hits on Willie (hits %d)" % max_hits)
	check(_flat(aggie.global_position, aggie_start) > 0.3,
		"Aggie actually moved to attack (displacement %.2f)" % _flat(aggie.global_position, aggie_start))
	check(not bool(aggie.is_lounging), "Aggie not left lounge-locked after the flurry")

	# --- bug 1: the catch window ------------------------------------
	await _staged_strike(0.90, 0.0, "strike A")
	await _staged_strike(0.70, 0.3, "strike B")
	await _sprint_chase()

	print("PLAYTEST TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _live_mouse() -> PvKMouse:
	for m in _game.mice:
		if is_instance_valid(m) and m.state != "caught":
			return m
	return null


func _steer(target_pos: Vector3, sprint: bool) -> void:
	var cat = _game.cat
	var b: Basis = _game._rig.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	var dvec: Vector3 = target_pos - cat.global_position
	dvec.y = 0.0
	var mv := Vector2.ZERO
	if dvec.length() > 0.05:
		var dn := dvec / dvec.length()
		mv = Vector2(dn.dot(right), dn.dot(fwd))
	_game.input_override = {"active": true, "move": mv, "sprint": sprint, "stalk": false}


func _staged_strike(press_at: float, lateral: float, label: String) -> void:
	var cat = _game.cat
	# Top the pool up first: a staged trial with no live mouse must
	# fail LOUDLY at the staging check, never masquerade as a miss
	# (the probe sweeps silently corrupted themselves that way —
	# caught mice are freed, and the pool is only 7).
	var live := 0
	for m in _game.mice:
		if is_instance_valid(m) and m.state != "caught":
			live += 1
	while live < 3:
		_game._spawn_one_mouse()
		live += 1
	var mouse := _live_mouse()
	check(mouse != null, "%s: a live mouse was staged" % label)
	if mouse == null:
		return
	mouse.state = "idle"
	mouse.set("_flee_t", 0.0)
	cat.global_position = Vector3(0.0, 0.05, 0.0)
	cat.velocity = Vector3.ZERO
	cat.rotation.y = PI # face +Z, toward the mouse
	mouse.global_position = Vector3(lateral, 0.0, 6.0)
	mouse.home = mouse.global_position
	var caught0: int = _game.caught_count
	var pressed := false
	var since_press := -1
	var caught := false
	for i in 60 * 12:
		_steer(mouse.global_position, true)
		var dist := _flat(cat.global_position, mouse.global_position)
		if not pressed and dist < press_at and float(cat.get("_strike_t")) < 0.0 and float(cat.get("_strike_cd")) <= 0.0:
			_game.attempt_strike()
			pressed = true
			since_press = 0
		elif pressed:
			since_press += 1
		await frames(1)
		if _game.caught_count > caught0:
			caught = true
			break
		if since_press > 90:
			break
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	check(pressed, "%s: the strike was pressed" % label)
	check(caught, "%s: staged strike pressed at %.2f m (lateral %.1f) catches" % [label, press_at, lateral])


func _sprint_chase() -> void:
	# Staged like the strike trials (mouse in the open, cat 9 m out):
	# a free-roam bot chase is not a fair test — the bot has no
	# obstacle avoidance and will ram a tree trunk for 30 s while
	# the mouse flees along the fence (a human walks around it).
	# The pursuit itself — sprint, flee, strike, catch — is unscripted.
	# Press discipline is < 0.80 m, not the 0.95 first sketched:
	# fire-time geometry is press + 0.31 (mouse fleeing during the
	# 0.10 s resolve, cat frozen) - 0.60 (paw reach); at 0.95 that
	# leaves paw_mouse ~0.59 against the 0.62 radius (measured,
	# probe7 — a coin flip in messy conditions), at 0.80 it is
	# ~0.43 with real margin, which is when a human presses too.
	var cat = _game.cat
	var target := _live_mouse()
	check(target != null, "chase: a live mouse exists")
	if target == null:
		return
	target.state = "idle"
	target.set("_flee_t", 0.0)
	target.global_position = Vector3(0.0, 0.0, 3.0)
	target.home = target.global_position
	cat.global_position = Vector3(0.0, 0.05, -6.0)
	cat.velocity = Vector3.ZERO
	cat.rotation.y = PI # face +Z, toward the mouse
	cat.stamina = cat.stamina_max # harness staging: a fresh cat for the chase
	var caught0: int = _game.caught_count
	var frames_used := 0
	var caught := false
	for i in 60 * 30:
		frames_used = i
		if not is_instance_valid(target) or target.state == "caught" or _game.caught_count > caught0:
			caught = true
			break
		if i % 6 == 0: # steer + strike at 10 Hz, like a human mashing
			_steer(target.global_position, true)
			var dist := _flat(cat.global_position, target.global_position)
			if dist < 0.80 and float(cat.get("_strike_t")) < 0.0 and float(cat.get("_strike_cd")) <= 0.0:
				_game.attempt_strike()
		await frames(1)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	check(caught, "scripted sprint chase (10 Hz steering, staged open yard) catches within 30 s (used %d frames)" % frames_used)
