extends Node
## MASSEY FOUNDATION tests — zones, combat, cat health.
## Run: godot --headless --path godot3d res://tests/test_massey.tscn
## Drives the real game + real zone scenes; asserts on STATE only.
## Locks the contract in docs/massey-zones.md: connector travel
## between every zone pair, the enemy base (hits/knockback/flee/
## death -> kill hook), cat damage + invulnerability + vehicle
## launch, the faint -> hub respawn with a life spent, jump/pounce
## reach, hiss timing, and the objectives registry + score events.

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


func _collect(node: Node, out: Array) -> void:
	if node is ZoneConnector:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _ready() -> void:
	_run()


func _run() -> void:
	print("MASSEY TESTS: loading main scene")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(12)
	_game.duo.choose("willie")
	await frames(6)
	var cat: PvKCat = _game.cat
	var zones: ZoneManager = _game.zones
	var obj: PvKObjectives = _game.objectives
	check(cat != null and cat.max_hp == 120.0, "Willie is the player with 120 HP (got %s)" % (cat.max_hp if cat else -1))

	# --- the spec ----------------------------------------------------------------
	check(HouseSpec.FOOTPRINT_W == 17.0 and HouseSpec.FOOTPRINT_D == 9.6, "spec footprint is 17.0 x 9.6")
	check(is_equal_approx(HouseSpec.floor_y(HouseSpec.BASEMENT), -2.6), "spec basement floor at -2.6")
	check(is_equal_approx(HouseSpec.floor_y(HouseSpec.ATTIC), 2.9), "spec attic floor at +2.9")
	var pairing_ok := true
	for zid: String in HouseSpec.ZONE_ORDER:
		for cfg: Variant in HouseSpec.connectors(zid):
			var d := cfg as Dictionary
			if not HouseSpec.entries(String(d["target_zone"])).has(String(d["target_entry"])):
				pairing_ok = false
	check(pairing_ok, "every connector targets an entry that exists")
	var prof: Dictionary = CombatData.profile("vehicle_hit")
	check(is_equal_approx(float(prof.get("damage_frac", 0.0)), 0.6) and bool(prof.get("launch", false)), "vehicle_hit profile: 60% HP + launch")

	# --- the module frame (doc section 9) -------------------------------------------
	var rt_ok := true
	for p: Vector2 in [Vector2(2.5, 4.8), Vector2(-6.5, -3.0), Vector2(4.8, -3.85)]:
		if HouseSpec.uv_to_pvk(HouseSpec.anchor_uv(p)).distance_to(p) > 0.01:
			rt_ok = false
	check(rt_ok, "anchor fractions round-trip PvK -> (u,v) -> PvK")
	check(HouseSpec.GTA_FOOTPRINT == Vector2(11.79, 15.64), "canonical GTA footprint is 11.79 x 15.64")
	var sofa_gta := HouseSpec.anchor("sofa", "gta")
	check(is_equal_approx(sofa_gta.y, 300.0) and absf(sofa_gta.x) <= 5.4 and absf(sofa_gta.z) <= 7.3, "sofa anchor lands inside the GTA cell at CELL_Y (got %s)" % sofa_gta)
	var sofa_pvk := HouseSpec.anchor("sofa", "pvk")
	check(sofa_pvk.distance_to(HouseSpec.SOFA_POS) < 0.15, "sofa anchor resolves back to the PvK sofa (got %s)" % sofa_pvk)
	check(is_equal_approx(HouseSpec.anchor("attic_entry", "gta").y, 340.0), "attic floor rides the GTA LINKED +40 pattern")

	# --- zones are built ------------------------------------------------------------
	check(zones != null and zones.zones.size() == 4, "zone manager holds all 4 zones")
	var gf: Node = zones.zones[HouseSpec.GROUND_FLOOR]
	check(gf.get_node_or_null("EntryFrontDoor") != null, "ground floor has EntryFrontDoor")
	check(gf.find_child("AggieDrawer", true, false) != null, "ground floor has the Aggie drawer")
	check(gf.find_child("WaterBowl", true, false) != null, "ground floor has Willie's water bowl")
	check(gf.find_child("Sofa", true, false) != null, "ground floor has the sofa (lap seat)")
	var bs: Node = zones.zones[HouseSpec.BASEMENT]
	var at: Node = zones.zones[HouseSpec.ATTIC]
	check(is_equal_approx((bs as Node3D).global_position.y, -2.6), "basement root sits at floor -2.6 (got %.2f)" % (bs as Node3D).global_position.y)
	check(is_equal_approx((at as Node3D).global_position.y, 2.9), "attic root sits at floor +2.9")
	var conns: Array = []
	_collect(_game, conns)
	check(conns.size() >= 6, "6+ connector volumes in the tree (got %d)" % conns.size())
	var conn_ok := true
	for c: Variant in conns:
		var zc := c as ZoneConnector
		if not zones.zones.has(zc.target_zone):
			conn_ok = false
		elif (zones.zones[zc.target_zone] as Node).call("get_entry", zc.target_entry) == null:
			conn_ok = false
	check(conn_ok, "every live connector resolves to a real entry")

	# --- travel: the real door trigger ----------------------------------------------
	cat.global_position = Vector3(2.5, 0.95, -9.85) # inside the porch volume
	cat.velocity = Vector3.ZERO
	var t := 0
	while zones.current_zone != HouseSpec.GROUND_FLOOR and t < 120:
		await frames(1)
		t += 1
	check(zones.current_zone == HouseSpec.GROUND_FLOOR, "walking into the front door travels inside")
	check(cat.global_position.distance_to(Vector3(2.5, 0.0, -196.45)) < 0.8, "player lands at the inside door entry (got %s)" % cat.global_position)
	var sib: PvKCat = _game.duo.sibling_cat()
	check(sib != null and sib.global_position.distance_to(cat.global_position) < 3.0, "sibling travels with the player")
	var guard := 0
	while zones.travelling and guard < 60:
		await frames(1)
		guard += 1

	# --- travel: every pair, instant --------------------------------------------------
	var trips: Array = [
		[HouseSpec.BASEMENT, "EntryStairs"],
		[HouseSpec.GROUND_FLOOR, "EntryStairsTop"],
		[HouseSpec.ATTIC, "EntryHatch"],
		[HouseSpec.GROUND_FLOOR, "EntryHatchBottom"],
		[HouseSpec.OUTSIDE, "EntryFrontDoor"],
	]
	for trip: Variant in trips:
		var zid := String(trip[0])
		var en := String(trip[1])
		zones.travel(zid, en, true)
		await frames(3)
		var want: Vector3 = HouseSpec.zone_origin(zid) + (HouseSpec.entries(zid)[en] as Transform3D).origin
		check(zones.current_zone == zid and cat.global_position.distance_to(want) < 0.35,
			"instant travel -> %s/%s (cat at %s, want %s)" % [zid, en, cat.global_position, want])

	# --- objectives ---------------------------------------------------------------------
	check(obj != null and obj.get_item("outside:mice") != null, "outside mice objective declared")
	_game.caught_count = 7
	await frames(4)
	check(obj.is_done("outside:mice"), "mice objective completes from the catch count")
	obj.add_score("ankle_attack")
	obj.add_score("lap_purr")
	check(obj.score == 60, "score events land (ankle 50 + lap 10 = %d)" % obj.score)
	var hud := _game.get_node("ObjectivesHUD") as ObjectivesHUD
	check(hud != null and not hud.panel_visible(), "objectives panel starts hidden")
	hud.toggle()
	check(hud.panel_visible(), "objectives panel toggles open")
	hud.toggle()
	obj.declare("test:rats", HouseSpec.BASEMENT, "Defeat 2 test rats", 2, "rat")

	# --- enemy base -----------------------------------------------------------------------
	zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(4)
	var kills0 := obj.total_kills
	var rat := PvKEnemy.new()
	rat.configure({"species_id": "rat", "max_hp": 30.0, "damage": 8.0, "flee_at_frac": 0.34,
		"detection_radius": 0.0, "color": Color(0.4, 0.35, 0.3)})
	_game.add_child(rat)
	rat.global_position = HouseSpec.zone_origin(HouseSpec.BASEMENT) + Vector3(2.0, 0.4, 2.0)
	t = 0
	while not rat.is_on_floor() and t < 40:
		await frames(1)
		t += 1
	check(rat.is_on_floor(), "enemy stands on the basement floor")
	var died_hit := [false]
	rat.died.connect(func(_e: PvKEnemy) -> void: died_hit[0] = true)
	rat.take_hit(12.0, rat.global_position + Vector3(-2, 0, 0))
	check(rat.hp == 18.0, "take_hit removes HP (got %.0f)" % rat.hp)
	var kb_peak := 0.0
	for i in 6:
		await frames(1)
		kb_peak = maxf(kb_peak, rat.velocity.x)
	check(kb_peak > 1.2, "take_hit knocks the enemy back (+x peak v=%.2f)" % kb_peak)
	rat.take_hit(12.0, rat.global_position)
	await frames(3)
	check(rat.state == "flee", "enemy flees under its flee threshold (state=%s)" % rat.state)
	rat.take_hit(50.0, rat.global_position)
	check(rat.state == "dead" and died_hit[0], "lethal hit kills: state + died signal")
	await frames(3)
	check(obj.total_kills == kills0 + 1, "death registers a kill with objectives")
	check(int((obj.get_item("test:rats") as Dictionary)["count"]) == 1, "kill objective advances")

	# --- enemy chase + attack hurts the cat ------------------------------------------------
	cat.heal_full()
	await frames(55) # burn off any invulnerability
	var hp0 := cat.hp
	var chaser := PvKEnemy.new()
	chaser.configure({"species_id": "rat", "max_hp": 60.0, "damage": 8.0, "speed": 2.2,
		"walk_speed": 0.8, "detection_radius": 7.0, "color": Color(0.45, 0.38, 0.3)})
	_game.add_child(chaser)
	chaser.global_position = cat.global_position + Vector3(2.6, 0.3, 0)
	var saw_chase := false
	t = 0
	while t < 300 and cat.hp >= hp0:
		await frames(1)
		t += 1
		if chaser.state == "chase" or chaser.state == "attack":
			saw_chase = true
	check(saw_chase, "enemy detects and chases the player cat")
	check(cat.hp < hp0, "enemy attack damages the cat (%.0f -> %.0f)" % [hp0, cat.hp])
	chaser.take_hit(999.0, chaser.global_position)
	await frames(2)

	# --- cat damage contract -----------------------------------------------------------------
	cat.heal_full()
	await frames(55)
	var applied := cat.take_damage(10.0, cat.global_position + Vector3(1, 0, 0))
	check(applied and cat.hp == 110.0, "cat takes flat damage (hp %.0f)" % cat.hp)
	check(not cat.take_damage(10.0, cat.global_position), "invulnerability window blocks repeat damage")
	await frames(55)
	cat.take_damage(0.0, cat.global_position + Vector3(-1, 0, 0), CombatData.profile("vehicle_hit"))
	check(is_equal_approx(cat.hp, 110.0 - 72.0), "vehicle_hit takes 60%% of max HP (hp %.0f)" % cat.hp)
	check(cat.velocity.y > 2.0, "vehicle_hit launches the cat (vy=%.2f)" % cat.velocity.y)
	await frames(40)
	var healed := cat.heal(9.0)
	check(healed == 9.0 and cat.hp == 47.0, "heal(amount) tops up via the lap/treat seam (hp %.0f)" % cat.hp)
	cat.heal_full()

	# --- hiss -----------------------------------------------------------------------------------
	await frames(55)
	check(cat.hiss(), "hiss() starts the startle state")
	await frames(3)
	check(cat.is_hissing() and cat.anim_state == "hiss", "cat is hissing (arched pose runs)")
	check(not cat.hiss(), "hiss() will not retrigger mid-hiss")
	await frames(100)
	check(not cat.is_hissing(), "hiss ends after ~1.5 s, control returns")

	# --- jump + pounce ----------------------------------------------------------------------------
	zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(4)
	var ledge := StaticBody3D.new()
	var lcs := CollisionShape3D.new()
	var lshape := BoxShape3D.new()
	lshape.size = Vector3(1.4, 0.5, 1.4)
	lcs.shape = lshape
	lcs.position = Vector3(0, 0.25, -198.0)
	ledge.add_child(lcs)
	var lmi := MeshInstance3D.new()
	var lbm := BoxMesh.new()
	lbm.size = Vector3(1.4, 0.5, 1.4)
	lmi.mesh = lbm
	lmi.position = Vector3(0, 0.25, -198.0)
	ledge.add_child(lmi)
	_game.add_child(ledge)
	cat.global_position = Vector3(0, 0.06, -196.9)
	cat.velocity = Vector3.ZERO
	cat.rotation.y = 0.0 # facing -z, at the ledge
	await frames(3)
	# Carry toward the ledge via the input seam on main (the cat
	# physics assigns horizontal velocity from input every frame).
	_game.input_override = {"active": true, "move": Vector2(0, -1), "sprint": false, "stalk": false}
	check(cat.jump(), "jump() fires from the floor")
	var apex := 0.0
	t = 0
	while t < 70:
		await frames(1)
		t += 1
		apex = maxf(apex, cat.global_position.y)
		if t > 10 and cat.is_on_floor():
			break
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	check(apex > 0.55, "jump apex clears the 0.5 m standard (apex %.2f)" % apex)
	check(cat.global_position.y > 0.4 and cat.is_on_floor(), "cat lands ON the 0.5 m ledge (y %.2f)" % cat.global_position.y)
	# Pounce outranges a ground strike:
	var dummy := PvKEnemy.new()
	dummy.configure({"species_id": "dummy", "max_hp": 500.0, "damage": 0.0,
		"detection_radius": 0.0, "flee_at_frac": 0.0, "color": Color(0.5, 0.5, 0.55)})
	_game.add_child(dummy)
	cat.global_position = Vector3(0, 0.56, -198.0) # back on the ledge top
	cat.velocity = Vector3.ZERO
	await frames(3)
	dummy.global_position = cat.global_position + Vector3(1.35, -0.4, 0)
	await frames(3)
	cat.rotation.y = -PI / 2.0 # facing +x, at the dummy
	cat.strike()
	await frames(26)
	check(dummy.hp == 500.0, "ground strike whiffs at pounce range (hp %.0f)" % dummy.hp)
	await frames(40) # strike duration + cooldown fully out before the pounce
	cat.jump()
	await frames(2)
	check(cat.pounce(), "pounce() fires mid-air")
	await frames(12)
	check(dummy.hp < 500.0, "pounce connects at extended range (hp %.0f)" % dummy.hp)
	dummy.take_hit(9999.0, dummy.global_position)

	# --- faint -> respawn at the hub ----------------------------------------------------------------
	zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(4)
	cat.heal_full()
	await frames(55)
	var lives0: int = _game.lives
	cat.take_damage(9999.0, cat.global_position)
	check(cat.is_fainted and cat.hp == 0.0, "lethal damage faints the cat (dramatic flop)")
	t = 0
	while t < 320 and (cat.is_fainted or zones.current_zone != HouseSpec.GROUND_FLOOR):
		await frames(1)
		t += 1
	check(zones.current_zone == HouseSpec.GROUND_FLOOR, "fainted cat respawns at the ground-floor hub")
	check(not cat.is_fainted and cat.hp == cat.max_hp, "respawn restores full HP")
	check(_game.lives == lives0 - 1, "a life is spent (9 -> %d), never a game-over" % _game.lives)

	print("MASSEY TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
