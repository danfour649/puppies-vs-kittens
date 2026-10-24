class_name SiblingAI
extends Node
## DUO — the sibling cat's brain.
##
## Default state is CHILL: lounge on a favourite spot (the kit's
## lounge flop), now and then wander slowly across the yard to
## another spot. Steering keeps a polite bubble around the player —
## the sibling paths AROUND the player's cat, never through it (the
## physics capsules are the backstop, not the plan).
##
## The provocation system can seize control with begin_dash() /
## begin_flurry() / begin_flee(); when it lets go, the cat settles
## back into chilling on its own.

const YARD := Rect2(-11.6, -8.6, 23.2, 17.2)
## MASSEY: the wander bounds follow the zone (set on travel).
var wander_rect := Rect2(-11.6, -8.6, 23.2, 17.2)

var cat: PvKCat = null
var player_cat: PvKCat = null
var lounge_spots: Array = []
## mode: idle | to_lounge | lounge | wander | dash | flurry | flee
var mode := "idle"
## When false, the cat holds its current mode (tests + cut moments);
## provocation commands work regardless.
var autonomous := true

var _target := Vector3.ZERO
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func bind(c: PvKCat, player: PvKCat, spots: Array) -> void:
	cat = c
	player_cat = player
	lounge_spots = spots
	autonomous = true
	if cat != null:
		go_lounge_nearest()


func unbind() -> void:
	if cat != null:
		cat.set_move_input(Vector3.ZERO, false, false)
	cat = null
	player_cat = null
	mode = "idle"


func go_lounge(spot: Vector3) -> void:
	_target = spot
	mode = "to_lounge"


func go_lounge_nearest() -> void:
	if cat == null or lounge_spots.is_empty():
		return
	var best: Vector3 = lounge_spots[0]
	var bd := INF
	for s: Variant in lounge_spots:
		var spot: Vector3 = s
		var d := _flat(cat.global_position, spot)
		if d < bd:
			bd = d
			best = spot
	go_lounge(best)


# --- provocation commands ----------------------------------------------------

func begin_dash() -> void:
	mode = "dash"


func begin_flurry() -> void:
	mode = "flurry"


func begin_flee() -> void:
	if cat == null:
		return
	# The lounge spot farthest from the other cat is safety.
	var from := cat.global_position
	if player_cat != null and is_instance_valid(player_cat):
		from = player_cat.global_position
	var best := cat.global_position
	var bd := -1.0
	for s: Variant in lounge_spots:
		var spot: Vector3 = s
		var d := _flat(from, spot)
		if d > bd:
			bd = d
			best = spot
	_target = best
	mode = "flee"


# --- brain -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if cat == null or not is_instance_valid(cat):
		return
	_timer -= delta
	match mode:
		"lounge":
			cat.set_move_input(Vector3.ZERO, false, false)
			if autonomous and _timer <= 0.0:
				_start_wander()
		"wander":
			if _drive(_target, 0.45, false) or _timer <= 0.0:
				go_lounge_nearest()
		"to_lounge":
			if _drive(_target, 0.55, false):
				_arrive_lounge()
		"flee":
			if _drive(_target, 1.0, true):
				_arrive_lounge()
		"dash":
			if player_cat != null and is_instance_valid(player_cat):
				_drive(player_cat.global_position, 1.0, true, true)
		"flurry":
			if player_cat != null and is_instance_valid(player_cat):
				if _flat(cat.global_position, player_cat.global_position) > 0.7:
					_drive(player_cat.global_position, 0.8, false, true)
				else:
					cat.set_move_input(Vector3.ZERO, false, false)
					_face(player_cat.global_position)
		_:
			cat.set_move_input(Vector3.ZERO, false, false)


## Drive toward a point. Returns true on arrival (within snap range).
## Unless `chase` is set (target IS the player), steering bends away
## from the player's cat so paths curve around it.
func _drive(point: Vector3, frac: float, sprint: bool, chase := false) -> bool:
	var to := point - cat.global_position
	to.y = 0.0
	if to.length() < 0.45:
		cat.set_move_input(Vector3.ZERO, false, false)
		return true
	var dir := to.normalized()
	if not chase and player_cat != null and is_instance_valid(player_cat):
		var away := cat.global_position - player_cat.global_position
		away.y = 0.0
		var d := away.length()
		if d < 1.15 and d > 0.001:
			dir = (dir + away.normalized() * (1.15 - d) * 1.8).normalized()
	cat.set_move_input(dir * frac, sprint, false)
	return false


func _arrive_lounge() -> void:
	cat.velocity = Vector3.ZERO
	cat.global_position = _target # spots carry their resting height
	cat.set_move_input(Vector3.ZERO, false, false)
	cat.set_lounge(true)
	mode = "lounge"
	_timer = _rng.randf_range(4.0, 9.0)


func _start_wander() -> void:
	var p := cat.global_position
	for tries in 4:
		p = Vector3(
			_rng.randf_range(wander_rect.position.x, wander_rect.position.x + wander_rect.size.x),
			0.0,
			_rng.randf_range(wander_rect.position.y, wander_rect.position.y + wander_rect.size.y))
		if player_cat == null or not is_instance_valid(player_cat):
			break
		if _flat(p, player_cat.global_position) > 2.2:
			break
	_target = p
	mode = "wander"
	_timer = 9.0


func _face(point: Vector3) -> void:
	var to := point - cat.global_position
	to.y = 0.0
	if to.length() > 0.01:
		var target_yaw := atan2(-to.normalized().x, -to.normalized().z)
		cat.rotation.y = lerp_angle(cat.rotation.y, target_yaw, 0.35)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
