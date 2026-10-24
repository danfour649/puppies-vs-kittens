extends Node
## Headless tests for the Massey basement zone (Willie and Aggie).
## Run: godot --headless --path godot3d res://zones/basement/tests_basement.tscn
## Drives the real zone + real cats and asserts on STATE only — never
## on rendered pixels (headless readbacks lie). Mirrors tests/smoke.gd.

const ZoneScene := preload("res://zones/basement/basement.tscn")
const ZoneScript := preload("res://zones/basement/basement.gd")
const CatScript := preload("res://cat_kit/cat.gd")
const RatScript := preload("res://zones/basement/rat.gd")

var _pass := 0
var _fail := 0
var _zone = null
var _cat: PvKHissCat = null


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


func _freeze_dangers() -> void:
	for r in _zone.rats:
		r.active = false
	for sp in _zone.spiders:
		sp.active = false


func _park_ghosts() -> void:
	for g in _zone.ghosts:
		g.target_cat = null
		g.set_solid(false)
		g.global_position = Vector3(-7.4, 0, 5.5)


func _run() -> void:
	print("BASEMENT TESTS: loading zone standalone")
	_zone = ZoneScene.instantiate()
	_zone.standalone_drive = false
	_zone.use_follow_cam = false
	add_child(_zone)
	await frames(12)
	_cat = _zone.player_cat as PvKHissCat

	# --- build & data ------------------------------------------------------
	check(_cat != null, "standalone cat spawned")
	check(_zone.rats.size() == 5, "5 rats (got %d)" % _zone.rats.size())
	check(_zone.spiders.size() == 2, "2 spiders (got %d)" % _zone.spiders.size())
	check(_zone.ghosts.size() == 3, "3 ghosts (got %d)" % _zone.ghosts.size())
	check(_zone.toys.size() == 3, "3 toys (got %d)" % _zone.toys.size())
	check(_zone.alpha_rat != null and _zone.alpha_rat.is_alpha, "alpha rat present")
	check(_cat.is_on_floor(), "cat stands on the basement floor")
	check(_cat.global_position.distance_to(ZoneScript.ENTRY_POS) < 0.6, "cat spawns at the entry stairs")
	var objs: Array = _zone.get_objectives()
	check(objs.size() == 3, "objectives.json declares 3 objectives (got %d)" % objs.size())
	check(String(objs[0].get("id", "")) == "clear_labyrinth_heart", "first objective is the labyrinth heart")
	check(not _zone.objective_done("clear_labyrinth_heart"), "heart objective starts undone")
	var has_unspooked := false
	for o: Dictionary in objs:
		if String(o.get("id", "")) == "unspooked":
			has_unspooked = true
	check(has_unspooked, "optional 'unspooked' objective declared")

	# --- the Aggie gap, derived from the character build data ---------------
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://cat_kit/cat_species.json"))
	var chars: Dictionary = data.get("characters", {})
	var w_dia := float(chars["willie"]["build"]["torso_dia"][0]) * float(chars["willie"]["scale"])
	var a_dia := float(chars["aggie"]["build"]["torso_dia"][0]) * float(chars["aggie"]["scale"])
	check(absf(w_dia - 0.154) < 0.001, "Willie body diameter from data is 0.154 (got %.3f)" % w_dia)
	check(absf(a_dia - 0.075) < 0.001, "Aggie body diameter from data is 0.075 (got %.3f)" % a_dia)
	check(ZoneScript.GAP_W > a_dia and ZoneScript.GAP_W < w_dia, "gap width %.3f sits between the cats (%.3f < gap < %.3f)" % [ZoneScript.GAP_W, a_dia, w_dia])
	var fit_w: Dictionary = ZoneScript.fit_capsule_for(_cat)
	check(absf(float(fit_w["diameter"]) - w_dia) < 0.001, "Willie fit capsule matches his build data")

	# --- grid truth: connectivity, alcove gating -----------------------------
	var entry_cell := Vector2i(11, 9)
	var heart_cell := Vector2i(8, 3)
	var feather_cell := Vector2i(13, 2)
	check(not ZoneScript.bfs_path(entry_cell, heart_cell, true).is_empty(), "grid: entry reaches the heart (Willie route)")
	check(ZoneScript.bfs_path(entry_cell, feather_cell, true).is_empty(), "grid: alcove unreachable when the gap is shut")
	check(not ZoneScript.bfs_path(entry_cell, feather_cell, false).is_empty(), "grid: alcove reachable through the gap (Aggie route)")

	_freeze_dangers()
	_park_ghosts()

	# --- scripted walk: entrance -> heart along the BFS path ------------------
	var path: Array = ZoneScript.bfs_path(entry_cell, heart_cell, true)
	check(path.size() > 5, "walk path has %d cells" % path.size())
	var wps: Array = []
	for cell: Vector2i in path:
		wps.append(ZoneScript.cell_center(cell.x, cell.y))
	wps.append(ZoneScript.HEART_POS)
	var wi := 0
	var stall := 0
	var total := 0
	while wi < wps.size() and total < 3600:
		var to: Vector3 = wps[wi] - _cat.global_position
		to.y = 0.0
		if to.length() < 0.38:
			wi += 1
			stall = 0
			continue
		_cat.set_move_input(to.normalized(), true, false)
		await frames(1)
		total += 1
		stall += 1
		if stall > 420:
			break
	_cat.set_move_input(Vector3.ZERO, false, false)
	check(wi >= wps.size(), "cat walked the labyrinth entrance -> heart (%d frames)" % total)
	check(_cat.global_position.distance_to(ZoneScript.HEART_POS) < 0.8, "cat reached the heart chamber")

	# --- the gap, physically: Aggie through, Willie stopped --------------------
	var aggie = CatScript.new()
	aggie.set_character("aggie")
	add_child(aggie)
	ZoneScript.apply_fit_capsule(aggie)
	var fit_a: Dictionary = ZoneScript.fit_capsule_for(aggie)
	check(absf(float(fit_a["diameter"]) - a_dia) < 0.001, "Aggie fit capsule matches her build data")
	aggie.global_position = Vector3(3.5, 0.05, -2.5)
	aggie.velocity = Vector3.ZERO
	await frames(5)
	aggie.set_move_input(Vector3(1, 0, 0), false, false)
	await frames(150)
	aggie.set_move_input(Vector3.ZERO, false, false)
	check(aggie.global_position.x > 4.85, "Aggie slipped through the gap (x=%.2f)" % aggie.global_position.x)
	_cat.global_position = Vector3(3.5, 0.05, -2.5)
	_cat.velocity = Vector3.ZERO
	await frames(5)
	_cat.set_move_input(Vector3(1, 0, 0), false, false)
	await frames(150)
	_cat.set_move_input(Vector3.ZERO, false, false)
	check(_cat.global_position.x < 4.05, "Willie cannot fit the gap (stopped at x=%.2f)" % _cat.global_position.x)
	aggie.queue_free()

	# --- ghosts: strike-through, the block, the hiss, the yield ------------------
	var g = _zone.ghosts[0]
	g.set_solid(true)
	g.global_position = Vector3(1.5, 0, -0.5) # tunnel-east choke
	g.set("_choke_i", 1)
	g.mode = "guard"
	g.set("_guard_t", 60.0)
	g.target_cat = _cat
	check(not g.has_method("take_hit"), "ghost has no take_hit — strikes cannot hurt it")
	_cat.global_position = Vector3(0.55, 0.05, -0.5)
	_cat.velocity = Vector3.ZERO
	_cat.rotation.y = -PI * 0.5 # face +x, toward the ghost
	await frames(3)
	var hp_pre_ghost: int = _zone.cat_hp
	_cat.strike()
	await frames(24)
	check(g.mode == "guard" and g.can_hiss(), "a paw strike passes through the ghost and changes nothing")
	check(_zone.cat_hp == hp_pre_ghost, "ghost contact costs no HP")
	# Head-on block at the choke: drive into the ghost ~4 s.
	_cat.global_position = Vector3(-4.9, 0.05, -0.5)
	_cat.velocity = Vector3.ZERO
	g.global_position = Vector3(-3.5, 0, -0.5)
	g.set("_choke_i", 0)
	await frames(3)
	var hiss_count := [0]
	_zone.cat_hissed.connect(func(_c): hiss_count[0] += 1)
	var saw_hiss := false
	var arch_max := 0.0
	var hiss_start_pos := Vector3.ZERO
	var push_frames := 0
	while push_frames < 300 and not saw_hiss:
		_cat.set_move_input(Vector3(1, 0, 0), false, false)
		await frames(1)
		push_frames += 1
		if _cat.is_hissing():
			saw_hiss = true
			hiss_start_pos = _cat.global_position
	check(saw_hiss, "blocked cat is forced into a hiss (after %d frames of pushing)" % push_frames)
	check(hiss_count[0] == 1, "zone routed exactly one hiss")
	check(_cat.global_position.x < -3.55, "the ghost held the choke — cat never passed (x=%.2f)" % _cat.global_position.x)
	check(_zone.cat_hp == hp_pre_ghost, "the hiss costs no HP (ghosts cannot damage)")
	# Keep pushing INTO the hiss: sample the arch at mid-hiss and prove
	# the control lock — the cat must not move while it lasts.
	var lock_frames := 0
	while _cat.is_hissing() and lock_frames < 80:
		_cat.set_move_input(Vector3(1, 0, 0), false, false)
		await frames(1)
		lock_frames += 1
		arch_max = maxf(arch_max, _cat._body.scale.y)
	check(arch_max > 1.08, "hiss pose: the Halloween arch is up (body scale y peaked %.2f)" % arch_max)
	check(_cat.global_position.distance_to(hiss_start_pos) < 0.06, "control lock: cat holds its ground while hissing")
	_cat.set_move_input(Vector3.ZERO, false, false)
	check(g.mode == "yield", "after the hiss the ghost yields")
	check(not g.can_hiss(), "yielding ghost is on hiss cooldown")
	# Walk straight through the yielded choke.
	var pass_frames := 0
	while pass_frames < 240 and _cat.global_position.x < -2.9:
		_cat.set_move_input(Vector3(1, 0, 0), false, false)
		await frames(1)
		pass_frames += 1
	_cat.set_move_input(Vector3.ZERO, false, false)
	check(_cat.global_position.x > -2.9, "cat passes the choke while the ghost yields")
	# No hiss-spam: stand next to the ghost inside its cooldown.
	await frames(60) # let the yield end; ghost back on patrol
	_cat.global_position = g.global_position + Vector3(0.42, 0.0, 0.0)
	_cat.velocity = Vector3.ZERO
	await frames(80)
	check(hiss_count[0] == 1, "no second hiss inside the cooldown window")
	_park_ghosts()

	# --- rats: paw strike, chase + bite, flee, death ------------------------------
	for r in _zone.rats:
		r.active = true
	# Paw strike through the zone's own wiring: borrow a zone rat,
	# frozen in front of the cat, then send it home.
	var pr = _zone.rats[3]
	pr.active = false
	pr.global_position = Vector3(0.75, 0.05, 4.5)
	_cat.global_position = Vector3(0.2, 0.05, 4.5)
	_cat.velocity = Vector3.ZERO
	_cat.rotation.y = -PI * 0.5
	await frames(3)
	_cat.strike()
	await frames(24)
	check(pr.hp == pr.max_hp - 1, "paw strike lands on a rat (hp %d/%d)" % [pr.hp, pr.max_hp])
	pr.global_position = Vector3(-4.5, 0.05, -0.5)
	pr.active = true

	var rat = RatScript.new()
	rat.position = Vector3(2.6, 0.05, 4.5)
	add_child(rat)
	rat.den = rat.position
	rat.target_cat = _cat
	var bites := [0]
	rat.bite.connect(func(_t, _d): bites[0] += 1)
	rat.bite.connect(_zone._on_enemy_bite)
	_cat.global_position = Vector3(0.2, 0.05, 4.5)
	_cat.velocity = Vector3.ZERO
	_cat.set_move_input(Vector3.ZERO, false, false)
	var hp_pre_rat: int = _zone.cat_hp
	var wait_bite := 0
	while bites[0] < 1 and wait_bite < 480:
		await frames(1)
		wait_bite += 1
	check(bites[0] >= 1, "rat chased and bit the cat (%d frames)" % wait_bite)
	check(_zone.cat_hp == hp_pre_rat - rat.bite_damage, "the bite subtracted HP through the zone (%d -> %d)" % [hp_pre_rat, _zone.cat_hp])
	rat.take_hit(2, _cat.global_position)
	var wait_flee := 0
	while rat.state != "flee" and wait_flee < 150:
		await frames(1)
		wait_flee += 1
	check(rat.state == "flee", "lone rat at 1 HP flees")
	var died_flag := [false]
	rat.died.connect(func(_r): died_flag[0] = true)
	rat.take_hit(1, _cat.global_position)
	await frames(40)
	check(died_flag[0] and rat.is_dead(), "rat dies at 0 HP and flops")
	check(absf(rat._model.rotation.z) > 1.0, "death flop: model rolled over (rot z %.2f)" % rat._model.rotation.z)
	rat.queue_free()

	# --- spider: drops on a cat passing under, bites, retreats ----------------------
	var sp = _zone.spiders[0]
	sp.active = true
	var sp_bites := [0]
	sp.bite.connect(func(_t, _d): sp_bites[0] += 1)
	_cat.global_position = Vector3(5.0, 0.05, -4.5)
	_cat.velocity = Vector3.ZERO
	_cat.set_move_input(Vector3.ZERO, false, false)
	var wait_drop := 0
	while sp.state not in ["bite_pause", "retreat", "cooldown"] and wait_drop < 300:
		await frames(1)
		wait_drop += 1
	check(sp.state != "hang", "spider dropped on the cat passing under (%d frames)" % wait_drop)
	check(sp_bites[0] >= 1, "spider bit once on the drop")
	var wait_up := 0
	while sp.state != "cooldown" and wait_up < 600:
		await frames(1)
		wait_up += 1
	check(sp.state == "cooldown" and sp._drop <= 0.10, "spider scurried back up its thread")
	_cat.global_position = ZoneScript.ENTRY_POS
	await frames(5)

	# --- the Alpha: HP bar, N strikes, the objective flips ---------------------------
	var alpha = _zone.alpha_rat
	check(alpha.hp == 10 and absf(alpha.hp_fraction() - 1.0) < 0.001, "alpha starts at full HP with a bar")
	alpha.take_hit(3, alpha.global_position + Vector3(1, 0, 0))
	await frames(5)
	check(alpha.hp == 7 and absf(alpha.hp_fraction() - 0.7) < 0.02, "alpha HP bar tracks damage (%.2f)" % alpha.hp_fraction())
	check(absf(alpha._bar_fg.scale.x - 0.7) < 0.05, "alpha bar foreground scaled to 0.7 (got %.2f)" % alpha._bar_fg.scale.x)
	for i in 7:
		alpha.take_hit(1, alpha.global_position + Vector3(1, 0, 0))
	await frames(10)
	check(alpha.is_dead(), "alpha rat dies after 10 strikes")
	check(_zone.objective_done("clear_labyrinth_heart"), "objective flips: labyrinth heart cleared")

	# --- a toy, collected ------------------------------------------------------------
	_cat.global_position = Vector3(-6.5, 0.05, 1.5)
	_cat.velocity = Vector3.ZERO
	await frames(20)
	check(_zone.toys_collected == 1, "ball collected by walking over it (%d/3)" % _zone.toys_collected)

	print("BASEMENT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
