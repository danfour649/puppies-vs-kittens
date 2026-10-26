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
## Colouring is each cat's own, per Daniel's ruled spec (2026-10-25;
## see cat_kit/README.md): Willie is white with #E8AF54 ginger tabby
## patches (cap, big saddle, white tail with a ginger underside,
## faint darker striping) and dark eyes; Aggie is a dark tortoiseshell —
## orange/cream mottling baked into her coat texture over a warm
## black-brown base (pass 3: pure texture, no scatter shells).
##
## Animation is entirely code-driven pose math (idle breathing, gait,
## crouch, lounge flop, strike), in the spirit of wildlife.gd's
## _step()-driven actor transforms.

signal paw_swiped
signal health_changed(hp: float, max_hp: float)
signal fainted(cat: PvKCat)
signal hissed(cat: PvKCat)
signal poisoned(cat: PvKCat, source: String)

const DATA_PATH := "res://cat_kit/cat_species.json"
const SculptLib := preload("res://cat_kit/cat_sculpt.gd")
const LEG_H := 0.35 # unit-space leg anchor height (GTA stray_cat leg_h)
const HISS_TIME := 1.5 # the startle lock (basement ghosts force this)
const INVULN_TIME := 0.8 # brief mercy window after any landed hit

# --- character identity / palette (from cat_species.json) -------------------
var character_id := "willie"
var species_name := "Willie"
var coat := Color(1, 1, 1)
var ginger := Color(0.9098, 0.6863, 0.3294) # #E8AF54 — Daniel's ruled ginger (2026-10-25)
var ginger_dark := Color(0.682, 0.515, 0.237) # #AE833C — derived from #E8AF54 (x0.75, x0.75, x0.72)
var mottle_orange := Color(0.690, 0.431, 0.173)
var mottle_cream := Color(0.749, 0.659, 0.478)
var nose_color := Color(0.851, 0.549, 0.478)
var eye_color := Color(0.10, 0.08, 0.07) # dark — Willie's ruled eye colour
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
## An ethology overlay (chatter, wiggle, loaf, …). CatSculpt blends a
## clip of this name when the rig has one, and does nothing when it
## does not. Gameplay never depends on the clip being present.
var manner := ""
var manner_k := 0.0
## Seconds into the manner. Negative follows the wall clock.
var manner_phase := -1.0
## Manner names whose clip is actually on this rig. The pose
## fallback stays quiet for those and plays for the rest.
var manner_clips: Dictionary = {}
var stamina := 100.0
var is_lounging := false
## HEAT: the courtship pose blend (Aggie's solicitation -- a rocking
## roll, front dipped, tail swung aside) and a performed act pose
## ("groom" -- Willie's pointed self-grooming). Poses are garnish on
## the state machine: they compose in _process like the hiss arch.
var courtship_k := 0.0
var courtship_target := 0.0
var act_pose := ""
var act_pose_k := 0.0
var _roll_phase := 0.0
var hp := 120.0
var is_fainted := false
var is_poisoned := false ## GLENYS/POISON: the run-ending state (eat_poison)
var is_held := false ## GLENYS: caught — no movement, no strikes, no harm

# --- structure verification handles (smoke test) ------------------------------
## PASS 3: Aggie's mottle lives in her baked coat texture; this is the
## texture's pattern coverage in permille (see _bake_tortie_texture).
var mottle_count := 0
var stripe_count := 0

var _torso: MeshInstance3D
var _saddle_patch: MeshInstance3D
var _eyes: Array = []
var _ears: Array = [] # [MeshInstance3D, side, base_rotation] — realism pass
var _inner_ears: Array = []
var _pupils: Array = []
var fur_shells := 0
var whisker_count := 0
## Blend-tree weights the pose layer already mixes. walk+trot+bound = 1 while moving.
var gait_walk := 1.0
var gait_trot := 0.0
var gait_bound := 0.0
var land_amount := 0.0
var pounce_amount := 0.0
## Jaw clip blend. play_meow() sets it; the sculpt tree eases it back.
var meow_k := 0.0
var _sculpt = null
var _tail_base: Array = [] # rest position per tail segment — realism pass
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
var _lunge := Vector3.ZERO
var _hiss_t := -1.0
var _hiss_k := 0.0
var _faint_k := 0.0
var _tail_segs: Array = [] # [MeshInstance3D, base diameter] — the hiss puff
var _tail_underside: Array = [] # Willie's ginger tail-underside shells (ruled spec)

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
	var voice := CatVoice.new()
	voice.name = "CatVoice"
	add_child(voice)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var fit := model_scale / 0.35
	cap.radius = 0.15 * fit
	cap.height = maxf(0.46 * fit, cap.radius * 2.0 + 0.04)
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
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


# --- baked coat textures (REALISM PASS 1) ------------------------------------
# Flat colour + hard-edged shells read as "speckles on a cat". Baking
# the pattern into the big shells' albedo puts soft colour IN the fur;
# the shells stay on top as deeper accents. Everything is a pure
# function of the character's mottle seed — same seed, same coat.
# albedo_color stays the exact palette colour (the texture carries
# only near-1.0 variation around it), so the data-level palette
# contract the smoke test asserts is untouched.

var _coat_mat: Material = null
var _coat_part_mats: Dictionary = {}
var _saddle_mat: Material = null

## Baked tortie fields, shared by every cat of the same seed in this
## process: "seed:part offset:size" -> [ImageTexture, coverage in
## permille]. Same seed, same coat — sharing the field IS the
## determinism contract, and it keeps a second Aggie from rebaking.
static var _coat_bake_cache: Dictionary = {}


## The tortie's coat material for one body part ("body" is the big
## torso/chest/haunch shells and the default; head/legs/tail get
## their own seed offsets so the pattern never repeats part-to-part).
func _coat_material(part := "body") -> Material:
	if pattern != "tortoiseshell":
		return null
	if part == "body":
		if _coat_mat == null:
			_coat_mat = _make_coat_material(0, 384)
		return _coat_mat
	if not _coat_part_mats.has(part):
		var off := int({"head": 104729, "legs": 209759, "tail": 314573}.get(part, 17))
		_coat_part_mats[part] = _make_coat_material(off, 256)
	return _coat_part_mats[part]


func _make_coat_material(seed_off: int, size: int) -> StandardMaterial3D:
	var key := "%d:%d:%d" % [int(mottle_cfg.get("seed", 1)), seed_off, size]
	if not _coat_bake_cache.has(key):
		_coat_bake_cache[key] = _bake_tortie_texture(coat, [mottle_orange, mottle_cream, coat.lightened(0.16), coat.darkened(0.25)], seed_off, size)
	var baked: Array = _coat_bake_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = coat
	m.roughness = 0.95
	m.albedo_texture = baked[0]
	if seed_off == 0:
		mottle_count = int(baked[1])
	return m


func _saddle_material() -> Material:
	if _saddle_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = ginger
		m.roughness = 0.95
		m.albedo_texture = _bake_coat_texture(ginger, [ginger_dark, ginger_dark.lightened(0.12), ginger.lightened(0.10)], 909)
		_saddle_mat = m
	return _saddle_mat


## A soft-blob colour field over `base`: seeded splats with quadratic
## falloff, drawn at wrapped x so the sphere seam never shows a cut,
## plus per-pixel fur noise. Tones are applied as MULTIPLIERS around
## 1.0 (tone/base per channel), keeping albedo_color the palette truth.
func _bake_coat_texture(base: Color, tones: Array, seed_off: int, blobs := 90) -> ImageTexture:
	var size := 192
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mottle_cfg.get("seed", 1)) + seed_off
	for i in blobs:
		var tone: Color = tones[rng.randi() % tones.size()]
		var mult := Color(
			clampf(tone.r / maxf(base.r, 0.02), 0.55, 1.5),
			clampf(tone.g / maxf(base.g, 0.02), 0.55, 1.5),
			clampf(tone.b / maxf(base.b, 0.02), 0.55, 1.5))
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var rad := rng.randi_range(7, 30)
		var strength := rng.randf_range(0.35, 0.8)
		for ox: int in [-size, 0, size]:
			_splat(img, cx + ox, cy, rad, mult, strength, size)
	for i in 2400:
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		var n := rng.randf_range(0.94, 1.06)
		var px: Color = img.get_pixel(x, y)
		img.set_pixel(x, y, Color(px.r * n, px.g * n, px.b * n))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- baked tortie texture (REALISM PASS 3) -----------------------------------
# Pass 2 baked three layers into a multiplier field stored in an
# 8-bit image — and 8 bits CLAMP at 1.0, so against Aggie's dark
# base (#241C17) every multiplier above 1.0 was thrown away: the
# bake could only suppress blue a little, and the most-orange texel
# it could render was (0.141, 0.110, 0.047) — dark brown. Every
# scrap of visible orange/cream came from the 95 scatter shells,
# which is exactly why they still read as stuck-on patches (lane-5
# pixel probe, 2026-10-25 — pass 2's own ceiling, root-caused).
# Pass 3 retires the shells and makes the texture the whole coat:
#   1) compose the pattern in ABSOLUTE colour space over the base
#      (pass 2's three layers — broad blotches with satellites, mid
#      marbling, fine speckle — blended TOWARD the true palette
#      tones, so patch centres genuinely reach #B06E2C / #BFA87A);
#   2) ship it as a multiplier field in a FLOAT image, where the
#      ratios a dark base needs (up to ~6x) survive storage.
# albedo_color stays the exact palette base, so the data-level
# palette contract (smoke, test_anim) is untouched — and the field
# preserves hue by construction: multiplier = tone / base renders
# the tone exactly. A pure function of the mottle seed.


## Blotch in colour space: blend the field TOWARD `tone` with a
## smootherstep shoulder. Drawn at wrapped x like _splat so the
## sphere seam never shows a cut.
func _splat_ellipse_tone(img: Image, cx: int, cy: int, rx: float, ry: float, rot: float, tone: Color, strength: float, size: int) -> void:
	var ext := int(maxf(rx, ry)) + 1
	var cs := cos(rot)
	var sn := sin(rot)
	for yy in range(maxi(0, cy - ext), mini(size, cy + ext + 1)):
		for xx in range(maxi(0, cx - ext), mini(size, cx + ext + 1)):
			var dx := float(xx - cx)
			var dy := float(yy - cy)
			var lx := dx * cs + dy * sn
			var ly := -dx * sn + dy * cs
			var q := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
			if q >= 1.0:
				continue
			var t := 1.0 - sqrt(q)
			var fall := t * t * t * (t * (t * 6.0 - 15.0) + 10.0) * strength
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).lerp(tone, fall))


## Round colour-space splat (satellites + marbling layers).
func _splat_tone(img: Image, cx: int, cy: int, rad: int, tone: Color, strength: float, size: int) -> void:
	for yy in range(maxi(0, cy - rad), mini(size, cy + rad + 1)):
		for xx in range(maxi(0, cx - rad), mini(size, cx + rad + 1)):
			var d := Vector2(xx - cx, yy - cy).length() / float(rad)
			if d >= 1.0:
				continue
			var fall := (1.0 - d) * (1.0 - d) * strength
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).lerp(tone, fall))


## Compose Aggie's tortoiseshell; returns [multiplier texture, coverage].
## Coverage is the permille of the field that ends up mottle rather
## than base — the pass-3 mottle_count contract (see smoke).
func _bake_tortie_texture(base: Color, tones: Array, seed_off: int, size: int) -> Array:
	var k := float(size) / 256.0
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mottle_cfg.get("seed", 1)) + 2707 + seed_off
	# Layer A: broad blotches, weighted to the true tortoiseshell tones.
	# QA round 2026-10-25: count/radius/strength raised after in-game
	# captures showed the pass-3 field landing invisibly on the torso
	# flanks (Aggie read solid black at gameplay distance, coverage
	# 260 permille). Same base, same tones, same seed — bolder lay-down
	# so the photo-spec mottling actually reads on the whole coat.
	for i in 26:
		var pick := rng.randf()
		var tone: Color = tones[3]
		if pick < 0.42:
			tone = tones[0]
		elif pick < 0.78:
			tone = tones[1]
		elif pick < 0.90:
			tone = tones[2]
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var rx := rng.randf_range(30.0, 56.0) * k
		var ry := rx * rng.randf_range(0.6, 0.95)
		var rot := rng.randf() * PI
		var strength := rng.randf_range(0.72, 0.95)
		for ox: int in [-size, 0, size]:
			_splat_ellipse_tone(img, cx + ox, cy, rx, ry, rot, tone, strength, size)
		# Satellites: two smaller splats hugging the blotch break its
		# clean elliptical outline (tortoiseshell patches cluster).
		for s in 2:
			var ang := rng.randf() * TAU
			var dist := rx * rng.randf_range(0.35, 0.7)
			var sx := cx + int(cos(ang) * dist)
			var sy := cy + int(sin(ang) * dist * 0.7)
			var srad := maxi(2, int(rx * rng.randf_range(0.3, 0.5)))
			for ox: int in [-size, 0, size]:
				_splat_tone(img, sx + ox, sy, srad, tone, strength * 0.8, size)
	# Layer B: mid marbling across the whole field.
	for i in 55:
		var tone_b: Color = tones[rng.randi() % tones.size()]
		var cx_b := rng.randi_range(0, size - 1)
		var cy_b := rng.randi_range(0, size - 1)
		var rad_b := maxi(2, int(rng.randf_range(10.0, 26.0) * k))
		var strength_b := rng.randf_range(0.22, 0.38)
		for ox: int in [-size, 0, size]:
			_splat_tone(img, cx_b + ox, cy_b, rad_b, tone_b, strength_b, size)
	# Layer C: fine speckle grain, deliberately LOW contrast.
	for i in 300:
		var tone_c: Color = tones[rng.randi() % tones.size()]
		var cx_c := rng.randi_range(0, size - 1)
		var cy_c := rng.randi_range(0, size - 1)
		var rad_c := maxi(1, int(rng.randf_range(3.0, 8.0) * k))
		var strength_c := rng.randf_range(0.10, 0.22)
		for ox: int in [-size, 0, size]:
			_splat_tone(img, cx_c + ox, cy_c, rad_c, tone_c, strength_c, size)
	# Convert to the multiplier field (float image: ratios survive),
	# with a whisper of fur grain, measuring coverage on the way.
	var fimg := Image.create(size, size, false, Image.FORMAT_RGBAF)
	var covered := 0
	for y in size:
		for x in size:
			var px: Color = img.get_pixel(x, y)
			var dd := Vector3(px.r - base.r, px.g - base.g, px.b - base.b).length()
			if dd > 0.14:
				covered += 1
			var n := rng.randf_range(0.97, 1.03)
			fimg.set_pixel(x, y, Color(
				clampf(px.r * n / maxf(base.r, 0.02), 0.25, 8.0),
				clampf(px.g * n / maxf(base.g, 0.02), 0.25, 8.0),
				clampf(px.b * n / maxf(base.b, 0.02), 0.25, 8.0)))
	fimg.generate_mipmaps()
	var coverage := int(round(1000.0 * float(covered) / float(size * size)))
	return [ImageTexture.create_from_image(fimg), coverage]

func _splat(img: Image, cx: int, cy: int, rad: int, mult: Color, strength: float, size: int) -> void:
	for yy in range(maxi(0, cy - rad), mini(size, cy + rad + 1)):
		for xx in range(maxi(0, cx - rad), mini(size, cx + rad + 1)):
			var d := Vector2(xx - cx, yy - cy).length() / float(rad)
			if d >= 1.0:
				continue
			var fall := (1.0 - d) * (1.0 - d) * strength
			var px: Color = img.get_pixel(xx, yy)
			img.set_pixel(xx, yy, Color(
				lerpf(px.r, px.r * mult.r, fall),
				lerpf(px.g, px.g * mult.g, fall),
				lerpf(px.b, px.b * mult.b, fall)))


## One shared unit sphere (radius 0.5), scaled per part into smooth
## ellipsoids — the remodel's answer to the GTA box frame.
func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.95) -> MeshInstance3D:
	return _ell_m(parent, pos, dia, _mat(c, rough), rot)


func _ell_m(parent: Node3D, pos: Vector3, dia: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		var hi := VisualQuality.is_high()
		_sphere.radial_segments = 48 if hi else 24
		_sphere.rings = 24 if hi else 12
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = mat
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _taper(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color) -> MeshInstance3D:
	return _taper_m(parent, pos, top_r, bot_r, h, _mat(c))


func _taper_m(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, mat: Material) -> MeshInstance3D:
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
	mi.material_override = mat
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
	# PASS 3: a tortie wears her baked coat texture on the big shells —
	# the whole mottle lives IN the fur; there are no scatter shells.
	var cm := _coat_material()
	if cm != null:
		_torso = _ell_m(_body, Vector3(0, 0.55, 0.02), torso_dia, cm)
		_ell_m(_body, Vector3(0, 0.545, -0.30), chest_dia, cm)
	else:
		_torso = _ell(_body, Vector3(0, 0.55, 0.02), torso_dia, coat)
		_ell(_body, Vector3(0, 0.545, -0.30), chest_dia, coat)
	var hx := torso_dia.x * 0.22
	for sx: float in [-1.0, 1.0]:
		if cm != null:
			_ell_m(_body, Vector3(sx * hx, 0.565, 0.29), haunch_dia, cm)
		else:
			_ell(_body, Vector3(sx * hx, 0.565, 0.29), haunch_dia, coat)

	if pattern == "tortoiseshell":
		_build_tortie_body()
	else:
		_build_bicolor_body()
	_build_head()
	_build_legs()
	_build_tail()
	SculptLib.attach(self)
	_sculpt = get("_sculpt")
	CatFidelity.dress(self)
	if _sculpt != null:
		_sculpt.adopt_whiskers(self)
		_sculpt.hide_leftovers(self)


## Willie's markings: a LARGE ginger saddle over the whole back and
## upper sides, a small chest bib, and faint darker tabby striping
## inside the saddle (Daniel's ruled spec, 2026-10-25).
func _build_bicolor_body() -> void:
	_saddle_patch = _ell_m(_body, Vector3(0, 0.612, 0.04), Vector3(0.468, 0.335, 0.82), _saddle_material())
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
	# Stripes wear the derived ginger_dark exactly. (Realism pass 1 sat
	# them 30% toward the ginger, but that softening belonged to the
	# photo-tuned palette; under Daniel's 2026-10-25 ruling the spec-lock
	# wins — tests/smoke.gd locks the stripe albedo to ginger_dark. The
	# baked saddle shading still does the tonal blending.)
	_stripes.append(_ell(parent, pos, dia, ginger_dark, rot))
	stripe_count = _stripes.size()


## Aggie's torso extras: her cream throat/chest and an orange accent
## (designed markings, like Willie's bib — the mottling itself is in
## the coat texture now). Deterministic: same seed, same cat.
func _build_tortie_body() -> void:
	_ell(_body, Vector3(0, 0.585, -0.42), Vector3(0.13, 0.17, 0.09), mottle_cream, Vector3(-0.35, 0, 0))
	_ell(_body, Vector3(0.05, 0.63, -0.40), Vector3(0.09, 0.11, 0.07), mottle_orange, Vector3(-0.3, 0, 0))


func _build_head() -> void:
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, LEG_H + 0.38, -0.5)
	_body.add_child(_head)
	var hcm := _coat_material("head")
	if hcm != null:
		_ell_m(_head, Vector3(0, 0.03, -0.05), Vector3(0.30, 0.28, 0.29), hcm) # skull
	else:
		_ell(_head, Vector3(0, 0.03, -0.05), Vector3(0.30, 0.28, 0.29), coat) # skull
	_ell(_head, Vector3(0, -0.035, -0.155), Vector3(0.185, 0.135, 0.155), coat) # muzzle
	if pattern == "tortoiseshell":
		# Mostly dark face; the orange mottling lives in the skull's
		# baked coat texture (pass 3) — no scatter shells any more.
		pass
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
		_ears.append([ear, sx, ear.rotation])
		var inner := _ell(_head, Vector3(sx * 0.088, 0.15, -0.032), Vector3(0.05, 0.09, 0.02), inner_ear_color)
		_inner_ears.append(inner)
	# Eyes: per-character from the data — Willie's dark (ruled spec, 2026-10-25), Aggie's green-gold.
	for sx: float in [-1.0, 1.0]:
		_eyes.append(_ell(_head, Vector3(sx * 0.067, 0.045, -0.178), Vector3(0.034, 0.034, 0.034), eye_color, Vector3.ZERO, 0.25))
	_ell(_head, Vector3(0, -0.018, -0.222), Vector3(0.042, 0.028, 0.026), nose_color, Vector3.ZERO, 0.5)


func _leg_key(sx: float, sz: float) -> String:
	return ("F" if sz < 0.0 else "B") + ("L" if sx < 0.0 else "R")


func _build_legs() -> void:
	# PASS 3: a tortie's legs wear her baked coat texture too — the
	# pattern runs down the legs IN the texture, no scatter shells.
	var leg_mat: Material = _coat_material("legs")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.12, LEG_H, sz * 0.32)
			_model.add_child(hip)
			_hips[_leg_key(sx, sz)] = hip
			if leg_mat != null:
				_ell_m(hip, Vector3.ZERO, Vector3(leg_r_top * 2.3, 0.13, leg_r_top * 2.3), leg_mat)
				_taper_m(hip, Vector3(0, -(leg_len * 0.5 + 0.005), 0), leg_r_top, leg_r_bot, leg_len, leg_mat)
				_ell_m(hip, Vector3(0, -(leg_len - 0.018), -0.016), Vector3(leg_r_top * 1.6, 0.06, leg_r_top * 2.0), leg_mat)
			else:
				_ell(hip, Vector3.ZERO, Vector3(leg_r_top * 2.3, 0.13, leg_r_top * 2.3), coat)
				_taper(hip, Vector3(0, -(leg_len * 0.5 + 0.005), 0), leg_r_top, leg_r_bot, leg_len, coat)
				_ell(hip, Vector3(0, -(leg_len - 0.018), -0.016), Vector3(leg_r_top * 1.6, 0.06, leg_r_top * 2.0), coat)


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
	# Tail segments: plain coat for Willie; Aggie's wear her tail
	# coat texture (dark base with orange running through it).
	# Willie's tail (Daniel's ruled spec, 2026-10-25): WHITE with a
	# ginger underside — a flattened ginger shell hugging the lower
	# half of each segment. No rings.
	var tail_mat: Material = _coat_material("tail")
	for i in segs.size():
		var s: Array = segs[i]
		var pos := Vector3(0, float(s[1]), float(s[0]))
		var seg_mi: MeshInstance3D
		if tail_mat != null:
			seg_mi = _ell_m(_tail, pos, Vector3.ONE * float(s[2]) * tail_k, tail_mat)
		else:
			seg_mi = _ell(_tail, pos, Vector3.ONE * float(s[2]) * tail_k, coat)
		_tail_segs.append([seg_mi, float(s[2]) * tail_k])
		_tail_base.append(pos)
		if pattern != "tortoiseshell":
			var dia := float(s[2]) * tail_k
			var under := _ell(_tail, pos + Vector3(0, -dia * 0.32, 0), Vector3(dia * 0.94, dia * 0.48, dia * 0.94), ginger)
			_tail_underside.append(under)


# --- controller -----------------------------------------------------------------

func set_move_input(dir: Vector3, sprint: bool, stalk: bool) -> void:
	_input_dir = dir
	_input_sprint = sprint
	_input_stalk = stalk


func strike() -> bool:
	if _strike_t >= 0.0 or _strike_cd > 0.0 or is_lounging or is_fainted or _hiss_t >= 0.0 or is_held or is_poisoned:
		return false
	_strike_t = 0.0
	_swipe_fired = false
	return true


func set_lounge(on: bool) -> void:
	is_lounging = on


## Opens the jaw clip. Gameplay meows (M, and Aggie's chirp) call this.
func play_meow() -> void:
	meow_k = 1.0
	var voice := get_node_or_null("CatVoice") as CatVoice
	if voice != null:
		voice.speak("chirp" if character_id == "aggie" else "meow")


## HEAT: blend the courtship pose in or out.
func set_courtship(on: bool) -> void:
	courtship_target = 1.0 if on else 0.0


## HEAT: a brief performed pose ("" clears). Only "groom" exists.
func set_act_pose(pose: String) -> void:
	act_pose = pose


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
	if not is_on_floor() or is_lounging or is_fainted or _hiss_t >= 0.0 or is_held or is_poisoned:
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
	_lunge = forward_dir() * 4.2
	velocity += _lunge + Vector3(0, 0.8, 0)
	return true


## True through the whole swipe. A floor snap must not
## shorten the reach before the paw lands.
func is_pouncing() -> bool:
	return _pounced


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
	is_poisoned = false
	is_held = false
	_invuln_t = 0.0
	set_lounge(false)
	health_changed.emit(hp, max_hp)


## GLENYS has him: held up in her arms. No movement, no strikes —
## and no harm, ever: a grab costs control and time, not HP. The
## Glenys system owns the hold/release; this is just the cat side.
func set_held(on: bool) -> void:
	is_held = on
	if on:
		velocity = Vector3.ZERO


## POISON — the game's ONLY lethal act, and it is always the cat's
## own doing: eating the chocolate Glenys offers, or getting into
## the basement rat poison. This is NOT a faint — no hub respawn,
## no life spent; the game ends the run (main listens for the
## `poisoned` signal). Damage never routes here: take_damage can
## only faint. Nothing else may call this.
func eat_poison(source: String) -> bool:
	if is_poisoned or is_fainted:
		return false
	is_poisoned = true
	is_held = false
	velocity = Vector3.ZERO
	set_lounge(true) # the flop; main decides what it means
	poisoned.emit(self, source)
	return true


func _faint() -> void:
	is_fainted = true
	set_lounge(true) # the dramatic flop; the game handles the respawn
	fainted.emit(self)


## The startle state — basement ghosts force it, anything may call
## it. Full arched-back Halloween pose (spine up, tail puffed, head
## low), HISS_TIME of control lock, NO damage. Emits hissed (the
## audio hook). Returns false if it couldn't start.
func hiss() -> bool:
	if _hiss_t >= 0.0 or is_lounging or is_fainted or is_held or is_poisoned:
		return false
	_hiss_t = 0.0
	hissed.emit(self)
	var voice := get_node_or_null("CatVoice") as CatVoice
	if voice != null:
		voice.speak("hiss")
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
			_pounced = false
			_lunge = Vector3.ZERO

	var want := Vector3.ZERO
	var speed := 0.0
	var moving := false
	if _input_dir.length() > 0.05 and not is_lounging and not is_fainted and not is_held and not is_poisoned and _hiss_t < 0.0 and _strike_t < 0.0:
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

	var carry := Vector3.ZERO
	if _lunge.length() > 0.05 and _strike_t >= 0.0:
		carry = _lunge
	velocity.x = want.x + carry.x
	velocity.z = want.z + carry.z
	# Grounded stick only when not moving up — a fresh jump()
	# sets velocity.y > 0 between frames and must survive this.
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	if is_on_floor() and _strike_t < 0.0:
		_pounced = false
		_lunge = Vector3.ZERO

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
# REALISM PASS 1: the pose layer is a small locomotion system that
# OBSERVES the cat (velocity, anim_state, yaw) and never drives it:
# speed-blended gaits (walk / trot / bound with per-leg cycle offsets),
# stride bob + roll, turn lean, a lagged follow-through tail curve,
# acceleration stretch, a landing settle, ear micro-motion, and an
# idle repertoire (stand -> sit -> groom). _update_pose() is separate
# from _process() so headless tests can step it with fixed deltas on a
# process-disabled cat and assert on the pose state.

## Per-leg gait cycle offsets (fractions of a stride cycle).
const GAIT_OFFS := {
	"walk": {"FL": 0.0, "BR": 0.25, "FR": 0.5, "BL": 0.75},
	"trot": {"FL": 0.0, "BR": 0.0, "FR": 0.5, "BL": 0.5},
	"bound": {"FL": 0.0, "FR": 0.06, "BL": 0.5, "BR": 0.56},
}

var _anim_t := 0.0
var _spd_s := 0.0 # smoothed horizontal speed
var _accel_s := 0.0 # smoothed acceleration
var _prev_yaw := 0.0
var _yaw_rate := 0.0 # smoothed turn rate (rad/s)
var _tail_bend := 0.0 # lagged lateral tail bend from turning
var _fall_v := 0.0
var _was_air := false
var _land_t := -1.0
var idle_time := 0.0 # read-only: seconds in the current idle bout
var idle_pose := "stand" # read-only: stand | sit | groom
var _sit_k := 0.0
var _groom_k := 0.0
var _ear_flick_t := 2.0
var _ear_flick := 0.0
var _ear_flick_side := 1.0


func _process(delta: float) -> void:
	_update_pose(delta)


func _update_pose(delta: float) -> void:
	_anim_t += delta
	_hiss_k = move_toward(_hiss_k, 1.0 if _hiss_t >= 0.0 else 0.0, delta * (5.0 if _hiss_t >= 0.0 else 2.5))
	_faint_k = move_toward(_faint_k, 1.0 if is_fainted else 0.0, delta * 3.0)
	_lounge_k = move_toward(_lounge_k, 1.0 if is_lounging else 0.0, delta * 2.2)
	courtship_k = move_toward(courtship_k, courtship_target, delta * 2.4)
	act_pose_k = move_toward(act_pose_k, 1.0 if act_pose != "" else 0.0, delta * 3.2)
	if courtship_k > 0.01:
		_roll_phase += delta * 5.2

	# --- observed motion (read-only: the physics layer owns these) ---
	var spd := Vector2(velocity.x, velocity.z).length()
	_accel_s = lerpf(_accel_s, clampf((spd - _spd_s) / maxf(delta, 0.001), -14.0, 14.0), 1.0 - exp(-8.0 * delta))
	_spd_s = lerpf(_spd_s, spd, 1.0 - exp(-10.0 * delta))
	_yaw_rate = lerpf(_yaw_rate, clampf(angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.001), -9.0, 9.0), 1.0 - exp(-7.0 * delta))
	_prev_yaw = rotation.y
	var sf := clampf(_spd_s / maxf(sprint_speed, 0.01), 0.0, 1.15) # gait driver
	var moving := anim_state in ["walk", "stalk", "sprint"]

	# --- gait clock + blend weights (walk -> trot -> bound by speed) --
	var w_walk := 1.0 - smoothstep(0.34, 0.55, sf)
	var w_bound := smoothstep(0.70, 0.95, sf)
	var w_trot := clampf(1.0 - w_walk - w_bound, 0.0, 1.0)
	if anim_state == "stalk":
		w_walk = 1.0
		w_trot = 0.0
		w_bound = 0.0
	gait_walk = w_walk
	gait_trot = w_trot
	gait_bound = w_bound
	pounce_amount = 1.0 if (not is_on_floor() and is_pouncing()) else 0.0
	if moving:
		var freq := lerpf(1.7, 3.9, clampf(sf, 0.0, 1.0))
		if anim_state == "stalk":
			freq = 1.5 + spd * 0.45
		_phase += delta * TAU * freq

	# --- landing settle: a brief crouch-dip after a real fall ---------
	if not is_on_floor():
		_fall_v = velocity.y
		_was_air = true
	elif _was_air:
		_was_air = false
		if _fall_v < -1.6:
			_land_t = 0.0
	if _land_t >= 0.0:
		_land_t += delta
		if _land_t > 0.24:
			_land_t = -1.0
	var land_dip := 0.0
	if _land_t >= 0.0:
		land_dip = sin(PI * clampf(_land_t / 0.24, 0.0, 1.0))
	land_amount = land_dip

	# --- idle repertoire: stand, then sit, with groom pulses ----------
	var idling := anim_state == "idle" and not is_lounging and not is_fainted and _hiss_t < 0.0 and _strike_t < 0.0
	if idling:
		idle_time += delta
	else:
		idle_time = 0.0
	var cyc := fmod(idle_time, 17.0)
	var sit_want := 1.0 if (idling and cyc > 4.0 and cyc < 11.0) else 0.0
	_sit_k = move_toward(_sit_k, sit_want, delta * (2.6 if sit_want > 0.0 else 4.5))
	var groom_want := 0.0
	if idling and _sit_k > 0.6:
		for w: Array in [[6.1, 7.3], [8.7, 9.9]]:
			if cyc > float(w[0]) and cyc < float(w[1]):
				groom_want = sin(PI * (cyc - float(w[0])) / (float(w[1]) - float(w[0])))
	_groom_k = move_toward(_groom_k, groom_want, delta * 5.0)
	idle_pose = "groom" if _groom_k > 0.4 else ("sit" if _sit_k > 0.5 else "stand")

	# --- body pose ------------------------------------------------------
	var body_scale := Vector3.ONE
	var body_y := 0.0
	var body_pitch := 0.0
	var body_roll := 0.85 * _faint_k # the faint flop still owns the roll base
	var tail_rot := Vector3(0, sin(_time * 1.7) * 0.08, 0)
	var head_rot := Vector3.ZERO
	match anim_state:
		"idle":
			body_scale.y = 1.0 + sin(_time * 2.1) * 0.025 # breathing
			head_rot.y = sin(_time * 0.43) * 0.38 * (1.0 - _sit_k) # look-around (less in a sit)
			head_rot.x = sin(_time * 0.31) * 0.06
		"walk", "sprint":
			pass # bob / roll / pitch come from the gait terms below
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
	if moving:
		# Two-beat bob for walk/trot, one suspension beat for the bound.
		body_y += sin(_phase * 2.0) * 0.016 * (w_walk * 0.6 + w_trot) + sin(_phase + 0.6) * 0.045 * w_bound
		body_roll += sin(_phase) * (0.020 * w_walk + 0.034 * w_trot)
		body_pitch += sin(_phase - 0.5) * 0.075 * w_bound
	# Turn lean: roll into the turn, scaled by speed.
	body_roll += clampf(_yaw_rate * 0.045, -0.17, 0.17) * clampf(_spd_s / 2.0, 0.0, 1.0)
	# Acceleration easing: stretch on launch, compress on the stop.
	body_pitch += clampf(-_accel_s * 0.006, -0.05, 0.07)
	var stretch := clampf(_accel_s * 0.008, -0.035, 0.055) * (1.0 if moving else 0.3)
	body_scale.z *= 1.0 + stretch
	body_scale.y *= 1.0 - stretch * 0.45
	# Airborne shape: reach on the pounce, tuck on the rise.
	if not is_on_floor():
		if is_pouncing():
			body_pitch += -0.13
		elif velocity.y > 1.0:
			body_pitch += 0.05
		else:
			body_pitch += -0.03
	body_y -= 0.055 * land_dip
	body_scale.y *= 1.0 - 0.07 * land_dip
	# The sit: haunches down (+x pitch drops the rear), chest proud,
	# tail wrapping around the side like the lounge's.
	if _sit_k > 0.0:
		body_pitch += 0.40 * _sit_k
		body_y -= 0.055 * _sit_k
		head_rot.x -= 0.10 * _sit_k
		tail_rot.y += 0.75 * _sit_k
	# The groom: head down to the raised front-right paw, lick bob.
	if _groom_k > 0.0:
		head_rot.x += (0.52 + sin(_anim_t * 9.0) * 0.06) * _groom_k
		head_rot.y += 0.34 * _groom_k
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
	if courtship_k > 0.0:
		# Solicitation: crouch a little, dip the head, swing the
		# tail aside; the roll itself lands on the body below.
		body_scale.y *= 1.0 - 0.13 * courtship_k
		head_rot.x = lerpf(head_rot.x, 0.30, courtship_k)
		tail_rot.y += 0.95 * courtship_k
	if act_pose_k > 0.0 and act_pose == "groom":
		# Pointed self-grooming: head right down to the paw.
		head_rot.x = lerpf(head_rot.x, 0.55, act_pose_k)
	# Head stabilisation: the head counters ~2/3 of the body's pitch and
	# ~half its roll, so the gaze stays level while the body works.
	head_rot.x -= body_pitch * 0.65
	head_rot.y -= body_roll * 0.4
	_body.scale = body_scale
	_body.position.y = body_y * (1.0 - _lounge_k)
	# body_roll already carries the faint flop (0.85 * _faint_k) as its
	# base; the heat roll rocks on top of it.
	_body.rotation.z = body_roll + sin(_roll_phase) * 0.38 * courtship_k # + HEAT roll
	_body.rotation.x = body_pitch * (1.0 - _lounge_k) - 0.10 * courtship_k # + HEAT present dip
	_head.rotation = head_rot
	_tail.rotation = tail_rot
	# Tail puff for the hiss (segments recorded at build time).
	for seg: Array in _tail_segs:
		(seg[0] as MeshInstance3D).scale = Vector3.ONE * float(seg[1]) * (1.0 + 0.75 * _hiss_k)
	# Invulnerability blink — never while fainted (he's a drama cat).
	if _model != null:
		_model.visible = (int(_time * 18.0) % 2 == 0) if (_invuln_t > 0.0 and not is_fainted) else true
	_update_tail(delta, sf, moving)
	_update_ears(delta, sf)
	_update_legs(land_dip, w_walk, w_trot, w_bound, moving)
	_update_pupils()
	if _sculpt != null:
		_sculpt.apply_state(self, delta)


## The tail as a lagged follow-through chain: each segment's rest
## position is re-curved by a sway wave that travels base -> tip
## (amplitude growing toward the tip) plus a smoothed bend from
## turning. Segments are spheres, so the curve lives in positions.
func _update_tail(delta: float, sf: float, moving: bool) -> void:
	_tail_bend = lerpf(_tail_bend, clampf(-_yaw_rate * 0.11, -0.55, 0.55), 1.0 - exp(-4.5 * delta))
	var amp := 0.016 + 0.05 * clampf(sf, 0.0, 1.0)
	var freq := 2.2 + 5.0 * clampf(sf, 0.0, 1.0)
	if anim_state == "stalk":
		amp *= 0.35 # a stalking tail is low and still
	if _lounge_k > 0.3:
		amp *= 0.4
	var n := _tail_segs.size()
	for i in n:
		var seg := _tail_segs[i][0] as MeshInstance3D
		var base: Vector3 = _tail_base[i]
		var t := float(i) / float(maxi(1, n - 1))
		var wave := sin(_anim_t * freq - t * 2.6) * amp * (0.2 + 0.8 * t)
		var stream := 1.0 - 0.4 * smoothstep(0.7, 0.95, sf) # flattens at the bound
		seg.position = Vector3(
			base.x + (wave + _tail_bend * 0.16) * t,
			base.y * stream + sin(_anim_t * freq - t * 2.6 - 0.9) * amp * 0.4 * t,
			base.z)


## Ear micro-motion: a slow splay drift, an occasional single-ear
## flick, pinned back by speed and flattened by the hiss.
func _update_ears(delta: float, sf: float) -> void:
	_ear_flick_t -= delta
	if _ear_flick_t <= 0.0:
		_ear_flick_t = randf_range(2.2, 5.5)
		_ear_flick = 1.0
		_ear_flick_side = 1.0 if randf() > 0.5 else -1.0
	_ear_flick = move_toward(_ear_flick, 0.0, delta * 6.0)
	for e: Array in _ears:
		var mi := e[0] as MeshInstance3D
		var sx := float(e[1])
		var r: Vector3 = e[2]
		r.z += sin(_anim_t * 1.3 + sx * 1.7) * 0.035
		r.x -= clampf(sf, 0.0, 1.0) * 0.30 + _hiss_k * 0.45
		if anim_state == "stalk":
			r.x += 0.28 # ears forward, listening
		elif anim_state == "sprint":
			r.x -= 0.12 # pinned by the run
		if sx == _ear_flick_side:
			r.x += sin(_ear_flick * PI) * 0.5
		mi.rotation = r


func _update_pupils() -> void:
	var k := 0.58
	if anim_state == "idle" or anim_state == "lounge":
		k = 0.78
	elif anim_state == "stalk" or anim_state == "hiss":
		k = 0.4
	elif anim_state == "sprint":
		k = 0.46
	k += sin(_time * 0.85) * 0.025
	for p in _pupils:
		(p as MeshInstance3D).scale = Vector3(k, k * 1.15, 0.3)


## Legs: the three gaits blended by their weights, with the special
## poses (lounge splay, sit fold, groom paw, airborne shapes, landing
## compression, the strike slash) layered over the cycle.
func _update_legs(land_dip: float, w_walk: float, w_trot: float, w_bound: float, moving: bool) -> void:
	for key in _hips:
		var hip := _hips[key] as Node3D
		if _lounge_k > 0.0:
			var splay := (0.5 if key.begins_with("F") else -0.35) * _lounge_k
			hip.rotation.x = lerpf(hip.rotation.x, splay, 0.5)
			continue
		var rot := 0.0
		if moving:
			var amp := 0.30 if anim_state == "stalk" else 0.52
			rot = (w_walk * sin(_phase + TAU * float(GAIT_OFFS["walk"][key]))
				+ w_trot * sin(_phase + TAU * float(GAIT_OFFS["trot"][key]))
				+ w_bound * sin(_phase + TAU * float(GAIT_OFFS["bound"][key]))) * amp * (1.0 + 0.35 * w_bound)
		elif _sit_k > 0.0:
			rot = (1.15 if key.begins_with("B") else 0.03) * _sit_k # hind fold, front pillars
		if _groom_k > 0.0 and key == "FR":
			rot = lerpf(rot, -0.85, _groom_k) # paw raised to the face
		if not is_on_floor():
			if is_pouncing():
				rot = -0.8 if key.begins_with("F") else 0.65
			elif velocity.y > 1.0:
				rot = lerpf(rot, 0.3, 0.6) # tucked on the rise
			else:
				rot = lerpf(rot, -0.25, 0.6) # reaching for the ground
		rot += land_dip * (0.35 if key.begins_with("F") else 0.3)
		hip.rotation.x = rot if (moving or not is_on_floor()) else lerpf(hip.rotation.x, rot, 0.35)
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
	# The groom pose raises the front-right paw to the dipped head.
	if act_pose_k > 0.0 and act_pose == "groom" and _hips.has("FR"):
		var gfr := _hips["FR"] as Node3D
		gfr.rotation.x = lerpf(gfr.rotation.x, -0.95, act_pose_k * 0.65)
