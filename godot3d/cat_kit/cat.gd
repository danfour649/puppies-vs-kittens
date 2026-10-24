class_name PvKCat
extends CharacterBody3D
## PvKCat — a procedural 3D cat in the GTA Fredericton wildlife idiom.
##
## The model is built exactly the way scripts/world/wildlife.gd builds its
## "quad" animals in _build_mesh(): flat-colour BoxMesh parts on a unit
## (~1 m) frame, forward = -Z, a Body group as child 0 that carries the
## gait bob, legs parented to the model root, and the whole model scaled
## by the species scale (stray_cat s = 0.32). This cat is Willy,
## Daniel's boy. His build is GTA's stray_cat: orange coat
## Color(0.85, 0.55, 0.25), and his lounge pose is wildlife.gd's own trick — body.scale = (1.05, 0.7, 1.0), "low and
## long, tail wrapped" (_spawn_river_cat).
##
## Kit refinements over the GTA original (geometry unchanged, only pivot
## wrappers added so parts can move): each leg sits under a hip pivot, the
## head under a neck pivot, the tail under a base pivot. Animation is all
## in code: idle breathing, diagonal-pair walk cycle, stalk crouch,
## paw-strike lunge, sprint, and the LOUNGE flop.
##
## Controller contract: call set_move_input() every physics frame, then
## strike() / set_lounge() on events. paw_swiped fires at the moment the
## paw lands; the host game checks catches around paw_point().

signal paw_swiped

const DATA_PATH := "res://cat_kit/cat_species.json"
const LEG_H := 0.35 ## wildlife.gd quad leg height (unit space)

var species_name := "Willy"
var coat := Color(0.85, 0.55, 0.25)
var model_scale := 0.32
var walk_speed := 2.4
var stalk_speed := 1.2 ## = GTA stray_cat spd: a hunting cat is a slow cat
var sprint_speed := 5.0
var strike_range := 0.55
var strike_cooldown := 0.38
var stamina_max := 100.0
var stamina_drain := 22.0
var stamina_regen := 14.0

## Read-only state for hosts/tests.
var anim_state := "idle"
var stamina := 100.0
var is_lounging := false

var _move_dir := Vector3.ZERO
var _want_sprint := false
var _want_stalk := false
var _cur_speed := 0.0
var _strike_t := -1.0
var _swipe_fired := false
var _cooldown := 0.0
var _phase := 0.0
var _time := 0.0
var _exhausted := false
var _lounge_k := 0.0 ## 0 = normal pose, 1 = full Willy lounge, eased

var _model: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _legs := {}
var _mats := {}
var _meshes := {}


func _init() -> void:
	_load_data()


func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	species_name = String(d.get("name", species_name))
	var col: Array = d.get("color", [0.85, 0.55, 0.25])
	coat = Color(float(col[0]), float(col[1]), float(col[2]))
	model_scale = float(d.get("scale", model_scale))
	var g: Dictionary = d.get("game", {})
	walk_speed = float(g.get("walk_speed", walk_speed))
	stalk_speed = float(g.get("stalk_speed", stalk_speed))
	sprint_speed = float(g.get("sprint_speed", sprint_speed))
	strike_range = float(g.get("strike_range", strike_range))
	strike_cooldown = float(g.get("strike_cooldown", strike_cooldown))
	stamina_max = float(g.get("stamina_max", stamina_max))
	stamina_drain = float(g.get("stamina_drain", stamina_drain))
	stamina_regen = float(g.get("stamina_regen", stamina_regen))
	stamina = stamina_max


func _ready() -> void:
	_build_model()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.15
	cap.height = 0.46
	cs.shape = cap
	cs.position = Vector3(0, 0.23, 0)
	add_child(cs)
	floor_snap_length = 0.25
	safe_margin = 0.04


# --- construction (mirrors wildlife.gd _mat/_box/_build_mesh) ---------------

func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	var dark := coat.darkened(0.35)
	var light := coat.lightened(0.45)
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	# Torso (wildlife.gd: box (bw, 0.35, 0.9) at leg_h + 0.18; quad bw = 0.35).
	_box(_body, Vector3(0.35, 0.35, 0.9), Vector3(0, LEG_H + 0.18, 0), coat)
	# Tabby stripes (kit refinement; the GTA stray_cat is a ginger tabby).
	for sz: float in [-0.22, 0.02, 0.26]:
		_box(_body, Vector3(0.36, 0.03, 0.07), Vector3(0, LEG_H + 0.36, sz), dark)
	# Pale chest patch (kit refinement).
	_box(_body, Vector3(0.3, 0.28, 0.1), Vector3(0, LEG_H + 0.12, -0.42), light)
	# Head group: same boxes as wildlife.gd, wrapped in a neck pivot.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, LEG_H + 0.38, -0.5)
	_body.add_child(_head)
	_box(_head, Vector3(0.26, 0.26, 0.3), Vector3(0, 0, -0.05), coat)
	_box(_head, Vector3(0.12, 0.1, 0.14), Vector3(0, -0.06, -0.24), dark) # snout
	_box(_head, Vector3(0.05, 0.03, 0.03), Vector3(0, -0.03, -0.315), Color(0.85, 0.45, 0.45)) # nose
	for ex: float in [-0.08, 0.08]:
		_box(_head, Vector3(0.06, 0.1, 0.04), Vector3(ex, 0.17, 0.0), coat) # ears
	for ex: float in [-0.065, 0.065]:
		_box(_head, Vector3(0.035, 0.05, 0.02), Vector3(ex, 0.03, -0.205), Color(0.15, 0.35, 0.15)) # eyes
	# Legs on the model root (as in GTA), each under a hip pivot for gait.
	for lx: float in [-0.12, 0.12]:
		for lz: float in [-0.32, 0.32]:
			var pivot := Node3D.new()
			pivot.position = Vector3(lx, LEG_H, lz)
			_model.add_child(pivot)
			_box(pivot, Vector3(0.09, LEG_H, 0.09), Vector3(0, -LEG_H * 0.5, 0), dark)
			_legs[_leg_key(lx, lz)] = pivot
	# Tail under a base pivot; GTA: box (0.08, 0.08, 0.5) centred z +0.65.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, LEG_H + 0.3, 0.42)
	_body.add_child(_tail)
	_box(_tail, Vector3(0.08, 0.08, 0.46), Vector3(0, 0, 0.21), coat)
	_box(_tail, Vector3(0.085, 0.085, 0.1), Vector3(0, 0, 0.4), light) # pale tip


func _leg_key(lx: float, lz: float) -> String:
	return ("F" if lz < 0.0 else "B") + ("L" if lx < 0.0 else "R")


# --- controller API ----------------------------------------------------------

## Call every physics frame. dir is a world-space horizontal direction
## (any length; clamped to 1). Sprint/stalk are requests, stamina rules.
func set_move_input(dir: Vector3, sprint: bool, stalk: bool) -> void:
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	_move_dir = dir
	_want_sprint = sprint
	_want_stalk = stalk


## Start a paw strike. Returns false on cooldown / mid-strike.
func strike() -> bool:
	if _strike_t >= 0.0 or _cooldown > 0.0:
		return false
	if is_lounging:
		set_lounge(false)
	_strike_t = 0.0
	_swipe_fired = false
	return true


func set_lounge(on: bool) -> void:
	is_lounging = on


func toggle_lounge() -> void:
	is_lounging = not is_lounging


## World-space facing (model forward is -Z, as in GTA).
func forward_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


## Where the front paw lands mid-strike, world space.
func paw_point() -> Vector3:
	return global_position + forward_dir() * strike_range + Vector3(0, 0.12, 0)


# --- simulation --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var moving := _move_dir.length() > 0.05
	if moving and is_lounging:
		set_lounge(false)
	var speed := 0.0
	var sprinting := false
	if moving and not is_lounging:
		speed = walk_speed
		if _want_stalk:
			speed = stalk_speed
		elif _want_sprint and not _exhausted:
			speed = sprint_speed
			sprinting = true
	if sprinting:
		stamina = maxf(stamina - stamina_drain * delta, 0.0)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(stamina + stamina_regen * delta, stamina_max)
		if _exhausted and stamina > 25.0:
			_exhausted = false
	var vel := velocity
	vel.x = _move_dir.x * speed
	vel.z = _move_dir.z * speed
	if _strike_t >= 0.0:
		vel.x *= 0.25
		vel.z *= 0.25
	if is_on_floor():
		vel.y = -1.0
	else:
		vel.y -= 22.0 * delta
	velocity = vel
	move_and_slide()
	_cur_speed = Vector2(velocity.x, velocity.z).length()
	if moving:
		var target_yaw := atan2(-_move_dir.x, -_move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
	if _strike_t >= 0.0:
		anim_state = "strike"
	elif is_lounging:
		anim_state = "lounge"
	elif not moving:
		anim_state = "idle"
	elif sprinting:
		anim_state = "sprint"
	elif _want_stalk:
		anim_state = "stalk"
	else:
		anim_state = "walk"


# --- animation (all in code; poses are pure functions of state + time) -------

func _process(delta: float) -> void:
	if _model == null:
		return
	_lounge_k = clampf(_lounge_k + (delta / 0.35) * (1.0 if is_lounging else -1.0), 0.0, 1.0)
	if _cur_speed > 0.05:
		_phase += delta * _cur_speed * 5.2
	# Defaults: upright, still, tail carried up with a slow sway.
	var body_pos := Vector3.ZERO
	var body_scale := Vector3.ONE
	var head_rot := Vector3.ZERO
	var tail_rot := Vector3(-0.35 + sin(_time * 2.3) * 0.05, sin(_time * 1.3) * 0.15, 0)
	var leg_rx := {"FL": 0.0, "FR": 0.0, "BL": 0.0, "BR": 0.0}
	match anim_state:
		"idle":
			body_scale.y = 1.0 + 0.025 * sin(_time * 2.1) # breathing
			head_rot.y = sin(_time * 0.35) * 0.18 # looking around
		"walk", "stalk", "sprint":
			var amp := 0.5
			var bob := 0.05
			if anim_state == "stalk":
				amp = 0.3
				bob = 0.02
				body_pos.y = -0.1
				body_scale.y = 0.84
				head_rot.x = 0.15
				tail_rot.x = -0.05
			elif anim_state == "sprint":
				amp = 0.75
				bob = 0.07
				body_pos.z = -0.03
				tail_rot.x = -0.75
			var s0 := sin(_phase) * amp
			var s1 := sin(_phase + PI) * amp
			leg_rx["FL"] = s0
			leg_rx["BR"] = s0
			leg_rx["FR"] = s1
			leg_rx["BL"] = s1
			body_pos.y += absf(sin(_phase)) * bob # GTA gait bob
		"strike":
			pass # posed by the strike timeline below
	if _lounge_k > 0.0:
		var k := _lounge_k
		body_scale = body_scale.lerp(Vector3(1.05, 0.7, 1.0), k) # GTA's numbers (the river cat's lounge scale)
		body_pos.y = lerpf(body_pos.y, -0.02, k)
		head_rot.x = lerpf(head_rot.x, 0.3, k)
		head_rot.z = lerpf(head_rot.z, 0.12, k)
		tail_rot.y = lerpf(tail_rot.y, 0.85, k) # tail wrapped
		tail_rot.x = lerpf(tail_rot.x, -0.1, k)
		leg_rx["FL"] = lerpf(leg_rx["FL"], 1.15, k)
		leg_rx["FR"] = lerpf(leg_rx["FR"], 1.15, k)
		leg_rx["BL"] = lerpf(leg_rx["BL"], -1.15, k)
		leg_rx["BR"] = lerpf(leg_rx["BR"], -1.15, k)
	if _strike_t >= 0.0:
		_strike_t += delta
		var t := _strike_t
		if not _swipe_fired and t >= 0.10:
			_swipe_fired = true
			paw_swiped.emit()
		var lunge := 0.0
		if t < 0.10:
			lunge = -0.10 * (t / 0.10) # wind back
		elif t < 0.20:
			lunge = lerpf(-0.10, 0.30, (t - 0.10) / 0.10) # lunge forward
		elif t < 0.34:
			lunge = lerpf(0.30, 0.0, (t - 0.20) / 0.14)
		body_pos.z = -lunge
		leg_rx["FR"] = -1.5 * sin(clampf(t / 0.3, 0.0, 1.0) * PI) # paw slash
		if t >= 0.34:
			_strike_t = -1.0
			_cooldown = strike_cooldown
	_body.position = body_pos
	_body.scale = body_scale
	_head.rotation = head_rot
	_tail.rotation = tail_rot
	for key: String in leg_rx:
		(_legs[key] as Node3D).rotation.x = leg_rx[key]
