class_name PvKEnemy
extends CharacterBody3D
## ENEMY BASE — the reusable vicious-animal actor for Willie and Aggie.
##
## Zone lanes CONFIGURE this, they don't fork it (see
## docs/massey-zones.md §3): rats, spiders, raccoons, squirrels,
## birds and dogs are all this actor with different numbers, a
## different colour/scale, and — where wanted — an overridden
## _build_visual().
##
## Brain: idle <-> wander around home; chase the player cat when it
## comes within detection_radius; attack as a LUNGE (damage lands on
## contact during the lunge, once per lunge, then a cooldown); flee
## when HP drops to flee_at_frac of max (0 = never flees).
##
## The player's paw finds enemies by itself (the foundation's paw
## sweep checks the "enemies" group on every paw_swiped), and death
## reports itself to the objectives registry. A zone lane's whole
## job is: new(), configure({...}), position, add_child.

signal died(enemy: PvKEnemy)
signal health_changed(enemy: PvKEnemy)

const GRAVITY := 22.0

# --- configuration (set via configure() before add_child, or edit) --------
var species_id := "critter"
var display_name := "Critter"
var max_hp := 30.0
var damage := 8.0 ## HP this enemy deals the cat per landed lunge
var wander_speed := 1.0
var chase_speed := 2.6
var lunge_speed := 7.0
var detection_radius := 6.0
var attack_range := 0.55
var attack_cooldown := 0.9
var flee_at_frac := 0.0
var flee_duration := 2.5
var wander_radius := 3.0
var body_color := Color(0.40, 0.35, 0.30)
var body_scale := 1.0

# --- state ------------------------------------------------------------------
var hp := 30.0
## state: idle | wander | chase | attack | flee | dead
var state := "idle"
var home := Vector3.ZERO

var visual: Node3D = null
var body_mat: StandardMaterial3D = null

var _target: Node3D = null
var _wander_point := Vector3.ZERO
var _state_t := 0.0
var _sense_t := 0.0
var _attack_cd := 0.0
var _lunge_t := -1.0
var _lunge_dir := Vector3.ZERO
var _lunge_hit_done := true
var _flee_lock := 0.0
## Unstick: straight-line steering wedges forever on a body parked
## dead ahead (slide projection cancels ~all motion when the approach
## is head-on). Accumulate near-zero progress while trying to move;
## on a wedge, sidestep around the blocker for a short burst.
var _stuck_t := 0.0
var _sidestep_t := 0.0
var _sidestep_sign := 1.0
var _flash_t := 0.0
var _kb := Vector3.ZERO ## knockback impulse, decays fast
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _col: CollisionShape3D = null


func configure(cfg: Dictionary) -> void:
	species_id = String(cfg.get("species_id", species_id))
	display_name = String(cfg.get("display_name", display_name))
	max_hp = float(cfg.get("max_hp", max_hp))
	hp = max_hp
	damage = float(cfg.get("damage", damage))
	wander_speed = float(cfg.get("wander_speed", wander_speed))
	chase_speed = float(cfg.get("chase_speed", chase_speed))
	lunge_speed = float(cfg.get("lunge_speed", lunge_speed))
	detection_radius = float(cfg.get("detection_radius", detection_radius))
	attack_range = float(cfg.get("attack_range", attack_range))
	attack_cooldown = float(cfg.get("attack_cooldown", attack_cooldown))
	flee_at_frac = float(cfg.get("flee_at_frac", flee_at_frac))
	flee_duration = float(cfg.get("flee_duration", flee_duration))
	wander_radius = float(cfg.get("wander_radius", wander_radius))
	body_color = cfg.get("color", body_color) as Color
	body_scale = float(cfg.get("scale", body_scale))


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	home = global_position
	hp = max_hp
	_build_visual()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.16 * body_scale
	shape.height = 0.44 * body_scale
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position = Vector3(0, 0.22 * body_scale, 0)
	add_child(_col)
	floor_snap_length = 0.15
	_wander_point = home
	_state_t = _rng.randf_range(0.3, 1.5)


## The default critter: ellipsoid body + head + eyes + a tail,
## smooth primitives in the kit idiom. Subclasses override to
## reskin — they must set `visual` and `body_mat` (the hit-flash
## target) and add their meshes under `visual`.
func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.95
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var dark := StandardMaterial3D.new()
	dark.albedo_color = body_color.darkened(0.35)
	dark.roughness = 0.95
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.08, 0.06, 0.05)
	eye.roughness = 0.3
	eye.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_part(Vector3(0, 0.30, 0.02), Vector3(0.34, 0.30, 0.52), body_mat)
	_part(Vector3(0, 0.38, -0.28), Vector3(0.22, 0.20, 0.22), body_mat)
	_part(Vector3(0, 0.30, 0.34), Vector3(0.09, 0.09, 0.30), dark) # tail
	for sx: float in [-1.0, 1.0]:
		_part(Vector3(sx * 0.055, 0.42, -0.375), Vector3(0.035, 0.035, 0.035), eye)
		_part(Vector3(sx * 0.07, 0.52, -0.30), Vector3(0.05, 0.09, 0.03), dark) # ears
	visual.scale = Vector3.ONE * body_scale


func _part(pos: Vector3, dia: Vector3, mat: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = dia
	visual.add_child(mi)
	return mi


# --- damage in / out ---------------------------------------------------------

## A paw (or anything) hits this enemy. Returns true if it connected.
func take_hit(dmg: float, from_position: Vector3) -> bool:
	if state == "dead" or dmg <= 0.0:
		return false
	hp = maxf(0.0, hp - dmg)
	_flash_t = 0.14
	var away := global_position - from_position
	away.y = 0.0
	if away.length() > 0.01:
		_kb += away.normalized() * 3.2
	_kb.y = 1.4
	health_changed.emit(self)
	if hp <= 0.0:
		_die()
	elif flee_at_frac > 0.0 and hp <= max_hp * flee_at_frac and state != "flee":
		state = "flee"
		_state_t = flee_duration
		_lunge_t = -1.0
	elif state == "idle" or state == "wander":
		state = "chase" # a hit wakes it up
	return true


func _die() -> void:
	state = "dead"
	died.emit(self)
	get_tree().call_group("objectives", "register_kill", species_id)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	# Fall over, then fade — the corpse never blocks the cats.
	var tw := create_tween()
	tw.tween_property(visual, "rotation:z", 1.45, 0.28)
	tw.parallel().tween_property(visual, "position:y", -0.06, 0.28)
	tw.tween_interval(0.35)
	tw.tween_property(body_mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(queue_free)


func is_alive() -> bool:
	return state != "dead"


# --- brain --------------------------------------------------------------------

func _sense() -> Node3D:
	var t := get_tree().get_first_node_in_group("player_cat") as Node3D
	if t == null or not is_instance_valid(t):
		return null
	if global_position.distance_to(t.global_position) > detection_radius:
		return null
	return t


func _physics_process(delta: float) -> void:
	_time += delta
	if state == "dead":
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		if body_mat != null:
			body_mat.emission_enabled = _flash_t > 0.0
			if _flash_t > 0.0:
				body_mat.emission = Color(1.0, 0.25, 0.15)
				body_mat.emission_energy_multiplier = clampf(_flash_t / 0.14, 0.0, 1.0) * 1.6
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _flee_lock > 0.0:
		_flee_lock -= delta
	_kb = _kb.move_toward(Vector3.ZERO, 14.0 * delta)

	var want := Vector3.ZERO
	match state:
		"idle":
			_state_t -= delta
			_sense_t -= delta
			if _sense_t <= 0.0:
				_sense_t = 0.15
				_target = _sense()
				if _target != null and _flee_lock <= 0.0:
					state = "chase"
			if _state_t <= 0.0 and state == "idle":
				_state_t = _rng.randf_range(2.0, 5.0)
				_wander_point = home + Vector3(
					_rng.randf_range(-wander_radius, wander_radius), 0.0,
					_rng.randf_range(-wander_radius, wander_radius))
				state = "wander"
		"wander":
			var to := _wander_point - global_position
			to.y = 0.0
			if to.length() < 0.3:
				state = "idle"
				_state_t = _rng.randf_range(1.0, 3.0)
			else:
				want = to.normalized() * wander_speed
			_sense_t -= delta
			if _sense_t <= 0.0:
				_sense_t = 0.15
				_target = _sense()
				if _target != null and _flee_lock <= 0.0:
					state = "chase"
		"chase":
			_target = _sense()
			if _target == null:
				state = "idle"
				_state_t = 0.6
			else:
				var to := _target.global_position - global_position
				to.y = 0.0
				var d := to.length()
				if d > attack_range:
					want = to.normalized() * chase_speed
				elif _attack_cd <= 0.0:
					state = "attack"
					_lunge_t = 0.26
					_lunge_hit_done = false
					_lunge_dir = to.normalized() if d > 0.01 else -global_transform.basis.z
					_attack_cd = attack_cooldown
		"attack":
			_lunge_t -= delta
			want = _lunge_dir * lunge_speed
			if not _lunge_hit_done and _target != null and is_instance_valid(_target):
				var d := global_position.distance_to(_target.global_position)
				if d < attack_range + 0.30:
					_lunge_hit_done = true
					if _target.has_method("take_damage"):
						_target.take_damage(damage, global_position, {})
			if _lunge_t <= 0.0:
				state = "chase"
		"flee":
			_state_t -= delta
			_target = _sense()
			if _target != null:
				var away := global_position - _target.global_position
				away.y = 0.0
				if away.length() > 0.01:
					want = away.normalized() * chase_speed * 1.1
			if _state_t <= 0.0:
				state = "idle"
				_state_t = 1.0
				_flee_lock = 2.0
				_target = null

	# Sidestep while wedged (see _stuck_t below): steer around the
	# blocker instead of pushing straight into it forever.
	if _sidestep_t > 0.0 and state != "attack":
		_sidestep_t -= delta
		want = want.rotated(Vector3.UP, _sidestep_sign * 1.1)
	velocity.x = want.x + _kb.x
	velocity.z = want.z + _kb.z
	velocity.y = _kb.y if _kb.y > 0.5 else (-1.0 if is_on_floor() else velocity.y - GRAVITY * delta)
	move_and_slide()
	# Wedge detection: states that steer somewhere (not the lunge,
	# which is ballistic) but make almost no real progress.
	if state == "chase" or state == "wander" or state == "flee":
		var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
		if want.length() > 0.5 and real < 0.2 * want.length():
			_stuck_t += delta
			if _stuck_t >= 0.30:
				_stuck_t = 0.0
				_sidestep_t = 0.45
				_sidestep_sign = -_sidestep_sign
		else:
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	if want.length() > 0.1:
		var yaw := atan2(-want.x, -want.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-10.0 * delta))
	if visual != null:
		var spd := Vector2(velocity.x, velocity.z).length()
		visual.position.y = absf(sin(_time * 9.0)) * 0.03 * clampf(spd / 2.0, 0.0, 1.0) if state != "dead" else visual.position.y
