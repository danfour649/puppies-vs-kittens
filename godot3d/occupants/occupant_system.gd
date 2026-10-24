class_name OccupantSystem
extends Node3D
## Occupants — the interaction layer between the player cat and the
## MasseyOccupants: ankle attacks, underfoot crossings, trip
## hazards, and the healing lap.
##
## Score contract (for the foundation HUD):
##   signal score_event(event_name: String, points: int, pos: Vector3)
## Events: ankle_attack +25 / ankle_shoo +10 / underfoot +15 /
## trip_hazard +50 / lap_purr +5 (ticks) / lap_full_heal +0
## (objective marker only). Popups are drawn here as floating
## Label3Ds; total_score and event_counts are kept for any HUD
## that wants numbers instead of signals.
##
## Heal seam: the lap heals through the first available of
## cat.heal(amount), a CatHealth child, or a writable hp property.

signal score_event(event_name: String, points: int, pos: Vector3)

const ANKLE_POINTS := 25
const SHOO_POINTS := 10
const UNDERFOOT_POINTS := 15
const TRIP_POINTS := 50
const PURR_POINTS := 5
const ANKLE_RADIUS := 0.5
const ANKLE_COOLDOWN := 10.0
const UNDERFOOT_COOLDOWN := 6.0
const UNDERFOOT_AHEAD_MIN := 0.15
const UNDERFOOT_AHEAD_MAX := 1.25
const UNDERFOOT_LATERAL := 0.38
const UNDERFOOT_MIN_CAT_SPEED := 0.9
const TRIP_AHEAD := 0.6
const TRIP_CHANCE := 0.5
const LAP_LOCKOUT := 20.0
const LAP_REGEN_PER_SEC := 0.10
const PURR_TICK := 4.0
const PURR_SESSION_CAP := 20
const MOUNT_RANGE := 1.15

var total_score := 0
var event_counts := {}
## Test seam: force the next qualifying crossing to stumble.
var force_stumble := false

var _cat: Node3D = null
var _occupants: Array = []
var _ankle_cd := {}
var _under_cd := {}
var _lockout := {}
var _prev_lat := {}
var _sessions := {}
var _popups: Array = []
var _rng := RandomNumberGenerator.new()
var _purr: AudioStreamPlayer3D = null


func _ready() -> void:
	_rng.seed = 20261024
	_purr = PurrAudio.make_player(self)


func register_occupant(occ: Node3D) -> void:
	if occ in _occupants:
		return
	_occupants.append(occ)
	occ.about_to_stand.connect(_on_occupant_about_to_stand.bind(occ))
	if _cat != null:
		occ.set_avoid_cat(_cat)


func set_player_cat(cat: Node3D) -> void:
	_cat = cat
	if cat != null and cat.has_signal("paw_swiped"):
		if not cat.paw_swiped.is_connected(_on_paw_swiped):
			cat.paw_swiped.connect(_on_paw_swiped)
	for occ in _occupants:
		occ.set_avoid_cat(cat)


# --- queries -----------------------------------------------------------------

func lap_lockout_left(occ: Node3D) -> float:
	return float(_lockout.get(occ, 0.0))


func is_lap_available(occ: Node3D) -> bool:
	return occ.is_seated() and not _sessions.has(occ) and lap_lockout_left(occ) <= 0.0


func lap_session_active(occ: Node3D = null) -> bool:
	if occ != null:
		return _sessions.has(occ)
	return not _sessions.is_empty()


func event_count(event_name: String) -> int:
	return int(event_counts.get(event_name, 0))


# --- lap sessions ---------------------------------------------------------------

func try_mount_lap(cat: Node3D) -> bool:
	if cat == null:
		return false
	for occ in _occupants:
		if not is_lap_available(occ):
			continue
		# Horizontal range only: the spot floats ~0.55 m up on the thighs,
		# and a floor-level cat should not have to pay that in range.
		var flat_cat := Vector3(cat.global_position.x, 0.0, cat.global_position.z)
		var flat_spot: Vector3 = occ.lap_spot()
		flat_spot.y = 0.0
		if flat_cat.distance_to(flat_spot) > MOUNT_RANGE:
			continue
		_sessions[occ] = {
			"cat": cat,
			"mount_t": 0.0,
			"from": cat.global_position,
			"purr_t": 0.0,
			"purr_points": 0,
			"full_heal_fired": false,
		}
		if cat.has_method("set_lounge"):
			cat.set_lounge(true)
		if cat.has_method("set_move_input"):
			cat.set_move_input(Vector3.ZERO, false, false)
		cat.set_meta("on_lap", true)
		occ.set_petting(true)
		_start_purr(occ)
		return true
	return false


## The cat jumps down (or is taken down): ends the session and puts
## the cat safely on the floor in front of the occupant.
func release_cat(cat: Node3D) -> void:
	for occ in _sessions.keys():
		if (_sessions[occ] as Dictionary)["cat"] == cat:
			end_lap_session(occ, "jumped")
			return


## The seam for the game's input layer: PvKCat.strike() refuses
## while lounging, so a PAW press on the lap routes here (a real
## paw_swiped during a session is treated the same way).
func attack_from_lap(cat: Node3D) -> void:
	for occ in _sessions.keys():
		if (_sessions[occ] as Dictionary)["cat"] == cat:
			end_lap_session(occ, "attack")
			return


func end_lap_session(occ: Node3D, reason: String) -> void:
	if not _sessions.has(occ):
		return
	var s: Dictionary = _sessions[occ]
	var cat: Node3D = s["cat"]
	_sessions.erase(occ)
	occ.set_petting(false)
	if is_instance_valid(cat):
		if cat.has_method("set_lounge"):
			cat.set_lounge(false)
		cat.set_meta("on_lap", false)
		# Down safely: floor in front of the occupant, never dropped.
		var floor_pos: Vector3 = occ.global_position + occ.forward_dir() * 0.75
		floor_pos.y = occ.global_position.y + 0.03
		cat.global_position = floor_pos
		if "velocity" in cat:
			cat.velocity = Vector3.ZERO
	if reason == "attack":
		_lockout[occ] = LAP_LOCKOUT
		_popup(occ.global_position + Vector3(0, 1.5, 0), "Down you go.", Color(0.95, 0.85, 0.6))
	if _sessions.is_empty() and _purr != null and _purr.playing:
		_purr.stop()


func _on_occupant_about_to_stand(occ: Node3D) -> void:
	if _sessions.has(occ):
		end_lap_session(occ, "stood")


func _start_purr(occ: Node3D) -> void:
	if _purr == null:
		return
	_purr.global_position = occ.lap_spot() + Vector3(0, 0.25, 0)
	if not _purr.playing:
		_purr.play()


# --- paw strikes: ankle attacks, shooing, lap attacks ------------------------------

func _on_paw_swiped() -> void:
	if _cat == null or not is_instance_valid(_cat):
		return
	# A strike during a lap session is an attack from the lap.
	for occ in _sessions.keys():
		if (_sessions[occ] as Dictionary)["cat"] == _cat:
			end_lap_session(occ, "attack")
			return
	var paw: Vector3 = _cat.paw_point() if _cat.has_method("paw_point") else _cat.global_position
	for occ in _occupants:
		var near_ankle := paw.distance_to(occ.ankle_pos(-1.0)) < ANKLE_RADIUS \
			or paw.distance_to(occ.ankle_pos(1.0)) < ANKLE_RADIUS
		if occ.is_seated():
			if near_ankle or paw.distance_to(occ.global_position + Vector3(0, 0.35, 0)) < 0.8:
				_shoo(occ)
				return
		elif near_ankle:
			if float(_ankle_cd.get(occ, 0.0)) > 0.0:
				return
			_ankle_cd[occ] = ANKLE_COOLDOWN
			var side := -1.0 if paw.distance_to(occ.ankle_pos(-1.0)) < paw.distance_to(occ.ankle_pos(1.0)) else 1.0
			occ.play_hop(side)
			_emit("ankle_attack", ANKLE_POINTS, occ.ankle_pos(side) + Vector3(0, 0.25, 0))
			_popup(occ.global_position + Vector3(0, 1.95, 0), "!", Color(1.0, 0.45, 0.3))
			return


func _shoo(occ: Node3D) -> void:
	occ.play_shoo()
	_lockout[occ] = LAP_LOCKOUT
	_emit("ankle_shoo", SHOO_POINTS, occ.global_position + Vector3(0, 0.4, 0))
	# Gentle pushback: the cat's velocity is input-driven every
	# frame, so the shoo is a direct nudge away from the occupant.
	if _cat != null and is_instance_valid(_cat):
		var away := _cat.global_position - occ.global_position
		away.y = 0.0
		if away.length() > 0.01:
			_cat.global_position += away.normalized() * 0.35


# --- per-frame: cooldowns, underfoot detection, lap upkeep ---------------------------

func _physics_process(delta: float) -> void:
	for k in _ankle_cd.keys():
		_ankle_cd[k] = maxf(0.0, float(_ankle_cd[k]) - delta)
	for k in _under_cd.keys():
		_under_cd[k] = maxf(0.0, float(_under_cd[k]) - delta)
	for k in _lockout.keys():
		_lockout[k] = maxf(0.0, float(_lockout[k]) - delta)
	_step_underfoot()
	_step_sessions(delta)


func _step_underfoot() -> void:
	if _cat == null or not is_instance_valid(_cat):
		return
	var cat_speed := 0.0
	if "velocity" in _cat:
		cat_speed = Vector2(_cat.velocity.x, _cat.velocity.z).length()
	for occ in _occupants:
		if not occ.is_walking():
			_prev_lat.erase(occ)
			continue
		var rel: Vector3 = _cat.global_position - occ.global_position
		rel.y = 0.0
		var ahead: float = rel.dot(occ.forward_dir())
		var lat: float = rel.dot(occ.right_dir())
		var prev: float = float(_prev_lat.get(occ, 0.0))
		if ahead > UNDERFOOT_AHEAD_MIN and ahead < UNDERFOOT_AHEAD_MAX \
				and absf(lat) < UNDERFOOT_LATERAL and cat_speed > UNDERFOOT_MIN_CAT_SPEED \
				and prev != 0.0 and _sgn(prev) != _sgn(lat) \
				and float(_under_cd.get(occ, 0.0)) <= 0.0:
			_under_cd[occ] = UNDERFOOT_COOLDOWN
			_emit("underfoot", UNDERFOOT_POINTS, _cat.global_position + Vector3(0, 0.4, 0))
			if ahead < TRIP_AHEAD and (force_stumble or _rng.randf() < TRIP_CHANCE):
				force_stumble = false
				occ.play_stumble()
				_emit("trip_hazard", TRIP_POINTS, occ.global_position + Vector3(0, 1.2, 0))
		_prev_lat[occ] = lat


func _step_sessions(delta: float) -> void:
	for occ in _sessions.keys():
		var s: Dictionary = _sessions[occ]
		var cat: Node3D = s["cat"]
		if not is_instance_valid(cat) or not occ.is_seated():
			end_lap_session(occ, "gone")
			continue
		var spot: Vector3 = occ.lap_spot()
		# Mount glide, then a soft pin. The pin is the only thing
		# holding the cat up (no physics platform — see occupant.gd),
		# so the cat's velocity is zeroed every step: left alone, its
		# gravity debt (22 m/s^2 while airborne) would eventually win
		# against the lerp.
		if cat is CharacterBody3D:
			(cat as CharacterBody3D).velocity = Vector3.ZERO
		if float(s["mount_t"]) < 1.0:
			s["mount_t"] = minf(1.0, float(s["mount_t"]) + delta / 0.35)
			var from: Vector3 = s["from"]
			cat.global_position = from.lerp(spot, _ease(float(s["mount_t"])))
		else:
			if cat.global_position.distance_to(spot) > 0.6:
				end_lap_session(occ, "jumped")
				continue
			cat.global_position = cat.global_position.lerp(spot, 1.0 - exp(-10.0 * delta))
		if cat.has_method("set_move_input"):
			cat.set_move_input(Vector3.ZERO, false, false)
		# The healing: +10% of max HP per second, to full.
		var max_hp := _cat_max_hp(cat)
		var before := _cat_hp(cat)
		_heal_cat(cat, max_hp * LAP_REGEN_PER_SEC * delta)
		var after := _cat_hp(cat)
		if before < max_hp - 0.001 and after >= max_hp - 0.001 and not bool(s["full_heal_fired"]):
			s["full_heal_fired"] = true
			_emit("lap_full_heal", 0, spot + Vector3(0, 0.35, 0), false)
			_popup(spot + Vector3(0, 0.45, 0), "Fully healed", Color(0.55, 1.0, 0.65))
		# Purr score ticks, capped per session.
		s["purr_t"] = float(s["purr_t"]) + delta
		if float(s["purr_t"]) >= PURR_TICK and int(s["purr_points"]) < PURR_SESSION_CAP:
			s["purr_t"] = 0.0
			s["purr_points"] = int(s["purr_points"]) + PURR_POINTS
			_emit("lap_purr", PURR_POINTS, spot + Vector3(0, 0.4, 0))


# --- score + popups ---------------------------------------------------------------------

func _emit(event_name: String, points: int, pos: Vector3, popup := true) -> void:
	total_score += points
	event_counts[event_name] = int(event_counts.get(event_name, 0)) + 1
	score_event.emit(event_name, points, pos)
	if popup and points > 0:
		var labels := {
			"ankle_attack": "+%d ANKLE!",
			"ankle_shoo": "+%d shooed!",
			"underfoot": "+%d Underfoot!",
			"trip_hazard": "+%d TRIP!",
			"lap_purr": "+%d Purr...",
		}
		var colors := {
			"ankle_attack": Color(1.0, 0.62, 0.25),
			"ankle_shoo": Color(0.95, 0.85, 0.55),
			"underfoot": Color(1.0, 0.85, 0.30),
			"trip_hazard": Color(1.0, 0.38, 0.30),
			"lap_purr": Color(1.0, 0.65, 0.85),
		}
		var fmt: String = labels.get(event_name, "+%d")
		_popup(pos, fmt % points, colors.get(event_name, Color.WHITE))


func _popup(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.pixel_size = 0.0032
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	_popups.append({"label": l, "t": 0.0})


func _process(delta: float) -> void:
	var done: Array = []
	for p in _popups:
		var d: Dictionary = p
		d["t"] = float(d["t"]) + delta
		var l: Label3D = d["label"]
		if not is_instance_valid(l):
			done.append(p)
			continue
		l.position.y += delta * 0.45
		var a := clampf(1.0 - float(d["t"]) / 1.3, 0.0, 1.0)
		l.modulate.a = a
		l.outline_modulate.a = 0.85 * a
		if float(d["t"]) >= 1.3:
			l.queue_free()
			done.append(p)
	for p in done:
		_popups.erase(p)


# --- heal seam ------------------------------------------------------------------------------

func _cat_health_node(cat: Node3D) -> Node:
	return cat.get_node_or_null("CatHealth")


func _cat_max_hp(cat: Node3D) -> float:
	if "max_hp" in cat:
		return float(cat.get("max_hp"))
	var h := _cat_health_node(cat)
	if h != null and "max_hp" in h:
		return float(h.get("max_hp"))
	return 100.0


func _cat_hp(cat: Node3D) -> float:
	if "hp" in cat:
		return float(cat.get("hp"))
	var h := _cat_health_node(cat)
	if h != null and "hp" in h:
		return float(h.get("hp"))
	return _cat_max_hp(cat)


func _heal_cat(cat: Node3D, amount: float) -> void:
	if amount <= 0.0:
		return
	if cat.has_method("heal"):
		cat.heal(amount)
		return
	var h := _cat_health_node(cat)
	if h != null and h.has_method("heal"):
		h.heal(amount)
		return
	if "hp" in cat:
		cat.set("hp", minf(_cat_max_hp(cat), _cat_hp(cat) + amount))


func _sgn(x: float) -> float:
	return -1.0 if x < 0.0 else 1.0


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
