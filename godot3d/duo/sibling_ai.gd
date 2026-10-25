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
##   | heat_seek | heat_solicit              (Aggie in heat, NPC)
##   | heat_stare | heat_groom | heat_knock | heat_knock_done
##   | heat_mount | heat_mount_hold          (Willie in heat, NPC)
## The name is the shared state machine. Territorial stalk / crouch /
## pounce is the other-cat profile (other_cat.gd); this sibling stays
## on the modes the duo and heat suites already drive.
const _MODES: Array[String] = [
	"idle", "to_lounge", "lounge", "wander", "dash", "flurry", "flee",
	"heat_seek", "heat_solicit", "heat_stare", "heat_groom", "heat_knock",
	"heat_knock_done", "heat_mount", "heat_mount_hold",
]
var _fsm: CreatureFSM
var mode: String:
	get:
		return _fsm.state if _fsm != null else "idle"
	set(value):
		if _fsm != null:
			_fsm.change_to(value)
var sees_player := false
var _brain: CreatureBrain
var _sense := CreaturePerception.new()
## When false, the cat holds its current mode (tests + cut moments);
## provocation commands work regardless.
var autonomous := true

var _target := Vector3.ZERO
var _timer := 0.0
var _rng := RandomNumberGenerator.new()

## HEAT: one-shot event flag for the HeatSystem to poll ("knock"
## when Willie reaches the drink and swipes it). Cleared by the
## reader. Plus the knock target and the mount hop latch.
var heat_event := ""
var _heat_target := Vector3.ZERO
var _heat_hopped := false


func _init() -> void:
	_fsm = CreatureFSM.new()
	for s: String in _MODES:
		_fsm.add_state(s)
	_fsm.change_to("idle")


func _ready() -> void:
	_rng.randomize()
	_brain = CreatureBrain.new()
	_brain.bind_profile("other_cat", _rng.randi())
	_sense.sight_range = 8.0
	_sense.sight_fov_deg = 150.0


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


# --- heat commands (the HeatSystem conducts; these just perform) -----------

## Aggie: hunt the player cat down, wherever he is.
func begin_heat_seek() -> void:
	if cat != null:
		cat.set_lounge(false)
		cat.set_courtship(false)
	mode = "heat_seek"


## Aggie: she caught up with him — roll, present, tail aside.
func begin_heat_solicit() -> void:
	mode = "heat_solicit"
	_timer = _rng.randf_range(2.6, 4.2)
	if cat != null:
		cat.set_move_input(Vector3.ZERO, false, false)
		cat.set_courtship(true)


## Willie: the blank stare. Stop dead, look at her, say nothing.
func begin_heat_stare() -> void:
	mode = "heat_stare"
	_timer = 2.2
	if cat != null:
		cat.set_move_input(Vector3.ZERO, false, false)
		cat.set_lounge(false)


## Willie: pointed self-grooming, pointedly not looking at her.
func begin_heat_groom() -> void:
	mode = "heat_groom"
	_timer = 2.8
	if cat != null:
		cat.set_move_input(Vector3.ZERO, false, false)
		cat.set_lounge(false)
		cat.set_act_pose("groom")


## Willie: wander off and knock the drink over (target = stand point).
func begin_heat_knock(target: Vector3) -> void:
	mode = "heat_knock"
	_heat_target = target
	_timer = 9.0


## Willie: the half-hearted mount attempt — hop on, hold a beat,
## remember he has somewhere else to be. Goes nowhere, by design.
func begin_heat_mount() -> void:
	mode = "heat_mount"
	_timer = 9.0
	_heat_hopped = false


## Heat over (or pre-empted): poses off, back to chilling.
func end_heat() -> void:
	if cat != null:
		cat.set_courtship(false)
		cat.set_act_pose("")
		cat.set_move_input(Vector3.ZERO, false, false)
	if mode.begins_with("heat"):
		mode = "idle"
		if autonomous:
			go_lounge_nearest()


## The HeatSystem's watchdog: a heat mode that outstayed its welcome.
func cancel_heat_mode() -> void:
	if cat != null:
		cat.set_courtship(false)
		cat.set_act_pose("")
	if mode.begins_with("heat"):
		mode = "idle"


# --- brain -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if cat == null or not is_instance_valid(cat):
		return
	# PLAYTEST FIX (bug 4): leaving lounge mode must un-lounge the
	# cat. PvKCat refuses to move or strike while is_lounging, and
	# nothing else ever cleared it (the duo suite masked the lock
	# by un-lounging her by hand). Any non-lounge mode means GO.
	if mode != "lounge" and cat.is_lounging:
		cat.set_lounge(false)
	_timer -= delta
	if player_cat != null and is_instance_valid(player_cat) and cat != null and is_instance_valid(cat):
		sees_player = _sense.can_see(cat.global_position, cat.forward_dir(), player_cat.global_position, false)
	match mode:
		"lounge":
			cat.set_move_input(Vector3.ZERO, false, false)
			if autonomous and _timer <= 0.0:
				_start_wander()
		"wander":
			if _drive(_target, 0.45, false) or _timer <= 0.0:
				go_lounge_nearest()
		"to_lounge":
			if _drive(_target, 0.55, false, false, _lounge_arrive_radius()):
				_arrive_lounge()
		"flee":
			if _drive(_target, 1.0, true, false, _lounge_arrive_radius()):
				_arrive_lounge()
		"dash":
			if player_cat != null and is_instance_valid(player_cat):
				_drive(player_cat.global_position, 1.0, true, true)
		"heat_seek":
			if player_cat != null and is_instance_valid(player_cat):
				if _flat(cat.global_position, player_cat.global_position) < 0.95:
					begin_heat_solicit()
				else:
					_drive(player_cat.global_position, 0.9, false, true)
		"heat_solicit":
			cat.set_move_input(Vector3.ZERO, false, false)
			if player_cat != null and is_instance_valid(player_cat):
				_face(player_cat.global_position)
				if _flat(cat.global_position, player_cat.global_position) > 1.35:
					cat.set_courtship(false)
					begin_heat_seek()
			if _timer <= 0.0:
				if player_cat != null and is_instance_valid(player_cat) \
						and _flat(cat.global_position, player_cat.global_position) < 1.1:
					_timer = _rng.randf_range(2.6, 4.2) # he's still here. Again.
				else:
					cat.set_courtship(false)
					begin_heat_seek()
		"heat_stare":
			cat.set_move_input(Vector3.ZERO, false, false)
			if player_cat != null and is_instance_valid(player_cat):
				_face(player_cat.global_position)
			if _timer <= 0.0:
				mode = "idle"
		"heat_groom":
			cat.set_move_input(Vector3.ZERO, false, false)
			if _timer <= 0.0:
				cat.set_act_pose("")
				mode = "idle"
		"heat_knock":
			if _drive(_heat_target, 0.8, false):
				cat.strike()
				heat_event = "knock"
				mode = "heat_knock_done"
				_timer = 1.2
			elif _timer <= 0.0:
				mode = "idle"
		"heat_knock_done":
			cat.set_move_input(Vector3.ZERO, false, false)
			if _timer <= 0.0:
				mode = "idle"
		"heat_mount":
			if player_cat != null and is_instance_valid(player_cat):
				var behind: Vector3 = player_cat.global_position - player_cat.forward_dir() * 0.55
				if _drive(behind, 0.95, true, true):
					cat.jump()
					_heat_hopped = true
					mode = "heat_mount_hold"
					_timer = 1.2
			if _timer <= 0.0 and mode == "heat_mount":
				mode = "idle" # couldn't get there — disinterest wins early
		"heat_mount_hold":
			cat.set_move_input(Vector3.ZERO, false, false)
			if player_cat != null and is_instance_valid(player_cat):
				_face(player_cat.global_position)
			if _timer <= 0.0:
				mode = "idle"
		"flurry":
			if player_cat != null and is_instance_valid(player_cat):
				if _flat(cat.global_position, player_cat.global_position) > 0.7:
					_drive(player_cat.global_position, 0.8, false, true)
				else:
					cat.set_move_input(Vector3.ZERO, false, false)
					_face(player_cat.global_position)
		_:
			cat.set_move_input(Vector3.ZERO, false, false)


## Arrival radius for lounge-bound drives. A furniture spot is
## unreachable on foot: the garden chair's seat slab (0.66 x 0.58,
## top at y 0.46) stops the capsule at a flat ~0.50 m from centre —
## outside the stock 0.45 arrival radius — so a WALKED lounge
## arrival could never fire and the cat wedged against the chair
## forever (she only ever lounged there from her spawn point on
## it). _arrive_lounge snaps the final stretch onto the spot, so
## an elevated spot gets a hop-on radius; floor spots keep stock.
func _lounge_arrive_radius() -> float:
	return 0.8 if _target.y > 0.1 else 0.45


## Drive toward a point. Returns true on arrival (within snap range).
## Unless `chase` is set (target IS the player), steering bends away
## from the player's cat so paths curve around it.
func _drive(point: Vector3, frac: float, sprint: bool, chase := false, arrive := 0.45) -> bool:
	var to := point - cat.global_position
	to.y = 0.0
	if to.length() < arrive:
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
