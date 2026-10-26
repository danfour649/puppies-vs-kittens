extends Node3D
## Willie and Aggie — the Massey Street cat game.
## You are the cat: Willie, built by cat_kit from GTA's
## Fredericton's stray_cat. Catch every mouse in the backyard.
## No birds. Puppies are Phase 2 (see README.md).

const CatScene := preload("res://cat_kit/cat.gd")
const MouseScene := preload("res://mouse.gd")
const TouchScene := preload("res://touch_controls_3d.gd")
# MASSEY MODULE: the house, the duo and the cat start as a drop-in
# module (module/, docs/massey-zones.md §9). main.gd is the module's
# first host: it provides the §9.3 host surface (the cat actor, the
# paw sink, the zone hook, the outside zone root API) and the module
# assembles everything else. Zone scenes load by path from
# HouseSpec, via the module.
const MasseyModuleScene := preload("res://module/massey_module.gd")
# OUTSIDE: the Massey outside zone (zones/outside/) hangs off main
# the same way the duo system does.
const OutsideScene := preload("res://zones/outside/outside_system.gd")
# GLENYS: the cat-chaser (glenys/) — Daniel's mother, her cane, and
# the two poisons that are the game's only lethal hazards. (The
# occupants' preloads moved into the module, which assembles them.)
const GlenysScript := preload("res://glenys/glenys.gd")
const GlenysSystemScript := preload("res://glenys/glenys_system.gd")

const MOUSE_COUNT := 7
const YARD := Rect2(-12.4, -9.4, 24.8, 18.8) # inside the fence
const CHAIR_SEAT := Vector3(4.5, 0.46, 4.5) # top of the garden chair

var cat: PvKCat
var aggie: PvKCat
var mice: Array = []
var caught_count := 0
var elapsed := 0.0
var won := false

# DUO state: the duo system (null until _ready's tail), the radius
# the paw check uses (the provoked buff widens it), and a camera
# shake offset the flurry writes into.
var duo: DuoSystem = null
# MASSEY state: the zone manager, the objectives registry, and the
# nine-lives counter (flavour — a faint is never a game-over).
var zones: ZoneManager = null
var objectives: PvKObjectives = null
var lives := 9
var module: MasseyModule = null # MASSEY MODULE (§9): owns zones/objectives/occupants assembly
## Zone roots live in the module now (MasseyModule._zone_roots, with
## zone_root(id) as its accessor). This read-only delegation keeps
## main's pre-module _zone_roots surface working for the harness
## (tests/test_playtest.gd, glenys/tests_glenys.gd read it directly).
var _zone_roots: Dictionary:
	get:
		return module._zone_roots if module != null else {}
var _faint_t := -1.0
var _banner_t := 0.0
var outside: OutsideSystem = null # OUTSIDE
var occupants: OccupantSystem = null # OCCUPANTS (hub)
var glenys: GlenysSystem = null # GLENYS (the cat-chaser)
var night: NightRun = null # the round: floors, Glenys, dawn
var run_over := false # POISON: a poison death ends the run (no respawn)
var catch_radius := 0.62
var duo_shake := Vector3.ZERO
var _mouse_seq := 0

var cam_yaw := PI
var cam_pitch := -0.48
var cam_dist := 4.6
## Indoors the lens sits just behind the shoulder, about at his eyes,
## looking a little up into the room. The yard keeps cam_dist.
const INDOOR_NEAR := 1.05
const INDOOR_FAR := 1.85
var indoor_zoom := 1.55
var look_invert := false
var look_sens := 1.0
var pause_menu: PauseMenu = null

## Smoke-test seam: when active, physics input comes from here.
var input_override := {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}

var _rig: Node3D
var _arm: SpringArm3D
var _status: Label
var _hp_bar: ProgressBar
var _prov_bar: ProgressBar
var _confirm: Label
var _restart_left := 0.0
var _banner: Label
var _hud_layer: CanvasLayer
var _touch: TouchControls3D
var _feel: CameraFeel
## Shots seam: when set, the camera rig tracks this node instead of the cat.
var cam_anchor: Node3D = null
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func _ready() -> void:
	# Web and desktop both boot the full house. The renderer picks
	# the quality tier (Forward+ here, GL Compatibility in the browser).
	_rng.randomize()
	_build_environment()
	_build_lights()
	cat = CatScene.new()
	cat.name = "Willie"
	add_child(cat)
	cat.global_position = Vector3(2.5, 0.1, -6.2)
	cat.rotation.y = PI # face into the yard (+Z); model forward is -Z
	cat.paw_swiped.connect(_on_paw_swiped)
	cat.poisoned.connect(_on_cat_poisoned)
	_build_camera()
	_build_hud()
	_touch = TouchScene.new()
	add_child(_touch)
	_touch.strike_pressed.connect(_on_touch_strike)
	_touch.pounce_pressed.connect(_on_touch_pounce)
	_touch.meow_pressed.connect(_on_touch_meow)
	_touch.restart_pressed.connect(restart_game)
	_touch.look_dragged.connect(_on_look_drag)
	_spawn_mice()
	# MASSEY MODULE: the duo (sibling cat, character select, meow +
	# provocation), the zones, the objectives registry and the
	# occupants assemble behind the §9 host interface.
	module = MasseyModuleScene.new()
	module.name = "MasseyModule"
	add_child(module)
	module.setup(self)
	duo = module.duo
	aggie = duo.aggie_cat # shots seam: main's Aggie handle is the duo sibling
	aggie.poisoned.connect(_on_cat_poisoned)
	cat.add_to_group("player_cat") # enemies hunt this group
	zones = module.zones
	objectives = module.objectives
	objectives.declare("outside:mice", HouseSpec.OUTSIDE, "Catch all 7 mice in the yard", MOUSE_COUNT)
	var obj_hud := ObjectivesHUD.new()
	obj_hud.name = "ObjectivesHUD"
	add_child(obj_hud)
	obj_hud.setup(objectives, zones)
	module.build_occupants()
	occupants = module.occupants
	_build_glenys()
	night = NightRun.new()
	night.name = "NightRun"
	add_child(night)
	night.setup(self)
	if _touch != null and night.compass() != null:
		_touch.pass_controls.append(night.compass())
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.bind(self)
	if _touch != null:
		_touch.pause_pressed.connect(pause_menu.toggle)
		_touch.process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_hud()
	# OUTSIDE: trees + squirrels, feeder birds + ambush, the street
	# frontage (hostile traffic, the Corolla island, the fish
	# treat) and pedestrians walking dogs.
	outside = OutsideScene.new()
	outside.name = "OutsideSystem"
	add_child(outside)
	outside.setup(self)


# --- materials / boxes (wildlife.gd idiom, shadows on for a diorama) --------

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


func _static_box(parent: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


# --- world -------------------------------------------------------------------

func _build_environment() -> void:
	var env := Node3D.new()
	env.name = "Yard"
	add_child(env)
	var grass := Color(0.32, 0.5, 0.22)
	var grass2 := Color(0.29, 0.46, 0.20)
	var grass3 := Color(0.335, 0.515, 0.23)
	var wood := Color(0.55, 0.42, 0.3)
	var wood_dark := Color(0.42, 0.31, 0.21)
	_box(env, Vector3(26.4, 0.2, 20.4), Vector3(0, -0.1, 0), grass)
	# Mown patches, a whisper above the lawn to avoid z-fighting.
	var patches := [grass2, grass3, grass2, grass3, grass2, grass3]
	var spots := [Vector2(-8, -3), Vector2(6, 1), Vector2(-2, 6), Vector2(9, -6), Vector2(-10, 5), Vector2(1, -1)]
	for i in spots.size():
		_box(env, Vector3(4.5, 0.012, 3.6), Vector3(spots[i].x, 0.006 + i * 0.0012, spots[i].y), patches[i])
	# Boundary: NO fence at 255 Massey (Daniel, 2026-10-25) — the
	# yard is ringed by an impassable thorn hedge of wild roses.
	# The invisible boundary statics further down are UNCHANGED,
	# so the hedge stops cats, mice and dogs exactly where the
	# fence did; only the visuals changed.
	_build_rose_hedge(env)
	# House along the north edge: wall, roof lip, door, windows, porch.
	var siding := Color(0.74, 0.71, 0.65)
	var trim := Color(0.92, 0.9, 0.85)
	_box(env, Vector3(17.0, 3.4, 0.4), Vector3(0, 1.7, -10.2), siding)
	_box(env, Vector3(17.6, 0.22, 2.4), Vector3(0, 3.55, -10.5), Color(0.3, 0.26, 0.24), Vector3(0.16, 0, 0))
	_box(env, Vector3(6.4, 0.24, 2.6), Vector3(2.5, 0.12, -8.7), wood) # porch deck
	_box(env, Vector3(1.05, 2.1, 0.12), Vector3(2.5, 1.29, -9.96), Color(0.36, 0.2, 0.12)) # door
	_box(env, Vector3(0.09, 0.09, 0.09), Vector3(2.05, 1.29, -9.88), Color(0.8, 0.7, 0.3)) # knob
	for wx: float in [-4.5, 6.5]:
		_box(env, Vector3(1.5, 1.1, 0.1), Vector3(wx, 1.9, -9.97), trim)
		_box(env, Vector3(1.3, 0.9, 0.12), Vector3(wx, 1.9, -9.97), Color(0.62, 0.74, 0.82))
	# Tree, crates, and the garden chair (the lounge throne).
	_box(env, Vector3(0.4, 2.6, 0.4), Vector3(-8.5, 1.3, -5.0), Color(0.4, 0.3, 0.2))
	_box(env, Vector3(2.6, 1.8, 2.6), Vector3(-8.5, 3.3, -5.0), Color(0.25, 0.45, 0.18), Vector3(0.1, 0.4, 0.05))
	_box(env, Vector3(1.9, 1.4, 1.9), Vector3(-8.2, 4.3, -4.6), Color(0.3, 0.52, 0.2), Vector3(-0.06, 0.9, 0.12))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(9.5, 0.36, -6.0), Color(0.6, 0.48, 0.32))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(10.3, 0.36, -6.1), Color(0.57, 0.45, 0.3))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(9.9, 1.08, -6.05), Color(0.63, 0.5, 0.34))
	var chair := Color(0.7, 0.68, 0.62)
	var chair_g := Node3D.new()
	chair_g.position = CHAIR_SEAT # group origin at seat-top height
	chair_g.rotation.y = 0.8 # back (+Z local) away from the lounging cat
	env.add_child(chair_g)
	_box(chair_g, Vector3(0.66, 0.06, 0.58), Vector3(0, -0.03, 0), chair)
	_box(chair_g, Vector3(0.66, 0.62, 0.06), Vector3(0, 0.28, 0.28), chair, Vector3(0.28, 0, 0))
	for sx: float in [-0.26, 0.26]:
		for sz: float in [-0.22, 0.22]:
			_box(chair_g, Vector3(0.07, 0.46, 0.07), Vector3(sx, -0.26, sz), chair)
	# Collision: perimeter, house, porch, tree, crates, chair.
	var statics := StaticBody3D.new()
	statics.name = "Statics"
	add_child(statics)
	_static_box(statics, Vector3(26.4, 0.2, 20.4), Vector3(0, -0.1, 0)) # the lawn itself
	_static_box(statics, Vector3(17.0, 3.4, 1.0), Vector3(0, 1.7, -10.2))
	_static_box(statics, Vector3(26.4, 1.3, 0.6), Vector3(0, 0.65, 10.2))
	_static_box(statics, Vector3(0.6, 1.3, 20.4), Vector3(13.2, 0.65, 0))
	_static_box(statics, Vector3(0.6, 1.3, 20.4), Vector3(-13.2, 0.65, 0))
	# The deck used to be a solid block from the lawn up to 0.24 m.
	# Willie hit that curb at z=-7.25 and could not reach the door.
	# The slab is the deck surface; the ramp is the step in front of it.
	_static_box(statics, Vector3(6.4, 0.1, 1.85), Vector3(2.5, 0.19, -9.08))
	var ramp := CollisionShape3D.new()
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(2.4, 0.08, 1.15)
	ramp.shape = ramp_shape
	ramp.position = Vector3(2.5, 0.12, -7.58)
	ramp.rotation.x = atan2(0.24, 1.05)
	statics.add_child(ramp)
	_static_box(statics, Vector3(0.5, 2.6, 0.5), Vector3(-8.5, 1.3, -5.0))
	_static_box(statics, Vector3(2.4, 1.5, 1.2), Vector3(9.9, 0.75, -6.05))
	_static_box(statics, Vector3(0.7, 0.46, 0.7), CHAIR_SEAT + Vector3(0, -0.23, 0))
	_build_front_roses(env)
	_dress_yard(env)
	var yard_life := YardLife.new()
	yard_life.name = "YardLife"
	env.add_child(yard_life)
	yard_life.build()


## REALISM PASS 1 dressing: grass tufts + flower dots, a hedge line
## inside the south fence, and the house's exterior trim (door frame,
## window sills + muntins, corner boards, eaves fascia, porch posts).
## Visual only — no statics, no layout or HouseSpec changes.
func _dress_yard(env: Node3D) -> void:
	var trim := Color(0.92, 0.9, 0.85)
	var wood_dark := Color(0.42, 0.31, 0.21)
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = 0.0
	blade_mesh.bottom_radius = 0.018
	blade_mesh.height = 0.24
	blade_mesh.radial_segments = 5
	var blade_mats: Array = [_mat(Color(0.26, 0.44, 0.18)), _mat(Color(0.36, 0.55, 0.24))]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4211
	var keep_out: Array = [Vector2(2.5, -8.7), Vector2(4.5, 4.5), Vector2(-8.5, -5.0), Vector2(9.9, -6.05)]
	var keep_r: Array = [1.7, 1.1, 1.3, 1.3]
	var placed := 0
	var tries := 0
	while placed < 14 and tries < 60:
		tries += 1
		var cx := rng.randf_range(-12.2, 12.2)
		var cz := rng.randf_range(-9.2, 9.5)
		var bad := false
		for i in keep_out.size():
			if Vector2(cx - keep_out[i].x, cz - keep_out[i].y).length() < keep_r[i]:
				bad = true
		if bad:
			continue
		placed += 1
		for b in 3:
			var blade := MeshInstance3D.new()
			blade.mesh = blade_mesh
			blade.material_override = blade_mats[rng.randi() % blade_mats.size()]
			blade.position = Vector3(cx + rng.randf_range(-0.09, 0.09), 0.11, cz + rng.randf_range(-0.09, 0.09))
			blade.rotation = Vector3(rng.randf_range(-0.28, 0.28), rng.randf() * TAU, rng.randf_range(-0.28, 0.28))
			blade.scale = Vector3.ONE * rng.randf_range(0.75, 1.45)
			env.add_child(blade)
		if placed % 2 == 0:
			var dot := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.032
			sm.height = 0.064
			sm.radial_segments = 8
			sm.rings = 4
			dot.mesh = sm
			dot.material_override = _mat(Color(0.95, 0.88, 0.55) if placed % 4 == 0 else Color(0.9, 0.9, 0.92))
			dot.position = Vector3(cx + 0.14, 0.1, cz + 0.1)
			env.add_child(dot)
	# (The plain south hedge line that used to sit here was
	# replaced by the wild-rose thorn hedge, _build_rose_hedge.)
	# House trim.
	_box(env, Vector3(0.12, 2.2, 0.14), Vector3(1.92, 1.32, -9.94), trim) # door jambs
	_box(env, Vector3(0.12, 2.2, 0.14), Vector3(3.08, 1.32, -9.94), trim)
	_box(env, Vector3(1.28, 0.12, 0.14), Vector3(2.5, 2.44, -9.94), trim) # lintel
	for wx: float in [-4.5, 6.5]:
		_box(env, Vector3(1.6, 0.07, 0.16), Vector3(wx, 1.32, -9.95), trim) # sill
		_box(env, Vector3(0.05, 0.9, 0.13), Vector3(wx, 1.9, -9.96), trim) # muntins
		_box(env, Vector3(1.3, 0.05, 0.13), Vector3(wx, 1.9, -9.96), trim)
	for sx: float in [-1.0, 1.0]:
		_box(env, Vector3(0.18, 3.4, 0.1), Vector3(sx * 8.45, 1.7, -9.96), trim) # corner boards
	_box(env, Vector3(17.6, 0.18, 0.06), Vector3(0, 3.38, -9.32), trim) # eaves fascia
	_box(env, Vector3(0.12, 1.5, 0.12), Vector3(0.0, 0.99, -7.55), wood_dark) # porch posts
	_box(env, Vector3(0.12, 1.5, 0.12), Vector3(5.0, 0.99, -7.55), wood_dark)
	_box(env, Vector3(1.4, 0.12, 0.5), Vector3(2.5, 0.06, -7.12), Color(0.55, 0.42, 0.3)) # step



## A smooth ball in the kit idiom (one shared unit sphere, scaled).
var _ball_mesh: SphereMesh = null
var _thorn_mesh: CylinderMesh = null


func _ball(parent: Node3D, pos: Vector3, dia: Vector3, c: Color) -> MeshInstance3D:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 0.5
		_ball_mesh.height = 1.0
		_ball_mesh.radial_segments = 14
		_ball_mesh.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = _ball_mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


## One wild-rose bush (Daniel, 2026-10-25): a tangled dark-green
## mass, pale thorn spikes poking out of it, and rose-pink / red
## blooms that read at gameplay distance. Built from the yard's
## existing plant idiom (ellipsoid masses + sphere dots).
func _rose_bush(parent: Node3D, pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	if _thorn_mesh == null:
		_thorn_mesh = CylinderMesh.new()
		_thorn_mesh.top_radius = 0.0
		_thorn_mesh.bottom_radius = 0.03
		_thorn_mesh.height = 0.18
		_thorn_mesh.radial_segments = 5
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rng.randf() * TAU
	parent.add_child(g)
	var mass := Color(0.13, 0.27, 0.10)
	var mass2 := Color(0.18, 0.33, 0.13)
	_ball(g, Vector3(0, 0.52 * s, 0), Vector3(1.75, 1.1, 1.2) * s, mass)
	_ball(g, Vector3(0.38 * s, 0.78 * s, 0.14 * s), Vector3(1.2, 0.82, 0.9) * s, mass2)
	_ball(g, Vector3(-0.42 * s, 0.72 * s, -0.12 * s), Vector3(1.05, 0.75, 0.85) * s, mass)
	# Thorns: pale little spikes poking out of the mass.
	var thorn := Color(0.78, 0.74, 0.62)
	for i in 5:
		var a := rng.randf() * TAU
		var spike := MeshInstance3D.new()
		spike.mesh = _thorn_mesh
		spike.material_override = _mat(thorn)
		spike.position = Vector3(cos(a) * 0.8 * s, rng.randf_range(0.5, 1.05) * s, sin(a) * 0.55 * s)
		spike.rotation = Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
		g.add_child(spike)
	# Blooms: wild-rose pinks and reds, one pale-yellow accent.
	var pinks: Array[Color] = [Color(0.93, 0.36, 0.51), Color(0.84, 0.20, 0.28), Color(0.96, 0.58, 0.64), Color(0.98, 0.85, 0.55)]
	for i in 9:
		var a2 := rng.randf() * TAU
		var r := rng.randf_range(0.5, 0.88) * s
		var bp := Vector3(cos(a2) * r, rng.randf_range(0.6, 1.2) * s, sin(a2) * r * 0.68)
		_ball(g, bp, Vector3.ONE * rng.randf_range(0.11, 0.17), pinks[rng.randi() % pinks.size()])


## The Massey boundary hedge (Daniel, 2026-10-25): a dense thorn
## hedge of wild roses on the south, east and west edges, exactly
## where the fence stood. VISUAL ONLY — the boundary statics in
## _build_environment are unchanged, so the hedge is exactly as
## impassable as the fence was.
func _build_rose_hedge(env: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# South edge: two staggered rows (the boundary row, plus a
	# lower front row where the plain hedge used to sit).
	var x := -12.6
	while x <= 12.7:
		_rose_bush(env, Vector3(x, 0, 9.92), rng.randf_range(1.0, 1.18), rng)
		x += 1.68
	x = -11.8
	while x <= 12.0:
		_rose_bush(env, Vector3(x, 0, 9.42), rng.randf_range(0.78, 0.9), rng)
		x += 1.68
	# East and west edges: one dense row each.
	for side: float in [-1.0, 1.0]:
		var z := -9.4
		while z <= 9.5:
			_rose_bush(env, Vector3(12.95 * side, 0, z), rng.randf_range(1.02, 1.2), rng)
			z += 1.68


## Front-garden wild roses (Daniel, 2026-10-25): an ornamental bed
## of the same roses along the house's street face. No collision —
## the front-lawn statics are untouched and the crossing routes
## (door axis, driveway mouth, Corolla) stay clear.
func _build_front_roses(env: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 511
	_box(env, Vector3(14.2, 0.05, 1.15), Vector3(-1.9, 0.026, -11.32), Color(0.24, 0.19, 0.12))
	for bx: float in [-7.6, -5.4, -3.2, -1.0, 1.2, 4.4]:
		_rose_bush(env, Vector3(bx, 0.05, -11.32), rng.randf_range(0.8, 0.95), rng)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	VisualQuality.dress_sun(sun)
	add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.25, 0.46, 0.75)
	psm.sky_horizon_color = Color(0.72, 0.8, 0.88)
	psm.ground_bottom_color = Color(0.2, 0.24, 0.18)
	psm.ground_horizon_color = Color(0.72, 0.8, 0.88)
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.fog_enabled = true
	e.fog_light_color = Color(0.78, 0.84, 0.9)
	e.fog_density = 0.012
	VisualQuality.apply_environment(e, "yard")
	we.environment = e
	add_child(we)


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CamRig"
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = cam_dist
	_arm.collision_mask = 1
	_arm.margin = 0.22
	_rig.add_child(_arm)
	var cam := Camera3D.new()
	cam.name = "GameCam"
	cam.current = true
	cam.fov = 55.0
	_arm.add_child(cam)
	_feel = CameraFeel.new()
	_feel.name = "CameraFeel"
	add_child(_feel)
	_feel.bind(self, _arm, cam)
	_rig.global_position = cat.global_position + Vector3(0, 0.3, 0)
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.visible = false
	_hud_layer = layer
	add_child(layer)
	var chip := PanelContainer.new()
	chip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chip.offset_left = 12
	chip.offset_top = 10
	chip.offset_right = 196
	chip.offset_bottom = 78
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = Color(0.06, 0.05, 0.06, 0.5)
	chip_box.set_corner_radius_all(8)
	chip_box.content_margin_left = 10
	chip_box.content_margin_right = 10
	chip_box.content_margin_top = 6
	chip_box.content_margin_bottom = 6
	chip.add_theme_stylebox_override("panel", chip_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(col)
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.text = "%d mice · %d lives" % [MOUSE_COUNT, lives]
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	col.add_child(_status)
	_hp_bar = _thin_bar(col, Color(0.82, 0.34, 0.3))
	_hp_bar.visible = false
	_prov_bar = _thin_bar(col, Color(0.95, 0.62, 0.28))
	_prov_bar.visible = false
	layer.add_child(chip)
	_confirm = Label.new()
	_confirm.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_confirm.offset_left = -280
	_confirm.offset_right = 280
	_confirm.offset_top = 18
	_confirm.offset_bottom = 52
	_confirm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.add_theme_font_size_override("font_size", 18)
	_confirm.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	_confirm.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_confirm.add_theme_constant_override("shadow_offset_x", 1)
	_confirm.add_theme_constant_override("shadow_offset_y", 1)
	_confirm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.visible = false
	layer.add_child(_confirm)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 120
	_banner.offset_bottom = 220
	_banner.visible = false
	layer.add_child(_banner)


func _thin_bar(parent: Node, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 6)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


# --- game --------------------------------------------------------------------

func _spawn_mice() -> void:
	for i in MOUSE_COUNT:
		_spawn_one_mouse()


func _spawn_one_mouse() -> void:
	_mouse_seq += 1
	var m: PvKMouse = MouseScene.new()
	m.name = "Mouse%d" % _mouse_seq
	add_child(m)
	var pos := Vector3(_rng.randf_range(-10.0, 11.0), 0, _rng.randf_range(-6.0, 8.5))
	m.global_position = pos
	m.home = pos
	m.bounds = YARD
	m.cat = cat
	m.rotation.y = _rng.randf() * TAU
	m.was_caught.connect(_on_mouse_caught)
	mice.append(m)


## DUO: Aggie's flurry makes Willie DROP a catch — the counter ticks
## down by one (min 0) and the mouse escapes back into the yard, so
## the total stays catchable and the win stays reachable. Annoying,
## not punishing.
func drop_caught_mouse() -> void:
	if won or caught_count <= 0:
		return
	caught_count -= 1
	_spawn_one_mouse()


func attempt_strike() -> void:
	if not won and not run_over:
		cat.strike()


func _on_touch_strike() -> void:
	if duo != null and duo.input_locked():
		return
	_face_swipe()
	attempt_strike()


func _on_touch_pounce() -> void:
	if duo != null and duo.input_locked():
		return
	_aim_nearest_mouse()
	_jump_or_pounce()


func _on_touch_meow() -> void:
	if run_over:
		return
	if duo != null and duo.input_locked():
		return
	if night != null and night.blocks_move():
		return
	if duo != null:
		duo.player_meow()


func _face_swipe() -> void:
	if _touch == null or cat == null:
		return
	var swipe := _touch.swipe_dir
	if swipe.length() < 0.25:
		return
	var world := _cam_relative(Vector2(swipe.x, -swipe.y))
	if world.length() < 0.05:
		return
	cat.rotation.y = TouchControls3D.yaw_to_face(world)


func _aim_nearest_mouse() -> void:
	if cat == null:
		return
	var best := Vector3.ZERO
	var best_d := 3.4
	var found := false
	for m: Variant in mice:
		if not is_instance_valid(m):
			continue
		var mouse := m as Node3D
		if mouse.get("state") == "caught":
			continue
		var d := cat.global_position.distance_to(mouse.global_position)
		if d < best_d:
			best_d = d
			best = mouse.global_position
			found = true
	if not found:
		return
	var to := best - cat.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	cat.rotation.y = TouchControls3D.yaw_to_face(to)


func _on_look_drag(relative: Vector2) -> void:
	var y_sign := 1.0 if look_invert else -1.0
	cam_yaw -= relative.x * 0.005 * look_sens
	cam_pitch = clampf(cam_pitch + y_sign * relative.y * 0.004 * look_sens, -1.15, -0.08)


func _on_paw_swiped() -> void:
	CombatDirector.check_paw_hits(get_tree(), cat)
	var pp := cat.paw_point()
	for m: Variant in mice:
		if not is_instance_valid(m):
			continue
		var mouse := m as PvKMouse
		if mouse.state == "caught":
			continue
		var d := Vector2(mouse.global_position.x - pp.x, mouse.global_position.z - pp.z).length()
		if d <= catch_radius: # DUO: the provoked buff widens this
			mouse.get_caught()


func _on_mouse_caught(_m: PvKMouse) -> void:
	caught_count += 1
	if caught_count >= MOUSE_COUNT and not won:
		won = true
		_banner.text = "All mice caught in %.1f s!\nWillie approves. Press R twice to play again." % elapsed
		_banner.visible = true
		cat.set_lounge(true) # victory flop, Willie style


func restart_game() -> void:
	get_tree().reload_current_scene()


## R asks first. A second R, or two fingers held still, starts over.
func _arm_restart() -> void:
	if _restart_left > 0.0:
		restart_game()
		return
	_restart_left = 2.6
	if _confirm != null:
		_confirm.text = "Press R again to start the night over"
		_confirm.visible = true


## MASSEY: Space / POUNCE — jump on the ground, pounce mid-air.
func _jump_or_pounce() -> void:
	if won or run_over or cat == null:
		return
	if duo != null and duo.input_locked():
		return
	if night != null and night.blocks_move():
		return
	if cat.is_on_floor():
		cat.jump()
	else:
		cat.pounce()


# --- Massey zones + occupants -----------------------------------------------------
# Assembly lives in the module now (module/massey_module.gd, §9):
# _ready creates MasseyModule, which instances the zones, the
# ZoneManager, the objectives registry and the occupants. What
# remains here is the host's side of the §9.3 interface: the zone
# hook below and the outside zone root API under it.

## GLENYS moves into the ground floor: Daniel's mother, cane and
## all. She notices the cats once they come into HER house — after
## that she follows them anywhere (see glenys/glenys_system.gd).
func _build_glenys() -> void:
	var actor := GlenysScript.new() as Glenys
	actor.name = "Glenys"
	add_child(actor)
	var home := HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR) + Vector3(-6.8, 0.0, 3.1)
	actor.place_at(home, PI * 0.75)
	glenys = GlenysSystemScript.new() as GlenysSystem
	glenys.name = "GlenysSystem"
	add_child(glenys)
	glenys.setup(self, actor)
	objectives.declare("glenys:escape_artist", HouseSpec.GROUND_FLOOR, "Escape Glenys x3", 3)


## POISON — the run-ending death, and the ONLY one. It routes here
## solely from the cat's own eat_poison (her chocolate, eaten on
## purpose; the basement rat poison, gotten into) — never from
## damage. No life is spent and there is no hub respawn: the run
## is over. R restarts. (The nine-lives faint flow is untouched.)
func _on_cat_poisoned(c: PvKCat, source: String) -> void:
	if run_over or c != cat:
		return # only the playable cat's poisoning ends the run
	run_over = true
	duo_shake = Vector3.ZERO
	if source == "chocolate":
		_banner.text = "The chocolate was poison, just as warned.\nGlenys only meant it as a treat — she's beside herself.\nRun over. Press R twice to play again."
	else:
		_banner.text = "Into the old rat poison — no coming back from that.\nRun over. Press R twice to play again."
	_banner.visible = true
	_banner_t = 0.0



func _indoors() -> bool:
	return zones != null and zones.current_zone != "" and zones.current_zone != HouseSpec.OUTSIDE


## Over the shoulder, about at his eyes, when the room is the frame.
## The stored yard pitch and distance stay put for the door back out.
func _camera_target() -> Vector3:
	if cam_anchor != null:
		return cam_anchor.global_position
	var pivot := 0.58 if _indoors() else 0.30
	var shoulder := Vector3.ZERO
	if _indoors() and _rig != null:
		var right := _rig.global_transform.basis.x
		right.y = 0.0
		if right.length() > 0.001:
			shoulder = right.normalized() * 0.28
	return cat.global_position + Vector3(0, pivot, 0) + shoulder + duo_shake


## Positive indoor pitch lowers the lens and looks up into the hoard.
## cam_pitch itself stays the yard angle.
func _arm_pitch() -> float:
	if _indoors():
		return clampf(cam_pitch + 0.60, 0.04, 0.22)
	return cam_pitch


func _arm_length() -> float:
	if _indoors():
		return clampf(indoor_zoom, INDOOR_NEAR, INDOOR_FAR)
	return cam_dist


func snap_camera() -> void:
	if _rig == null or _arm == null or cat == null:
		return
	_rig.global_position = _camera_target()
	_arm.rotation.x = _arm_pitch()
	_arm.spring_length = _arm_length()


func on_zone_changed(zone_id: String) -> void:
	snap_camera()
	if duo != null and module != null and module.zone_root(zone_id) != null:
		duo.relocate_sibling(module.zone_root(zone_id))


# The outside zone root API (interior zones: zones/zone_root.gd).
func get_entry(entry_name: String) -> Node3D:
	return get_node_or_null(entry_name) as Node3D


func get_lounge_spots() -> Array:
	return DuoSystem.LOUNGE_SPOTS.duplicate()


func get_wander_rect() -> Rect2:
	return HouseSpec.wander_rect(HouseSpec.OUTSIDE)


func mice_left() -> int:
	return MOUSE_COUNT - caught_count


# --- input + loop ------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_apply_hud()
	var dir := Vector3.ZERO
	var sprint := false
	var stalk := false
	if bool(input_override["active"]):
		var mv: Vector2 = input_override["move"]
		dir = _cam_relative(mv)
		sprint = bool(input_override["sprint"])
		stalk = bool(input_override["stalk"])
	else:
		var ix := 0.0
		var iz := 0.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			ix -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			ix += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			iz += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			iz -= 1.0
		var stick := _touch.move_vector()
		if stick.length() > 0.12:
			ix = stick.x
			iz = -stick.y
		dir = _cam_relative(Vector2(ix, iz))
		sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		stalk = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
		if _touch != null and _touch.stalk_held:
			stalk = true
		# DUO: while the character select is up, the cat waits.
		# (The input_override seam above is deliberately not locked:
		# the smoke test drives straight through it.)
		if duo != null and duo.input_locked():
			dir = Vector3.ZERO
		if run_over or (night != null and night.blocks_move()):
			# Poison, or the night card / the ending. The override
			# above is left alone so the suites can still walk.
			dir = Vector3.ZERO
			sprint = false
			stalk = false
	cat.set_move_input(dir, sprint, stalk)


func _cam_relative(mv: Vector2) -> Vector3:
	if mv.length() < 0.05:
		return Vector3.ZERO
	var b := _rig.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	var d := right * mv.x + fwd * mv.y
	if d.length() > 1.0:
		d = d.normalized()
	return d


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_SPACE: # MASSEY: jump on the ground, pounce mid-air
					_jump_or_pounce()
				KEY_F:
					attempt_strike()
				KEY_L:
					cat.toggle_lounge()
				KEY_M: # DUO: meow (provoke responsibly)
					if duo != null:
						duo.player_meow()
				KEY_R:
					_arm_restart()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _indoors():
				indoor_zoom = clampf(indoor_zoom - 0.18, INDOOR_NEAR, INDOOR_FAR)
			else:
				cam_dist = clampf(cam_dist - 0.5, 2.2, 9.0)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _indoors():
				indoor_zoom = clampf(indoor_zoom + 0.18, INDOOR_NEAR, INDOOR_FAR)
			else:
				cam_dist = clampf(cam_dist + 0.5, 2.2, 9.0)


## Paw, corner chip, and compass stay off the cat picker, the night
## card, and the pause menu. Play brings them back.
func _hud_covered() -> bool:
	if pause_menu != null and pause_menu.open:
		return true
	if duo != null and duo.input_locked():
		return true
	if night != null and night.blocks_move():
		return true
	return false


func _apply_hud() -> void:
	var cover := _hud_covered()
	if _hud_layer != null:
		_hud_layer.visible = not cover
	if _touch != null:
		_touch.set_blocked(cover)
	if cover and night != null:
		var comp := night.compass()
		if comp != null:
			comp.visible = false


func _process(delta: float) -> void:
	_apply_hud()
	if not won and not run_over:
		elapsed += delta
	var target := _camera_target()
	_rig.global_position = _rig.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	_rig.rotation.y = cam_yaw
	var length := _arm_length()
	_arm.rotation.x = _arm_pitch()
	_arm.spring_length = length
	if _feel != null:
		_feel.apply(length)
	if _restart_left > 0.0:
		_restart_left = maxf(0.0, _restart_left - delta)
		if _restart_left <= 0.0 and _confirm != null:
			_confirm.visible = false
	if _status != null:
		var line := "%d mice · %d lives" % [mice_left(), lives]
		if objectives != null and objectives.score > 0:
			line += " · %d" % objectives.score
		_status.text = line
	if objectives != null:
		objectives.set_progress("outside:mice", caught_count)
	if _hp_bar != null and cat != null and cat.max_hp > 0.0:
		var frac := 100.0 * cat.hp / cat.max_hp
		_hp_bar.value = frac
		_hp_bar.visible = frac < 98.0
	if _prov_bar != null:
		var meter := 0.0
		if duo != null and duo.prov != null:
			meter = duo.prov.meter
		_prov_bar.value = meter
		_prov_bar.visible = meter > 2.0
	# The faint flow: flop for a beat, then wake up at the hub with
	# a life spent. Never a game-over — cats have nine (and spares).
	if cat != null and cat.is_fainted:
		_faint_t += delta
		if _faint_t >= 1.5 and zones != null and not zones.travelling:
			_faint_t = -1.0
			lives -= 1
			var fresh := false
			if lives < 0:
				lives = 9
				fresh = true
			zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor")
			cat.heal_full()
			if not won:
				_banner.text = ("%s used up all nine?! A fresh set of lives, then." % cat.species_name) if fresh else ("Oof — %s shakes it off at home. Lives x %d" % [cat.species_name, lives])
				_banner.visible = true
				_banner_t = 2.4
	elif _faint_t > 0.0:
		_faint_t = -1.0
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0 and not won:
			_banner.visible = false
