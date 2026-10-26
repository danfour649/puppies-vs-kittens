class_name CreatureBrain
extends RefCounted
## One brain for every creature. A profile picks the species rules,
## CreaturePerception and (optionally) a CatScentMap supply the
## senses, and CreatureFSM holds the state name. `step` returns
## {state, speed, target, alarm, mob, note} — the body still moves
## itself, so a mouse file stays a mouse file.


var profile: Dictionary = {}
var perception := CreaturePerception.new()
var fsm := CreatureFSM.new()
var rng := RandomNumberGenerator.new()
var runway: Array[Vector3] = []
var nibble_spots: Array[Vector3] = []
var flee_t := 0.0

var _timer := 0.6
var _nibble_i := 0
var goal := Vector3.ZERO
var _alarm_on := false
var _hunt := "perch"
var _crouch_t := 0.0
var _pounce_t := 0.0
var _recover_t := 0.0
var _alert := false
var _quiet_t := 0.0
var _orbit_t := 0.0


func bind_profile(id: String, seed_value: int = 1) -> void:
	profile = CreatureProfiles.get_profile(id).duplicate(true)
	rng.seed = seed_value
	perception.sight_range = float(profile.get("sight_range", perception.sight_range))
	perception.sight_fov_deg = float(profile.get("sight_fov", perception.sight_fov_deg))
	perception.hearing_range = float(profile.get("hearing_range", perception.hearing_range))
	fsm = CreatureFSM.new()
	var states: Array = profile.get("states", ["idle"])
	for s: Variant in states:
		fsm.add_state(String(s))
	if not states.is_empty():
		fsm.change_to(String(states[0]))
	_timer = rng.randf_range(0.15, 0.8)
	flee_t = 0.0
	_alarm_on = false
	_hunt = "perch"
	_crouch_t = 0.0
	_pounce_t = 0.0
	_recover_t = 0.0
	_alert = false
	_quiet_t = 0.0
	_orbit_t = 0.0
	runway.clear()
	nibble_spots.clear()
	_nibble_i = 0


func step(delta: float, ctx: Dictionary) -> Dictionary:
	var id := String(profile.get("id", "mouse"))
	var intent: Dictionary
	match id:
		"songbird":
			intent = _step_bird(delta, ctx)
		"other_cat":
			intent = _step_cat(delta, ctx)
		"rat":
			intent = _step_rat(delta, ctx)
		_:
			intent = _step_mouse(delta, ctx)
	var next := String(intent.get("state", fsm.state))
	if fsm.has_state(next):
		fsm.change_to(next)
		fsm.tick(delta, ctx)
	intent["state"] = fsm.state if fsm.state != "" else next
	return intent


# --- shared steering -------------------------------------------------------

func remember_runway(pos: Vector3) -> void:
	if not runway.is_empty():
		var last: Vector3 = runway[runway.size() - 1]
		if Vector2(last.x - pos.x, last.z - pos.z).length() < 0.35:
			return
	runway.append(pos)
	if runway.size() > 8:
		runway.remove_at(0)


## A previous runway point, or the zero vector with reused=false.
func sample_runway() -> Dictionary:
	var reuse := float(profile.get("runway_reuse", 0.0))
	if runway.is_empty() or rng.randf() > reuse:
		return {"reused": false, "pos": Vector3.ZERO}
	return {"reused": true, "pos": runway[rng.randi() % runway.size()]}


static func blend_thigmotaxis(target: Vector3, wall_pull: Vector3, strength: float) -> Vector3:
	return target + Vector3(wall_pull.x, 0.0, wall_pull.z) * strength


## Push `desired` away from a novel object. `neophobia` near 0 (mouse)
## barely moves it; near 1 (rat) steps well clear. `familiarity` 0 is
## brand new, 1 is an old friend and is ignored.
static func steer_neophobia(desired: Vector3, _pos: Vector3, novel: Vector3, neophobia: float, familiarity: float = 0.0, radius: float = 1.7) -> Vector3:
	var away := desired - novel
	away.y = 0.0
	var d := away.length()
	if d > radius:
		return desired
	var wariness := clampf(neophobia, 0.0, 1.0) * (1.0 - clampf(familiarity, 0.0, 1.0))
	if wariness <= 0.001:
		return desired
	if d < 0.05:
		away = Vector3(1.0, 0.0, 0.0)
		d = 1.0
	return desired + away.normalized() * wariness * 1.5


# --- basement rat combat (the existing pack contract) ----------------------

## The pack rules the basement suite already asserts, lifted onto the
## shared brain so rat.gd doesn't keep a private copy:
## alone at 1 HP and inside aggro → flee; flee ending inside aggro
## drops straight back into chase; leaving aggro drops chase to idle.
static func decide_rat(state: String, hp: int, dist: float, packmates: int, aggro: float, flee_t: float, delta: float) -> Dictionary:
	var next := state
	var ft := flee_t
	var set_timer := false
	var timer := 0.0
	if state != "flee" and hp <= 1 and dist < aggro and packmates == 0:
		next = "flee"
		ft = 2.5
	if next == "flee":
		ft -= delta
		if ft <= 0.0 or dist == INF:
			next = "idle"
			set_timer = true
			timer = 0.5
			ft = 0.0
		else:
			return {
				"state": "flee",
				"flee_t": ft,
				"fleeing": true,
				"set_timer": false,
				"timer": 0.0,
			}
	if dist < aggro:
		next = "chase"
	elif next == "chase":
		next = "idle"
		set_timer = true
		timer = 0.3
	return {
		"state": next,
		"flee_t": ft,
		"fleeing": false,
		"set_timer": set_timer,
		"timer": timer,
	}


# --- mouse -----------------------------------------------------------------

func forget_alert() -> void:
	_alert = false
	_quiet_t = 0.0
	flee_t = 0.0


## A crack the mouse can reach that puts more distance between her
## and the threat. Already standing in one counts, even if the cat
## has walked up to it — she holds. `ok` is false when the open
## floor is the better idea.
static func pick_cover(pos: Vector3, threat: Vector3, covers: Array, reach: float = 2.35) -> Dictionary:
	var none := {"ok": false, "pos": pos, "dist": INF}
	if covers.is_empty():
		return none
	var threat_d := Vector2(pos.x - threat.x, pos.z - threat.z).length()
	var best := none
	var best_gain := 0.2
	for c: Variant in covers:
		if typeof(c) != TYPE_VECTOR3:
			continue
		var cp: Vector3 = c
		var dist := Vector2(pos.x - cp.x, pos.z - cp.z).length()
		if dist <= 0.28:
			return {"ok": true, "pos": cp, "dist": dist}
		if dist > reach:
			continue
		var cover_d := Vector2(cp.x - threat.x, cp.z - threat.z).length()
		var gain := cover_d - threat_d
		if gain > best_gain:
			best_gain = gain
			best = {"ok": true, "pos": cp, "dist": dist}
	return best


func _step_mouse(delta: float, ctx: Dictionary) -> Dictionary:
	var pos: Vector3 = ctx.get("pos", Vector3.ZERO)
	var hour := float(ctx.get("hour", 21.0))
	var activity := CreatureProfiles.nocturnal_activity(hour) if bool(profile.get("nocturnal", true)) else 1.0
	var scent := float(ctx.get("scent", 0.0))
	var flee_range := float(ctx.get("flee_range", profile.get("hearing_range", 2.4)))
	# Sounds carry past the body radius, so a meow reaches a mouse
	# who has not seen him yet. The body check below is unchanged
	# for a walk or a sprint — the yard chase depends on it.
	var hear_r := float(profile.get("hearing_range", 2.4)) * 2.2
	var heard := perception.loudest(pos, ctx.get("sounds", []), hear_r)
	var heard_loud := float(heard.get("loudness", 0.0))
	var danger := maxf(scent, heard_loud)
	var has_cat := bool(ctx.get("has_cat", false))
	var cat_pos: Vector3 = ctx.get("cat_pos", pos)
	var gait := String(ctx.get("gait", ""))
	var stalking := gait == "stalk"
	var cat_near := false
	var away := Vector3.ZERO
	if has_cat:
		away = Vector3(pos.x - cat_pos.x, 0.0, pos.z - cat_pos.z)
		var dist := away.length()
		var fwd: Vector3 = ctx.get("forward", Vector3(0, 0, -1))
		var blocked := bool(ctx.get("cat_blocked", false))
		if stalking:
			# A stalk is not "a cat in the radius". She hears the
			# whisper, and she sees him if he is in front.
			danger = maxf(danger, perception.hear_loudness(pos, cat_pos, CatNoise.loudness("stalk"), flee_range))
			var seen := perception.can_see(pos, fwd, cat_pos, blocked)
			if dist < 0.55:
				cat_near = true
				danger = maxf(danger, 1.0)
			elif seen and dist < 0.85:
				cat_near = true
				danger = maxf(danger, 0.9)
			elif seen:
				danger = maxf(danger, 0.5)
		else:
			# Hearing covers a cat behind the mouse — the yard contract
			# is "inside the radius", from any side.
			if dist < flee_range and dist > 0.001:
				cat_near = true
				danger = maxf(danger, 1.0)
			elif perception.can_see(pos, fwd, cat_pos, blocked):
				cat_near = true
				danger = maxf(danger, 0.85)
	var flee_danger := float(profile.get("flee_danger", 0.7))
	var freeze_danger := float(profile.get("freeze_danger", 0.42))
	var home: Vector3 = ctx.get("home", pos)
	var note := ""
	var speed := 0.0
	var target := pos
	var next := fsm.state if fsm.state != "" else "idle"
	var threatened := cat_near or danger >= freeze_danger
	if threatened:
		_alert = true
		_quiet_t = 0.0
		var threat := cat_pos if has_cat else pos
		var cover := pick_cover(pos, threat, ctx.get("cracks", []))
		if bool(cover.get("ok", false)):
			var tucked := float(cover.get("dist", 1.0)) <= 0.28
			target = _clamp_target(cover["pos"], ctx)
			return _intent("crack", 0.0 if tucked else float(profile.get("flee_speed", 3.05)), target, false, false, "tucked" if tucked else "crack")

	if cat_near or danger >= flee_danger:
		# Entering a flee zeroes the burst timer. Continuing one keeps
		# the timer the body synced in (the yard chase harness writes it).
		if next != "flee":
			flee_t = 0.0
		next = "flee"
		flee_t += delta
		var burst := float(profile.get("flee_burst", 1.2))
		speed = float(profile.get("flee_speed", 3.05)) if flee_t < burst else float(profile.get("flee_tired", 1.95))
		if away.length() < 0.001:
			away = Vector3(0, 0, 1)
		target = pos + away.normalized() * 6.0
		note = "flee"
	elif danger >= freeze_danger:
		next = "freeze"
		flee_t = 0.0
		speed = 0.0
		target = pos
		note = "freeze"
	else:
		_quiet_t += delta
		var home_flat := Vector2(pos.x - home.x, pos.z - home.z).length()
		var settle := float(profile.get("return_after", 0.75))
		# The scare is over. She does not stay gone: once the floor
		# is quiet she creeps back to the spot she was nibbling.
		if _alert and _quiet_t >= settle and home_flat > 0.55:
			flee_t = 0.0
			target = _clamp_target(home, ctx)
			remember_runway(pos)
			return _intent("return", float(profile.get("wander_speed", 1.2)), target, false, false, "return")
		if _alert and _quiet_t >= settle:
			_alert = false
		if next == "flee" or next == "freeze" or next == "crack" or next == "return":
			next = "idle"
			_timer = 0.35
		flee_t = 0.0
		if activity < 0.22:
			next = "idle"
			speed = 0.0
			target = pos
			note = "day-roost"
		else:
			_timer -= delta
			var novel: Dictionary = ctx.get("novel", {})
			var investigating := false
			if not novel.is_empty() and CreatureProfiles.investigates_novel("mouse"):
				var np: Vector3 = novel.get("pos", pos)
				if Vector2(pos.x - np.x, pos.z - np.z).length() > 0.3:
					investigating = true
					next = "nibble"
					target = np
					goal = np
					speed = float(profile.get("wander_speed", 1.2)) * 0.8
					note = "investigate"
			if not investigating:
				if next != "nibble" and next != "runway":
					next = "idle"
				if _timer <= 0.0 or bool(ctx.get("force_nibble", false)):
					var picked := _pick_nibble_or_runway(pos, home, ctx)
					next = String(picked["state"])
					target = picked["target"]
					goal = target
					_timer = float(picked["timer"])
					note = String(picked["note"])
				elif next == "idle":
					target = pos
					speed = 0.0
				else:
					target = goal
				if next == "nibble" or next == "runway":
					speed = float(profile.get("wander_speed", 1.2)) * (0.45 if next == "nibble" else 1.0)
					if Vector2(pos.x - target.x, pos.z - target.z).length() < 0.18:
						next = "idle"
						speed = 0.0
						_timer = rng.randf_range(0.4, 1.2)
						note = "arrived"
	target = _clamp_target(target, ctx)
	if next != "flee" and next != "freeze":
		var pull: Vector3 = ctx.get("wall_pull", Vector3.ZERO)
		target = blend_thigmotaxis(target, pull, float(profile.get("thigmotaxis", 0.0)))
		target = _clamp_target(target, ctx)
	if speed > 0.0:
		remember_runway(pos)
	return _intent(next, speed, target, false, false, note)


func _pick_nibble_or_runway(pos: Vector3, home: Vector3, ctx: Dictionary) -> Dictionary:
	var anchors: Array = ctx.get("nibble_anchors", [])
	var runway_pick := sample_runway()
	if bool(runway_pick["reused"]) and not bool(ctx.get("force_nibble", false)) and anchors.is_empty():
		return {"state": "runway", "target": runway_pick["pos"], "timer": 4.0, "note": "runway"}
	if bool(profile.get("cache_food", false)) and not nibble_spots.is_empty():
		return {"state": "nibble", "target": nibble_spots[0], "timer": 2.5, "note": "cache"}
	var target := home
	if not anchors.is_empty():
		var i := _nibble_i % anchors.size()
		_nibble_i += 1
		target = anchors[i]
	else:
		var spot := home + Vector3(rng.randf_range(-2.2, 2.2), 0.0, rng.randf_range(-2.2, 2.2))
		if not nibble_spots.is_empty():
			var prev: Vector3 = nibble_spots[nibble_spots.size() - 1]
			if Vector2(spot.x - prev.x, spot.z - prev.z).length() < 0.35:
				spot.x += 0.8
		nibble_spots.append(spot)
		target = spot
	# Runway reuse still wins sometimes when anchors exist, so the
	# paths between nibbles get worn in.
	if bool(runway_pick["reused"]) and rng.randf() < float(profile.get("runway_reuse", 0.0)):
		return {"state": "runway", "target": runway_pick["pos"], "timer": 3.5, "note": "runway"}
	return {"state": "nibble", "target": target, "timer": rng.randf_range(2.4, 5.5), "note": "nibble"}


# --- rat (wander / novel objects; combat stays in decide_rat) -------------

func _step_rat(delta: float, ctx: Dictionary) -> Dictionary:
	var pos: Vector3 = ctx.get("pos", Vector3.ZERO)
	var home: Vector3 = ctx.get("home", pos)
	var novel: Dictionary = ctx.get("novel", {})
	var target := home + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
	var next := "wander"
	var note := "wander"
	if not novel.is_empty():
		var np: Vector3 = novel.get("pos", pos)
		var fam := float(novel.get("familiarity", 0.0))
		target = steer_neophobia(target, pos, np, float(profile.get("neophobia", 0.88)), fam)
		if float(profile.get("neophobia", 1.0)) >= 0.5 and fam < 0.5:
			next = "avoid"
			note = "neophobia"
		elif CreatureProfiles.investigates_novel(String(profile.get("id", "rat"))):
			next = "wander"
			target = np
			note = "investigate"
	target = blend_thigmotaxis(target, ctx.get("wall_pull", Vector3.ZERO), float(profile.get("thigmotaxis", 0.0)))
	return _intent(next, float(profile.get("wander_speed", 0.8)), target, false, false, note)


# --- songbird --------------------------------------------------------------

func _step_bird(delta: float, ctx: Dictionary) -> Dictionary:
	var pos: Vector3 = ctx.get("pos", Vector3.ZERO)
	var indoor := bool(ctx.get("indoor", false))
	var has_cat := bool(ctx.get("has_cat", false))
	var cat_pos: Vector3 = ctx.get("cat_pos", pos)
	var lights: Array = ctx.get("lights", [])
	var flock: Array = ctx.get("flock", [])
	var sees := false
	var dist := INF
	if has_cat:
		dist = Vector2(pos.x - cat_pos.x, pos.z - cat_pos.z).length()
		sees = dist < float(profile.get("sight_range", 7.0)) and perception.can_see(
			pos, ctx.get("forward", Vector3(0, 0, -1)), cat_pos, bool(ctx.get("cat_blocked", false))
		)
		# A bird on the ground hears a cat that has walked up behind it.
		if dist < 2.2:
			sees = true
	var heard := perception.loudest(pos, ctx.get("sounds", []), float(profile.get("hearing_range", 8.0)))
	var alarm_heard := String(heard.get("kind", "")) == "alarm" and float(heard.get("loudness", 0.0)) > 0.15
	if (sees or alarm_heard) and indoor:
		_alarm_on = true
		var light := _nearest_light(pos, lights)
		return _intent("panic_light", float(profile.get("panic_speed", 4.2)), light, true, false, "window")
	if sees and not indoor:
		# First look is the alarm call. The next look, the flock mobs.
		if _alarm_on:
			return _intent("mob", float(profile.get("mob_speed", 2.1)), cat_pos, true, true, "mob")
		_alarm_on = true
		return _intent("alarm", 0.0, pos, true, false, "alarm")
	if alarm_heard and not indoor:
		_alarm_on = true
		return _intent("alarm", 0.0, pos, true, false, "alarm-heard")
	_alarm_on = false
	var centroid := _flock_centroid(pos, flock)
	if bool(profile.get("flock", true)) and not flock.is_empty():
		if Vector2(pos.x - centroid.x, pos.z - centroid.z).length() > 1.8:
			return _intent("flock", float(profile.get("flock_speed", 1.6)), centroid, false, false, "flock")
	var forage := pos + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
	return _intent("forage", float(profile.get("forage_speed", 0.7)), forage, false, false, "forage")


func _nearest_light(pos: Vector3, lights: Array) -> Vector3:
	if lights.is_empty():
		return pos + Vector3(0, 1.4, 0)
	var best: Vector3 = lights[0]
	var bd := INF
	for L: Variant in lights:
		var lp: Vector3 = L
		var d := pos.distance_to(lp)
		if d < bd:
			bd = d
			best = lp
	return best


func _flock_centroid(pos: Vector3, flock: Array) -> Vector3:
	if flock.is_empty():
		return pos
	var acc := Vector3.ZERO
	for p: Variant in flock:
		acc += p as Vector3
	return acc / float(flock.size())


# --- the other cat ---------------------------------------------------------

func _step_cat(delta: float, ctx: Dictionary) -> Dictionary:
	var pos: Vector3 = ctx.get("pos", Vector3.ZERO)
	var hour := float(ctx.get("hour", 19.0))
	var active := CreatureProfiles.crepuscular_activity(hour)
	var perches: Array = ctx.get("perches", [])
	var perch := _highest_perch(pos, perches)
	var has_prey := bool(ctx.get("has_prey", ctx.get("has_cat", false)))
	var prey: Vector3 = ctx.get("prey_pos", ctx.get("cat_pos", pos))
	var dist := INF
	var sees := false
	if has_prey:
		dist = Vector2(pos.x - prey.x, pos.z - prey.z).length()
		sees = dist < float(profile.get("sight_range", 8.0))
	# Deep night and noon are for the high box, unless a pounce is
	# already in motion.
	var committed := _hunt == "crouch" or _hunt == "pounce"
	if active < 0.28 and not committed:
		_hunt = "perch"
		_crouch_t = 0.0
		_pounce_t = 0.0
		return _intent("perch", 0.7, perch, false, false, "perch")
	if not sees:
		_hunt = "perch" if active < 0.45 else "patrol"
		_crouch_t = 0.0
		if _hunt == "perch":
			return _intent("perch", 0.7, perch, false, false, "perch")
		var patrol: Vector3 = ctx.get("patrol", perch)
		return _intent("patrol", 0.6, patrol, false, false, "territory")
	var crouch_r := float(profile.get("crouch_range", 1.65))
	var pounce_r := float(profile.get("pounce_range", 0.85))
	if _hunt == "pounce":
		_pounce_t += delta
		if _pounce_t >= float(profile.get("pounce_time", 0.32)):
			_hunt = "recover"
			_recover_t = 0.0
			return _intent("recover", 0.9, perch, false, false, "recover")
		return _intent("pounce", float(profile.get("pounce_speed", 4.4)), prey, false, false, "pounce")
	if _hunt == "recover":
		_recover_t += delta
		if _recover_t > 1.2:
			_hunt = "perch"
		return _intent("recover", 0.9, perch, false, false, "recover")
	if _hunt == "crouch" or dist <= crouch_r:
		_hunt = "crouch"
		_crouch_t += delta
		if _crouch_t >= float(profile.get("crouch_time", 0.35)) and dist <= pounce_r:
			_hunt = "pounce"
			_pounce_t = 0.0
			return _intent("pounce", float(profile.get("pounce_speed", 4.4)), prey, false, false, "pounce")
		return _intent("crouch", 0.0, pos, false, false, "crouch")
	_hunt = "stalk"
	_crouch_t = 0.0
	return _intent("stalk", float(profile.get("stalk_speed", 0.85)), prey, false, false, "stalk")


func _highest_perch(pos: Vector3, perches: Array) -> Vector3:
	if perches.is_empty():
		return pos + Vector3(0, 1.2, 0)
	var best: Vector3 = perches[0]
	for p: Variant in perches:
		var pp: Vector3 = p
		if pp.y > best.y:
			best = pp
	return best


# --- helpers ---------------------------------------------------------------

func _clamp_target(target: Vector3, ctx: Dictionary) -> Vector3:
	if not ctx.has("bounds_min"):
		return target
	var mn: Vector3 = ctx["bounds_min"]
	var mx: Vector3 = ctx["bounds_max"]
	target.x = clampf(target.x, mn.x, mx.x)
	target.z = clampf(target.z, mn.z, mx.z)
	target.y = 0.0
	return target


func _intent(state: String, speed: float, target: Vector3, alarm: bool, mob: bool, note: String) -> Dictionary:
	return {
		"state": state,
		"speed": speed,
		"target": target,
		"alarm": alarm,
		"mob": mob,
		"note": note,
	}
