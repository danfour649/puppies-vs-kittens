class_name PvKCat
extends CharacterBody3D
## PvKCat — a procedural 3D cat: Willy, Daniel's boy.
##
## Construction keeps the GTA Fredericton wildlife idiom's architecture —
## a unit (~1 m) frame, forward = -Z, a Body group as child 0 that
## carries the gait bob, legs parented to the model root under hip
## pivots, the head under a neck pivot, the tail under a base pivot, and
## the whole model scaled by the species scale (stray_cat s = 0.32) —
## so the port path back into GTA (see README.md) is unchanged. But the
## parts are SMOOTH primitives (ellipsoids, tapered cylinders, capsule
## paws, a segmented-sphere tail), not GTA's flat boxes: Willy is a
## modelled cat, not a voxel toy.
##
## Colouring is Willy's own, sampled from the original v0.1 hand-drawn
## kitten art (cat_kit/reference-willy-v01.png — the same sprite ships
## in every version): a WHITE coat with GINGER patches (#E8AF54) — a
## saddle along the spine sweeping into the tail, a cap on top of the
## head, a small chest bib — dark eyes and a small pink nose. It is
## deliberately NOT GTA stray_cat's solid orange (0.85, 0.55, 0.25);
## that palette belongs to a different cat. The lounge pose is still
## wildlife.gd's own trick — body.scale = (1.05, 0.7, 1.0), "low and
## long, tail wrapped" (_spawn_river_cat).
##
## Animation is all in code: idle breathing, diagonal-pair walk cycle,
## stalk crouch, paw-strike lunge, sprint, and the LOUNGE flop.
##
## Controller contract: call set_move_input() every physics frame, then
## strike() / set_lounge() on events. paw_swiped fires at the moment the
## paw lands; the host game checks catches around paw_point().

signal paw_swiped

const DATA_PATH := "res://cat_kit/cat_species.json"
const LEG_H := 0.35 ## wildlife.gd quad leg height (unit space)

var species_name := "Willy"
var coat := Color(1.0, 1.0, 1.0) ## Willy's white, from the v0.1 art
var ginger := Color(0.9098, 0.6863, 0.3294) ## sampled ginger #E8AF54
var nose_color := Color(0.851, 0.549, 0.478) ## pink #D98C7A
var eye_color := Color(0.10, 0.08, 0.07) ## near-black brown
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
var _torso: MeshInstance3D
var _saddle_patch: MeshInstance3D
var _legs := {}
var _mats := {}
var _sphere_mesh: SphereMesh
var _cyl_meshes := {}


func _init() -> void:
	_load_data()


func _json_color(a: Variant, fallback: Color) -> Color:
	if typeof(a) == TYPE_ARRAY and (a as Array).size() >= 3:
		var arr: Array = a
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


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
	coat = _json_color(d.get("color", []), coat)
	var pal: Dictionary = d.get("palette", {})
	if not pal.is_empty():
		coat = _json_color(pal.get("coat", []), coat)
		ginger = _json_color(pal.get("ginger", []), ginger)
		nose_color = _json_color(pal.get("nose", []), nose_color)
		eye_color = _json_color(pal.get("eye", []), eye_color)
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


# --- construction (smooth primitives on the GTA anchor layout) -------------

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


## One shared unit sphere (diameter 1); ellipsoids are instances scaled
## to their diameters, so parts blend instead of butting like boxes.
func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.9) -> MeshInstance3D:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 0.5
		_sphere_mesh.height = 1.0
		_sphere_mesh.radial_segments = 32
		_sphere_mesh.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere_mesh
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _taper(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color) -> MeshInstance3D:
	var key := "%f|%f|%f" % [top_r, bot_r, h]
	if not _cyl_meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = top_r
		cm.bottom_radius = bot_r
		cm.height = h
		cm.radial_segments = 16
		_cyl_meshes[key] = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_meshes[key]
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	# Torso: a long ellipsoid with a chest sphere at the front and two
	# haunch spheres at the rear, all blended into one body mass.
	_torso = _ell(_body, Vector3(0, 0.55, 0.02), Vector3(0.38, 0.37, 0.92), coat)
	_ell(_body, Vector3(0, 0.545, -0.30), Vector3(0.365, 0.355, 0.36), coat) # chest
	for hx: float in [-0.088, 0.088]:
		_ell(_body, Vector3(hx, 0.565, 0.29), Vector3(0.20, 0.30, 0.34), coat) # haunches
	# Willy's ginger saddle: flattened ellipsoid shells hugging the back,
	# sweeping from mid-back to the tail base (v0.1 art layout).
	_saddle_patch = _ell(_body, Vector3(0, 0.615, 0.06), Vector3(0.395, 0.27, 0.68), ginger)
	_ell(_body, Vector3(0, 0.60, 0.33), Vector3(0.37, 0.24, 0.30), ginger) # rear saddle
	# Small ginger chest bib at the throat (v0.1 art).
	_ell(_body, Vector3(0, 0.60, -0.435), Vector3(0.15, 0.19, 0.10), ginger, Vector3(-0.35, 0, 0))
	# Head group under a neck pivot (same anchor as the GTA build).
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, LEG_H + 0.38, -0.5)
	_body.add_child(_head)
	_ell(_head, Vector3(0, 0.03, -0.05), Vector3(0.30, 0.28, 0.29), coat) # skull
	_ell(_head, Vector3(0, -0.035, -0.155), Vector3(0.185, 0.135, 0.155), coat) # muzzle
	# Ginger cap on top of the head, between the ears (v0.1 art).
	_ell(_head, Vector3(0, 0.095, -0.045), Vector3(0.295, 0.175, 0.285), ginger)
	# Ears: pinched spheres tilted out, pale inner ear on the front face.
	for ex: float in [-0.088, 0.088]:
		var tilt := Vector3(0.06, 0, -signf(ex) * 0.14)
		_ell(_head, Vector3(ex, 0.165, -0.01), Vector3(0.085, 0.15, 0.05), coat, tilt)
		_ell(_head, Vector3(ex, 0.16, -0.038), Vector3(0.05, 0.09, 0.02), Color(0.89, 0.65, 0.56), tilt)
	# Dark eyes, slightly proud; tiny pink nose.
	for ex: float in [-0.067, 0.067]:
		_ell(_head, Vector3(ex, 0.045, -0.178), Vector3(0.034, 0.034, 0.034), eye_color, Vector3.ZERO, 0.25)
	_ell(_head, Vector3(0, -0.018, -0.222), Vector3(0.042, 0.028, 0.026), nose_color, Vector3.ZERO, 0.5)
	# Legs on the model root (as in GTA), each under a hip pivot for
	# gait: hip blend sphere, tapered leg, capsule paw. All white.
	for lx: float in [-0.12, 0.12]:
		for lz: float in [-0.32, 0.32]:
			var pivot := Node3D.new()
			pivot.position = Vector3(lx, LEG_H, lz)
			_model.add_child(pivot)
			_ell(pivot, Vector3(0, -0.02, 0), Vector3(0.145, 0.13, 0.145), coat)
			_taper(pivot, Vector3(0, -0.175, 0), 0.060, 0.044, 0.34, coat)
			_ell(pivot, Vector3(0, -0.332, -0.016), Vector3(0.10, 0.06, 0.13), coat)
			_legs[_leg_key(lx, lz)] = pivot
	# Tail under a base pivot: a curved chain of shrinking spheres.
	# White at the base and tip, ginger along the rear (v0.1 art).
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, LEG_H + 0.3, 0.42)
	_body.add_child(_tail)
	var tail_segs := [
		[0.02, 0.000, 0.112, coat],
		[0.068, 0.005, 0.108, coat],
		[0.116, 0.013, 0.103, ginger],
		[0.164, 0.024, 0.097, ginger],
		[0.212, 0.038, 0.090, ginger],
		[0.260, 0.055, 0.083, ginger],
		[0.308, 0.074, 0.075, ginger],
		[0.356, 0.094, 0.067, ginger],
		[0.400, 0.114, 0.058, coat],
	]
	for seg: Array in tail_segs:
		_ell(_tail, Vector3(0, float(seg[1]), float(seg[0])), Vector3.ONE * float(seg[2]), seg[3] as Color)


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
