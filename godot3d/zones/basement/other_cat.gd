class_name OtherCat
extends Node3D
## Aggie, when she is not the cat you are playing. Territorial,
## crepuscular, fond of the high boxes. At dusk she runs the whole
## sequence: stalk, crouch, pounce — then back up to the perch.
## A pounce baps Willie. It does not hurt him. She is his sister.


var brain: CreatureBrain
var body: PvKCat
var state := "perch"
var prey: Node3D = null
var perches: Array = []
var hour := 19.0
var territory := Vector3.ZERO
var territory_radius := 5.5
## Willie, when he is the rival and not the prey node.
var rival: Node3D = null
## Mice she will try to reach before he does.
var quarry: Array = []
var steals := 0
var steal_cap := 1
var boast := ""
var bapped := false

var _pos := Vector3.ZERO
var _watch_t := 0.0
const WATCH_BEFORE_HUNT := 2.5


func _ready() -> void:
	brain = CreatureBrain.new()
	brain.bind_profile("other_cat", 11)
	body = PvKCat.new()
	body.set_character("aggie")
	body.name = "Aggie"
	add_child(body)
	body.set_collision_layer_value(1, false)
	body.set_collision_mask_value(1, false)
	_pos = global_position


func _process(delta: float) -> void:
	if brain == null or body == null:
		return
	_watch_t += delta
	var options: Array = []
	var live: Array = []
	if _watch_t >= WATCH_BEFORE_HUNT and steals < steal_cap:
		for q: Variant in quarry:
			if not is_instance_valid(q):
				continue
			if String(q.get("state")) == "caught":
				continue
			options.append((q as Node3D).global_position)
			live.append(q)
	var has_rival := rival != null and is_instance_valid(rival)
	var legacy := options.is_empty() and prey != null and is_instance_valid(prey)
	var prey_pos := prey.global_position if legacy else _pos
	var intent: Dictionary = brain.step(delta, {
		"pos": _pos,
		"forward": body.forward_dir(),
		"hour": hour,
		"has_prey": legacy,
		"prey_pos": prey_pos,
		"perches": perches,
		"patrol": territory if territory != Vector3.ZERO else _pos,
		"territory": territory,
		"territory_radius": territory_radius,
		"has_rival": has_rival,
		"rival_pos": rival.global_position if has_rival else _pos,
		"prey_options": options,
	})
	var prev := state
	state = String(intent.get("state", state))
	var speed := float(intent.get("speed", 0.0))
	var target: Vector3 = intent.get("target", _pos)
	if state == "perch" or state == "recover":
		if not perches.is_empty():
			target = _highest()
	if state == "crouch":
		speed = 0.0
	var to := target - _pos
	var flat := Vector3(to.x, 0.0, to.z)
	var step_len := minf(speed * delta, flat.length())
	if step_len > 0.001 and flat.length() > 0.02:
		_pos += flat.normalized() * step_len
		var yaw := atan2(-flat.x, -flat.z)
		body.rotation.y = lerp_angle(body.rotation.y, yaw, 1.0 - exp(-8.0 * delta))
	# Vertical: perches are boxes. She climbs by simply going up
	# once she is standing at the foot, and drops when she hunts.
	var want_y := target.y if state == "perch" or state == "recover" else 0.05
	if state == "stalk" or state == "crouch" or state == "pounce":
		want_y = 0.05
	_pos.y = move_toward(_pos.y, want_y, delta * (1.6 if want_y > _pos.y else 3.5))
	body.global_position = _pos
	body.velocity = Vector3.ZERO
	var moving := flat.length() > 0.08 and speed > 0.05 and absf(_pos.y - want_y) < 0.3
	var dir := flat.normalized() if moving else Vector3.ZERO
	body.set_move_input(dir, state == "pounce", state == "stalk" or state == "crouch")
	var strike: Node3D = null
	if not live.is_empty():
		var aim: Vector3 = intent.get("target", _pos)
		var best_d := 1.3
		for q: Variant in live:
			var qp: Vector3 = (q as Node3D).global_position
			var qd := Vector2(qp.x - aim.x, qp.z - aim.z).length()
			if qd < best_d:
				best_d = qd
				strike = q
	elif has_rival and options.is_empty():
		strike = rival
	elif legacy:
		strike = prey
	if state == "pounce" and prev != "pounce":
		bapped = false
	if state == "pounce" and strike != null and not bapped:
		var sp: Vector3 = strike.global_position
		var d := Vector2(_pos.x - sp.x, _pos.z - sp.z).length()
		if d < 0.55 and absf(_pos.y - sp.y) < 0.8:
			bapped = true
			if strike.has_method("taken_by_rival") and steals < steal_cap:
				steals += 1
				boast = "Aggie got there first. She looks terribly pleased."
				strike.taken_by_rival()
			elif strike is PvKCat:
				var away := sp - _pos
				away.y = 0.0
				if away.length() > 0.01:
					(strike as PvKCat).velocity += away.normalized() * 2.4 + Vector3(0, 1.2, 0)


func _highest() -> Vector3:
	var best: Vector3 = perches[0]
	for p: Variant in perches:
		var pp: Vector3 = p
		if pp.y > best.y:
			best = pp
	return best
