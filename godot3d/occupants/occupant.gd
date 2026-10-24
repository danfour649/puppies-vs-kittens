class_name MasseyOccupant
extends CharacterBody3D
## Occupants — a human resident of 255 Massey, in NPC mode.
##
## Construction mirrors GTA Fredericton's procedural humans:
## scripts/body_proportions.gd (segment layout on a 1.70 m total:
## HEAD_Y 1.565, SHOULDER_Y 1.38 / X 0.24, HIP_Y 0.88 / X 0.125,
## KNEE_Y 0.47, ANKLE_Y 0.10, UPPER_ARM 0.30, FORE_ARM 0.27,
## THIGH 0.41, SHIN 0.37) and scripts/npc/pedestrian.gd's
## _build_body idiom (head sphere + torso + pivot limbs), rebuilt
## here as smooth primitives in the PvK cat_kit style. Looks come
## from scripts/npc/folasade.gd (her skin/hair/gold + Ankara gown)
## and scripts/player_appearance.gd (Daniel's default swatches).
##
## Routines are station data: [{pos, yaw, action, dwell}] — walk to
## the station, then stand or sit for `dwell` seconds, loop. While
## seated the lap is live: a LapSpot marker the lap system pins the
## cat to. Standing is telegraphed: about_to_stand fires
## 0.8 s before the rise so the system can put the cat down first.

signal sat_down
signal about_to_stand
signal stood_up

const HIP_Y := 0.88
const HIP_X := 0.125
const SHOULDER_Y := 1.38
const SHOULDER_X := 0.24
const SEAT_DROP := 0.42 ## pelvis 0.88 -> ~0.46 seat height
const WALK_SPEED := 0.9
const STAND_TELEGRAPH := 0.8

var occupant_id := "daniel"
var display_name := "Daniel"
var walk_speed := WALK_SPEED
## Tests turn dwells down with this; the demo room leaves it at 1.
var dwell_scale := 1.0

var _look: Dictionary = {}
var _stations: Array = []
var _station_i := 0
var _state := "idle" ## walk | dwell | sit_down | seated | stand_telegraph | stand_up | idle
var _dwell_left := 0.0
var _moving := false
var _phase := 0.0
var _time := 0.0
var _seat_k := 0.0
var _pet_k := 0.0
var _petting := false
var _react_t := 0.0
var _react_dur := 0.45
var _react_kind := ""
var _react_side := 1.0
var _avoid_cat: Node3D = null

var _model: Node3D
var _head_pivot: Node3D
var _skull: MeshInstance3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _lap_spot: Marker3D
var _mats := {}
var _sphere: SphereMesh
var _capsule: CapsuleMesh


## look: {id, name, skin, hair, top, bottom, shoes (Color),
##        dress: bool, hair_long: bool, gold: bool, height: float}
## stations: Array of {pos: Vector3, yaw: float, action: String,
##        dwell: float}
func setup(look: Dictionary, stations: Array) -> void:
	_look = look
	occupant_id = String(look.get("id", "daniel"))
	display_name = String(look.get("name", "Daniel"))
	_stations = stations
	_build_model()
	_station_i = 0
	if _stations.size() > 0:
		_state = "walk"


func _ready() -> void:
	if _model == null and not _look.is_empty():
		_build_model()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.17
	cap.height = 1.66
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	collision_layer = 4
	collision_mask = 1
	# NOTE: no physics "lap platform" — an earlier build had a StaticBody3D
	# box on the thighs, but it overlapped this body's own capsule and
	# depenetration shoved the occupant around while seated. The lap system
	# pins the cat to the lap spot kinematically instead; that is enough.


# --- model -----------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	if _mats.has(c):
		return _mats[c]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	_mats[c] = m
	return m


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
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
	mi.scale = Vector3(dia.x * scl.x, dia.y * scl.y, dia.z * scl.z)
	parent.add_child(mi)
	return mi


func _caps(parent: Node3D, pos: Vector3, r: float, h: float, c: Color) -> MeshInstance3D:
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = h
	cap.radial_segments = 16
	cap.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = cap
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _limb(parent: Node3D, pivot_pos: Vector3, upper_len: float, upper_r: float, fore_len: float, fore_r: float, upper_c: Color, fore_c: Color, end_c: Color, end_box := false) -> Array:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	_caps(pivot, Vector3(0, -upper_len * 0.5, 0), upper_r, upper_len + upper_r * 1.4, upper_c)
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -upper_len, 0)
	pivot.add_child(elbow)
	_caps(elbow, Vector3(0, -fore_len * 0.5, 0), fore_r, fore_len + fore_r * 1.4, fore_c)
	if end_box:
		_box(elbow, Vector3(0, -fore_len - 0.035, -0.045), Vector3(0.095, 0.06, 0.25), end_c)
	else:
		_ell(elbow, Vector3(0, -fore_len - 0.03, 0), Vector3(0.075, 0.10, 0.085), end_c)
	return [pivot, elbow]


func _build_model() -> void:
	var skin: Color = _look.get("skin", Color(0.72, 0.52, 0.38))
	var hair: Color = _look.get("hair", Color(0.10, 0.09, 0.09))
	var top: Color = _look.get("top", Color(0.30, 0.36, 0.50))
	var bottom: Color = _look.get("bottom", Color(0.18, 0.18, 0.20))
	var shoes: Color = _look.get("shoes", Color(0.08, 0.08, 0.09))
	var dress := bool(_look.get("dress", false))
	var leg_c: Color = skin if dress else bottom

	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * float(_look.get("height", 1.0))
	add_child(_model)

	# Pelvis + torso.
	_ell(_model, Vector3(0, 0.92, 0), Vector3(0.33, 0.23, 0.26), bottom if not dress else top)
	var torso := _caps(_model, Vector3(0, 1.16, 0), 0.155, 0.68, top)
	torso.scale = Vector3(1.18, 1.0, 0.82)
	if dress:
		var skirt := CylinderMesh.new()
		skirt.top_radius = 0.175
		skirt.bottom_radius = 0.315
		skirt.height = 0.58
		skirt.radial_segments = 20
		var smi := MeshInstance3D.new()
		smi.mesh = skirt
		smi.material_override = _mat(_look.get("skirt", top))
		smi.position = Vector3(0, 0.66, 0)
		_model.add_child(smi)

	# Head on its neck pivot (GTA HEAD_Y 1.565, radius 0.115).
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0, 1.44, 0)
	_model.add_child(_head_pivot)
	_skull = _ell(_head_pivot, Vector3(0, 0.125, 0), Vector3(0.23, 0.242, 0.226), skin)
	_ell(_head_pivot, Vector3(0, 0.155, 0.028), Vector3(0.236, 0.245, 0.232), hair) # hair cap, swept back
	if bool(_look.get("hair_long", false)):
		_ell(_head_pivot, Vector3(0, -0.14, 0.088), Vector3(0.26, 0.52, 0.13), hair)
	_ell(_head_pivot, Vector3(-0.042, 0.135, -0.104), Vector3(0.024, 0.024, 0.02), Color(0.05, 0.04, 0.04))
	_ell(_head_pivot, Vector3(0.042, 0.135, -0.104), Vector3(0.024, 0.024, 0.02), Color(0.05, 0.04, 0.04))
	_ell(_head_pivot, Vector3(0, 0.10, -0.112), Vector3(0.032, 0.04, 0.03), skin)
	if bool(_look.get("gold", false)):
		var gold := Color(0.85, 0.65, 0.25)
		_ell(_head_pivot, Vector3(-0.118, 0.06, 0), Vector3(0.02, 0.028, 0.02), gold)
		_ell(_head_pivot, Vector3(0.118, 0.06, 0), Vector3(0.02, 0.028, 0.02), gold)
		_ell(_model, Vector3(0, 1.295, -0.148), Vector3(0.035, 0.045, 0.02), gold)

	# Arms: shoulder pivot -> upper -> elbow pivot -> forearm + hand.
	var arm_l := _limb(_model, Vector3(-SHOULDER_X, SHOULDER_Y, 0), 0.30, 0.048, 0.27, 0.042, top, skin, skin)
	var arm_r := _limb(_model, Vector3(SHOULDER_X, SHOULDER_Y, 0), 0.30, 0.048, 0.27, 0.042, top, skin, skin)
	_shoulder_l = arm_l[0]
	_elbow_l = arm_l[1]
	_shoulder_r = arm_r[0]
	_elbow_r = arm_r[1]
	# Legs: hip pivot -> thigh -> knee pivot -> shin + shoe.
	var leg_l := _limb(_model, Vector3(-HIP_X, HIP_Y, 0), 0.41, 0.072, 0.37, 0.056, leg_c, leg_c, shoes, true)
	var leg_r := _limb(_model, Vector3(HIP_X, HIP_Y, 0), 0.41, 0.072, 0.37, 0.056, leg_c, leg_c, shoes, true)
	_hip_l = leg_l[0]
	_knee_l = leg_l[1]
	_hip_r = leg_r[0]
	_knee_r = leg_r[1]

	_lap_spot = Marker3D.new()
	_lap_spot.name = "LapSpot"
	_lap_spot.position = Vector3(0, 1.00, -0.30)
	_model.add_child(_lap_spot)


# --- public queries ----------------------------------------------------------

func forward_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func right_dir() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	return r.normalized()


func is_walking() -> bool:
	return _state == "walk" and _moving


func is_seated() -> bool:
	return _state == "seated" and _seat_k > 0.95


func state_name() -> String:
	return _state


func lap_spot() -> Vector3:
	if _lap_spot != null:
		return _lap_spot.global_position
	return global_position + Vector3(0, 0.58, 0)


func ankle_pos(side: float) -> Vector3:
	return global_transform * Vector3(side * HIP_X, 0.12, 0)


func head_top_y() -> float:
	if _skull != null:
		return _skull.global_position.y + 0.125
	return global_position.y + 1.70


func last_reaction() -> String:
	return _react_kind


func set_avoid_cat(cat: Node3D) -> void:
	_avoid_cat = cat


func set_petting(on: bool) -> void:
	_petting = on


# --- reactions -----------------------------------------------------------------

func play_hop(side: float) -> void:
	_react_kind = "hop"
	_react_side = side
	_react_dur = 0.45
	_react_t = _react_dur


func play_stumble() -> void:
	_react_kind = "stumble"
	_react_dur = 0.9
	_react_t = _react_dur


func play_shoo() -> void:
	_react_kind = "shoo"
	_react_dur = 0.6
	_react_t = _react_dur


# --- test / integration seams ----------------------------------------------------

func place_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO


func set_routine(stations: Array) -> void:
	_stations = stations
	_station_i = 0
	_state = "walk" if stations.size() > 0 else "idle"


func go_station(i: int) -> void:
	if _stations.is_empty():
		return
	_station_i = clampi(i, 0, _stations.size() - 1)
	_state = "walk"


func end_dwell_now() -> void:
	match _state:
		"dwell":
			_advance_station()
		"seated":
			_begin_stand()
		"sit_down":
			_seat_k = 1.0
			_state = "seated"
			sat_down.emit()
			_dwell_left = _station_dwell()


# --- routine state machine ---------------------------------------------------------

func _station() -> Dictionary:
	if _stations.is_empty():
		return {}
	return _stations[_station_i]


func _station_dwell() -> float:
	return float((_station() as Dictionary).get("dwell", 4.0))


func _advance_station() -> void:
	if _stations.is_empty():
		_state = "idle"
		return
	_station_i = (_station_i + 1) % _stations.size()
	_state = "walk"


func _begin_stand() -> void:
	_state = "stand_telegraph"
	_dwell_left = STAND_TELEGRAPH
	about_to_stand.emit()


func _physics_process(delta: float) -> void:
	if _react_t > 0.0:
		_react_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -2.0
		move_and_slide()
		_moving = false
		return

	match _state:
		"walk":
			_step_walk(delta)
		"dwell":
			_moving = false
			velocity = Vector3(0, -2, 0)
			move_and_slide()
			_face_station_yaw(delta)
			_dwell_left -= delta * dwell_scale
			if _dwell_left <= 0.0:
				_advance_station()
		"sit_down":
			_moving = false
			velocity = Vector3(0, -2, 0)
			move_and_slide()
			_face_station_yaw(delta)
			_seat_k = move_toward(_seat_k, 1.0, delta * 2.0)
			if _seat_k >= 1.0:
				_state = "seated"
				_dwell_left = _station_dwell()
				sat_down.emit()
		"seated":
			_moving = false
			velocity = Vector3(0, -2, 0)
			move_and_slide()
			_dwell_left -= delta * dwell_scale
			if _dwell_left <= 0.0:
				_begin_stand()
		"stand_telegraph":
			_moving = false
			velocity = Vector3(0, -2, 0)
			move_and_slide()
			_dwell_left -= delta
			if _dwell_left <= 0.0:
				_state = "stand_up"
		"stand_up":
			_moving = false
			velocity = Vector3(0, -2, 0)
			move_and_slide()
			_seat_k = move_toward(_seat_k, 0.0, delta * 2.0)
			if _seat_k <= 0.0:
				stood_up.emit()
				_advance_station()
		_:
			_moving = false


func _step_walk(delta: float) -> void:
	var st := _station()
	if st.is_empty():
		_moving = false
		return
	var target: Vector3 = st.get("pos", Vector3.ZERO)
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.18:
		_moving = false
		velocity = Vector3(0, -2, 0)
		move_and_slide()
		if String(st.get("action", "stand")) == "sit":
			_state = "sit_down"
		else:
			_state = "dwell"
			_dwell_left = _station_dwell()
		return
	var dir := to.normalized()
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-6.0 * delta))
	var fwd := forward_dir()
	var vel := fwd * walk_speed * clampf(to.length(), 0.35, 1.0)
	# Polite sidestep: mostly step around a cat dead ahead. (The cat
	# scores for cutting it closer than this.)
	if _avoid_cat != null and is_instance_valid(_avoid_cat):
		var rel := _avoid_cat.global_position - global_position
		rel.y = 0.0
		var ahead := rel.dot(fwd)
		var lat := rel.dot(right_dir())
		if ahead > 0.0 and ahead < 0.65 and absf(lat) < 0.40:
			vel += right_dir() * 0.55 * (1.0 if lat <= 0.0 else -1.0)
	velocity.x = vel.x
	velocity.z = vel.z
	velocity.y = -2.0
	move_and_slide()
	_moving = true
	_phase += delta * (4.6 * walk_speed)


func _face_station_yaw(delta: float) -> void:
	var st := _station()
	if st.is_empty() or not st.has("yaw"):
		return
	rotation.y = lerp_angle(rotation.y, float(st.get("yaw", 0.0)), 1.0 - exp(-5.0 * delta))


# --- posing (pure functions of state + time, like the cat) ---------------------------

func _process(delta: float) -> void:
	_time += delta
	if _model == null:
		return
	_pet_k = move_toward(_pet_k, 1.0 if (_petting and is_seated()) else 0.0, delta * 3.0)

	var moving := _state == "walk" and _moving
	if not moving and _state != "walk":
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, 1.0 - exp(-8.0 * delta))

	# Seat drop + rest lean.
	var hop_y := 0.0
	var lean := -0.04 * _seat_k
	if _state == "stand_telegraph":
		lean = -0.16
	_model.position.y = -SEAT_DROP * _seat_k
	_model.rotation.x = lean
	_model.rotation.z = 0.0

	# Legs.
	var swing := 0.0
	var knee_l := 0.0
	var knee_r := 0.0
	if moving:
		swing = sin(_phase) * 0.55
		knee_l = maxf(0.0, sin(_phase - 2.2)) * 0.8
		knee_r = maxf(0.0, sin(_phase + PI - 2.2)) * 0.8
	var hip_l_x := lerpf(swing, 1.45, _seat_k)
	var hip_r_x := lerpf(-swing, 1.45, _seat_k)
	_hip_l.rotation.x = hip_l_x
	_hip_r.rotation.x = hip_r_x
	_knee_l.rotation.x = lerpf(-knee_l, -1.40, _seat_k)
	_knee_r.rotation.x = lerpf(-knee_r, -1.40, _seat_k)

	# Arms.
	var arm_l_x := 0.0
	var arm_r_x := 0.0
	var arm_l_z := 0.06
	var arm_r_z := -0.06
	var elb_l := -0.12
	var elb_r := -0.12
	if moving:
		arm_l_x = sin(_phase + PI) * 0.38
		arm_r_x = sin(_phase) * 0.38
	if _seat_k > 0.0:
		arm_l_x = lerpf(arm_l_x, 0.55, _seat_k)
		arm_r_x = lerpf(arm_r_x, 0.55, _seat_k)
		elb_l = lerpf(elb_l, -0.35, _seat_k)
		elb_r = lerpf(elb_r, -0.35, _seat_k)
	if _pet_k > 0.0:
		var stroke := sin(_time * 2.6)
		arm_r_x = lerpf(arm_r_x, 0.78 + stroke * 0.16, _pet_k)
		elb_r = lerpf(elb_r, -0.55 + sin(_time * 2.6 + 0.7) * 0.22, _pet_k)
	_shoulder_l.rotation = Vector3(arm_l_x, 0, arm_l_z)
	_shoulder_r.rotation = Vector3(arm_r_x, 0, arm_r_z)
	_elbow_l.rotation.x = elb_l
	_elbow_r.rotation.x = elb_r

	# Head: idle look-around, down at the cat while petting.
	_head_pivot.rotation.y = sin(_time * 0.33) * 0.22 * (1.0 - _pet_k)
	_head_pivot.rotation.x = lerpf(sin(_time * 0.27) * 0.05, -0.36, _pet_k)

	# Reactions overlay.
	if _react_t > 0.0:
		var k := 1.0 - _react_t / _react_dur # 0 -> 1 over the reaction
		match _react_kind:
			"hop":
				_model.position.y += sin(k * PI) * 0.15
				var shake := sin(k * 40.0) * 0.30 * (1.0 - k)
				if _react_side < 0.0:
					_knee_l.rotation.x += shake
				else:
					_knee_r.rotation.x += shake
				_shoulder_l.rotation.z = -0.55 * sin(k * PI)
				_shoulder_r.rotation.z = 0.55 * sin(k * PI)
			"stumble":
				_model.rotation.z = sin(k * 16.0) * 0.13 * (1.0 - k)
				_shoulder_l.rotation.x = k * TAU * 1.6
				_shoulder_r.rotation.x = k * TAU * 1.6 + PI
			"shoo":
				_shoulder_r.rotation.x = 0.95 + sin(k * 22.0) * 0.25
				_head_pivot.rotation.y = sin(k * 16.0) * 0.20
	elif _react_kind != "":
		_react_kind = ""
