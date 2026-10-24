class_name Provocation
extends Node
## DUO — Aggie's provocation meter: the household's signature dynamic.
##
## Willie meows CONSTANTLY. Every meow Aggie hears (earshot ~8 m)
## fills her meter; it decays slowly. At the threshold she acts:
##
## - Aggie is the NPC: she DASHES at Willie, lands a flurry of paw
##   strikes (knockback, a brief slow, and he drops a catch), then
##   FLEES to the far lounge spot and cools down.
## - Aggie is the player: she gets a PROVOKED window instead —
##   ~5 s at +40% speed with a wider, one-hit catch arc.
##
## The meter belongs to Aggie whoever holds the controller; the
## meows that fill it are always Willie's.

signal triggered

const EARSHOT := 8.0
const THRESHOLD := 100.0
const PER_MEOW := 34.0
const DECAY := 2.0
const BUFF_TIME := 5.0
const COOLDOWN_AFTER_BUFF := 3.0
const COOLDOWN_AFTER_FLURRY := 5.0
const DASH_TIMEOUT := 6.0
const FLURRY_TIME := 2.4
const FLURRY_STRIKE_EVERY := 0.5
const FLURRY_RANGE := 0.85

var meter := 0.0
## state: calm | active | cooldown
var state := "calm"

var aggie: PvKCat = null
var willie: PvKCat = null
var sibling: SiblingAI = null
var duo: Node = null # DuoSystem (untyped: no cyclic class refs)

var _t := 0.0
var _strike_t := 0.0
var _hits := 0
var _dropped := false


func setup(a: PvKCat, w: PvKCat, sib: SiblingAI, d: Node) -> void:
	aggie = a
	willie = w
	sibling = sib
	duo = d


func aggie_is_player() -> bool:
	return duo != null and duo.get("player_cat") == aggie


func speed_multiplier() -> float:
	if state == "active" and aggie_is_player():
		return 1.4
	return 1.0


func reset() -> void:
	if state == "active" and aggie_is_player() and duo != null:
		duo.apply_provoked_buff(false)
	state = "calm"
	meter = 0.0
	_hits = 0


func hear_meow(from_cat: Node3D) -> void:
	if from_cat != willie or state != "calm":
		return
	if aggie == null or willie == null:
		return
	if _flat(aggie.global_position, willie.global_position) > EARSHOT:
		return
	meter = minf(meter + PER_MEOW, THRESHOLD)
	if meter >= THRESHOLD:
		_trigger()


## Called by the duo system when Aggie's paw actually lands mid-flurry.
func register_paw_hit() -> void:
	if state != "active" or aggie_is_player():
		return
	_hits += 1
	if duo != null:
		duo.apply_flurry_hit(_dropped)
	_dropped = true


func _trigger() -> void:
	triggered.emit()
	if duo != null:
		duo.show_flash()
	_hits = 0
	_dropped = false
	if aggie_is_player():
		state = "active"
		_t = BUFF_TIME
		if duo != null:
			duo.apply_provoked_buff(true)
	else:
		state = "active"
		_t = DASH_TIMEOUT
		_strike_t = 0.0
		if sibling != null:
			sibling.begin_dash()


func _physics_process(delta: float) -> void:
	match state:
		"calm":
			meter = maxf(meter - DECAY * delta, 0.0)
		"active":
			if aggie_is_player():
				_t -= delta
				meter = THRESHOLD * clampf(_t / BUFF_TIME, 0.0, 1.0)
				if _t <= 0.0:
					if duo != null:
						duo.apply_provoked_buff(false)
					state = "cooldown"
					_t = COOLDOWN_AFTER_BUFF
					meter = 0.0
			elif sibling == null:
				state = "cooldown"
				_t = COOLDOWN_AFTER_FLURRY
				meter = 0.0
			elif sibling.mode == "dash":
				_t -= delta
				if _flat(aggie.global_position, willie.global_position) < FLURRY_RANGE:
					sibling.begin_flurry()
					_t = FLURRY_TIME
				elif _t <= 0.0:
					_end_flurry() # he outran her — this time
			elif sibling.mode == "flurry":
				_t -= delta
				_strike_t -= delta
				if _strike_t <= 0.0:
					_strike_t = FLURRY_STRIKE_EVERY
					aggie.strike()
				if _t <= 0.0 or _hits >= 3:
					_end_flurry()
			else:
				_end_flurry() # sibling was diverted; bail out cleanly
		"cooldown":
			meter = 0.0
			_t -= delta
			if _t <= 0.0:
				state = "calm"


func _end_flurry() -> void:
	if sibling != null:
		sibling.begin_flee()
	state = "cooldown"
	_t = COOLDOWN_AFTER_FLURRY
	meter = 0.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
