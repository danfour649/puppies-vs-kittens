extends Node
## Headless tests for the HEAT system (duo/heat_system.gd): Aggie's
## heat cycle, her solicitation of the neutered Willie, his comedy
## response table, the player-Aggie urge/interrupt path, and the
## no-kittens invariant. Run:
##   godot --headless --path godot3d res://duo/tests_heat.tscn
## Same discipline as tests_duo.gd: drive the real game, assert on
## STATE only — never on rendered pixels.

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


func _wait_for(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _cat_count(game: Node) -> int:
	var n := 0
	var stack: Array = [game]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is PvKCat:
			n += 1
		for c: Node in node.get_children():
			stack.append(c)
	return n


func _ready() -> void:
	_run()


func _run() -> void:
	# ---------- audio: the yowl is real, generated data ----------
	var ystream := MeowAudio.stream_for("aggie_yowl")
	check(ystream != null, "aggie yowl stream generated")
	check(absf(ystream.get_length() - 1.15) < 0.06, "yowl ~1.15 s, long (got %.2f)" % ystream.get_length())
	var chirp := MeowAudio.stream_for("aggie")
	check(ystream.get_length() > chirp.get_length() * 4.0,
		"yowl unmistakably longer than Aggie's chirp (%.2f vs %.2f)" % [ystream.get_length(), chirp.get_length()])

	# ---------- PHASE A: play as Willie, Aggie is the NPC ----------
	print("HEAT A: loading main scene (play as Willie)")
	DuoCharacters.last_choice = ""
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await frames(12)
	var duo = game.duo
	var heat = duo.heat
	check(heat != null, "heat system present")
	check(heat.state == "off", "heat starts off (state=%s)" % heat.state)
	check(heat.cycle_time_left > 0.0 and heat.cycle_time_left <= 30.5,
		"first cycle is on the clock (%.1f s)" % heat.cycle_time_left)
	duo.choose("willie")
	await frames(5)
	var willie = duo.willie_cat
	var aggie = duo.aggie_cat
	duo.sibling.autonomous = false
	check(not heat.bowl_tipped, "the drink bowl starts upright")
	# Start a heat stretch and hold it open.
	heat.force_heat()
	check(heat.state == "heat", "forced heat starts")
	check(heat.heat_time_left >= 29.9 and heat.heat_time_left <= 60.1,
		"heat stretch is 30-60 s as specced (rolled %.1f)" % heat.heat_time_left)
	heat.heat_time_left = 999.0
	await frames(3)
	check(duo.sibling.mode.begins_with("heat"), "Aggie is on heat behaviour (mode=%s)" % duo.sibling.mode)
	# She hunts him down wherever he is.
	willie.velocity = Vector3.ZERO
	willie.global_position = Vector3(0, 0.05, 0)
	aggie.velocity = Vector3.ZERO
	aggie.global_position = Vector3(-8, 0.05, -6)
	aggie.set_lounge(false)
	var sought := await _wait_for(func() -> bool: return duo.sibling.mode == "heat_solicit", 1200)
	check(sought, "Aggie hunted Willie down and solicits (mode=%s)" % duo.sibling.mode)
	check(_flat(aggie.global_position, willie.global_position) < 1.1,
		"solicitation happens at his side (%.2f m)" % _flat(aggie.global_position, willie.global_position))
	await frames(30)
	check(aggie.courtship_k > 0.4, "the courtship pose is up: roll/present (k=%.2f)" % aggie.courtship_k)
	check(heat.yowl_count >= 1, "she yowls while she solicits (count=%d)" % heat.yowl_count)
	# He dodges: she follows. That is the hazard.
	willie.global_position = Vector3(7, 0.05, 6)
	var reseek := await _wait_for(func() -> bool: return duo.sibling.mode == "heat_seek", 240)
	check(reseek, "he moved off — she breaks off and hunts again (mode=%s)" % duo.sibling.mode)
	var sought2 := await _wait_for(func() -> bool: return duo.sibling.mode == "heat_solicit", 1200)
	check(sought2, "she ran him down a second time (mode=%s)" % duo.sibling.mode)
	# Dignity: a provocation flurry suspends heat behaviour; it resumes.
	aggie.global_position = willie.global_position + Vector3(1.2, 0.05, 0)
	aggie.set_lounge(false)
	await frames(5)
	for i in 3:
		duo.emit_meow(willie)
		await frames(2)
	check(duo.prov.state == "active", "Willie's meowing provoked her mid-heat")
	await frames(10)
	check(heat.state == "heat", "heat itself survives the interruption")
	check(not duo.sibling.mode.begins_with("heat"), "heat behaviour suspended for the flurry (mode=%s)" % duo.sibling.mode)
	var cooled := await _wait_for(func() -> bool: return duo.prov.state == "cooldown", 1500)
	check(cooled, "the flurry played out and cooled down")
	var resumed := await _wait_for(func() -> bool: return duo.sibling.mode.begins_with("heat"), 600)
	check(resumed, "heat behaviour resumes after the flurry (mode=%s)" % duo.sibling.mode)
	# End of heat: poses down, sibling released.
	heat.end_heat()
	await frames(5)
	check(heat.state != "heat", "heat ends on command (state=%s)" % heat.state)
	check(aggie.courtship_target == 0.0, "courtship pose released at heat end")
	check(not duo.sibling.mode.begins_with("heat"), "sibling released from heat modes (mode=%s)" % duo.sibling.mode)
	check(_cat_count(game) == 2, "NO KITTENS: exactly two cats exist (count=%d)" % _cat_count(game))
	game.queue_free()
	await frames(5)

	# ---------- PHASE B: play as Aggie, Willie is the NPC ----------
	print("HEAT B: loading main scene (play as Aggie)")
	DuoCharacters.last_choice = ""
	var game2 = load("res://main.tscn").instantiate()
	add_child(game2)
	await frames(12)
	var duo2 = game2.duo
	var heat2 = duo2.heat
	duo2.choose("aggie")
	await frames(5)
	var player2: PvKCat = game2.cat
	var willie2 = duo2.willie_cat
	duo2.sibling.autonomous = false
	heat2.force_heat()
	heat2.heat_time_left = 999.0
	check(heat2.state == "heat", "heat runs with Aggie as the player")
	# The urge climbs while she's away from him.
	player2.velocity = Vector3.ZERO
	player2.global_position = Vector3(-9, 0.05, -7)
	willie2.velocity = Vector3.ZERO
	willie2.global_position = Vector3(9, 0.05, 7)
	await frames(240)
	check(heat2.urge > 10.0, "the urge meter climbs in heat (urge=%.1f)" % heat2.urge)
	check(heat2._objective_label.visible, "the Find Willie objective shows for player Aggie")
	check(heat2._urge_bar.visible, "the urge bar shows for player Aggie")
	# The involuntary roll-and-yowl interrupt: brief, then control back.
	var yowls_before: int = heat2.yowl_count
	heat2.force_interrupt()
	check(player2.courtship_target == 1.0, "interrupt: the courtship pose takes her over")
	check(bool(game2.input_override["active"]), "interrupt: control wobbles (input override on)")
	await frames(80)
	check(not bool(game2.input_override["active"]), "interrupt ends and control returns")
	check(player2.courtship_target == 0.0, "interrupt: pose released")
	check(heat2.yowl_count > yowls_before, "interrupt: she yowled (count=%d)" % heat2.yowl_count)
	# Willie's response table, performed on cue beside her.
	player2.velocity = Vector3.ZERO
	player2.global_position = Vector3(0, 0.05, 1.7)
	willie2.velocity = Vector3.ZERO
	willie2.global_position = player2.global_position + Vector3(1.2, 0.05, 0)
	await frames(5)
	heat2.force_response("stare")
	check(duo2.sibling.mode == "heat_stare", "response: the blank stare (mode=%s)" % duo2.sibling.mode)
	var stare_done := await _wait_for(func() -> bool: return duo2.sibling.mode == "idle", 400)
	check(stare_done, "the stare ends on its own")
	heat2.force_response("groom")
	check(duo2.sibling.mode == "heat_groom", "response: pointed self-grooming (mode=%s)" % duo2.sibling.mode)
	await frames(15)
	check(willie2.act_pose == "groom", "the groom pose is on him (pose=%s)" % willie2.act_pose)
	var groom_done := await _wait_for(func() -> bool: return duo2.sibling.mode == "idle", 400)
	check(groom_done and willie2.act_pose == "", "the grooming ends and the pose clears")
	heat2.force_response("knock")
	check(duo2.sibling.mode == "heat_knock", "response: off to knock the drink over (mode=%s)" % duo2.sibling.mode)
	var tipped := await _wait_for(func() -> bool: return heat2.bowl_tipped, 1500)
	check(tipped, "Willie reached the bowl and knocked it over (tipped=%s)" % str(heat2.bowl_tipped))
	check(heat2.response_log.has("knock"), "the knock is in the response log")
	var knock_done := await _wait_for(func() -> bool: return duo2.sibling.mode == "idle", 600)
	check(knock_done, "he saunters back from the bowl")
	# The half-hearted mount attempt — and the punchline.
	willie2.velocity = Vector3.ZERO
	willie2.global_position = player2.global_position + Vector3(1.5, 0.05, 0)
	await frames(5)
	heat2.force_response("mount")
	check(duo2.sibling.mode == "heat_mount", "response: the half-hearted mount attempt (mode=%s)" % duo2.sibling.mode)
	var held := await _wait_for(func() -> bool: return duo2.sibling.mode == "heat_mount_hold", 900)
	check(held, "he hops on and holds a beat (mode=%s)" % duo2.sibling.mode)
	check(heat2.mount_attempts == 1, "the attempt is counted (attempts=%d)" % heat2.mount_attempts)
	check(heat2.punchline_shown, "the punchline popup fired on the first attempt")
	check(heat2._popup_label.text == HeatSystem.PUNCHLINE, "the popup states it plainly: '%s'" % heat2._popup_label.text)
	var mount_done := await _wait_for(func() -> bool: return duo2.sibling.mode == "idle", 400)
	check(mount_done, "immediate disinterest: he wanders off")
	# The scheduler also performs on its own when she's near.
	var log_size: int = heat2.response_log.size()
	player2.velocity = Vector3.ZERO
	willie2.velocity = Vector3.ZERO
	willie2.global_position = player2.global_position + Vector3(1.2, 0.05, 0)
	var auto := await _wait_for(func() -> bool: return heat2.response_log.size() > log_size, 1200)
	check(auto, "the response scheduler performs unprompted (log=%d)" % heat2.response_log.size())
	# No kittens. Ever. After everything.
	check(_cat_count(game2) == 2, "NO KITTENS: still exactly two cats (count=%d)" % _cat_count(game2))
	var kitten_found := false
	var stack2: Array = [game2]
	while not stack2.is_empty():
		var nd: Node = stack2.pop_back()
		if nd.name.to_lower().contains("kitten"):
			kitten_found = true
		for c2: Node in nd.get_children():
			stack2.append(c2)
	check(not kitten_found, "no kitten node exists anywhere in the tree")
	heat2.end_heat()
	await frames(5)
	check(not heat2.bowl_tipped, "the bowl is set back upright after the heat")
	game2.queue_free()
	await frames(3)
	print("HEAT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
