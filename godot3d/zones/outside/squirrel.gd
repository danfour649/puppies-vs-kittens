class_name PvKSquirrel
extends Node3D
## Willie and Aggie — a yard squirrel, in the PvKMouse idiom
## (procedural unit-frame build, glides, no physics body — the
## brain is a _step like GTA's wildlife.gd).
##
## Life: FORAGE on the ground (dig, sit-up lookout, hop to a new
## spot) -> a cat closing in (or lunging) sends it FLEEing to its
## home tree -> CLIMB the trunk -> TAUNT from the first branch
## (tail flicking; safe from ground pounces — only a cat that
## climbs the trunk can swipe it there) -> when the yard is calm,
## DESCEND and forage again. Catchable on the ground (2 strikes)
## or mid-climb (a well-timed trunk-base pounce).

signal caught(sq: PvKSquirrel)

const MODEL_SCALE := 0.30
const COAT := Color(0.45, 0.38, 0.33) # grey-brown
const BELLY := Color(0.78, 0.72, 0.62)
const TAIL_COL := Color(0.52, 0.44, 0.36)

var state := "forage"
var hp := OutsideLayout.SQUIRREL_HP
var home_tree: YardTree = null
var forage_anchor := Vector3.ZERO
var cat: Node3D = null ## refreshed by OutsideSystem every frame

var climb_y := 0.0 ## height on the trunk while climbing/descending
var invuln_t := 0.0

var _mode := "dig" # forage sub-state: dig / situp / hop
var _mode_t := 0.0
var _target := Vector3.ZERO
var _calm_t := 0.0
var _time := 0.0
var _phase := 0.0
var _bound_ph := 0.0 # REALISM PASS 1: bound cycle phase (flee/hop)
var _model: Node3D
var _body: Node3D
var _tail: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func setup(tree: YardTree, anchor: Vector3, seed_: int) -> void:
	home_tree = tree
	forage_anchor = anchor
	_rng.seed = seed_
	global_position = anchor
	_target = anchor


func _ready() -> void:
	_build_model()
	_mode_t = _rng.randf_range(0.4, 1.4)


func is_safe() -> bool:
	return state == "taunt"


## A landed paw. Returns true if the hit connected.
## source: "ground" (foraging/fleeing on the grass), "pounce"
## (trunk-base pounce while climbing — the system rolls the catch
## chance first), "branch" (a climbing cat's swipe on the perch).
func take_hit(source: String) -> bool:
	if state == "caught" or invuln_t > 0.0:
		return false
	match source:
		"pounce":
			get_caught()
			return true
		"ground":
			if state in ["climb", "taunt", "descend"]:
				return false
			hp -= 1
			invuln_t = 1.0
			if hp <= 0:
				get_caught()
			else:
				state = "flee" # hurt: run for the tree, now
			return true
		"branch":
			if state != "taunt":
				return false
			hp -= 1
			invuln_t = 1.0
			if hp <= 0:
				get_caught()
			else:
				# Knocked off the perch: drops, then runs for
				# the ground cover and re-forages, furious.
				global_position = home_tree.global_position + _out_dir() * 0.8
				global_position.y = 0.0
				climb_y = 0.0
				state = "forage"
				_mode = "hop"
				_target = _new_forage_target()
				_mode_t = 2.0
			return true
	return false


func get_caught() -> void:
	if state == "caught":
		return
	state = "caught"
	caught.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * MODEL_SCALE * 1.25, 0.07)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.001, 0.16)
	tw.tween_callback(queue_free)


## Test/staging seam: start a climb right now.
func debug_force_climb() -> void:
	if state == "caught":
		return
	global_position = home_tree.global_position + _out_dir() * 0.45
	global_position.y = 0.0
	climb_y = 0.0
	state = "climb"


func _out_dir() -> Vector3:
	if home_tree == null:
		return Vector3.RIGHT
	return home_tree.branch_dir


func _new_forage_target() -> Vector3:
	var p := forage_anchor + Vector3(_rng.randf_range(-2.6, 2.6), 0, _rng.randf_range(-2.6, 2.6))
	p.x = clampf(p.x, OutsideLayout.YARD_RECT.position.x, OutsideLayout.YARD_RECT.position.x + OutsideLayout.YARD_RECT.size.x)
	p.z = clampf(p.z, OutsideLayout.YARD_RECT.position.y, OutsideLayout.YARD_RECT.position.y + OutsideLayout.YARD_RECT.size.y)
	p.y = 0.0
	return p


func _physics_process(delta: float) -> void:
	if state == "caught" or _body == null:
		return
	_time += delta
	_phase += delta * 9.0
	if invuln_t > 0.0:
		invuln_t -= delta
	# Flee check first, like wildlife.gd.
	if state in ["forage", "descend"] and _cat_threat():
		state = "flee"
	match state:
		"forage":
			_step_forage(delta)
		"flee":
			_step_toward(home_tree.global_position + _out_dir() * 0.40, OutsideLayout.SQUIRREL_RUN_SPEED, delta)
			# REALISM PASS 1: the bounding gait — back arches, body
			# porpoises, tail arcs a beat behind the bound.
			_bound_ph += delta * (11.0 + OutsideLayout.SQUIRREL_RUN_SPEED * 1.6)
			_body.position.y = absf(sin(_bound_ph)) * 0.085
			_body.rotation.x = sin(_bound_ph) * 0.30
			_tail.rotation.x = -0.30 + sin(_bound_ph - 1.1) * 0.32
			_tail.rotation.z = sin(_bound_ph - 1.1) * 0.14
			if _flat_dist(global_position, home_tree.global_position) < 0.42:
				state = "climb"
				climb_y = 0.0
		"climb":
			# Settle out of the bound as the trunk takes over.
			_body.position.y = lerpf(_body.position.y, 0.0, 0.35)
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, 0.35)
			climb_y = minf(climb_y + OutsideLayout.SQUIRREL_CLIMB_SPEED * delta, home_tree.branch_y)
			global_position = home_tree.surface_point(climb_y, _out_dir())
			_face(home_tree.global_position, delta) # nose into the trunk
			if climb_y >= home_tree.branch_y - 0.001:
				state = "taunt"
				global_position = home_tree.perch_pos()
				_calm_t = 0.0
		"taunt":
			global_position = home_tree.perch_pos()
			# The taunt: that tail, flicking, just out of reach.
			_tail.rotation.z = sin(_time * 11.0) * 0.35
			_tail.rotation.x = -0.5 + sin(_time * 5.5) * 0.12
			if cat != null and _flat_dist(global_position, cat.global_position) > OutsideLayout.SQUIRREL_CALM_RADIUS:
				_calm_t += delta
			else:
				_calm_t = 0.0
			if _calm_t > OutsideLayout.SQUIRREL_CALM_TIME:
				state = "descend"
		"descend":
			climb_y = maxf(climb_y - OutsideLayout.SQUIRREL_CLIMB_SPEED * 1.6 * delta, 0.0)
			if climb_y > 0.0:
				global_position = home_tree.surface_point(climb_y, _out_dir())
			else:
				global_position = home_tree.global_position + _out_dir() * 0.55
				global_position.y = 0.0
				state = "forage"
				_mode = "dig"
				_mode_t = _rng.randf_range(0.6, 1.6)


func _cat_threat() -> bool:
	if cat == null or not is_instance_valid(cat):
		return false
	var d := _flat_dist(global_position, cat.global_position)
	if d < OutsideLayout.SQUIRREL_FLEE_RADIUS:
		return true
	var st := String(cat.get("anim_state"))
	if st in ["sprint", "strike"] and d < OutsideLayout.SQUIRREL_LUNGE_RADIUS:
		return true
	# A meow carries past the ordinary flee radius. A stalk does not.
	var meow_loud := 0.0
	if cat.has_meta("meow_until_msec") and Time.get_ticks_msec() < int(cat.get_meta("meow_until_msec")):
		meow_loud = CatNoise.loudness("meow")
	if CreatureBrain.squirrel_hears_meow(d, meow_loud, float(CreatureProfiles.squirrel()["meow_radius"])):
		return true
	return false


func _step_forage(delta: float) -> void:
	_mode_t -= delta
	# Body language per sub-state: dig = nose-down buzz, situp =
	# upright lookout, hop = travel.
	match _mode:
		"dig":
			_body.rotation.x = 0.38 + sin(_phase * 2.2) * 0.07
			_body.position.y = absf(sin(_phase * 2.2)) * 0.03
		"situp":
			_body.rotation.x = -0.52
			_body.position.y = 0.06
		"hop":
			_body.rotation.x = sin(_phase) * 0.18
			_body.position.y = absf(sin(_phase)) * 0.10
			_tail.rotation.x = -0.25 + sin(_phase - 1.0) * 0.25 # tail arcs behind the hop
			_step_toward(_target, 1.7, delta)
			if _flat_dist(global_position, _target) < 0.2:
				_mode_t = 0.0
	if _mode_t <= 0.0:
		match _mode:
			"dig":
				_mode = "situp"
				_mode_t = _rng.randf_range(0.8, 1.8)
			"situp":
				_mode = "hop"
				_target = _new_forage_target()
				_mode_t = 3.0
			"hop":
				_mode = "dig"
				_mode_t = _rng.randf_range(1.0, 2.2)
	if _mode != "hop":
		_body.rotation.x = lerpf(_body.rotation.x, 0.38 if _mode == "dig" else -0.52, 0.4)


func _step_toward(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.03:
		return
	var step := to.normalized() * minf(speed * delta, to.length())
	global_position += step
	_face(global_position + to, delta)


func _face(world_point: Vector3, delta: float) -> void:
	var to := world_point - global_position
	to.y = 0.0
	if to.length() < 0.03:
		return
	var target_yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- model (unit frame, mouse idiom; the tail is the glory) -----------

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


func _build_model() -> void:
	var dark := COAT.darkened(0.3)
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var leg_h := 0.30
	_box(_body, Vector3(0.42, 0.40, 0.85), Vector3(0, leg_h + 0.20, 0), COAT)
	_box(_body, Vector3(0.34, 0.30, 0.30), Vector3(0, leg_h + 0.16, 0.08), BELLY) # belly patch
	_box(_body, Vector3(0.30, 0.30, 0.30), Vector3(0, leg_h + 0.42, -0.48), COAT) # head
	_box(_body, Vector3(0.13, 0.10, 0.16), Vector3(0, leg_h + 0.36, -0.68), dark) # snout
	for ex: float in [-0.09, 0.09]:
		_box(_body, Vector3(0.06, 0.11, 0.04), Vector3(ex, leg_h + 0.62, -0.46), COAT) # ears
	# The tail: a big curved banner — base angled up behind, fluffy
	# tip. Parent group at the rear so the taunt can flick it.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, leg_h + 0.28, 0.44)
	_body.add_child(_tail)
	_box(_tail, Vector3(0.15, 0.55, 0.15), Vector3(0, 0.24, 0.10), TAIL_COL, Vector3(0.5, 0, 0))
	_box(_tail, Vector3(0.23, 0.48, 0.23), Vector3(0, 0.62, 0.30), TAIL_COL, Vector3(0.9, 0, 0))
	_box(_tail, Vector3(0.19, 0.30, 0.19), Vector3(0, 0.92, 0.52), BELLY.darkened(0.1), Vector3(1.2, 0, 0))
	for lx: float in [-0.13, 0.13]:
		for lz: float in [-0.28, 0.30]:
			_box(_model, Vector3(0.09, leg_h, 0.09), Vector3(lx, leg_h * 0.5, lz), dark)
