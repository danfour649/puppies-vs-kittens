extends Node
## Headless tests for the DUO iteration (character select, sibling
## NPC, meow + provocation). Run:
##   godot --headless --path godot3d res://duo/tests_duo.tscn
## Same discipline as tests/smoke.gd: drive the real game, assert on
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


func _alive_mice(game: Node) -> Array:
	var out: Array = []
	for m: Variant in game.mice:
		if is_instance_valid(m) and (m as PvKMouse).state != "caught":
			out.append(m)
	return out


func _ready() -> void:
	_run()


func _run() -> void:
	# ---------- audio: the meow is real, generated data ----------
	var wstream := MeowAudio.stream_for("willie")
	check(wstream != null, "willie meow stream generated")
	check(absf(wstream.get_length() - 0.45) < 0.06, "willie meow ~0.45 s (got %.2f)" % wstream.get_length())
	var astream := MeowAudio.stream_for("aggie")
	check(absf(astream.get_length() - 0.18) < 0.05, "aggie chirp ~0.18 s (got %.2f)" % astream.get_length())

	# ---------- PHASE A: play as Willie, sibling is Aggie ----------
	print("DUO A: loading main scene (play as Willie)")
	DuoCharacters.last_choice = "" # fresh process state for phase A
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await frames(12)
	var duo = game.duo
	check(duo != null, "duo system present")
	check(duo.select_ui.option_count() == 2, "character select builds two options (got %d)" % duo.select_ui.option_count())
	check(duo.select_visible(), "character select shows at game start")
	# MK-pattern select (2026-10-25): the highlight starts on the
	# first cat, moves WITHOUT picking, and confirm() picks the
	# highlighted cat through the real chosen signal.
	check(duo.select_ui.highlighted_id() == "willie", "select highlight starts on Willie (got %s)" % duo.select_ui.highlighted_id())
	duo.select_ui.highlight("aggie")
	check(duo.select_ui.highlighted_id() == "aggie", "highlight moves to Aggie without picking")
	check(duo.select_visible(), "moving the highlight does not pick")
	for cid: String in ["willie", "aggie"]:
		var chd: Dictionary = duo.chars[cid]
		check(String(chd.get("line", "")) != "", "%s carries its one select line" % cid)
		check(String(chd.get("start_name", "")) != "", "%s carries a start name for the minimap" % cid)
	check(duo.select_ui._minimap.starts.size() == 2, "minimap marks both cats' real starts")
	duo.select_ui.highlight("willie")
	duo.select_ui.confirm()
	await frames(5)
	check(not duo.select_visible(), "confirm picks the highlighted cat and closes the select")
	var willie = duo.willie_cat
	var aggie = duo.aggie_cat
	check(willie != null and aggie != null and willie != aggie, "two distinct cat instances")
	check(game.cat == willie, "default player is the first character")
	check(String(aggie.species_name) == String(duo.chars["aggie"]["name"]), "sibling name comes from character data (got %s)" % aggie.species_name)
	check(duo.sibling_cat() == aggie, "sibling is the other cat")
	check(String(aggie.pattern) == "tortoiseshell", "sibling Aggie uses the real tortie pattern (got %s)" % aggie.pattern)
	check(aggie.mottle_count > 0, "sibling Aggie model has tortie mottle patches (count=%d)" % aggie.mottle_count)
	check(absf(aggie.model_scale - 0.25) < 0.011, "sibling Aggie scale is 0.25 from the characters schema (got %.2f)" % aggie.model_scale)
	check(String(willie.pattern) == "bicolor" and willie.stripe_count > 0, "Willie is the striped bicolor build (stripes=%d)" % willie.stripe_count)
	check(absf(willie.model_scale - 0.35) < 0.011, "Willie scale is 0.35 from the characters schema (got %.2f)" % willie.model_scale)
	await frames(30)
	check(duo.sibling.mode == "lounge", "sibling starts chill: lounging (got %s)" % duo.sibling.mode)
	check(aggie.is_lounging, "sibling cat is in the lounge flop")
	duo.choose("willie")
	await frames(5)
	check(not duo.select_visible(), "select closes on choose")
	check(game.cat == willie, "player stays Willie after choosing him")
	# Freeze the mice so catch checks are about mechanics, not fleeing.
	for m: Variant in game.mice:
		m.cat = null
	await _catch_one(game, willie, game.mice[0])
	check(game.caught_count == 1, "Willie caught a mouse (caught=%d)" % game.caught_count)
	# Provocation: park Aggie beside Willie and let him meow.
	duo.sibling.autonomous = false
	aggie.velocity = Vector3.ZERO
	aggie.global_position = willie.global_position + Vector3(1.2, 0.05, 0)
	aggie.set_lounge(false)
	await frames(5)
	for i in 3:
		duo.emit_meow(willie)
		await frames(2)
	check(duo.meow_count >= 3, "meows went through the audio path (count=%d)" % duo.meow_count)
	check(duo.prov.state == "active", "three meows in earshot provoked Aggie (state=%s)" % duo.prov.state)
	var saw_flurry := await _wait_for(func() -> bool: return duo.sibling.mode == "flurry", 600)
	check(saw_flurry, "Aggie dashed in and started her flurry (mode=%s)" % duo.sibling.mode)
	var saw_cool := await _wait_for(func() -> bool: return duo.prov.state == "cooldown", 900)
	check(saw_cool, "Aggie fled and the meter cooled down (state=%s)" % duo.prov.state)
	check(duo.prov.meter == 0.0, "meter reset after the flurry")
	check(game.caught_count == 0, "the flurry made Willie drop his catch (caught=%d)" % game.caught_count)
	check(_alive_mice(game).size() == 7, "the dropped mouse escaped back into the yard (alive=%d)" % _alive_mice(game).size())
	# The mice loop still completes -> win, sibling notwithstanding.
	duo.sibling.autonomous = false
	duo.sibling.go_lounge(Vector3(4.5, 0.46, 4.5))
	# Re-freeze ALL mice — including the respawned one, which was
	# spawned live (correctly: in the real game it should flee).
	for m: Variant in game.mice:
		if is_instance_valid(m):
			m.cat = null
	await frames(10)
	# HARDENED (win-loop race): do NOT iterate a snapshot of the
	# alive list. One swipe catches every mouse inside the catch
	# radius, so an earlier strike can catch a later snapshot entry
	# too — and a caught mouse frees itself ~0.23 s later, so the
	# snapshot entry could be caught or outright freed by the time
	# its turn came (the old loop then struck at a freed instance).
	# Re-fetch the alive list before every catch instead; the win
	# is still earned mouse by mouse through the same mechanics,
	# and the guard only bounds a loop that is no longer catching.
	var win_guard := 0
	while not game.won and win_guard < 40:
		win_guard += 1
		var alive_now := _alive_mice(game)
		if alive_now.is_empty():
			break
		await _catch_one(game, willie, alive_now[0])
	check(game.won, "win state reached with the sibling in the yard")
	check((game.get("_banner") as Label).visible, "win banner visible")
	game.queue_free()
	await frames(5)

	# ---------- PHASE B: play as Aggie, sibling is Willie ----------
	print("DUO B: loading main scene (play as Aggie)")
	DuoCharacters.last_choice = ""
	var game2 = load("res://main.tscn").instantiate()
	add_child(game2)
	await frames(12)
	var duo2 = game2.duo
	check(duo2.chars.size() >= 2, "character data has both cats")
	duo2.choose("aggie")
	await frames(5)
	check(game2.cat == duo2.aggie_cat, "player is Aggie after choosing her")
	check(game2.cat.model_scale < duo2.willie_cat.model_scale,
		"player Aggie is smaller than sibling Willie (%.2f < %.2f)" % [game2.cat.model_scale, duo2.willie_cat.model_scale])
	check(duo2.sibling_cat() == duo2.willie_cat, "sibling is Willie")
	check(String(game2.cat.pattern) == "tortoiseshell" and game2.cat.mottle_count > 0, "player Aggie is the real tortie model (pattern=%s, mottles=%d)" % [game2.cat.pattern, game2.cat.mottle_count])
	# Willie NPC paths AROUND the player, not through her.
	var sib2 = duo2.sibling
	sib2.autonomous = false
	var player2 = game2.cat
	player2.velocity = Vector3.ZERO
	player2.global_position = Vector3(0, 0.05, 1.7)
	duo2.willie_cat.velocity = Vector3.ZERO
	duo2.willie_cat.global_position = Vector3(-8, 0.05, 0)
	sib2.go_lounge(Vector3(8.5, 0.0, 3.5))
	var min_d := 999.0
	var arrived := false
	for i in 1500:
		await get_tree().physics_frame
		var d := Vector2(duo2.willie_cat.global_position.x - player2.global_position.x,
			duo2.willie_cat.global_position.z - player2.global_position.z).length()
		min_d = minf(min_d, d)
		if sib2.mode == "lounge":
			arrived = true
			break
	check(arrived, "Willie NPC walked to his lounge spot (mode=%s)" % sib2.mode)
	check(min_d > 0.22, "Willie NPC path kept off the player (min distance %.2f m)" % min_d)
	# NPC Willie's own meowing provokes the PLAYER Aggie -> buff.
	duo2.willie_cat.velocity = Vector3.ZERO
	duo2.willie_cat.global_position = player2.global_position + Vector3(2.0, 0.05, 0)
	await frames(3)
	for i in 3:
		duo2.emit_meow(duo2.willie_cat)
		await frames(2)
	check(duo2.prov.state == "active", "player Aggie provoked by NPC Willie's meowing")
	check(duo2.prov.speed_multiplier() > 1.39, "provoked speed buff applies (x%.2f)" % duo2.prov.speed_multiplier())
	check(game2.catch_radius > 0.43, "provoked catch radius widened (%.2f)" % game2.catch_radius)
	check(duo2.aura.visible, "provoked aura is visible")
	check(player2.walk_speed > float(duo2.chars["aggie"]["walk_speed"]) * 1.3,
		"player cat's walk speed is actually raised (%.2f)" % player2.walk_speed)
	# Provoked catch: a mouse 0.55 m past the paw point is out of the
	# base 0.42 arc but inside the provoked one — one hit takes it.
	for m: Variant in game2.mice:
		m.cat = null
	var mouse2: PvKMouse = game2.mice[0]
	player2.velocity = Vector3.ZERO
	player2.global_position = Vector3(0, 0.05, 1.7)
	player2.rotation.y = 0.0
	await frames(3)
	var paw: Vector3 = player2.paw_point()
	mouse2.global_position = paw + player2.forward_dir() * 0.55
	await frames(2)
	var ok2: bool = player2.strike()
	check(ok2, "provoked strike started")
	await frames(50)
	check(game2.caught_count == 1, "provoked strike caught the out-of-arc mouse (caught=%d)" % game2.caught_count)
	game2.queue_free()
	await frames(3)

	# ---------- PHASE C: walked lounge arrival (chair regression) ----------
	# The garden chair's seat slab stops a walking cat at a flat
	# ~0.50 m from centre; with the stock 0.45 arrival radius a
	# walked arrival NEVER fired (she could only lounge there from
	# her spawn point on it). Regression: start her on the ground,
	# send her to the chair, require a real walked arrival.
	print("DUO C: walked arrival at the garden chair")
	DuoCharacters.last_choice = ""
	var game3 = load("res://main.tscn").instantiate()
	add_child(game3)
	await frames(12)
	var duo3 = game3.duo
	var sib3 = duo3.sibling
	var scat3: PvKCat = duo3.sibling_cat()
	duo3.choose("willie")
	sib3.autonomous = false
	var chair_spot := Vector3(4.5, 0.46, 4.5) # main.CHAIR_SEAT
	scat3.velocity = Vector3.ZERO
	scat3.global_position = Vector3(4.5, 0.05, 7.3) # ground, 2.8 m south of the chair
	await frames(3)
	sib3.go_lounge(chair_spot)
	var walked := await _wait_for(func() -> bool: return sib3.mode == "lounge" and scat3.is_lounging, 900)
	check(walked, "sibling WALKED to the garden chair and lounged (mode=%s)" % sib3.mode)
	var flat_d := Vector2(scat3.global_position.x - chair_spot.x, scat3.global_position.z - chair_spot.z).length()
	check(flat_d < 0.05, "sibling settled on the chair seat (flat dist %.2f)" % flat_d)
	game3.queue_free()
	await frames(3)
	print("DUO TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _wait_strike(game: Node, cat: PvKCat, cond: Callable, max_frames: int) -> bool:
	# _wait_for plus the tree-climb release. A swipe beside a trunk
	# whose squirrel is taunting makes the outside system auto-start
	# a climb (its paw_swiped handler, "nothing struck at a trunk"
	# step), and the climb turns the cat's PHYSICS PROCESS OFF until
	# the player climbs down — so a staged strike can freeze
	# mid-swing (_strike_t parked just past the 0.10 s swipe) and
	# strike() then refuses forever: the long "strike started"
	# failure streaks. That is intended game behaviour (the outside
	# suite tests the auto-climb); the harness simply has to climb
	# back down, through the game's own test seam (climb_axis_debug
	# is the S key), before the strike state can advance again.
	var sys = game.outside
	for i in max_frames:
		if bool(cond.call()):
			if sys != null:
				sys.climb_axis_debug = 0.0
			return true
		if sys != null and sys.climbing() and sys.player_cat() == cat:
			sys.climb_axis_debug = -1.0
		await get_tree().physics_frame
	if sys != null:
		sys.climb_axis_debug = 0.0
	return bool(cond.call())


func _catch_one(game: Node, cat: PvKCat, mouse: PvKMouse) -> void:
	# HARDENED (win-loop race): never strike on a fixed frame
	# cadence. A strike cycle is 0.34 s of strike plus the species'
	# strike_cooldown of recovery (~0.72 s total for Willie); the
	# old fixed 45-frame settle after each strike left only ~5
	# frames of slack over that cycle, which vanished under box
	# load and strike() started failing its check in streaks.
	# Poll the cat's real strike state instead (the suite already
	# reaches into internals elsewhere, e.g. select_ui._minimap),
	# via _wait_strike so a swipe-triggered tree climb cannot
	# freeze the swing mid-cycle. The target is also re-validated
	# before anything touches it: a previous swipe may have caught
	# it already, and a caught mouse frees itself moments later.
	if not is_instance_valid(mouse) or mouse.state == "caught":
		return
	# Stand the cat half a metre behind the mouse, facing it (-Z fwd).
	cat.velocity = Vector3.ZERO
	cat.global_position = Vector3(mouse.global_position.x, 0.05, mouse.global_position.z + 0.5)
	cat.rotation.y = 0.0
	await frames(3)
	# Wait for the previous strike cycle to fully recover. The
	# bound is generous; on timeout we still attempt the strike
	# below and its check reports the failure, exactly as before.
	await _wait_strike(game, cat, func() -> bool: return cat._strike_t < 0.0 and cat._strike_cd <= 0.0, 900)
	if not is_instance_valid(mouse) or mouse.state == "caught":
		return
	# Pin the mouse on the paw point at the last moment: a
	# wandering mouse can drift out of the arc during the strike
	# windup otherwise.
	var pp: Vector3 = cat.paw_point()
	mouse.global_position = Vector3(pp.x, 0.0, pp.z)
	var ok: bool = cat.strike()
	check(ok, "strike started")
	# Wait for THIS strike to run its course (the swipe resolves
	# at 0.10 s, the strike ends at 0.34 s) rather than counting
	# a fixed 45 frames that raced the cooldown under load.
	await _wait_strike(game, cat, func() -> bool: return cat._strike_t < 0.0, 300)
	await frames(3)
