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
	# Willie's photo palette, asserted on the values fed into the
	# materials (data level only — rendered readbacks lie headless).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://cat_kit/cat_species.json"))
	var chars: Dictionary = data.get("characters", {})
	var willie: Dictionary = chars.get("willie", {})
	var pal: Dictionary = willie.get("palette", {})
	var j_coat: Array = pal.get("coat", [])
	var j_ginger: Array = pal.get("ginger", [])
	var j_eye: Array = pal.get("eye", [])
	var want_coat := Color(float(j_coat[0]), float(j_coat[1]), float(j_coat[2]))
	var want_ginger := Color(float(j_ginger[0]), float(j_ginger[1]), float(j_ginger[2]))
	var want_eye := Color(float(j_eye[0]), float(j_eye[1]), float(j_eye[2]))
	check(cat.coat.is_equal_approx(want_coat), "coat colour comes from Willie's photo palette (got %s)" % cat.coat)
	var torso_mat := (cat._torso.material_override as StandardMaterial3D).albedo_color
	check(torso_mat.is_equal_approx(want_coat), "torso material albedo is the palette white (got %s)" % torso_mat)
	var saddle_mat := (cat._saddle_patch.material_override as StandardMaterial3D).albedo_color
	check(saddle_mat.is_equal_approx(want_ginger), "saddle patch albedo is the photo ginger (got %s)" % saddle_mat)
	check(not want_ginger.is_equal_approx(Color(0.9098, 0.6863, 0.3294)), "ginger deepened from the v0.1 art #E8AF54")
	check(cat.eye_color.is_equal_approx(want_eye), "eyes are the palette green-gold (got %s)" % cat.eye_color)
	var eye_mat := (cat._eyes[0].material_override as StandardMaterial3D).albedo_color
	check(eye_mat.is_equal_approx(want_eye), "eye material albedo is green-gold (got %s)" % eye_mat)
	check(absf(cat.model_scale - 0.35) < 0.001, "Willie scale is 0.35 (got %.3f)" % cat.model_scale)
	check(cat.stripe_count >= 6, "tabby striping present (%d stripes)" % cat.stripe_count)
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
	# --- Aggie: the tortie sister, lounging on the garden chair. ---
	var aggie = _game.aggie
	check(aggie != null, "aggie exists")
	check(aggie.species_name == "Aggie", "second cat is Aggie (got %s)" % aggie.species_name)
	check(absf(aggie.model_scale - 0.25) < 0.001 and aggie.model_scale < cat.model_scale, "Aggie scale 0.25 < Willie 0.35 (got %.3f)" % aggie.model_scale)
	var ag: Dictionary = chars.get("aggie", {})
	var apal: Dictionary = ag.get("palette", {})
	var j_base: Array = apal.get("base", [])
	var want_base := Color(float(j_base[0]), float(j_base[1]), float(j_base[2]))
	var a_torso := (aggie._torso.material_override as StandardMaterial3D).albedo_color
	check(a_torso.is_equal_approx(want_base), "aggie torso is the tortie base (got %s)" % a_torso)
	check(aggie.eye_color.is_equal_approx(want_eye), "aggie eyes green-gold like his (got %s)" % aggie.eye_color)
	check(aggie.mottle_count > 0, "aggie mottle patches built (%d)" % aggie.mottle_count)
	check(aggie.torso_dia.x < cat.torso_dia.x * 0.8, "aggie build is wiry, not a scaled Willie (torso %.2f vs %.2f)" % [aggie.torso_dia.x, cat.torso_dia.x])
	check(aggie.is_lounging, "aggie lounges on the chair")
	var achar: Dictionary = ag.get("character", {})
	check(String(achar.get("fight_style", "")) == "burst_and_flee", "character data: aggie fights burst-and-flee")
	check(String(achar.get("provocation_trigger", "")) == "willie_meowing", "character data: willie meowing provokes aggie")
	check(bool(achar.get("wins_vs_willie", false)), "character data: aggie always beats willie")
	check(absf(float(achar.get("weight_vs_willie", 0.0)) - 0.5) < 0.001, "character data: aggie weighs half of willie")
	# Determinism: a fresh Aggie build scatters identically.
	var ag2 = CatScript.new()
	ag2.set_character("aggie")
	add_child(ag2)
	await frames(3)
	check(ag2.mottle_count == aggie.mottle_count, "aggie mottle count deterministic (%d vs %d)" % [ag2.mottle_count, aggie.mottle_count])
	var sig1 := 0.0
	for mi in aggie._mottles:
		sig1 += mi.position.x * 3.0 + mi.position.y * 5.0 + mi.position.z * 7.0
	var sig2 := 0.0
	for mi in ag2._mottles:
		sig2 += mi.position.x * 3.0 + mi.position.y * 5.0 + mi.position.z * 7.0
	check(absf(sig1 - sig2) < 0.001, "aggie mottle scatter identical across builds")
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
