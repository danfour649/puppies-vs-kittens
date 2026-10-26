extends Node
## GLENYS tests — the cat-chaser (TODO.md, Daniel's locked spec).
## Run: godot --headless --path godot3d res://glenys/tests_glenys.tscn
## Drives the REAL game (main.tscn) like test_massey: asserts on
## state only. Covers: she targets the playable cat under BOTH
## character selections; predictive steering + divider routing;
## pursuit catches a stationary cat; the grab is a caught state
## (held, escapable by struggling) that costs NO hit points and
## drops a carried catch; a cat on a lap is safe; the forget-pause
## suspends pursuit; she follows zone travel after a delay; the
## chocolate kills ONLY when deliberately eaten (run-ending, no
## life spent, not a faint) and never by proximity; the basement
## rat poison kills only on the bait itself; the basement dressing
## landed without touching the maze contract.

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


func load_game():
	# Untyped on purpose (the test_massey pattern): the tests drive
	# main's script vars dynamically (game.zones, game.duo, ...).
	var g = load("res://main.tscn").instantiate()
	add_child(g)
	await frames(14)
	return g


func free_game(g: Node) -> void:
	remove_child(g)
	g.free()
	await frames(3)


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func wiggle_free(sys: GlenysSystem) -> void:
	for i in 8:
		sys.struggle_wiggle(Vector2(1, 0))
		sys.struggle_wiggle(Vector2(-1, 0))
	await frames(4)


func _ready() -> void:
	_run()


func _run() -> void:
	# ================= instance A: pursuit, grab, forget, follow ==============
	print("GLENYS TESTS A: loading main scene")
	var game = await load_game()
	var sys: GlenysSystem = game.get("glenys") as GlenysSystem
	var actor: Glenys = sys.actor
	check(sys != null and actor != null, "Glenys lives in the game (system + actor)")
	check(is_equal_approx(actor.walk_speed, 0.8), "cane pace: walk speed is 0.8 m/s (got %.2f)" % actor.walk_speed)
	check(game.objectives.get_item("glenys:escape_artist") != null, "escape objective declared")
	game.duo.choose("willie")
	await frames(4)
	check(sys.player_target() == game.cat and sys.player_target().character_id == "willie", "she targets the playable cat (Willie selected)")
	check(sys.state == "dormant", "dormant until the cats come into her house (state %s)" % sys.state)

	# Into her house: she wakes.
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	var t := 0
	while t < 90 and sys.state == "dormant":
		await frames(1)
		t += 1
	check(sys.state == "pursue", "she wakes when the cat enters the ground floor")
	sys.set("_forget_t", 9999.0) # isolate the pursuit asserts
	sys.set("_offer_t", 9999.0)
	var origin := HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
	var cat: PvKCat = game.cat

	# Predictive steering: drive the cat, the steer point leads it.
	actor.global_position = cat.global_position + Vector3(2.5, 0, -1.5)
	game.input_override["active"] = true
	game.input_override["move"] = Vector2(1, 0)
	await frames(24)
	game.input_override["active"] = false
	cat.set_move_input(Vector3.ZERO, false, false)
	check(cat.velocity.length() > 0.4, "test cat actually moving for the steering assert")
	var predicted := sys.steering_target()
	var lead := (predicted - cat.global_position).dot(cat.velocity.normalized())
	check(lead > 0.1, "steering leads the cat (corner-cutting prediction, lead %.2f m)" % lead)

	# Divider routing: she in the kitchen, cat in the living room,
	# her steer point is the doorway gap, not the wall.
	actor.global_position = origin + Vector3(-5.0, 0.1, -2.0)
	cat.global_position = origin + Vector3(3.0, 0.1, 2.0)
	cat.velocity = Vector3.ZERO
	await frames(3)
	var gap_point := sys.steering_target()
	check(flat(gap_point, origin + Vector3(HouseSpec.DIVIDER_X, 0, 0)) < 0.7, "steering routes through the divider gap (got %s)" % gap_point)

	# Pursuit catches a stationary cat in the same room.
	cat.set_lounge(false)
	actor.global_position = origin + Vector3(-0.5, 0.1, 1.0)
	var hp_before: float = cat.hp
	t = 0
	while t < 700 and sys.state != "grab":
		await frames(1)
		t += 1
	check(sys.state == "grab", "cane-paced pursuit still corners a stationary cat (%d frames)" % t)
	check(cat.is_held, "the grab is a caught state (cat held)")
	check(is_equal_approx(cat.hp, hp_before), "the grab costs NO hit points (%.0f -> %.0f)" % [hp_before, cat.hp])

	# Struggle out: score + objective, still no injury.
	await wiggle_free(sys)
	check(sys.state == "reset", "struggling frees the cat (she resets, state %s)" % sys.state)
	check(not cat.is_held, "the cat is loose after the struggle")
	check(sys.escapes == 1, "the escape is counted")
	check(int(game.objectives.get_item("glenys:escape_artist")["count"]) == 1, "escape objective progressed")
	check(is_equal_approx(cat.hp, hp_before), "the whole grab cost NO hit points, start to finish")

	# A carried catch is dropped by a grab (the duo respawn rule).
	game.caught_count = 2
	check(sys.debug_grab(), "second grab (debug seam)")
	check(game.caught_count == 1, "the grab drops a carried catch (2 -> %d)" % game.caught_count)
	await wiggle_free(sys)
	check(sys.escapes == 2, "second escape counted")

	# A cat on a lap is safe from her — even Glenys won't.
	cat.set_meta("on_lap", true)
	sys.state = "pursue"
	sys.set("_grab_cool", 0.0)
	actor.global_position = cat.global_position + Vector3(0.4, 0, 0.3)
	await frames(40)
	check(sys.state != "grab" and not cat.is_held, "a cat on a lap is safe from her")
	cat.set_meta("on_lap", false)
	t = 0
	while t < 200 and sys.state != "grab":
		await frames(1)
		t += 1
	check(sys.state == "grab", "off the lap, she can grab again")
	await wiggle_free(sys)

	# The forget-pause: she stops dead, then resumes.
	sys.state = "pursue" # the escape reset may still be running
	sys.force_forget()
	check(sys.state == "forget", "the dementia beat: she forgets mid-pursuit")
	var froze_at := actor.global_position
	await frames(30)
	check(flat(actor.global_position, froze_at) < 0.06, "pursuit is suspended while she forgets (moved %.3f m)" % flat(actor.global_position, froze_at))
	sys.set("_forget_left", 0.05)
	await frames(12)
	check(sys.state == "pursue", "…and then she remembers the cat")

	# The vanish: a cat who suddenly is NOT where he was (travel,
	# respawn, a scripted relocation) has given her the slip — she
	# breaks off, blinking, instead of beelining to the new spot.
	cat.global_position = origin + Vector3(-5.5, 0.1, 2.5)
	await frames(4)
	check(sys.state == "forget", "a vanished cat breaks off the pursuit (state %s)" % sys.state)
	sys.set("_forget_left", 0.05)
	await frames(10)

	# Zone following: the cat goes to the basement; she arrives
	# through the same connector after her delay.
	game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(4)
	check(sys.state == "follow_wait", "she follows zone travel (state %s)" % sys.state)
	sys.set("_follow_left", 0.05)
	await frames(14)
	check(sys.her_zone == HouseSpec.BASEMENT, "she arrives in the cat's new zone")
	var entry_world := HouseSpec.zone_origin(HouseSpec.BASEMENT) + Vector3(2.85, 0, 4.05)
	check(flat(actor.global_position, entry_world) < 1.6, "she comes through the basement entry (at %s)" % actor.global_position)
	check(sys.state == "pursue" or sys.state == "grab", "and the pursuit resumes downstairs (state %s)" % sys.state)
	if sys.state == "grab":
		await wiggle_free(sys)

	# Targeting follows the character select.
	game.duo.choose("aggie")
	await frames(4)
	check(sys.player_target() == game.cat and sys.player_target().character_id == "aggie", "she targets the playable cat (Aggie selected)")
	await free_game(game)

	# ================= instance B: the chocolate, eaten =======================
	print("GLENYS TESTS B: the chocolate, eaten on purpose")
	game = await load_game()
	sys = game.get("glenys") as GlenysSystem
	actor = sys.actor
	game.duo.choose("willie")
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(6)
	sys.force_wake()
	sys.set("_forget_t", 9999.0)
	cat = game.cat
	cat.set_lounge(false)
	actor.global_position = cat.global_position + Vector3(2.0, 0, 0.5)
	sys.force_offer()
	check(sys.state == "offer", "she offers the chocolate")
	var lives_before: int = game.lives
	cat.global_position = actor.chocolate_point() + Vector3(0.3, 0, 0)
	cat.velocity = Vector3.ZERO
	sys.set_eat_held(true)
	t = 0
	while t < 160 and not cat.is_poisoned:
		await frames(1)
		t += 1
	check(cat.is_poisoned, "holding to eat the chocolate poisons the cat")
	check(game.run_over, "a poison death ENDS THE RUN")
	check(game.lives == lives_before, "no nine-lives spent on a poison death (%d)" % game.lives)
	check(not cat.is_fainted, "poison is not a faint — no hub respawn flow")
	check(sys.state == "distraught", "and Glenys is distraught (she meant it as a treat)")
	await free_game(game)

	# ================= instance C: refused / mere proximity ===================
	print("GLENYS TESTS C: proximity never kills; refusal works")
	game = await load_game()
	sys = game.get("glenys") as GlenysSystem
	actor = sys.actor
	game.duo.choose("willie")
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(6)
	sys.force_wake()
	sys.set("_forget_t", 9999.0)
	cat = game.cat
	cat.set_lounge(false)
	actor.global_position = cat.global_position + Vector3(2.0, 0, 0.5)
	sys.force_offer()
	cat.global_position = actor.chocolate_point() + Vector3(0.3, 0, 0)
	cat.velocity = Vector3.ZERO
	await frames(90) # a full 1.5 s standing IN the chocolate's face
	check(not cat.is_poisoned and not game.run_over, "standing next to the chocolate never auto-kills")
	sys.set("_offer_left", 0.05)
	await frames(14)
	# The offer is over and the game is live again — pursuit, or
	# (he's standing right there) an immediate grab. Both are the
	# correct continuation; a lingering "offer" state is not.
	check(sys.state == "pursue" or sys.state == "grab", "an uneaten offer ends and the game moves on (state %s)" % sys.state)
	if sys.state == "grab":
		await wiggle_free(sys)
	check(not cat.is_poisoned and not game.run_over, "refusing the chocolate costs nothing")
	await free_game(game)

	# ================= instance D: rat poison + dressing ======================
	print("GLENYS TESTS D: the basement bait and the dressing")
	game = await load_game()
	game.duo.choose("willie")
	game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(6)
	cat = game.cat
	var roots: Dictionary = game.get("_zone_roots")
	var basement: PvKBasement = roots[HouseSpec.BASEMENT] as PvKBasement
	check(int(basement.get("dressing_count")) >= 12, "basement dressing landed (%d props)" % int(basement.get("dressing_count")))
	var bait_world := basement.to_global(basement.poison_pos())
	cat.global_position = bait_world + Vector3(1.3, 0.1, 0)
	cat.velocity = Vector3.ZERO
	await frames(24)
	check(not cat.is_poisoned, "beside the bait is safe (contact only)")
	cat.global_position = bait_world + Vector3(0, 0.1, 0)
	cat.velocity = Vector3.ZERO
	t = 0
	while t < 60 and not cat.is_poisoned:
		await frames(1)
		t += 1
	check(cat.is_poisoned, "getting INTO the rat poison bait is lethal")
	check(game.run_over, "rat poison ends the run the same way")
	await free_game(game)

	# ================= instance E: across the furniture line ==============
	# Regression for the furniture stall (found by the close-out
	# in-game drive, 2026-10-25): the divider routing used to drop
	# out at |z| <= 0.9 while the actual gap is |z| <= 0.6, so a
	# cat east of the living-room furniture line left her pinned
	# at GF local (-2.09, 0.90) in a target flip-flop, dist
	# frozen (the front-door cat: 5.30 m, never grabbed). These
	# stagings park a STATIONARY cat across the divider and
	# require the grab, front-door + mid-room + the mirror.
	# EACH STAGE GETS A FRESH GAME: a grab at the front-door
	# entry ends with the cat popping free ON the door connector
	# disc, which travels him outside - shared-instance staging
	# inherits current_zone = outside, which silently disables
	# the very routing under test (that desync bit this suite's
	# first draft: E2 "passed" on an outside follow-grab and E3
	# ran with her_zone stuck outside, routing off).
	print("GLENYS TESTS E: pursuit across the furniture line (stall regression)")
	origin = HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
	var stages: Array = [
		["front-door cat, her in the NW kitchen", Vector3(-4.5, 0.1, 3.2), Vector3(2.5, 0.0, 3.55)],
		["mid-room cat, her in the NW kitchen", Vector3(-4.5, 0.1, 3.2), Vector3(0.5, 0.0, 1.5)],
		["kitchen cat, her in the living room (mirror)", Vector3(-0.5, 0.1, 1.0), Vector3(-4.5, 0.0, 3.2)],
	]
	for st in stages:
		game = await load_game()
		sys = game.get("glenys") as GlenysSystem
		actor = sys.actor
		game.duo.choose("willie")
		game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
		await frames(6)
		sys.force_wake()
		cat = game.cat
		cat.set_lounge(false)
		actor.global_position = origin + (st[1] as Vector3)
		actor.velocity = Vector3.ZERO
		cat.global_position = origin + (st[2] as Vector3)
		cat.velocity = Vector3.ZERO
		# The cat's teleport is a vanish: burn her slip-pause off
		# instantly, then pin forget and offers out of the run.
		var w := 0
		while sys.state != "pursue" and w < 300:
			if sys.state == "forget":
				sys.set("_forget_left", 0.01)
			if sys.state == "reset":
				sys.set("_reset_left", 0.01)
			await frames(1)
			w += 1
		sys.set("_forget_t", 9999.0)
		sys.set("_offer_t", 9999.0)
		sys.set("_grab_cool", 0.0)
		t = 0
		while t < 1500 and sys.state != "grab":
			await frames(1)
			t += 1
			if t % 120 == 0:
				sys.set("_forget_t", 9999.0)
				sys.set("_offer_t", 9999.0)
		check(sys.state == "grab", "she corners a stationary cat across the furniture line: %s (%d frames)" % [st[0], t])
		await free_game(game)

	print("GLENYS TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
