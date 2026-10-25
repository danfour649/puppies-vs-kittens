class_name PvKCat
extends CharacterBody3D
## The kit cat actor: a smooth-primitive procedural cat for Godot 4.7,
## built to GTA Fredericton's stray_cat construction idiom (unit ~1 m
## frame, forward -Z, Body group as child 0, legs parented to the root
## under hip pivots, species scale on the model root). See
## cat_kit/README.md for the GTA provenance and the port path.
##
## Characters (cat_species.json -> characters): `willie` (default) and
## `aggie`. Call set_character("aggie") right after new(), before
## add_child — the model is built in _ready from the character record.
## Colouring is each cat's own, from Daniel's photos of the real cats
## (reference/ in this folder): Willie is white with rich-orange tabby
## patches (cap, big saddle, ringed tail, faint darker striping);
## Aggie is a dark tortoiseshell — a seeded scatter of orange/cream
## mottle shells over a warm black-brown base.
##
## Animation is entirely code-driven pose math (idle breathing, gait,
## crouch, lounge flop, strike), in the spirit of wildlife.gd's
## _step()-driven actor transforms.

signal paw_swiped
signal health_changed(hp: float, max_hp: float)
signal fainted(cat: PvKCat)
signal hissed(cat: PvKCat)

const DATA_PATH := "res://cat_kit/cat_species.json"
const LEG_H := 0.35 # unit-space leg anchor height (GTA stray_cat leg_h)
const HISS_TIME := 1.5 # the startle lock (basement ghosts force this)
const INVULN_TIME := 0.8 # brief mercy window after any landed hit

# --- character identity / palette (from cat_species.json) -------------------
var character_id := "willie"
var species_name := "Willie"
var coat := Color(1, 1, 1)
var ginger := Color(0.780, 0.439, 0.125)
var ginger_dark := Color(0.592, 0.329, 0.090)
var mottle_orange := Color(0.690, 0.431, 0.173)
var mottle_cream := Color(0.749, 0.659, 0.478)
var nose_color := Color(0.851, 0.549, 0.478)
var eye_color := Color(0.541, 0.604, 0.231)
var inner_ear_color := Color(0.89, 0.65, 0.56)
var pattern := "bicolor"
var model_scale := 0.35
var mottle_cfg: Dictionary = {}

# --- build profile (unit-space diameters; the silhouette lives here) --------
var torso_dia := Vector3(0.44, 0.42, 0.95)
var chest_dia := Vector3(0.42, 0.40, 0.38)
var haunch_dia := Vector3(0.23, 0.34, 0.37)
var leg_len := 0.30
var leg_r_top := 0.066
var leg_r_bot := 0.050
var tail_k := 1.3

# --- game tuning (from cat_species.json) -------------------------------------
var walk_speed := 2.4
var stalk_speed := 1.2
var sprint_speed := 5.0
var strike_range := 0.55
var strike_cooldown := 0.38
var stamina_max := 100.0
var stamina_drain := 22.0
var stamina_regen := 14.0
var max_hp := 120.0
var jump_velocity := 6.0
## External move-speed multiplier (walk/stalk/sprint), default 1.0.
## Owned by the zone the cat is standing in — the attic sets 0.55 while
## a cat wades through insulation — and the owner resets it to 1.0 when
## the cat leaves. Composes with DuoSystem's walk_speed scaling.
var speed_multiplier := 1.0

# --- read-only state (the controller contract) -------------------------------
var anim_state := "idle"
var stamina := 100.0
var is_lounging := false
var hp := 120.0
var is_fainted := false

# --- structure verification handles (smoke test) ------------------------------
var mottle_count := 0
var stripe_count := 0

var _torso: MeshInstance3D
var _saddle_patch: MeshInstance3D
var _eyes: Array = []
var _mottles: Array = []
var _stripes: Array = []

# --- rig ----------------------------------------------------------------------
var _model: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _hips := {}
var _mats := {}
var _sphere: SphereMesh
var _cyls := {}

var _input_dir := Vector3.ZERO
var _input_sprint := false
var _input_stalk := false
var _phase := 0.0
var _time := 0.0
var _strike_t := -1.0
var _strike_cd := 0.0
var _swipe_fired := false
var _lounge_k := 0.0
var _invuln_t := 0.0
var _pounced := false
var _hiss_t := -1.0
var _hiss_k := 0.0
var _faint_k := 0.0
var _tail_segs: Array = [] # [MeshInstance3D, base diameter] — the hiss puff

static var _doc: Dictionary = {}
static var _doc_loaded := false


static func _species_doc() -> Dictionary:
	if not _doc_loaded:
		_doc_loaded = true
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				_doc = parsed
	return _doc


func set_character(id: String) -> void:
	character_id = id
	_apply_character()


func _init() -> void:
	_apply_character()


func _apply_character() -> void:
	var chars: Dictionary = _species_doc().get("characters", {})
	var c: Dictionary = chars.get(character_id, {})
	if c.is_empty():
		return
	species_name = String(c.get("name", species_name))
	model_scale = float(c.get("scale", model_scale))
	var pal: Dictionary = c.get("palette", {})
	pattern = String(pal.get("pattern", pattern))
	coat = _json_color(pal.get("coat", pal.get("base", [])), coat)
	ginger = _json_color(pal.get("ginger", []), ginger)
	ginger_dark = _json_color(pal.get("ginger_dark", []), ginger_dark)
	mottle_orange = _json_color(pal.get("mottle_orange", []), mottle_orange)
	mottle_cream = _json_color(pal.get("mottle_cream", []), mottle_cream)
	nose_color = _json_color(pal.get("nose", []), nose_color)
	eye_color = _json_color(pal.get("eye", []), eye_color)
	inner_ear_color = _json_color(pal.get("inner_ear", []), inner_ear_color)
	mottle_cfg = pal.get("mottle", {})
	var b: Dictionary = c.get("build", {})
	torso_dia = _json_vec3(b.get("torso_dia", []), torso_dia)
	chest_dia = _json_vec3(b.get("chest_dia", []), chest_dia)
	haunch_dia = _json_vec3(b.get("haunch_dia", []), haunch_dia)
	leg_len = float(b.get("leg_len", leg_len))
	leg_r_top = float(b.get("leg_r_top", leg_r_top))
	leg_r_bot = float(b.get("leg_r_bot", leg_r_bot))
	tail_k = float(b.get("tail_k", tail_k))
	var g: Dictionary = c.get("game", {})
	walk_speed = float(g.get("walk_speed", walk_speed))
	stalk_speed = float(g.get("stalk_speed", stalk_speed))
	sprint_speed = float(g.get("sprint_speed", sprint_speed))
	strike_range = float(g.get("strike_range", strike_range))
	strike_cooldown = float(g.get("strike_cooldown", strike_cooldown))
	stamina_max = float(g.get("stamina_max", stamina_max))
	stamina_drain = float(g.get("stamina_drain", stamina_drain))
	stamina_regen = float(g.get("stamina_regen", stamina_regen))
	max_hp = float(g.get("hp", max_hp))
	hp = max_hp
	jump_velocity = float(g.get("jump_velocity", jump_velocity))
	stamina = stamina_max


func _json_color(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


func _json_vec3(v: Variant, fallback: Vector3) -> Vector3:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 3:
		var a: Array = v
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


func _ready() -> void:
	_build_model()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.15
	cap.height = 0.46
	col.shape = cap
	col.position = Vector3(0, 0.23, 0)
	add_child(col)
	floor_snap_length = 0.2
	motion_mode = MOTION_MODE_GROUNDED


# --- model --------------------------------------------------------------------

func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


## One shared unit sphere (radius 0.5), scaled per part into smooth
## ellipsoids — the remodel's answer to the GTA box frame.
func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.95) -> MeshInstance3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 32
		_sphere.rings = 16
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _taper(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color) -> MeshInstance3D:
	var key := "%s|%s|%s" % [top_r, bot_r, h]
	if not _cyls.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = top_r
		cm.bottom_radius = bot_r
		cm.height = h
		cm.radial_segments = 16
		_cyls[key] = cm
	var mi := MeshInstance3D.new()
	mi.mesh = _cyls[key]
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
	_model.add_child(_body) # Body stays child 0 (GTA contract)

	# Torso mass: main ellipsoid + blended chest + haunches (coat/base).
	_torso = _ell(_body, Vector3(0, 0.55, 0.02), torso_dia, coat)
	_ell(_body, Vector3(0, 0.545, -0.30), chest_dia, coat)
	var hx := torso_dia.x * 0.22
	for sx: float in [-1.0, 1.0]:
		_ell(_body, Vector3(sx * hx, 0.565, 0.29), haunch_dia, coat)

	if pattern == "tortoiseshell":
		_build_tortie_body()
	else:
		_build_bicolor_body()
	_build_head()
	_build_legs()
	_build_tail()


## Willie's markings: a LARGE ginger saddle over the whole back and
## upper sides (photo truth), a small chest bib, and faint darker
## tabby striping inside the saddle.
func _build_bicolor_body() -> void:
	_saddle_patch = _ell(_body, Vector3(0, 0.612, 0.04), Vector3(0.468, 0.335, 0.82), ginger)
	_ell(_body, Vector3(0, 0.605, 0.335), Vector3(0.46, 0.31, 0.38), ginger)
	_ell(_body, Vector3(0, 0.60, -0.44), Vector3(0.15, 0.19, 0.10), ginger, Vector3(-0.35, 0, 0))
	# Back stripes: flattened darker shells lying across the saddle.
	for i in 6:
		var z := -0.22 + i * 0.115
		var yy := 0.775 - 0.16 * pow(absf(z - 0.05) / 0.30, 2.0)
		_stripe(_body, Vector3(0, yy, z), Vector3(0.40, 0.05, 0.08), Vector3(0.04 * (1 if i % 2 == 0 else -1), 0.05 * (1 if i % 3 == 0 else -1), 0.05 * (1 if i % 2 == 0 else -1)))
	# Flank stripes on the saddle's upper sides.
	for sx: float in [-1.0, 1.0]:
		for z in [-0.08, 0.10, 0.26]:
			_stripe(_body, Vector3(sx * 0.205, 0.66, z), Vector3(0.045, 0.17, 0.085), Vector3(0.10, 0, sx * 0.10))


func _stripe(parent: Node3D, pos: Vector3, dia: Vector3, rot: Vector3) -> void:
	_stripes.append(_ell(parent, pos, dia, ginger_dark, rot))
	stripe_count = _stripes.size()


## Aggie's coat: the dark base shows through a seeded scatter of
## orange/cream mottle shells, denser on the torso, plus her cream
## throat/chest. Deterministic — same seed, same cat, every build.
func _build_tortie_body() -> void:
	_ell(_body, Vector3(0, 0.585, -0.42), Vector3(0.13, 0.17, 0.09), mottle_cream, Vector3(-0.35, 0, 0))
	_ell(_body, Vector3(0.05, 0.63, -0.40), Vector3(0.09, 0.11, 0.07), mottle_orange, Vector3(-0.3, 0, 0))
	var rng := _mottle_rng()
	_scatter(_body, Vector3(0, 0.55, 0.02), torso_dia * 0.5, int(mottle_cfg.get("torso", 64)), rng, 0.04, 0.11)


func _mottle_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mottle_cfg.get("seed", 1))
	return rng


## Scatter `count` small flattened two-tone shells over an ellipsoid
## surface (center + radii in the parent's space). Every random draw
## comes from the caller's seeded RNG, so the whole cat is a pure
## function of the seed.
func _scatter(parent: Node3D, center: Vector3, radii: Vector3, count: int, rng: RandomNumberGenerator, smin: float, smax: float) -> void:
	var tones: Array = [mottle_orange, mottle_cream]
	for i in count:
		var theta := rng.randf() * TAU
		var y := lerpf(-0.7, 1.0, rng.randf()) # bias up: more mottle on top/sides
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var dir := Vector3(cos(theta) * r, y, sin(theta) * r)
		var pos := center + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z)
		var s := rng.randf_range(smin, smax)
		var tone: Color = tones[rng.randi() % tones.size()]
		var mi := _ell(parent, pos, Vector3(s, s * 0.38, s * rng.randf_range(0.7, 1.1)), tone, Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		_mottles.append(mi)
	mottle_count = _mottles.size()


func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, LEG_H + 0.38, -0.5)
	_body.add_child(_head)
	_ell(_head, Vector3(0, 0.03, -0.05), Vector3(0.30, 0.28, 0.29), coat) # skull
	_ell(_head, Vector3(0, -0.035, -0.155), Vector3(0.185, 0.135, 0.155), coat) # muzzle
	if pattern == "tortoiseshell":
		# Mostly dark face, orange mottling. Each scattered part
		# re-seeds (seed + part offset) so counts can change
		# independently without reshuffling the other parts.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(mottle_cfg.get("seed", 1)) + 101
		_scatter(_head, Vector3(0, 0.03, -0.05), Vector3(0.145, 0.135, 0.14), int(mottle_cfg.get("head", 12)), rng, 0.035, 0.08)
	else:
		# The cap: wraps the top of the head, around the ears, and
		# down the sides of the cheeks; the face blaze stays white.
		_ell(_head, Vector3(0, 0.092, -0.04), Vector3(0.315, 0.185, 0.30), ginger)
		for sx: float in [-1.0, 1.0]:
			_ell(_head, Vector3(sx * 0.117, 0.0, -0.05), Vector3(0.105, 0.175, 0.20), ginger, Vector3(0, -sx * 0.10, -sx * 0.12))
		_stripe(_head, Vector3(0, 0.205, -0.02), Vector3(0.17, 0.045, 0.06), Vector3(0, 0, 0.04))
		_stripe(_head, Vector3(0, 0.195, 0.06), Vector3(0.15, 0.04, 0.055), Vector3(0, 0, -0.03))
	# Ears: pinched spheres; Willie's sit inside his ginger cap,
	# Aggie's are her dark base. Pale inset on the front face.
	var ear_col := ginger if pattern != "tortoiseshell" else coat
	for sx: float in [-1.0, 1.0]:
		var ear := _ell(_head, Vector3(sx * 0.088, 0.155, -0.01), Vector3(0.085, 0.15, 0.05), ear_col, Vector3(0.06, 0, -sx * 0.14))
		ear.scale.z = 0.05
		_ell(_head, Vector3(sx * 0.088, 0.15, -0.032), Vector3(0.05, 0.09, 0.02), inner_ear_color)
	# Eyes: green-gold/hazel for both cats (photo truth).
	for sx: float in [-1.0, 1.0]:
		_eyes.append(_ell(_head, Vector3(sx * 0.067, 0.045, -0.178), Vector3(0.034, 0.034, 0.034), eye_color, Vector3.ZERO, 0.25))
	_ell(_head, Vector3(0, -0.018, -0.222), Vector3(0.042, 0.028, 0.026), nose_color, Vector3.ZERO, 0.5)


func _leg_key(sx: float, sz: float) -> String:
	return ("F" if sz < 0.0 else "B") + ("L" if sx < 0.0 else "R")


func _build_legs() -> void:
	var rng: RandomNumberGenerator = null
	if pattern == "tortoiseshell":
		rng = _mottle_rng()
		rng.seed = int(mottle_cfg.get("seed", 1)) + 202
	var per_leg := 0
	if pattern == "tortoiseshell":
		per_leg = int(mottle_cfg.get("legs", 8)) / 4
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.12, LEG_H, sz * 0.32)
			_model.add_child(hip)
			_hips[_leg_key(sx, sz)] = hip
			_ell(hip, Vector3.ZERO, Vector3(leg_r_top * 2.3, 0.13, leg_r_top * 2.3), coat)
			_taper(hip, Vector3(0, -(leg_len * 0.5 + 0.005), 0), leg_r_top, leg_r_bot, leg_len, coat)
			_ell(hip, Vector3(0, -(leg_len - 0.018), -0.016), Vector3(leg_r_top * 1.6, 0.06, leg_r_top * 2.0), coat)
			if rng != null and per_leg > 0:
				_scatter(hip, Vector3(0, -leg_len * 0.48, 0), Vector3(leg_r_top * 1.02, leg_len * 0.40, leg_r_top * 1.02), per_leg, rng, 0.03, 0.055)


func _build_tail() -> void:
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, LEG_H + 0.30, 0.42)
	_body.add_child(_tail)
	# [along, up, diameter] per segment, base to tip.
	var segs: Array = [
		[0.02, 0.0, 0.112], [0.07, 0.002, 0.108], [0.12, 0.008, 0.102],
		[0.17, 0.016, 0.096], [0.22, 0.027, 0.090], [0.265, 0.041, 0.082],
		[0.31, 0.057, 0.074], [0.355, 0.079, 0.066], [0.400, 0.114, 0.058],
	]
	var tail_cols: Array
	if pattern == "tortoiseshell":
		tail_cols = [coat, coat, coat, coat, coat, coat, coat, coat, coat]
	else: # Willie's tail: substantially ginger, ringed with the darker tone
		tail_cols = [coat, ginger, ginger_dark, ginger, ginger_dark, ginger, ginger_dark, ginger, ginger]
	var seg_pos: Array = []
	for i in segs.size():
		var s: Array = segs[i]
		var pos := Vector3(0, float(s[1]), float(s[0]))
		seg_pos.append([pos, float(s[2]) * tail_k])
		var seg_mi := _ell(_tail, pos, Vector3.ONE * float(s[2]) * tail_k, tail_cols[i])
		_tail_segs.append([seg_mi, float(s[2]) * tail_k])
	if pattern == "tortoiseshell":
		# Orange running through the dark tail (photo truth).
		var rng := _mottle_rng()
		rng.seed = int(mottle_cfg.get("seed", 1)) + 303
		var tones: Array = [mottle_orange, mottle_cream]
		for i in int(mottle_cfg.get("tail", 9)):
			var sp: Array = seg_pos[rng.randi() % seg_pos.size()]
			var c: Vector3 = sp[0]
			var rad: float = float(sp[1]) * 0.5
			var ang := rng.randf() * TAU
			var pos := c + Vector3(cos(ang) * rad, sin(ang) * rad, rng.randf_range(-0.02, 0.02))
			var s := rng.randf_range(0.035, 0.07)
			var tone: Color = tones[rng.randi() % tones.size()]
			_mottles.append(_ell(_tail, pos, Vector3(s, s * 0.45, s * 0.9), tone, Vector3(0, 0, rng.randf_range(-0.4, 0.4))))
		mottle_count = _mottles.size()



# --- controller -----------------------------------------------------------------

func set_move_input(dir: Vector3, sprint: bool, stalk: bool) -> void:
	_input_dir = dir
	_input_sprint = sprint
	_input_stalk = stalk


func strike() -> bool:
	if _strike_t >= 0.0 or _strike_cd > 0.0 or is_lounging or is_fainted or _hiss_t >= 0.0:
		return false
	_strike_t = 0.0
	_swipe_fired = false
	return true


func set_lounge(on: bool) -> void:
	is_lounging = on


func toggle_lounge() -> void:
	is_lounging = not is_lounging


func forward_dir() -> Vector3:
	var b := global_transform.basis
	var f := -b.z
	f.y = 0.0
	return f.normalized()


## Where the striking paw lands: front-right paw, half a strike ahead.
## Mid-pounce the paw reaches ~1.6x as far (see combat_director.gd).
func paw_point() -> Vector3:
	var r := strike_range * model_scale / 0.32
	if is_pouncing():
		r *= 1.6
	return global_position + forward_dir() * r


# --- combat / health / startle (the zone-facing cat API) ----------------------

## A real jump, for shelves and platforms. Standard platforming
## ledge in the Massey house is 0.5 m; this apex clears ~0.8 m.
func jump() -> bool:
	if not is_on_floor() or is_lounging or is_fainted or _hiss_t >= 0.0:
		return false
	velocity.y = jump_velocity
	return true


## Mid-jump only: the paw strike becomes a pounce — a forward lunge
## with the longer paw reach above. Returns true if it fired.
func pounce() -> bool:
	if is_on_floor() or _pounced or is_fainted:
		return false
	if not strike():
		return false
	_pounced = true
	velocity += forward_dir() * 4.2 + Vector3(0, 0.8, 0)
	return true


func is_pouncing() -> bool:
	return _pounced and not is_on_floor()


## Damage in, from enemies / cars / the world. `profile` is a
## CombatData profile: it may carry damage_frac (fraction of max HP
## — vehicle_hit) and launch (pop the cat up hard). Returns true if
## the hit landed (brief invulnerability swallows the rest).
func take_damage(amount: float, from_position: Vector3, profile: Dictionary = {}) -> bool:
	if is_fainted:
		return false
	if _invuln_t > 0.0 and not bool(profile.get("ignore_invuln", false)):
		return false
	var dmg := amount
	if profile.has("damage_frac"):
		dmg = max_hp * float(profile["damage_frac"])
	if dmg <= 0.0:
		return false
	hp = maxf(0.0, hp - dmg)
	_invuln_t = INVULN_TIME
	var away := global_position - from_position
	away.y = 0.0
	var kb := float(profile.get("knockback", 2.5))
	if away.length() > 0.01:
		velocity.x += away.normalized().x * kb
		velocity.z += away.normalized().z * kb
	if bool(profile.get("launch", false)):
		velocity.y = 7.5
	elif is_on_floor():
		velocity.y = maxf(velocity.y, 1.2)
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_faint()
	return true


## Partial heal — the lap-petting / fish-treat seam. The house
## occupants' lap state and the outside lane's treats call this;
## it only ever tops the cat up (and never un-faints him — a faint
## is the game's respawn flow, §4 of the zones doc).
func heal(amount: float) -> float:
	if is_fainted or amount <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)
	return hp - before


func heal_full() -> void:
	hp = max_hp
	is_fainted = false
	_invuln_t = 0.0
	set_lounge(false)
	health_changed.emit(hp, max_hp)


func _faint() -> void:
	is_fainted = true
	set_lounge(true) # the dramatic flop; the game handles the respawn
	fainted.emit(self)


## The startle state — basement ghosts force it, anything may call
## it. Full arched-back Halloween pose (spine up, tail puffed, head
## low), HISS_TIME of control lock, NO damage. Emits hissed (the
## audio hook). Returns false if it couldn't start.
func hiss() -> bool:
	if _hiss_t >= 0.0 or is_lounging or is_fainted:
		return false
	_hiss_t = 0.0
	hissed.emit(self)
	return true


func is_hissing() -> bool:
	return _hiss_t >= 0.0


# --- physics --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	if _invuln_t > 0.0:
		_invuln_t -= delta
	if _hiss_t >= 0.0:
		_hiss_t += delta
		if _hiss_t >= HISS_TIME:
			_hiss_t = -1.0
	if _strike_cd > 0.0:
		_strike_cd -= delta
	if _strike_t >= 0.0:
		_strike_t += delta
		if _strike_t >= 0.10 and not _swipe_fired:
			_swipe_fired = true
			paw_swiped.emit()
		if _strike_t >= 0.34:
			_strike_t = -1.0
			_strike_cd = strike_cooldown

	var want := Vector3.ZERO
	var speed := 0.0
	var moving := false
	if _input_dir.length() > 0.05 and not is_lounging and not is_fainted and _hiss_t < 0.0 and _strike_t < 0.0:
		moving = true
		var sprinting := _input_sprint and stamina > 1.0
		speed = (stalk_speed if _input_stalk else (sprint_speed if sprinting else walk_speed)) * speed_multiplier
		want = _input_dir.normalized() * speed
		if sprinting and not _input_stalk:
			stamina = maxf(0.0, stamina - stamina_drain * delta)
		var target_yaw := atan2(-_input_dir.x, -_input_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
	if not moving:
		stamina = minf(stamina_max, stamina + stamina_regen * delta)

	velocity.x = want.x
	velocity.z = want.z
	# Grounded stick only when not moving up — a fresh jump()
	# sets velocity.y > 0 between frames and must survive this.
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	if is_on_floor():
		_pounced = false

	if _strike_t >= 0.0:
		anim_state = "strike"
	elif _hiss_t >= 0.0:
		anim_state = "hiss"
	elif is_lounging:
		anim_state = "lounge"
	elif moving:
		anim_state = "stalk" if _input_stalk else ("sprint" if _input_sprint and stamina > 1.0 else "walk")
	else:
		anim_state = "idle"


# --- animation (poses are pure functions of state + time) ------------------------

func _process(delta: float) -> void:
	_hiss_k = move_toward(_hiss_k, 1.0 if _hiss_t >= 0.0 else 0.0, delta * (5.0 if _hiss_t >= 0.0 else 2.5))
	_faint_k = move_toward(_faint_k, 1.0 if is_fainted else 0.0, delta * 3.0)
	var spd := Vector2(velocity.x, velocity.z).length()
	if anim_state in ["walk", "stalk", "sprint"]:
		_phase += delta * (4.2 + spd * 1.9)
	_lounge_k = move_toward(_lounge_k, 1.0 if is_lounging else 0.0, delta * 2.2)

	# Body: gait bob / stalk crouch / lounge flop.
	var body_scale := Vector3.ONE
	var body_y := 0.0
	var tail_rot := Vector3(0, sin(_time * 1.7) * 0.08, 0)
	var head_rot := Vector3.ZERO
	match anim_state:
		"idle":
			body_scale.y = 1.0 + sin(_time * 2.1) * 0.025 # breathing
			head_rot.y = sin(_time * 0.43) * 0.38 # look-around
			head_rot.x = sin(_time * 0.31) * 0.06
		"walk", "sprint":
			body_y = absf(sin(_phase)) * (0.05 if anim_state == "walk" else 0.065)
		"stalk":
			body_scale.y = 0.84
			body_y = -0.04
			tail_rot.x = 0.42 # tail levels out behind
			head_rot.x = 0.12
		"strike":
			var t := _strike_t
			if t < 0.10: # windup: rock back
				body_y = -0.05 * (t / 0.10)
				head_rot.x = -0.10 * (t / 0.10)
			elif t < 0.20: # lunge
				var k := (t - 0.10) / 0.10
				body_y = lerpf(-0.05, 0.035, k)
				head_rot.x = lerpf(-0.10, 0.16, k)
			else: # recover
				var k := (t - 0.20) / 0.14
				body_y = lerpf(0.035, 0.0, k)
				head_rot.x = lerpf(0.16, 0.0, k)
		"lounge":
			pass
	if _lounge_k > 0.0:
		# Willow's flop numbers (wildlife.gd _spawn_river_cat): low and
		# long, tail wrapped — eased in by _lounge_k.
		body_scale = body_scale.lerp(Vector3(1.05, 0.7, 1.0), _lounge_k)
		tail_rot.y = lerpf(tail_rot.y, 0.85, _lounge_k)
		head_rot.x = lerpf(head_rot.x, 0.22, _lounge_k)
	if _hiss_k > 0.0:
		# The Halloween arch: spine arched up, head low, tail high.
		body_scale = body_scale * Vector3(1.0 + 0.03 * _hiss_k, 1.0 + 0.30 * _hiss_k, 1.0 - 0.04 * _hiss_k)
		body_y += 0.05 * _hiss_k
		head_rot.x = lerpf(head_rot.x, 0.34, _hiss_k)
		tail_rot.x = lerpf(tail_rot.x, -0.85, _hiss_k)
	_body.scale = body_scale
	_body.position.y = body_y * (1.0 - _lounge_k)
	_body.rotation.z = 0.85 * _faint_k # the faint flop rolls him over
	_head.rotation = head_rot
	_tail.rotation = tail_rot
	# Tail puff for the hiss (segments recorded at build time).
	for seg: Array in _tail_segs:
		(seg[0] as MeshInstance3D).scale = Vector3.ONE * float(seg[1]) * (1.0 + 0.75 * _hiss_k)
	# Invulnerability blink — never while fainted (he's a drama cat).
	if _model != null:
		_model.visible = (int(_time * 18.0) % 2 == 0) if (_invuln_t > 0.0 and not is_fainted) else true

	# Legs: diagonal pairs; tucked away in the lounge.
	var amp := 0.0
	if anim_state == "walk":
		amp = 0.55
	elif anim_state == "sprint":
		amp = 0.8
	elif anim_state == "stalk":
		amp = 0.3
	for key in _hips:
		var hip := _hips[key] as Node3D
		var splay := 0.0
		if _lounge_k > 0.0:
			splay = (0.5 if key.begins_with("F") else -0.35) * _lounge_k
			hip.rotation.x = lerpf(hip.rotation.x, splay, 0.5)
			continue
		var ph := _phase + (0.0 if key in ["FL", "BR"] else PI)
		hip.rotation.x = sin(ph) * amp if amp > 0.0 else lerpf(hip.rotation.x, 0.0, 0.3)
	# The strike slash: front-right leg whips through its arc.
	if anim_state == "strike" and _hips.has("FR"):
		var fr := _hips["FR"] as Node3D
		var t := _strike_t
		if t < 0.10:
			fr.rotation.x = lerpf(0.0, 0.7, t / 0.10) # paw raised back
		elif t < 0.22:
			fr.rotation.x = lerpf(0.7, -1.15, (t - 0.10) / 0.12) # the slash
		else:
			fr.rotation.x = lerpf(-1.15, 0.0, (t - 0.22) / 0.12)
