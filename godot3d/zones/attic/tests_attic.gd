extends Node
## Headless tests for the attic zone (Willie and Aggie — Massey).
## Run: godot --headless --path godot3d res://zones/attic/tests_attic.tscn
## Loads the attic STANDALONE with a harness cat (PvKHarnessCat — a
## stand-in for the foundation lane's cat combat/jump pass) and
## asserts on STATE only, like the main smoke test.

const AtticScene := preload("res://zones/attic/attic.tscn")
const HarnessCatScene := preload("res://zones/attic/harness_cat.gd")
const RaccoonScene := preload("res://zones/attic/raccoon.gd")

var _pass := 0
var _fail := 0
var _attic = null
var _cat = null


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


func _place(node: Node3D, pos: Vector3, yaw := 0.0) -> void:
	node.velocity = Vector3.ZERO
	node.global_position = pos
	node.rotation.y = yaw


func _ready() -> void:
	_run()


func _run() -> void:
	print("ATTIC TESTS: loading zone standalone")
	_attic = AtticScene.instantiate()
	add_child(_attic)
	_cat = HarnessCatScene.new()
	_cat.name = "HarnessCat"
	add_child(_cat)
	_place(_cat, Vector3(4.55, 0.05, 3.55))
	_attic.setup(_cat)
	await frames(10)

	var mother = _attic.mother
	var kits: Array = _attic.kits

	# --- the family exists, sized and tuned as specced ----------------
	check(mother != null, "mother raccoon exists")
	check(kits.size() == 3, "three kits (got %d)" % kits.size())
	check(mother.hp_max == 12, "mother HP pool is the boss pool (got %d)" % mother.hp_max)
	check(kits[0].hp_max == 2, "kits are fragile (hp %d)" % kits[0].hp_max)
	check(mother.model_scale > kits[0].model_scale * 1.8, "mother ~2x kit scale (%.2f vs %.2f)" % [mother.model_scale, kits[0].model_scale])
	check(_cat.is_on_floor(), "cat stands on the attic floor")
	check(_cat.global_position.y > -0.1 and _cat.global_position.y < 0.25, "cat at floor height (y=%.2f)" % _cat.global_position.y)

	# --- objective data -------------------------------------------------
	var obj: Dictionary = _attic.get_objective("reclaim_attic")
	check(not obj.is_empty(), "objective 'reclaim_attic' loads from data")
	check(String(obj.get("title", "")) == "Reclaim the attic", "objective title is Willie's: Reclaim the attic")
	check(_attic.objective_state == "active", "objective starts active")
	check(not _attic.perch_unlocked, "perch locked before the win")

	# --- insulation slow zones -------------------------------------------
	check(absf(_attic.speed_factor_at(Vector3(0.8, 0.0, 2.6)) - 0.55) < 0.001, "inside a pile the cat is slowed (factor %.2f)" % _attic.speed_factor_at(Vector3(0.8, 0.0, 2.6)))
	check(absf(_attic.speed_factor_at(Vector3(-1.0, 0.0, 0.5)) - 1.0) < 0.001, "open floor is full speed")

	# --- contact damage cooldown (unit-level, spare raccoon) --------------
	var spare = RaccoonScene.new()
	spare.set_role("mother")
	add_child(spare)
	spare.set_target(_cat)
	_place(spare, Vector3(4.35, 0.05, 3.35))
	await frames(3)
	var hits0: int = _cat.hits_taken
	spare._try_contact(1, 0.62)
	spare._try_contact(1, 0.62)
	check(_cat.hits_taken == hits0 + 1, "contact damage lands once per cooldown (hits %d -> %d)" % [hits0, _cat.hits_taken])
	spare.queue_free()
	await frames(3)

	# --- harness jump (stand-in for the foundation cat pass) ---------------
	var y0: float = _cat.global_position.y
	_cat.jump()
	var ymax := y0
	for i in 50:
		await get_tree().physics_frame
		ymax = maxf(ymax, _cat.global_position.y)
	check(ymax > y0 + 0.8, "harness cat jumps (rose %.2f m)" % (ymax - y0))
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		if _cat.is_on_floor():
			landed = true
			break
	check(landed, "cat lands back on the floor")

	# --- the knee wall / roof stops the cat ----------------------------------
	_place(_cat, Vector3(3.0, 0.05, -3.4))
	_cat.set_move_input(Vector3(0, 0, -1), false, false)
	await frames(50)
	_cat.set_move_input(Vector3.ZERO, false, false)
	check(_cat.global_position.z > -4.62, "cat stopped by the knee wall (z=%.2f)" % _cat.global_position.z)
	check(_cat.global_position.z < -3.9, "cat actually walked to the wall (z=%.2f)" % _cat.global_position.z)

	# --- beams are walkable -----------------------------------------------------
	_place(_cat, Vector3(0.4, 1.78, 0.0))
	await frames(25)
	check(_cat.is_on_floor() and _cat.global_position.y > 1.45, "cat stands on a collar beam (y=%.2f)" % _cat.global_position.y)

	# --- kits scatter when faced ---------------------------------------------------
	var kit0 = kits[0]
	_place(_cat, Vector3(1.8, 0.05, 1.75), 0.0) # facing -z, at the kit
	_place(kit0, Vector3(1.8, 0.05, 0.6))
	var saw_scatter := false
	for i in 70:
		await get_tree().physics_frame
		if kit0.state in ["scatter", "cower"]:
			saw_scatter = true
			break
	check(saw_scatter, "kit scatters when the cat faces it (state %s)" % kit0.state)

	# --- kit nip-and-retreat ---------------------------------------------------------
	var kit1 = kits[1]
	_place(_cat, Vector3(0.5, 0.05, -2.2), 0.0) # facing -z, AWAY from the kit behind
	_place(kit1, Vector3(0.5, 0.05, -1.15))
	kit1._nip_cd = 0.0
	var hits_before: int = _cat.hits_taken
	var saw_nip := false
	var min_dist := 99.0
	for i in 110:
		await get_tree().physics_frame
		if kit1.state == "nip":
			saw_nip = true
		min_dist = minf(min_dist, kit1.global_position.distance_to(_cat.global_position))
	check(saw_nip, "kit darts in for a nip when the cat isn't looking")
	check(min_dist < 0.6 or _cat.hits_taken > hits_before, "nip connects (min dist %.2f, hits %d -> %d)" % [min_dist, hits_before, _cat.hits_taken])
	var settled := false
	for i in 130:
		await get_tree().physics_frame
		if kit1.state in ["retreat", "hover", "scatter", "cower"]:
			settled = true
			break
	check(settled, "kit retreats after the nip (state %s)" % kit1.state)

	# --- Mother: telegraph BEFORE charge, charge is fast, charge hurts ----------------
	for k in kits:
		_place(k, Vector3(5.4, 0.05, 4.15)) # park the kits far away
		k.set_physics_process(false) # frozen: no nips, no lane-blocking
	_place(mother, Vector3(-1.0, 0.05, -3.0))
	mother.home = mother.global_position
	mother._enter("guard") # clear any state the earlier tests left her in
	mother._charge_cd = 0.0
	_place(_cat, Vector3(-1.0, 0.05, -0.2), 0.0)
	var hits_pre_charge: int = _cat.hits_taken
	var order: Array = []
	var charge_speed_seen := 0.0
	var charge_amount := 0
	for i in 420:
		await get_tree().physics_frame
		if mother.state not in order:
			order.append(mother.state)
		if mother.state == "charge":
			charge_speed_seen = maxf(charge_speed_seen, Vector2(mother.velocity.x, mother.velocity.z).length())
		if _cat.hits_taken > hits_pre_charge and charge_amount == 0:
			charge_amount = _cat.last_hit_amount
		if _cat.hits_taken > hits_pre_charge and mother.state in ["recover", "guard"]:
			break
	check("telegraph" in order, "mother telegraphs before charging (saw %s)" % str(order))
	check("charge" in order, "mother charges (saw %s)" % str(order))
	check(order.find("telegraph") < order.find("charge"), "telegraph strictly precedes the charge")
	check(charge_speed_seen > 3.5, "charge is a fast rush (%.1f m/s)" % charge_speed_seen)
	check(_cat.hits_taken > hits_pre_charge, "charge/swipe run hurt the cat (hits %d -> %d)" % [hits_pre_charge, _cat.hits_taken])
	check(charge_amount == 2, "the charge itself deals 2 (first hit was %d)" % charge_amount)
	for k in kits:
		k.set_physics_process(true)

	# --- stagger at thresholds, and stagger scatters the kits ---------------------------
	_place(_cat, Vector3(4.55, 0.05, 3.55)) # far away; direct calls only
	for k in kits:
		_place(k, mother.global_position + Vector3(0.8, 0, 0.4))
		if k.state != "hover":
			k._enter("hover")
	mother.hp = mother.hp_max
	mother.take_hit(4, _cat.global_position)
	check(mother.state == "stagger", "mother staggers crossing 75%% HP (state %s)" % mother.state)
	check(absf(mother.hp_bar_fraction - 8.0 / 12.0) < 0.01, "HP bar fraction tracks damage (%.2f)" % mother.hp_bar_fraction)
	var all_scattered := true
	for k in kits:
		if k.state != "scatter":
			all_scattered = false
	check(all_scattered, "mother's stagger scatters every kit")
	await frames(70) # stagger + scatter play out
	check(mother.state == "guard", "mother recovers to guard after stagger")

	# --- kill Mother WITH THE PAW: objective flips, kits flee, rewards unlock ------------
	mother.hp = 1
	_place(mother, Vector3(0.0, 0.05, -0.6))
	mother._enter("guard")
	_place(_cat, Vector3(0.0, 0.05, 0.18), 0.0)
	await frames(4)
	var struck: bool = _cat.strike()
	check(struck, "cat strike starts")
	await frames(40)
	check(mother.state == "dead", "mother falls to the paw (state %s)" % mother.state)
	check(_attic.objective_state == "won", "objective flips to won")
	check(_attic.perch_unlocked, "window perch unlocks")
	check(_attic.hoard_revealed, "bottle-cap hoard revealed")
	check((_attic.get_node("BottleCapHoard") as Node3D).visible, "hoard node visible")
	var all_fled := false
	for i in 420:
		await get_tree().physics_frame
		var done := true
		for k in kits:
			if k.state != "fled":
				done = false
		if done:
			all_fled = true
			break
	check(all_fled, "with Mother down, every kit flees to the eaves for good")

	# --- the perch is a lounge spot -------------------------------------------------------
	_place(_cat, Vector3(PvKAttic.PERCH_POS.x, PvKAttic.PERCH_POS.y + 0.06, PvKAttic.PERCH_POS.z))
	await frames(15)
	check(_cat.is_on_floor() and _cat.global_position.y > 1.4, "cat stands on the window perch (y=%.2f)" % _cat.global_position.y)
	_cat.set_lounge(true)
	await frames(12)
	check(_cat.anim_state == "lounge", "cat lounges on the unlocked perch")

	print("ATTIC TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
