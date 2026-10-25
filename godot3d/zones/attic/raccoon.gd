class_name PvKRaccoon
extends CharacterBody3D
## A raccoon for the Willie and Aggie attic fight, built in the cat
## kit's smooth-primitive idiom (shared unit sphere scaled into
## ellipsoids, tapered-cylinder legs, segmented ringed tail, Body
## group as child 0, forward -Z, code-driven pose animation).
##
## Two roles from one builder — call set_role() right after new(),
## before add_child (same contract as PvKCat.set_character):
##   "mother" — the boss. ~Willie's size, big HP pool with a visible
##              HP bar, guards the nest: telegraphed paw-scrape ->
##              straight-line CHARGE (contact damage), close-range
##              swipe, staggers at 75/50/25% HP, enrages under 30%.
##   "kit"    — small, fast, fragile. Hovers near Mother, darts in
##              for a nip when the cat isn't facing it, scatters when
##              faced / when Mother staggers, flees to the eaves for
##              good when Mother falls.
##
## Combat contract (shared with the foundation lane's enemy base):
##   hp / hp_max, take_hit(damage, from_pos) with knockback + hit
##   flash, contact damage against `target` with a shared cooldown
##   (CONTACT_CD), death = flop (mother and kits), kits flee instead
##   of fighting on once Mother is down.
## Damage out: if `target` has take_hit(damage, from_pos) it is
## called; `damaged_target` is always emitted for HUD listeners
## (display only — listeners must not re-apply damage).

signal died(r: PvKRaccoon)
signal staggered(r: PvKRaccoon)
signal damaged_target(amount: int, from_pos: Vector3)

const CONTACT_CD := 1.0
const CONTACT_R := 0.62

# --- identity / tuning (set by set_role) --------------------------------------
var role := "mother"
var model_scale := 0.40
var hp_max := 12
var hp := 12
var walk_speed := 1.15 # mother approach; kits override
var charge_speed := 5.0
var contact_damage := 1

var state := "guard"
var enraged := false
var target: Node3D = null ## the cat (set by the zone)
var zone: Node = null ## optional: speed_factor_at(pos) slow zones
var home := Vector3.ZERO ## nest anchor (mother) / orbit centre
var mother: PvKRaccoon = null ## kits only
var refuges: Array = [] ## kits: eave hide points (set by the zone)

var hp_bar_fraction := 1.0 ## read by tests; drives the bar sprites

var _state_t := 0.0
var _time := 0.0
var _phase := 0.0
var _contact_cd := 0.0
var _charge_cd := 1.2 # first charge comes a little late
var _swipe_cd := 0.0
var _nip_cd := 2.0
var _charge_dir := Vector3.ZERO
var _swipe_hit_done := false
var _next_stagger := 0.75
var _kb := Vector3.ZERO
var _flop_k := 0.0
var _orbit_a := 0.0
var _scatter_to := Vector3.ZERO
var _refuge := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

# --- rig -----------------------------------------------------------------------
var _model: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _hips := {}
var _mats := {}
var _sphere: SphereMesh
var _cyls := {}
var _flash_parts: Array = [] # [MeshInstance3D, Material] pairs
var _flash_t := 0.0
var _flash_mat: StandardMaterial3D
var _bar_fg: Sprite3D
var _eyes: Array = []

const GREY := Color(0.46, 0.46, 0.48)
const GREY_DARK := Color(0.30, 0.30, 0.32)
const CREAM := Color(0.78, 0.75, 0.70)
const MASK := Color(0.07, 0.07, 0.08)
const SOCK := Color(0.16, 0.16, 0.17)

static var _bar_tex: Texture2D


func set_role(p_role: String) -> void:
	role = p_role
	if role == "kit":
		model_scale = 0.20
		hp_max = 2
		walk_speed = 1.7
		charge_speed = 3.8 # nip dart speed
		state = "hover"
	else:
		model_scale = 0.40
		hp_max = 12
		walk_speed = 1.15
		charge_speed = 5.0
		state = "guard"
	hp = hp_max


func _init() -> void:
	set_role("mother")


func set_target(t: Node3D) -> void:
	target = t


func forward_dir() -> Vector3:
	var b := global_transform.basis
	var f := -b.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


func _ready() -> void:
	_rng.randomize()
	_orbit_a = _rng.randf() * TAU
	_nip_cd = _rng.randf_range(1.2, 3.0)
	_build_model()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if role == "mother":
		cap.radius = 0.17
		cap.height = 0.52
		col.position = Vector3(0, 0.26, 0)
	else:
		cap.radius = 0.11
		cap.height = 0.34
		col.position = Vector3(0, 0.17, 0)
	col.shape = cap
	add_child(col)
	floor_snap_length = 0.15
	motion_mode = MOTION_MODE_GROUNDED
	home = global_position


# --- model (cat-kit idiom) ------------------------------------------------------

func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.95) -> MeshInstance3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 24
		_sphere.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	_flash_parts.append([mi, mi.material_override])
	return mi


func _taper(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color) -> MeshInstance3D:
	var key := "%s|%s|%s" % [top_r, bot_r, h]
	if not _cyls.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = top_r
		cm.bottom_radius = bot_r
		cm.height = h
		cm.radial_segments = 12
		_cyls[key] = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _cyls[key]
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	_flash_parts.append([mi, mi.material_override])
	return mi


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body) # Body stays child 0 (kit contract)

	# Torso: grey mass with a lighter belly and an arched rump.
	_ell(_body, Vector3(0, 0.56, 0.04), Vector3(0.54, 0.50, 0.92), GREY)
	_ell(_body, Vector3(0, 0.45, -0.12), Vector3(0.44, 0.36, 0.60), CREAM)
	_ell(_body, Vector3(0, 0.65, 0.30), Vector3(0.48, 0.42, 0.46), GREY)
	for sx: float in [-1.0, 1.0]:
		_ell(_body, Vector3(sx * 0.13, 0.52, 0.30), Vector3(0.24, 0.34, 0.38), GREY_DARK)

	_build_head()
	_build_legs()
	_build_tail()
	if role == "mother":
		_build_hp_bar()


func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.74, -0.50)
	_body.add_child(_head)
	_ell(_head, Vector3(0, 0.02, -0.02), Vector3(0.33, 0.31, 0.32), GREY) # skull
	for sx: float in [-1.0, 1.0]: # pale cheeks
		_ell(_head, Vector3(sx * 0.095, -0.055, -0.10), Vector3(0.17, 0.15, 0.17), CREAM)
	_ell(_head, Vector3(0, -0.075, -0.185), Vector3(0.16, 0.115, 0.17), CREAM) # muzzle
	_ell(_head, Vector3(0, -0.045, -0.275), Vector3(0.058, 0.042, 0.05), MASK, Vector3.ZERO, 0.35) # nose
	# THE MASK: a black band worn across the eyes — flattened, proud of
	# the skull, angled like a bandit's disguise.
	_ell(_head, Vector3(0, 0.045, -0.125), Vector3(0.355, 0.135, 0.225), MASK, Vector3(0.10, 0, 0))
	for sx: float in [-1.0, 1.0]:
		# eyes: glossy beads sitting IN the mask, with a glint
		_eyes.append(_ell(_head, Vector3(sx * 0.078, 0.05, -0.205), Vector3(0.040, 0.040, 0.030), Color(0.02, 0.02, 0.02), Vector3.ZERO, 0.2))
		_ell(_head, Vector3(sx * 0.078 - 0.012, 0.062, -0.222), Vector3(0.013, 0.013, 0.008), Color(0.95, 0.95, 0.95), Vector3.ZERO, 0.2)
		# pale brow patches above the mask
		_ell(_head, Vector3(sx * 0.088, 0.125, -0.125), Vector3(0.105, 0.045, 0.09), CREAM, Vector3(0.1, 0, -sx * 0.15))
		# ears: dark-rimmed rounded triangles (pinched spheres)
		var ear := _ell(_head, Vector3(sx * 0.108, 0.165, 0.01), Vector3(0.105, 0.125, 0.05), GREY_DARK, Vector3(0.05, 0, -sx * 0.12))
		ear.scale.z = 0.05
		_ell(_head, Vector3(sx * 0.108, 0.158, -0.016), Vector3(0.058, 0.072, 0.02), CREAM)


func _build_legs() -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var key := ("F" if sz < 0.0 else "B") + ("L" if sx < 0.0 else "R")
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.15, 0.34, sz * 0.30)
			_model.add_child(hip)
			_hips[key] = hip
			_ell(hip, Vector3.ZERO, Vector3(0.15, 0.13, 0.15), GREY_DARK)
			_taper(hip, Vector3(0, -0.13, 0), 0.052, 0.040, 0.26, SOCK)
			_ell(hip, Vector3(0, -0.265, -0.02), Vector3(0.085, 0.055, 0.115), MASK)


func _build_tail() -> void:
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.60, 0.44)
	_body.add_child(_tail)
	# Ringed tail: alternating grey / near-black bands, cat-kit style
	# overlapping segment chain, a touch thicker than a cat's.
	var segs: Array = [
		[0.02, 0.0, 0.135], [0.075, 0.004, 0.132], [0.13, 0.012, 0.126],
		[0.185, 0.024, 0.118], [0.24, 0.040, 0.108], [0.295, 0.062, 0.098],
		[0.35, 0.090, 0.086], [0.405, 0.126, 0.074], [0.46, 0.172, 0.062],
	]
	for i in segs.size():
		var s: Array = segs[i]
		var col := GREY if i % 2 == 0 else MASK
		_ell(_tail, Vector3(0, float(s[1]), float(s[0])), Vector3.ONE * float(s[2]), col)


func _build_hp_bar() -> void:
	if _bar_tex == null:
		var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1))
		_bar_tex = ImageTexture.create_from_image(img)
	var root := Node3D.new()
	root.name = "HpBar"
	root.position = Vector3(0, model_scale * 1.30, 0)
	add_child(root)
	var bg := Sprite3D.new()
	bg.texture = _bar_tex
	bg.pixel_size = 0.01
	bg.modulate = Color(0.22, 0.04, 0.04)
	root.add_child(bg)
	_bar_fg = Sprite3D.new()
	_bar_fg.texture = _bar_tex
	_bar_fg.pixel_size = 0.01
	_bar_fg.centered = false
	_bar_fg.position = Vector3(-0.16, -0.02, 0.0)
	_bar_fg.modulate = Color(0.35, 0.85, 0.35)
	_bar_fg.render_priority = 1
	root.add_child(_bar_fg)


# --- combat ----------------------------------------------------------------------

func take_hit(damage: int, from_pos: Vector3) -> void:
	if state == "dead" or state == "fled":
		return
	hp = maxi(0, hp - damage)
	hp_bar_fraction = float(hp) / float(hp_max)
	_flash()
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = -forward_dir()
	_kb += away.normalized() * (2.0 if role == "mother" else 5.0)
	if hp <= 0:
		_die()
		return
	if role == "mother":
		if not enraged and hp <= int(ceil(hp_max * 0.30)):
			_enrage()
		var frac := float(hp) / float(hp_max)
		if frac < _next_stagger:
			_next_stagger -= 0.25
			_enter("stagger")
			staggered.emit(self)
	else:
		scatter()


func _enrage() -> void:
	enraged = true
	walk_speed *= 1.35
	charge_speed *= 1.28
	var rage := _mat(Color(0.75, 0.12, 0.08), 0.25)
	for pair in _flash_parts:
		if (pair[0] as MeshInstance3D) in _eyes:
			pair[1] = rage # flash-restore returns the enraged eyes
	for e in _eyes:
		(e as MeshInstance3D).material_override = rage


func _die() -> void:
	_enter("dead")
	velocity = Vector3.ZERO
	died.emit(self)
	for ch in get_children():
		if ch is CollisionShape3D:
			(ch as CollisionShape3D).set_deferred("disabled", true)


func _flash() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.albedo_color = Color(1, 0.92, 0.85)
		_flash_mat.roughness = 0.6
	for pair in _flash_parts:
		(pair[0] as MeshInstance3D).material_override = _flash_mat
	_flash_t = 0.08


func _restore_flash() -> void:
	for pair in _flash_parts:
		(pair[0] as MeshInstance3D).material_override = pair[1]


func _damage_target(amount: int) -> void:
	if target == null:
		return
	_contact_cd = CONTACT_CD
	damaged_target.emit(amount, global_position)
	if target.has_method("take_hit"):
		target.take_hit(amount, global_position)


func _try_contact(amount: int, radius: float) -> bool:
	if target == null or _contact_cd > 0.0:
		return false
	if global_position.distance_to(target.global_position) <= radius:
		_damage_target(amount)
		return true
	return false


# --- family orders (called by the zone) -------------------------------------------

func scatter() -> void:
	if role != "kit" or state == "dead" or state == "fled" or state == "flee":
		return
	_scatter_to = _pick_refuge()
	_enter("scatter")


func flee_final() -> void:
	if role != "kit" or state == "dead" or state == "fled":
		return
	_refuge = _pick_refuge()
	_enter("flee")


func _pick_refuge() -> Vector3:
	if refuges.size() > 0:
		return refuges[_rng.randi() % refuges.size()]
	if target != null:
		var away := global_position - target.global_position
		away.y = 0.0
		return global_position + away.normalized() * 3.0
	return home


# --- brain -------------------------------------------------------------------------

func _enter(s: String) -> void:
	state = s
	_state_t = 0.0
	if s == "swipe":
		_swipe_hit_done = false


func _speed_factor() -> float:
	if zone != null and zone.has_method("speed_factor_at"):
		return float(zone.speed_factor_at(global_position))
	return 1.0


func _steer_velocity(to: Vector3, speed: float) -> Vector3:
	var d := to - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return Vector3.ZERO
	return d.normalized() * speed * _speed_factor()


func _face(pos: Vector3, delta: float, rate := 10.0) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var target_yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


func _target_dist() -> float:
	if target == null:
		return 999.0
	return global_position.distance_to(target.global_position)


func _cat_facing_me(max_deg := 65.0) -> bool:
	if target == null:
		return false
	var f: Vector3
	if target.has_method("forward_dir"):
		f = target.forward_dir()
	else:
		f = -target.global_transform.basis.z
		f.y = 0.0
		f = f.normalized()
	var to_me := global_position - target.global_position
	to_me.y = 0.0
	if to_me.length() < 0.01:
		return true
	return rad_to_deg(f.angle_to(to_me.normalized())) <= max_deg


func _physics_process(delta: float) -> void:
	_time += delta
	_state_t += delta
	if _contact_cd > 0.0:
		_contact_cd -= delta
	if _charge_cd > 0.0:
		_charge_cd -= delta
	if _swipe_cd > 0.0:
		_swipe_cd -= delta
	if _nip_cd > 0.0:
		_nip_cd -= delta

	var want := Vector3.ZERO
	if state != "dead" and state != "fled":
		if role == "mother":
			want = _mother_brain(delta)
		else:
			want = _kit_brain(delta)

	velocity.x = want.x + _kb.x
	velocity.z = want.z + _kb.z
	_kb = _kb.move_toward(Vector3.ZERO, delta * 14.0)
	velocity.y = -1.0 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()

	if state == "charge":
		# Hit a wall (or the cat): the rush is spent. Floor contact
		# doesn't count — only near-horizontal normals end the charge.
		for i in get_slide_collision_count():
			if absf(get_slide_collision(i).get_normal().y) < 0.5:
				_enter("recover")
				break


func _mother_brain(delta: float) -> Vector3:
	var dist := _target_dist()
	match state:
		"guard":
			if target == null:
				return Vector3.ZERO
			_face(target.global_position, delta)
			if dist > 5.2:
				# Drift back to the nest if dragged away.
				if global_position.distance_to(home) > 0.6:
					return _steer_velocity(home, walk_speed)
				return Vector3.ZERO
			if dist <= 0.95 and _swipe_cd <= 0.0:
				_enter("swipe")
			elif _charge_cd <= 0.0 and dist >= 1.6 and dist <= 4.4:
				_enter("telegraph")
			elif dist > 0.95:
				return _steer_velocity(target.global_position, walk_speed)
			return Vector3.ZERO
		"swipe":
			_face(target.global_position, delta, 14.0)
			if _state_t >= 0.12 and not _swipe_hit_done:
				_swipe_hit_done = true
				_try_contact(contact_damage, 1.05)
			if _state_t >= 0.34:
				_swipe_cd = 0.9
				_enter("guard")
			return Vector3.ZERO
		"telegraph":
			# Paw-scrape: planted, crouched, staring the cat down.
			if target != null:
				_face(target.global_position, delta, 6.0)
			var dur := 0.45 if enraged else 0.65
			if _state_t >= dur:
				if target != null:
					_charge_dir = target.global_position - global_position
					_charge_dir.y = 0.0
					_charge_dir = _charge_dir.normalized()
				_enter("charge")
			return Vector3.ZERO
		"charge":
			_try_contact(2, CONTACT_R + 0.08)
			if _state_t >= 0.85:
				_enter("recover")
			return _charge_dir * charge_speed * _speed_factor()
		"recover":
			if _state_t >= 0.55:
				_charge_cd = 2.1 if enraged else 3.4
				_enter("guard")
			return Vector3.ZERO
		"stagger":
			if _state_t >= 0.9:
				_enter("guard")
			return Vector3.ZERO
	return Vector3.ZERO


func _kit_brain(delta: float) -> Vector3:
	match state:
		"hover":
			# Cat checks come FIRST: a kit dragged far from Mother
			# still reacts to the cat in front of it.
			if target != null:
				# Faced at close range? Scatter. Cat not looking? Nip.
				if _target_dist() < 1.25 and _cat_facing_me():
					scatter()
					return Vector3.ZERO
				if _nip_cd <= 0.0 and _target_dist() <= 2.8 and not _cat_facing_me():
					_enter("nip")
					return Vector3.ZERO
			var anchor := home
			if mother != null and is_instance_valid(mother):
				_orbit_a += delta * 0.5
				anchor = mother.global_position + Vector3(cos(_orbit_a), 0, sin(_orbit_a)) * 0.85
			if global_position.distance_to(anchor) > 0.45:
				_face(anchor, delta)
				return _steer_velocity(anchor, walk_speed)
			if target != null:
				_face(target.global_position, delta, 4.0)
			return Vector3.ZERO
		"nip":
			if target == null:
				_enter("hover")
				return Vector3.ZERO
			_face(target.global_position, delta, 14.0)
			if _target_dist() <= 0.52:
				_try_contact(contact_damage, 0.55)
				_enter("retreat")
				return Vector3.ZERO
			if _cat_facing_me() and _target_dist() > 0.7:
				scatter()
				return Vector3.ZERO
			if _state_t > 1.4:
				_enter("retreat")
				return Vector3.ZERO
			return _steer_velocity(target.global_position, charge_speed)
		"retreat":
			var anchor := home
			if mother != null and is_instance_valid(mother):
				anchor = mother.global_position
			_face(anchor, delta)
			if global_position.distance_to(anchor) < 0.5 or _state_t > 1.6:
				_nip_cd = _rng.randf_range(2.5, 4.5)
				_enter("hover")
				return Vector3.ZERO
			return _steer_velocity(anchor, charge_speed * 0.9)
		"scatter":
			_face(_scatter_to, delta, 14.0)
			if global_position.distance_to(_scatter_to) < 0.35 or _state_t > 1.3:
				_enter("cower")
				return Vector3.ZERO
			return _steer_velocity(_scatter_to, 4.4)
		"cower":
			if _state_t >= 0.9:
				if mother != null and is_instance_valid(mother) and mother.state == "dead":
					flee_final()
				else:
					_enter("hover")
			return Vector3.ZERO
		"flee":
			_face(_refuge, delta, 14.0)
			if global_position.distance_to(_refuge) < 0.35 or _state_t > 4.0:
				_enter("fled")
				velocity = Vector3.ZERO
				return Vector3.ZERO
			return _steer_velocity(_refuge, 4.4)
	return Vector3.ZERO


# --- poses (code animation, cat-kit style) ------------------------------------------

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_restore_flash()
	if _bar_fg != null:
		_bar_fg.scale.x = maxf(hp_bar_fraction, 0.0)
		_bar_fg.modulate = Color(0.9, 0.25, 0.2) if hp_bar_fraction < 0.3 else Color(0.35, 0.85, 0.35)

	var spd := Vector2(velocity.x, velocity.z).length()
	var moving := spd > 0.25 and state != "dead"
	if moving:
		_phase += delta * (5.0 + spd * 2.2)
	_flop_k = move_toward(_flop_k, 1.0 if state == "dead" else 0.0, delta * 3.0)

	var body_scale := Vector3.ONE
	var body_y := 0.0
	var body_pitch := 0.0
	var head_pitch := 0.0
	var tail_lift := 0.0
	match state:
		"guard", "hover", "cower":
			body_scale.y = 1.0 + sin(_time * 2.0) * 0.02
			if state == "cower":
				body_scale.y *= 0.82
		"telegraph":
			body_scale.y = 0.86
			body_y = -0.05
			body_pitch = 0.14
			head_pitch = 0.30
			# the scrape: front-right leg drags back, fast
			if _hips.has("FR"):
				(_hips["FR"] as Node3D).rotation.x = 0.55 + sin(_time * 26.0) * 0.30
		"charge", "nip", "scatter", "flee":
			body_pitch = -0.07
			head_pitch = -0.05
			tail_lift = 0.35
		"stagger":
			_body.rotation.z = sin(_state_t * 24.0) * 0.13 * maxf(0.0, 1.0 - _state_t / 0.9)
			head_pitch = 0.35
		"swipe":
			if _state_t < 0.14:
				body_pitch = lerpf(0.0, -0.22, _state_t / 0.14)
			else:
				body_pitch = lerpf(-0.22, 0.0, minf(1.0, (_state_t - 0.14) / 0.2))
			if _hips.has("FR"):
				(_hips["FR"] as Node3D).rotation.x = -1.0 if _state_t >= 0.10 and _state_t < 0.26 else 0.0
	# REALISM PASS 1: the waddle — a raccoon's whole body rolls side
	# to side over its stride, with a little bounce on top.
	var waddle := sin(_phase) * 0.085 if moving else 0.0
	if moving and state != "dead":
		body_y += absf(sin(_phase)) * 0.02
	if state != "stagger":
		_body.rotation.z = lerpf(_body.rotation.z, 1.85, _flop_k) if state == "dead" else waddle
	if state == "dead":
		body_y = -0.10 * _flop_k
	_body.scale = body_scale
	_body.position.y = body_y
	_body.rotation.x = body_pitch
	_head.rotation.x = head_pitch
	_tail.rotation.x = -tail_lift

	var amp := 0.0
	if moving:
		amp = 0.85 if state in ["charge", "nip", "scatter", "flee"] else 0.5
	for key in _hips:
		if state == "telegraph" and key == "FR":
			continue
		if state == "swipe" and key == "FR":
			continue
		var hip := _hips[key] as Node3D
		if state == "dead":
			hip.rotation.x = lerpf(hip.rotation.x, 0.45, _flop_k)
			continue
		var ph := _phase + (0.0 if key in ["FL", "BR"] else PI)
		hip.rotation.x = sin(ph) * amp if amp > 0.0 else lerpf(hip.rotation.x, 0.0, 0.3)
