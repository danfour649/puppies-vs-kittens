class_name PvKRat
extends CharacterBody3D
## A basement rat — the vicious pack animal of the Massey basement.
## Bigger, meaner cousin of the yard mouse (PvKMouse): same unit-frame
## box-built model idiom, but a real physics body so maze walls block
## it, and a pack brain instead of a flee brain:
##   idle/wander near its den -> chase the cat inside aggro_radius
##   -> a healthy rat ripostes (a short lunge) instead of giving
##   ground -> bite -> flee when alone at low HP.
## The Alpha (is_alpha) is cat-sized, hits harder, and wears an HP bar.
##
## Combat contract (shared with the zone controller):
##   take_hit(damage, from_position) — HP loss, red flash, knockback,
##     death flop at 0. Emits hp_changed / died.
##   bite(target, damage) — emitted when this rat bites the cat; the
##     zone routes it into the cat's HP (foundation lane owns cat HP;
##     the standalone zone tracks its own pool — see basement.gd).
## All tuning lives in the @export vars below (data, not magic numbers
## scattered through the brain).

signal bite(target: Node3D, damage: int)
signal died(rat: PvKRat)
signal hp_changed(rat: PvKRat)

@export var max_hp := 3
@export var bite_damage := 1
@export var chase_speed := 2.7
@export var wander_speed := 0.8
@export var flee_speed := 3.4
@export var aggro_radius := 4.5
@export var bite_range := 0.32
@export var bite_cooldown := 0.9
@export var pack_radius := 3.0 ## packmates inside this keep a hurt rat brave
@export var model_scale := 0.22 ## unit-frame scale (yard mice are 0.10)
@export var is_alpha := false
@export var active := true ## tests / the hub can freeze the brain

var hp: int
## idle, wander, chase, flee, dead — the name lives on the shared
## state machine. Combat transitions go through CreatureBrain.decide_rat.
var _fsm: CreatureFSM
var state: String:
	get:
		return _fsm.state if _fsm != null else "idle"
	set(value):
		if _fsm != null:
			_fsm.change_to(value)
var _startle_t := 0.0 ## set by startle() — a cat hiss freezes the rat
var target_cat: Node3D = null
var den := Vector3.ZERO
## A new object in the den. Empty unless a caller sets it — rats
## steer around it (neophobia). Mice, given the same object, would not.
var novel_pos := Vector3.ZERO
var novel_active := false
var _sense := CreaturePerception.new()

const COAT := Color(0.30, 0.26, 0.22)
const COAT_ALPHA := Color(0.20, 0.17, 0.15)
const EYE := Color(0.78, 0.14, 0.10)
const GRAVITY := 22.0

var _model: Node3D
var _body: Node3D
var _target := Vector3.ZERO
var _timer := 0.0
var _bite_cd := 0.0
var _flee_t := 0.0
var _phase := 0.0
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}
var _parts: Array = [] ## [MeshInstance3D, original Material] for the hit flash
var _flash_mat: StandardMaterial3D
var _bar: Node3D = null
var _bar_fg: MeshInstance3D = null


func _init() -> void:
	_fsm = CreatureFSM.new()
	for s: String in ["idle", "wander", "chase", "riposte", "flee", "dead"]:
		_fsm.add_state(s)
	_fsm.change_to("idle")


func _ready() -> void:
	hp = max_hp
	_rng.randomize()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1.0, 0.25, 0.18)
	_flash_mat.roughness = 0.6
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.09
	cap.height = 0.24
	col.shape = cap
	col.position = Vector3(0, 0.12, 0)
	add_child(col)
	_build_model()
	if is_alpha:
		_build_hp_bar()
	den = global_position
	_target = global_position


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
	_parts.append([mi, mi.material_override])
	return mi


func _coat() -> Color:
	return COAT_ALPHA if is_alpha else COAT


var _legs: Array = [] # REALISM PASS 1: [pivot, lx, lz] per leg
var _scurry_ph := 0.0 # REALISM PASS 1
var _tail_pivot: Node3D = null # REALISM PASS 1


func _build_model() -> void:
	var coat := _coat()
	var dark := coat.darkened(0.35)
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var leg_h := 0.35
	_box(_body, Vector3(0.38, 0.36, 0.95), Vector3(0, leg_h + 0.18, 0), coat)
	_box(_body, Vector3(0.30, 0.30, 0.34), Vector3(0, leg_h + 0.40, -0.58), coat)
	_box(_body, Vector3(0.13, 0.11, 0.16), Vector3(0, leg_h + 0.33, -0.80), dark) # snout
	for ex: float in [-0.09, 0.09]:
		_box(_body, Vector3(0.06, 0.10, 0.03), Vector3(ex, leg_h + 0.60, -0.52), dark) # ears
		_box(_body, Vector3(0.045, 0.045, 0.02), Vector3(ex * 0.72, leg_h + 0.44, -0.72), EYE) # eyes
	# REALISM PASS 1: the tail hangs from a base pivot so it can drag
	# and sway behind the scurry instead of riding as a fixed plank.
	_tail_pivot = Node3D.new()
	_tail_pivot.position = Vector3(0, leg_h + 0.12, 0.43)
	_body.add_child(_tail_pivot)
	_box(_tail_pivot, Vector3(0.035, 0.035, 0.70), Vector3(0, 0, 0.35), Color(0.62, 0.45, 0.42)) # tail
	if is_alpha:
		_box(_body, Vector3(0.40, 0.10, 0.70), Vector3(0, leg_h + 0.40, 0.05), coat.lightened(0.25)) # mane ridge
	for lx: float in [-0.13, 0.13]:
		for lz: float in [-0.34, 0.34]:
			# REALISM PASS 1: hip pivots for the scurry stride.
			var pivot := Node3D.new()
			pivot.position = Vector3(lx, leg_h, lz)
			_model.add_child(pivot)
			_box(pivot, Vector3(0.09, leg_h, 0.09), Vector3(0, -leg_h * 0.5, 0), dark)
			_legs.append([pivot, lx, lz])


func _build_hp_bar() -> void:
	_bar = Node3D.new()
	_bar.name = "HpBar"
	_bar.position = Vector3(0, 0.52, 0)
	add_child(_bar)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.05, 0.05)
	bg_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var fg_mat := StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.85, 0.20, 0.15)
	fg_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var bg := MeshInstance3D.new()
	var bgq := QuadMesh.new()
	bgq.size = Vector2(0.56, 0.085)
	bg.mesh = bgq
	bg.material_override = bg_mat
	_bar.add_child(bg)
	_bar_fg = MeshInstance3D.new()
	var fgq := QuadMesh.new()
	fgq.size = Vector2(0.52, 0.06)
	_bar_fg.mesh = fgq
	_bar_fg.material_override = fg_mat
	_bar.add_child(_bar_fg)
	_update_bar()


func _update_bar() -> void:
	if _bar_fg == null:
		return
	var frac := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	_bar_fg.scale.x = maxf(frac, 0.001)
	_bar_fg.position.x = -0.26 * (1.0 - frac)


func hp_fraction() -> float:
	return clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)


# --- combat contract ----------------------------------------------------------

func take_hit(damage: int, from_position: Vector3) -> void:
	if state == "dead":
		return
	hp -= damage
	hp_changed.emit(self)
	_update_bar()
	_flash()
	var away := global_position - from_position
	away.y = 0.0
	if away.length() > 0.01:
		velocity += away.normalized() * 2.6 + Vector3(0, 1.2, 0)
	if hp <= 0:
		_die()
	else:
		# Getting hit breaks a flee and brings the rat back at the cat —
		# unless it is alone and nearly dead (checked in the brain).
		if state != "flee":
			state = "chase"


func _flash() -> void:
	for pair: Array in _parts:
		(pair[0] as MeshInstance3D).material_override = _flash_mat
	var tw := create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(_unflash)


func _unflash() -> void:
	for pair: Array in _parts:
		(pair[0] as MeshInstance3D).material_override = pair[1]


func _die() -> void:
	state = "dead"
	hp = 0
	hp_changed.emit(self)
	_update_bar()
	if _bar != null:
		_bar.visible = false
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "rotation:z", PI * 0.5, 0.28)
	tw.parallel().tween_property(_model, "position:y", 0.02, 0.28)


func is_dead() -> bool:
	return state == "dead"


## A nearby cat hiss: the rat freezes, ears up, for `duration` seconds.
func startle(duration: float) -> void:
	_startle_t = maxf(_startle_t, duration)


# --- brain --------------------------------------------------------------------

func _packmates_nearby() -> int:
	var n := 0
	for other in get_tree().get_nodes_in_group("basement_rats"):
		if other == self or not (other is PvKRat):
			continue
		var r := other as PvKRat
		if not r.is_dead() and global_position.distance_to(r.global_position) <= pack_radius:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if state == "dead":
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _startle_t > 0.0:
		_startle_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_bite_cd = maxf(0.0, _bite_cd - delta)
	_timer -= delta
	var to_cat := Vector3.ZERO
	var dist := INF
	if target_cat != null and is_instance_valid(target_cat):
		to_cat = target_cat.global_position - global_position
		if absf(to_cat.y) > 0.6:
			to_cat = Vector3.ZERO # another floor: never aggro/bite through it
		else:
			to_cat.y = 0.0
			dist = to_cat.length()
			# Hearing is the aggro sense. The radius matches the old
			# distance check, and a cat just outside it must NOT look
			# like "no cat" (that would cancel a flee early).
			_sense.hearing_range = aggro_radius
			if not _sense.hears(global_position, target_cat.global_position, 1.0, aggro_radius):
				dist = aggro_radius

	# Pack combat — owned by the shared brain, same thresholds as before.
	var decision := CreatureBrain.decide_rat(state, hp, dist, _packmates_nearby(), aggro_radius, _flee_t, delta)
	state = String(decision["state"])
	_flee_t = float(decision["flee_t"])
	if bool(decision.get("set_timer", false)):
		_timer = float(decision["timer"])
	if bool(decision.get("fleeing", false)):
		var away := -to_cat.normalized() if to_cat.length() > 0.01 else Vector3(0, 0, 1)
		_drive(away, flee_speed, delta)
		move_and_slide()
		return
	if CreatureBrain.rat_riposte(state, hp, dist, _packmates_nearby(), bite_range):
		state = "riposte"

	match state:
		"riposte":
			# She meets him. Same bite as a chase — the difference is
			# she closes the last step instead of waiting to be reached.
			var reach := bite_range * 1.45
			if dist <= reach:
				velocity.x = 0.0
				velocity.z = 0.0
				if _bite_cd <= 0.0 and target_cat != null:
					_bite_cd = bite_cooldown * 0.75
					bite.emit(target_cat, bite_damage)
			elif to_cat.length() > 0.01:
				_drive(to_cat.normalized(), chase_speed * 1.35, delta)
		"chase":
			if dist <= bite_range:
				velocity.x = 0.0
				velocity.z = 0.0
				if _bite_cd <= 0.0 and target_cat != null:
					_bite_cd = bite_cooldown
					bite.emit(target_cat, bite_damage)
			else:
				_drive(to_cat.normalized(), chase_speed, delta)
		"idle":
			velocity.x = 0.0
			velocity.z = 0.0
			if _timer <= 0.0:
				state = "wander"
				var a := _rng.randf() * TAU
				_target = den + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.4, 2.0)
				if novel_active:
					_target = CreatureBrain.steer_neophobia(_target, global_position, novel_pos, CreatureProfiles.neophobia_of("rat"))
				_timer = 5.0
		"wander":
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.15 or _timer <= 0.0:
				state = "idle"
				_timer = _rng.randf_range(0.8, 2.6)
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				_drive(to.normalized(), wander_speed, delta)
	move_and_slide()


func _drive(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.05:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))


func _process(delta: float) -> void:
	if _body == null or state == "dead":
		return
	# Scurry bob, faster when chasing (PvKMouse idiom).
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.1:
		_phase += delta * (10.0 + spd * 6.0)
		_body.position.y = absf(sin(_phase)) * 0.10
	else:
		_body.position.y = 0.0
	# REALISM PASS 1: scurry — fast small diagonal strides, and the
	# tail dragging a lazy half-frequency S behind them.
	if spd > 0.1:
		_scurry_ph += delta * (16.0 + spd * 6.0)
	var samp := clampf(spd * 0.22, 0.0, 0.5)
	for lg: Array in _legs:
		var off := 0.0 if (float(lg[1]) < 0.0) == (float(lg[2]) < 0.0) else PI
		(lg[0] as Node3D).rotation.x = sin(_scurry_ph + off) * samp
	if _tail_pivot != null:
		_tail_pivot.rotation.y = sin(_scurry_ph * 0.5 - 0.8) * 0.22 * (1.0 if spd > 0.1 else 0.3)
