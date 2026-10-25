class_name Glenys
extends CharacterBody3D
## GLENYS — Daniel's mother, resident of 255 Massey Street, and
## the cats' most relentless problem.
##
## Character note (Daniel's, and affectionate): she got her master's
## degree in computer science in the 1960s. The cane is newer than
## the degree. She is demented, she adores the cats, and given time
## she WILL catch one — the brain lives in glenys_system.gd; this
## file is the body: build, gait, poses, and the cane.
##
## Construction mirrors the occupants (occupants/occupant.gd),
## which mirror GTA Fredericton's scripts/body_proportions.gd
## segment layout and scripts/npc/pedestrian.gd's _build_body idiom
## (smooth ellipsoid parts, pivot limbs) — adjusted down for a
## small, stooped elderly woman of about 1.52 m where the occupants
## stand 1.70: shoulders low, head forward, a grey bun, a cardigan
## over a dress, sensible shoes. The cane is in her right hand and
## it TAPS as she walks — a synthesised knock (no audio assets, the
## MeowAudio pattern), so the player hears her coming.

const HIP_Y := 0.80
const SHOULDER_Y := 1.22
const SHOULDER_X := 0.21
const WALK_SPEED := 0.8 ## cane pace: slow, and utterly relentless

var walk_speed := WALK_SPEED
var pose_mode := "idle" ## idle | walk | grab | offer | forget | reset | distraught
var speed_now := 0.0 ## planar speed last physics frame (anim + taps)

var _move_dir := Vector3.ZERO
var _model: Node3D
var _head_pivot: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _cane: Node3D
var _chocolate: Node3D
var _hold_point: Marker3D
var _phase := 0.0
var _time := 0.0
var _tap_step := 0
var _voice: AudioStreamPlayer3D
var _mats := {}
var _sphere: SphereMesh
var _rng := RandomNumberGenerator.new()

const SKIN := Color(0.88, 0.70, 0.56)
const HAIR := Color(0.82, 0.81, 0.79) ## grey, gone almost white
const CARDIGAN := Color(0.55, 0.49, 0.60) ## lavender-grey knit
const DRESS := Color(0.40, 0.36, 0.47)
const STOCKING := Color(0.76, 0.63, 0.52)
const SHOE := Color(0.16, 0.13, 0.12)
const CANE_WOOD := Color(0.36, 0.24, 0.13)
const CHOCOLATE := Color(0.23, 0.13, 0.07)


func _ready() -> void:
	_rng.randomize()
	_build_model()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.20
	cap.height = 1.50
	col.shape = cap
	col.position = Vector3(0, 0.75, 0)
	add_child(col)
	collision_layer = 4 # the occupants' layer: a person, not scenery
	collision_mask = 1
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "CaneTap"
	_voice.unit_size = 1.6
	_voice.max_distance = 20.0
	_voice.volume_db = -11.0
	_voice.stream = _tap_stream()
	add_child(_voice)


## The occupants' placement idiom (occupant.gd place_at).
func place_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO


## The brain steers through here; zero means stand still.
func set_move_dir(dir: Vector3) -> void:
	_move_dir = dir


func set_pose(mode: String) -> void:
	pose_mode = mode


func set_chocolate_visible(on: bool) -> void:
	if _chocolate != null:
		_chocolate.visible = on


## Where the offered chocolate is, in the world (the eat radius is
## measured from here).
func chocolate_point() -> Vector3:
	if _chocolate == null:
		return global_position
	return _chocolate.global_position


## Where a caught cat is held: up in front of her, at chest height.
func hold_point_global() -> Vector3:
	if _hold_point == null:
		return global_position + Vector3(0, 0.95, 0)
	return _hold_point.global_position


# --- model -----------------------------------------------------------------

func _mat(c: Color, rough := 0.92) -> StandardMaterial3D:
	if _mats.has(c):
		return _mats[c]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[c] = m
	return m


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color) -> MeshInstance3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 24
		_sphere.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func _taper(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	_model.rotation.x = 0.06 # the stoop starts here and never leaves
	add_child(_model)

	# Dress: a cone from the hips down, cardigan torso above it.
	_taper(_model, Vector3(0, 0.62, 0), 0.17, 0.31, 0.52, DRESS)
	_ell(_model, Vector3(0, 1.06, -0.015), Vector3(0.40, 0.42, 0.30), CARDIGAN)
	_ell(_model, Vector3(0, HIP_Y + 0.04, 0), Vector3(0.34, 0.20, 0.27), DRESS) # hip mass under the dress top

	# Legs on hip pivots (the gait swings these): stockings + shoes.
	for sx: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.09, HIP_Y, 0)
		_model.add_child(hip)
		_taper(hip, Vector3(0, -0.33, 0), 0.052, 0.038, 0.68, STOCKING)
		_ell(hip, Vector3(0, -0.70, -0.045), Vector3(0.085, 0.06, 0.21), SHOE)
		if sx < 0.0:
			_leg_l = hip
		else:
			_leg_r = hip

	# Arms on shoulder pivots: cardigan sleeves, skin hands. The
	# right arm (+X — she faces -Z) carries the cane.
	for sx: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(sx * SHOULDER_X, SHOULDER_Y, 0)
		_model.add_child(sh)
		_taper(sh, Vector3(0, -0.24, 0), 0.048, 0.038, 0.48, CARDIGAN)
		_ell(sh, Vector3(0, -0.50, 0), Vector3(0.07, 0.09, 0.07), SKIN)
		sh.rotation.x = -0.14 # arms hang a little forward — the stoop again
		if sx < 0.0:
			_arm_l = sh
		else:
			_arm_r = sh

	# Head on its pivot: low, forward, grey bun behind. The pivot
	# sits LOW so the skull nests into the cardigan's shoulder
	# curve (a floating head reads wrong instantly), with a short
	# neck column bridging the two.
	_taper(_model, Vector3(0, 1.21, -0.03), 0.052, 0.078, 0.16, SKIN) # neck
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0, 1.26, -0.05)
	_model.add_child(_head_pivot)
	_ell(_head_pivot, Vector3(0, 0.07, -0.01), Vector3(0.205, 0.225, 0.21), SKIN) # skull
	_ell(_head_pivot, Vector3(0, 0.10, 0.012), Vector3(0.225, 0.19, 0.225), HAIR) # hair cap — wider than the skull so a grey rim crowns it from the front too
	_ell(_head_pivot, Vector3(0, 0.155, 0.095), Vector3(0.10, 0.10, 0.10), HAIR) # the bun
	for sx: float in [-1.0, 1.0]:
		_ell(_head_pivot, Vector3(sx * 0.042, 0.075, -0.105), Vector3(0.026, 0.026, 0.02), Color(0.10, 0.09, 0.09)) # eyes

	# THE CANE: right side, shaft + curved handle (a flattened torus
	# arc reads as the crook). Animated in _process: plant, tap, lift.
	_cane = Node3D.new()
	_cane.position = Vector3(0.30, 0, -0.10)
	_model.add_child(_cane)
	_taper(_cane, Vector3(0, 0.46, 0), 0.016, 0.013, 0.92, CANE_WOOD)
	var crook := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.045
	tm.outer_radius = 0.075
	crook.mesh = tm
	crook.material_override = _mat(CANE_WOOD)
	crook.position = Vector3(-0.03, 0.94, 0)
	crook.rotation = Vector3(0, PI * 0.5, 0)
	_cane.add_child(crook)
	_ell(_cane, Vector3(0, 0.012, 0), Vector3(0.035, 0.024, 0.035), Color(0.08, 0.08, 0.08)) # rubber tip

	# The chocolate she offers: a little plate of chunks, hidden
	# until the offer pose (glenys_system drives visibility).
	_chocolate = Node3D.new()
	_chocolate.name = "Chocolate"
	_chocolate.position = Vector3(0.26, 0.72, -0.34)
	_chocolate.visible = false
	_model.add_child(_chocolate)
	_taper(_chocolate, Vector3(0, 0, 0), 0.085, 0.06, 0.018, Color(0.92, 0.90, 0.86))
	_ell(_chocolate, Vector3(-0.03, 0.03, -0.02), Vector3(0.075, 0.045, 0.06), CHOCOLATE)
	_ell(_chocolate, Vector3(0.035, 0.032, 0.015), Vector3(0.065, 0.05, 0.055), CHOCOLATE.darkened(0.15))
	_ell(_chocolate, Vector3(0.0, 0.055, -0.03), Vector3(0.055, 0.04, 0.05), CHOCOLATE.lightened(0.1))

	_hold_point = Marker3D.new()
	_hold_point.name = "HoldPoint"
	_hold_point.position = Vector3(0, 0.98, -0.42)
	add_child(_hold_point)


# --- physics + gait ----------------------------------------------------------

func _physics_process(delta: float) -> void:
	var want := Vector3.ZERO
	if _move_dir.length() > 0.05:
		want = _move_dir.normalized() * walk_speed
	velocity.x = want.x
	velocity.z = want.z
	if is_on_floor():
		velocity.y = -2.0 # the occupants' grounded stick
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	speed_now = Vector2(velocity.x, velocity.z).length()


func _process(delta: float) -> void:
	_time += delta
	var moving := speed_now > 0.08
	if moving:
		_phase += delta * speed_now * 7.0
		# Cane taps: one knock per plant (twice per gait cycle).
		var step := int(_phase / PI)
		if step != _tap_step:
			_tap_step = step
			if _voice != null and not _voice.playing:
				_voice.pitch_scale = _rng.randf_range(0.92, 1.08)
				_voice.play()
	# Gait: legs swing against each other; the cane side steps
	# shorter, the way a cane gait actually goes.
	var swing := sin(_phase) * (0.34 if moving else 0.0)
	if _leg_l != null:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, swing, 0.55)
	if _leg_r != null:
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -swing * 0.8, 0.55)
	# Bob + a whisper of sway.
	if _model != null:
		_model.position.y = (absf(sin(_phase)) * 0.016) if moving else 0.0
	# Cane cycle: plant ahead, bear down, lift — unless a pose owns it.
	if _cane != null and pose_mode != "grab":
		_cane.rotation.x = lerpf(_cane.rotation.x, -0.10 + (0.16 * sin(_phase - 0.7) if moving else 0.0), 0.5)
	# Arms + head by pose (targets eased toward, like the cat's poses).
	var arm_l_x := -0.14
	var arm_r_x := -0.14
	var head_y := 0.0
	var head_x := 0.05
	match pose_mode:
		"grab":
			arm_l_x = -1.05
			arm_r_x = -1.05
		"offer":
			arm_r_x = -0.92
			arm_l_x = -0.30
		"forget":
			head_y = sin(_time * 0.7) * 0.55
			head_x = 0.16
		"reset":
			arm_l_x = -0.55
			arm_r_x = -0.55
			head_x = 0.30
		"distraught":
			arm_l_x = -2.25
			arm_r_x = -2.25
			head_x = 0.34
	if _arm_l != null:
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_l_x, 1.0 - exp(-8.0 * delta))
	if _arm_r != null:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r_x, 1.0 - exp(-8.0 * delta))
	if _cane != null and pose_mode == "grab":
		_cane.rotation.x = lerpf(_cane.rotation.x, 0.85, 0.4) # the cane dangles, forgotten
	if _head_pivot != null:
		_head_pivot.rotation.y = lerpf(_head_pivot.rotation.y, head_y, 1.0 - exp(-4.0 * delta))
		_head_pivot.rotation.x = lerpf(_head_pivot.rotation.x, head_x, 1.0 - exp(-4.0 * delta))


# --- cane-tap synth (MeowAudio pattern: no assets, rendered in code) --------

static func _tap_stream() -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE * 0.07)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1963 # her graduation decade, give or take
	for i in n:
		var t := float(i) / float(RATE)
		var knock := rng.randf_range(-1.0, 1.0) * 0.55 * exp(-t * 70.0)
		var thock := sin(TAU * 300.0 * t) * 0.45 * exp(-t * 48.0)
		var v := clampf(knock + thock, -1.0, 1.0) * 0.8
		data.encode_s16(i * 2, int(v * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
