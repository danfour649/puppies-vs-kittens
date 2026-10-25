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
var _faint_t := -1.0
var _banner_t := 0.0
var _lbl_hp: Label
var _hp_bar: ProgressBar
var _lbl_lives: Label
var outside: OutsideSystem = null # OUTSIDE
var occupants: OccupantSystem = null # OCCUPANTS (hub)
var glenys: GlenysSystem = null # GLENYS (the cat-chaser)
var run_over := false # POISON: a poison death ends the run (no respawn)
var catch_radius := 0.62
var duo_shake := Vector3.ZERO
var _mouse_seq := 0

var cam_yaw := PI
var cam_pitch := -0.48
var cam_dist := 4.6

## Smoke-test seam: when active, physics input comes from here.
var input_override := {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}

var _rig: Node3D
var _arm: SpringArm3D
var _lbl_left: Label
var _lbl_caught: Label
var _lbl_time: Label
var _banner: Label
var _touch: TouchControls3D
var _dragging := false
## Shots seam: when set, the camera rig tracks this node instead of the cat.
var cam_anchor: Node3D = null
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func _ready() -> void:
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
	_touch.strike_pressed.connect(attempt_strike)
	_touch.pounce_pressed.connect(_jump_or_pounce)
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
	# Fence: posts + two rails on the south, east and west edges.
	for side: int in [-1, 1]:
		var x := 13.0 * side
		for zi in range(-10, 11, 2):
			_box(env, Vector3(0.14, 1.15, 0.14), Vector3(x, 0.57, float(zi)), wood_dark)
		_box(env, Vector3(0.06, 0.12, 20.4), Vector3(x, 0.85, 0), wood)
		_box(env, Vector3(0.06, 0.12, 20.4), Vector3(x, 0.4, 0), wood)
	for zi in range(-12, 13, 2):
		_box(env, Vector3(0.14, 1.15, 0.14), Vector3(float(zi), 0.57, 10.0), wood_dark)
	_box(env, Vector3(26.4, 0.12, 0.06), Vector3(0, 0.85, 10.0), wood)
	_box(env, Vector3(26.4, 0.12, 0.06), Vector3(0, 0.4, 10.0), wood)
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
	_static_box(statics, Vector3(6.4, 0.24, 2.6), Vector3(2.5, 0.12, -8.7))
	_static_box(statics, Vector3(0.5, 2.6, 0.5), Vector3(-8.5, 1.3, -5.0))
	_static_box(statics, Vector3(2.4, 1.5, 1.2), Vector3(9.9, 0.75, -6.05))
	_static_box(statics, Vector3(0.7, 0.46, 0.7), CHAIR_SEAT + Vector3(0, -0.23, 0))
	_dress_yard(env)


## REALISM PASS 1 dressing: grass tufts + flower dots, a hedge line
## inside the south fence, and the house's exterior trim (door frame,
## window sills + muntins, corner boards, eaves fascia, porch posts).
## Visual only — no statics, no layout or HouseSpec changes.
func _dress_yard(env: Node3D) -> void:
	var trim := Color(0.92, 0.9, 0.85)
	var wood_dark := Color(0.42, 0.31, 0.21)
	var hedge := Color(0.16, 0.32, 0.12)
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
	# South-fence hedge line (inside the fence, slight height jitter).
	for i in 9:
		_box(env, Vector3(2.55, 0.5 + 0.08 * sin(i * 2.3), 0.5), Vector3(-11.0 + i * 2.75, 0.27, 9.55), hedge.darkened(0.05 * (i % 3)))
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


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
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
	we.environment = e
	add_child(we)


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CamRig"
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = cam_dist
	_arm.margin = 0.25
	_rig.add_child(_arm)
	var cam := Camera3D.new()
	cam.fov = 55.0
	_arm.add_child(cam)
	_rig.global_position = cat.global_position + Vector3(0, 0.3, 0)
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_lbl_left = _hud_label(layer, "Mice Left: %d" % MOUSE_COUNT, Vector2(18, 12))
	_lbl_caught = _hud_label(layer, "Caught: 0", Vector2(18, 48))
	_lbl_time = _hud_label(layer, "Time: 0.0", Vector2(18, 84))
	_lbl_hp = _hud_label(layer, "HP", Vector2(18, 176))
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(62, 182)
	_hp_bar.size = Vector2(150, 14)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0, 0, 0, 0.55)
	hp_bg.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.30, 0.25)
	hp_fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	layer.add_child(_hp_bar)
	_lbl_lives = _hud_label(layer, "Lives x 9", Vector2(224, 176))
	var restart := Button.new()
	restart.text = "RESTART"
	restart.add_theme_font_size_override("font_size", 22)
	restart.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	restart.offset_left = -150
	restart.offset_right = -18
	restart.offset_top = 12
	restart.offset_bottom = 58
	restart.pressed.connect(restart_game)
	layer.add_child(restart)
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


func _hud_label(parent: Node, text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


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
		_banner.text = "All mice caught in %.1f s!\nWillie approves. Press R to play again." % elapsed
		_banner.visible = true
		cat.set_lounge(true) # victory flop, Willie style


func restart_game() -> void:
	get_tree().reload_current_scene()


## MASSEY: Space / POUNCE — jump on the ground, pounce mid-air.
func _jump_or_pounce() -> void:
	if won or run_over or cat == null:
		return
	if duo != null and duo.input_locked():
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
		_banner.text = "The chocolate was poison, just as warned.\nGlenys only meant it as a treat — she's beside herself.\nRun over. Press R to play again."
	else:
		_banner.text = "Into the old rat poison — no coming back from that.\nRun over. Press R to play again."
	_banner.visible = true
	_banner_t = 0.0



func snap_camera() -> void:
	if _rig != null and cat != null:
		_rig.global_position = cat.global_position + Vector3(0, 0.3, 0)


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
		# DUO: while the character select is up, the cat waits.
		# (The input_override seam above is deliberately not locked:
		# the smoke test drives straight through it.)
		if duo != null and duo.input_locked():
			dir = Vector3.ZERO
		if run_over: # POISON: the run is over; the cat goes nowhere.
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
					restart_game()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.5, 2.2, 9.0)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.5, 2.2, 9.0)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.005
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.004, -1.15, -0.08)


func _process(delta: float) -> void:
	if not won and not run_over:
		elapsed += delta
	var target := cat.global_position + Vector3(0, 0.3, 0) + duo_shake # DUO shake
	if cam_anchor != null:
		target = cam_anchor.global_position
	_rig.global_position = _rig.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch
	_arm.spring_length = cam_dist
	_lbl_left.text = "Mice Left: %d" % mice_left()
	_lbl_caught.text = "Caught: %d" % caught_count
	_lbl_time.text = "Time: %.1f" % elapsed
	if objectives != null:
		objectives.set_progress("outside:mice", caught_count)
	if _hp_bar != null and cat != null and cat.max_hp > 0.0:
		_hp_bar.value = 100.0 * cat.hp / cat.max_hp
		_lbl_lives.text = "Lives x %d" % lives
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
