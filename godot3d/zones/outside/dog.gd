class_name PvKDog
extends Node3D
## Willie and Aggie — the heritage threat: a dog being walked past
## 255 Massey. The original 2020 game's enemies were puppies; these
## are the front-yard menace in dog form.
##
## HEEL (walks, sniffs) -> ALERT (player cat spotted in the front
## zone: ears up, barking) -> STRAIN (lunges to the leash limit
## while the human leans back and skids) -> if the cat comes
## within DOG_SLIP_RADIUS, the leash SLIPS -> CHASE (faster than
## Willie, about Aggie's pace; cannot climb, never enters the
## house or the back yard). Escape valves end a chase: tree climb
## (circle the trunk, give up), hiding still in a bush (one
## confused circle), leaving the front zone, or outrunning the
## give-up radius/time. Then it trots back, leash "reattached".
## Bites and the grab are resolved by OutsideSystem (damage
## contract); the dog just runs the behaviour.
##
## Dogs target the PLAYER cat only. The sibling is a backyard cat
## and stays out of this system entirely.

signal chase_ended(dog: PvKDog, valve: String)

var size := "small" ## "small" (yappy, fast, light bite) or "big" (heavy)
var state := "heel"
var human: PvKWalker = null
var cat: Node3D = null ## the player cat, refreshed by the system
var sys: Node = null ## OutsideSystem (untyped: dynamic calls)

var bark_count := 0
var chase_t := 0.0

var _state_t := 0.0
var _bark_t := 0.0
var _scent_t := 0.0
var _chase_live := false
var _strain_peak := 0.0 ## longest continuous strain (cool-cat objective)
var _orbit_centre := Vector3.ZERO
var _orbit_r := 1.2
var _orbit_t := 0.0
var _orbit_dur := 0.0
var _orbit_valve := ""
var _orbit_ang := 0.0
var _voice: AudioStreamPlayer3D
var _leash: MeshInstance3D
var _collar_h := 0.35
var _time := 0.0
var _phase := 0.0
var _model: Node3D
var _body: Node3D
var _tail: Node3D
var _ear_l: MeshInstance3D
var _ear_r: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}

const SCALES := {"small": 0.50, "big": 0.74}
const COATS := {"small": Color(0.72, 0.58, 0.40), "big": Color(0.23, 0.18, 0.15)}


func setup(p_size: String, p_owner: PvKWalker, seed_: int) -> void:
	size = p_size
	human = p_owner
	_rng.seed = seed_
	_build()
	_voice = OutsideAudio.make_voice(self, -8.0)
	_voice.position = Vector3(0, _collar_h + 0.15, 0)


func model_scale() -> float:
	return SCALES[size]


## The visible leash: a thin cylinder strung hand -> collar each
## frame. Lives under the zone root (added by the system).
func attach_leash(parent: Node) -> void:
	_leash = MeshInstance3D.new()
	_leash.name = "Leash"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.013
	cm.bottom_radius = 0.013
	cm.height = 1.0
	cm.radial_segments = 6
	_leash.mesh = cm
	_leash.material_override = _mat(Color(0.55, 0.12, 0.12))
	parent.add_child(_leash)


func start_chase() -> void:
	state = "chase"
	chase_t = 0.0
	_scent_t = 0.0
	_chase_live = true
	if human != null:
		human.skidding = false


func start_orbit(centre: Vector3, r: float, dur: float, valve: String) -> void:
	state = "orbit"
	_orbit_centre = centre
	_orbit_centre.y = 0.0
	_orbit_r = r
	_orbit_dur = dur
	_orbit_t = 0.0
	_orbit_valve = valve
	var rel := global_position - centre
	_orbit_ang = atan2(rel.z, rel.x)


func start_return(valve: String) -> void:
	if _chase_live:
		_chase_live = false
		chase_ended.emit(self, valve)
	state = "return"
	if human != null:
		human.skidding = false


func _bark() -> void:
	bark_count += 1
	if _voice != null:
		_voice.stream = OutsideAudio.bark_stream(size == "big")
		_voice.play()


func _physics_process(delta: float) -> void:
	_time += delta
	_state_t += delta
	if human == null or not is_instance_valid(human):
		return
	match state:
		"heel":
			_step_heel(delta)
			if _cat_spotted():
				state = "alert"
				_state_t = 0.0
				_bark()
				_bark_t = 0.55
		"alert":
			_face_cat(delta, 10.0)
			_bark_t -= delta
			if _bark_t <= 0.0:
				_bark()
				_bark_t = 0.8
			if not _cat_spotted():
				state = "heel"
			elif _state_t > 0.4:
				state = "strain"
				_state_t = 0.0
				_strain_peak = 0.0
		"strain":
			_step_strain(delta)
		"chase":
			_step_chase(delta)
		"orbit":
			_step_orbit(delta)
		"return":
			_step_return(delta)
	# The dog never crosses into the back yard (house line).
	global_position.z = minf(global_position.z, -9.7)
	global_position.z = maxf(global_position.z, -21.2)
	global_position.y = 0.0
	_update_leash()
	# Ear/tail language.
	var alerted := state in ["alert", "strain", "chase"]
	if _ear_l != null:
		var ear_rot := -0.35 if alerted else 0.25
		_ear_l.rotation.x = lerpf(_ear_l.rotation.x, ear_rot, 1.0 - exp(-10.0 * delta))
		_ear_r.rotation.x = _ear_l.rotation.x
	if _tail != null:
		if state in ["alert", "strain"]:
			_tail.rotation.y = sin(_time * 16.0) * 0.4 # wagging hard
		elif state == "chase":
			_tail.rotation.y = 0.0
		else:
			_tail.rotation.y = sin(_time * 3.0) * 0.15


func _cat_spotted() -> bool:
	if cat == null or not is_instance_valid(cat) or sys == null:
		return false
	if not sys.cat_in_front(cat.global_position):
		return false
	var d := _flat_dist(global_position, cat.global_position)
	if sys.cat_hidden(cat):
		return d < OutsideLayout.DOG_ALERT_RADIUS_HIDDEN
	return d < OutsideLayout.DOG_ALERT_RADIUS


func _step_heel(delta: float) -> void:
	var anchor := human.global_position + Vector3(-0.55 * human.dir, 0, 0.32)
	_move_toward(anchor, 3.4, delta, 10.0)
	# Sniffing: the front dips now and then.
	_phase += delta * 2.0
	_body.rotation.x = 0.10 + 0.08 * sin(_phase * 0.7)


func _step_strain(delta: float) -> void:
	_strain_peak = maxf(_strain_peak, _state_t)
	human.skidding = true
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark()
		_bark_t = 1.1
	var hand := human.hand_pos()
	var to_cat := cat.global_position - hand
	to_cat.y = 0.0
	if to_cat.length() < 0.01:
		return
	var anchor := hand + to_cat.normalized() * OutsideLayout.LEASH_LEN
	_move_toward(anchor, 3.6, delta, 12.0)
	# Hard leash limit: the dog cannot pass the end of its lead.
	var rel := global_position - hand
	rel.y = 0.0
	if rel.length() > OutsideLayout.LEASH_LEN:
		var clamped := hand + rel.normalized() * OutsideLayout.LEASH_LEN
		global_position.x = clamped.x
		global_position.z = clamped.z
	_face_cat(delta, 12.0)
	# The slip.
	if _flat_dist(global_position, cat.global_position) < OutsideLayout.DOG_SLIP_RADIUS:
		if sys != null:
			sys.on_leash_slip(self)
		return
	# Cat gone (left the front zone): stand down.
	if not _cat_spotted() and _state_t > 0.6:
		human.skidding = false
		if _strain_peak >= 1.2 and sys != null:
			sys.on_cool_cat(self)
		state = "heel"


func _step_chase(delta: float) -> void:
	chase_t += delta
	if sys == null:
		return
	# Escape valves, in the cat's favour.
	var tree: Variant = sys.cat_climbing_tree()
	if tree != null:
		var t := tree as YardTree
		start_orbit(t.global_position, 1.15, OutsideLayout.DOG_TREE_CIRCLE_TIME, "tree")
		return
	if sys.cat_hidden(cat):
		if _flat_dist(global_position, cat.global_position) < 3.4:
			_scent_t += delta
			if _scent_t > 0.9:
				var bush: Vector3 = sys.nearest_bush_pos(cat.global_position)
				start_orbit(bush, 1.35, OutsideLayout.DOG_BUSH_CONFUSE_TIME, "bush")
				return
	else:
		_scent_t = 0.0
	if not sys.cat_in_front(cat.global_position):
		start_return("region")
		return
	if _flat_dist(global_position, cat.global_position) > OutsideLayout.DOG_GIVE_UP_DIST or chase_t > OutsideLayout.DOG_GIVE_UP_TIME:
		start_return("outrun")
		return
	# Pursuit: turn-rate-limited steering at range (the arcs are
	# the character — a big dog turns like a truck), easing off as
	# it closes so the turning circle shrinks inside the gap, and
	# a direct lunge for the last stretch. Without the ease and
	# the lunge, the turn circle (~2.7 m for the big dog) is wider
	# than the bite range and the dog orbits a still cat forever.
	var speed := float(OutsideLayout.DOG_CHASE_SPEED[size])
	var turn := float(OutsideLayout.DOG_TURN_RATE[size])
	var to := cat.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.45:
		var want_yaw := atan2(-to.x, -to.z)
		rotation.y = lerp_angle(rotation.y, want_yaw, 1.0 - exp(-turn * delta))
		if dist < 1.2:
			var goal := Vector3(cat.global_position.x, global_position.y, cat.global_position.z)
			global_position = global_position.move_toward(goal, speed * 0.8 * delta)
		else:
			var fwd := -global_transform.basis.z
			fwd.y = 0.0
			var spd := speed * clampf(dist / 2.4, 0.5, 1.0)
			global_position += fwd.normalized() * spd * delta
		_phase += delta * speed * 3.0
		_body.position.y = absf(sin(_phase)) * 0.05
	sys.dog_bite_check(self)


func _step_orbit(delta: float) -> void:
	_orbit_t += delta
	# If the cat breaks cover mid-circle, the chase is back on.
	if _orbit_valve == "bush" and sys != null and not sys.cat_hidden(cat):
		state = "chase"
		return
	if _orbit_valve == "tree" and sys != null and sys.cat_climbing_tree() == null:
		state = "chase"
		return
	_orbit_ang += delta * 2.4 / _orbit_r
	var target := _orbit_centre + Vector3(cos(_orbit_ang) * _orbit_r, 0, sin(_orbit_ang) * _orbit_r)
	_move_toward(target, 2.7, delta, 10.0)
	if _orbit_t > _orbit_dur:
		start_return(_orbit_valve)


func _step_return(delta: float) -> void:
	var anchor := human.global_position + Vector3(-0.3 * human.dir, 0, 0.3)
	_move_toward(anchor, 4.6, delta, 12.0)
	if _flat_dist(global_position, anchor) < 0.45:
		state = "heel"
		human.state = "walk"


func _move_toward(target: Vector3, speed: float, delta: float, face_rate: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.03:
		return
	var step := to.normalized() * minf(speed * delta, to.length())
	global_position += step
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-face_rate * delta))


func _face_cat(delta: float, rate: float) -> void:
	if cat == null:
		return
	var to := cat.global_position - global_position
	to.y = 0.0
	if to.length() < 0.03:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-rate * delta))


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_leash() -> void:
	if _leash == null or human == null:
		return
	_leash.visible = state in ["heel", "alert", "strain"]
	if not _leash.visible:
		return
	var a := human.hand_pos()
	var b := global_position + Vector3(0, _collar_h, 0)
	var mid := (a + b) * 0.5
	var d := a.distance_to(b)
	_leash.global_position = mid
	_leash.scale = Vector3(1, maxf(d, 0.05), 1)
	if d > 0.05:
		_leash.look_at_from_position(mid, b, Vector3.UP)
		_leash.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# --- model (unit frame, mouse idiom) --------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build() -> void:
	var coat: Color = COATS[size]
	var dark := coat.darkened(0.3)
	var scale_ := model_scale()
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * scale_
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var leg_h := 0.34
	_collar_h = (leg_h + 0.40) * scale_
	_box(_body, Vector3(0.40, 0.42, 0.95), Vector3(0, leg_h + 0.21, 0), coat)
	_box(_body, Vector3(0.30, 0.30, 0.32), Vector3(0, leg_h + 0.44, -0.55), coat) # head
	_box(_body, Vector3(0.16, 0.14, 0.26), Vector3(0, leg_h + 0.36, -0.80), dark) # snout
	_ear_l = _box(_body, Vector3(0.07, 0.2, 0.05), Vector3(-0.1, leg_h + 0.62, -0.48), dark)
	_ear_r = _box(_body, Vector3(0.07, 0.2, 0.05), Vector3(0.1, leg_h + 0.62, -0.48), dark)
	_box(_body, Vector3(0.42, 0.08, 0.1), Vector3(0, leg_h + 0.3, -0.3), Color(0.62, 0.1, 0.1)) # collar
	_tail = Node3D.new()
	_tail.position = Vector3(0, leg_h + 0.34, 0.48)
	_body.add_child(_tail)
	_box(_tail, Vector3(0.09, 0.09, 0.42), Vector3(0, 0.05, 0.2), coat, Vector3(-0.5, 0, 0))
	for lx: float in [-0.12, 0.12]:
		for lz: float in [-0.32, 0.32]:
			_box(_model, Vector3(0.1, leg_h, 0.1), Vector3(lx, leg_h * 0.5, lz), dark)
