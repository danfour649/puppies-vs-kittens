class_name OutsideSystem
extends Node
## Willie and Aggie — the MASSEY OUTSIDE zone. Hangs off main.gd
## exactly like the duo system does (one marked block in _ready):
## main stays boss of the back yard (mice, camera, win); this node
## adds everything outside the fence line of the original diorama:
##
##   * 3 climbable trees + squirrels (forage / flee / climb /
##     taunt / descend) in the back yard
##   * the bird feeder and its endless bird stream, 3 ambush
##     bushes, and the stillness-meter ambush game
##   * the front of the house: front lawn, sidewalk, Massey
##     Street with two-way traffic whose drivers AIM at a cat on
##     the road (bounded swerve + horn telegraph), the parked
##     silver Corolla as a safe island, and a full-heal fish
##     treat across the street
##   * pedestrians walking dogs on the sidewalk: heel -> alert ->
##     strain (human skidding) -> leash slip -> chase, with tree /
##     bush / region / outrun escape valves and a grab-and-shake
##
## Placements are ALL in outside_layout.gd (named constants
## relative to the house footprint). Damage goes through
## apply_damage(): the ledger values live in OutsideLayout
## (DMG_*, percents of a life) and INTEGRATION forwards every hit
## to the foundation cat, which owns real HP/nine-lives (vehicles
## via the CombatData profile). Climb entry is the cat's real paw
## (a strike or pounce at a trunk — _on_player_paw); the climb
## itself and the vehicle launch stay pin/arc harnesses by
## design: while one is active, this system drives the cat and
## the cat's own physics sleeps.

const SquirrelScene := preload("res://zones/outside/squirrel.gd")
const BirdScene := preload("res://zones/outside/bird.gd")
const TreeScene := preload("res://zones/outside/yard_tree.gd")
const CarScene := preload("res://zones/outside/car.gd")
const WalkerScene := preload("res://zones/outside/walker.gd")
const DogScene := preload("res://zones/outside/dog.gd")

const CAR_COLOURS := [Color(0.62, 0.16, 0.14), Color(0.16, 0.3, 0.55), Color(0.75, 0.72, 0.68), Color(0.2, 0.45, 0.3), Color(0.55, 0.4, 0.65), Color(0.85, 0.6, 0.15)]

var game: Node = null

# --- world handles (tests + shots read these) -------------------------
var trees: Array = []
var squirrels: Array = []
var birds: Array = []
var cars: Array = []
var walker: PvKWalker = null
var dog: PvKDog = null
var zone_root: Node3D

# --- ambush state ------------------------------------------------------
var stillness := 0.0
var birds_caught := 0
var ambush_catches := 0
var squirrels_treed := 0
var squirrels_caught := 0

# --- damage ledger (LOCAL contract; foundation reconciles) -------------
var hp := OutsideLayout.CAT_HP_MAX
var lives_lost := 0
var last_damage := 0.0
var last_damage_kind := ""
var damage_log: Array = []

# --- road state ----------------------------------------------------------
var crossings_total := 0
var crossings_this_life := 0
var dog_escapes := 0

# --- objectives -----------------------------------------------------------
var objectives := {
	"first_bird": {"title": "First bird", "target": 1, "progress": 0, "done": false},
	"squirrel_treed": {"title": "Squirrel treed x3", "target": 3, "progress": 0, "done": false},
	"ambush_master": {"title": "Ambush master: 3 pounce catches", "target": 3, "progress": 0, "done": false},
	"cross_massey_back": {"title": "Cross Massey and back", "target": 1, "progress": 0, "done": false},
	"highway_cat": {"title": "Highway cat: 3 crossings in one life", "target": 3, "progress": 0, "done": false},
	"dog_dodger": {"title": "Dog dodger: escape 3 chases", "target": 3, "progress": 0, "done": false},
	"cool_cat": {"title": "Cool cat: pass a fully-straining dog, no slip", "target": 1, "progress": 0, "done": false},
}

# --- test seams ------------------------------------------------------------
var catch_roll_override := -1.0 ## >= 0: force the trunk-pounce roll
var climb_axis_debug := 0.0 ## tests drive the climb with this

var _rng := RandomNumberGenerator.new()
var _wired_cat: PvKCat = null
var _last_meow_count := 0
var _bird_spawn_t := 1.2
var _car_spawn_t := 2.0
var _walker_t := 9.0 ## first walker comes sooner, so the system is discoverable
var _bite_cd := 0.0
var _cat_iframes := 0.0
var _bites: Array = [] ## recent bite times (grab window), current chase only
var _band := "back"
var _went_far := false
var _shake_t := 0.0
var _toast_t := 0.0
var _time := 0.0
var _respawns: Array = [] ## {tree, t}
var _feeder_perches: Array = [] ## {pos, bird}
var _treat_active := true
var _treat_t := 0.0
var _treat_node: Node3D

# control stub (climb / launch): see header
var _control := {"active": false, "kind": "", "cat": null, "tree": null, "side": Vector3.RIGHT, "y": 0.0, "t": 0.0, "dur": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "arc": 0.0}

var _hud_layer: CanvasLayer
var _still_label: Label
var _still_bar: ProgressBar
var _toast_label: Label
var _road_label: Label
var _mats := {}
var _meshes := {}


func setup(game_node: Node) -> void:
	game = game_node
	_rng.randomize()
	zone_root = Node3D.new()
	zone_root.name = "OutsideZone"
	game.add_child(zone_root)
	_build_frontage()
	_build_corolla()
	_build_fish_treat()
	_build_trees()
	_build_feeder()
	_build_bushes()
	_spawn_squirrels()
	_build_hud()
	if game.get("duo") != null:
		_last_meow_count = int(game.duo.get("meow_count"))


func player_cat() -> PvKCat:
	if game == null:
		return null
	return game.get("cat") as PvKCat


func player_id() -> String:
	if game != null and game.get("duo") != null:
		return String(game.duo.player_id())
	return "willie"


# --- construction ---------------------------------------------------------

func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.95) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _static(parent: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


func _build_frontage() -> void:
	var grass := Color(0.32, 0.5, 0.22)
	var grass_far := Color(0.27, 0.43, 0.19)
	var concrete := Color(0.62, 0.62, 0.60)
	var asphalt := Color(0.15, 0.15, 0.16)
	var hedge := Color(0.16, 0.32, 0.12)
	var env := Node3D.new()
	env.name = "Frontage"
	zone_root.add_child(env)
	# Front lawn (top a hair under y=0 to avoid z-fighting the
	# back lawn's edge), sidewalk, street, far side.
	_box(env, Vector3(26.4, 0.18, 2.9), Vector3(0, -0.095, -11.85), grass)
	_box(env, Vector3(36.0, 0.06, 0.9), Vector3(0, -0.03, -13.65), concrete)
	_box(env, Vector3(36.0, 0.06, 5.6), Vector3(0, -0.031, -16.9), asphalt)
	_box(env, Vector3(36.0, 0.06, 0.9), Vector3(0, -0.03, -20.15), concrete)
	_box(env, Vector3(36.0, 0.18, 3.0), Vector3(0, -0.095, -22.1), grass_far)
	# Neighbour lawns beyond the lot-line hedges (scenery).
	_box(env, Vector3(5.0, 0.18, 2.9), Vector3(-15.7, -0.095, -11.85), grass_far)
	_box(env, Vector3(5.0, 0.18, 2.9), Vector3(15.7, -0.095, -11.85), grass_far)
	# Centre-line dashes.
	for xi in range(-17, 18, 3):
		_box(env, Vector3(1.4, 0.012, 0.14), Vector3(float(xi), 0.006, OutsideLayout.LANE_CENTRE_Z), Color(0.8, 0.72, 0.4))
	# Driveway: house to street, on the east side.
	_box(env, Vector3(2.6, 0.07, 3.8), Vector3(7.2, -0.031, -12.25), Color(0.32, 0.32, 0.33))
	# Lot-line hedges at the front + the far hedge closing the world.
	for sx: float in [-13.45, 13.45]:
		_box(env, Vector3(0.5, 0.9, 2.9), Vector3(sx, 0.45, -11.85), hedge)
	_box(env, Vector3(36.0, 1.1, 0.5), Vector3(0, 0.55, -23.5), hedge)
	for sx: float in [-17.8, 17.8]:
		_box(env, Vector3(0.6, 1.2, 10.6), Vector3(sx, 0.6, -18.5), hedge)
	# Statics: grounds and blockers.
	var statics := StaticBody3D.new()
	statics.name = "OutsideStatics"
	zone_root.add_child(statics)
	_static(statics, Vector3(36.4, 0.2, 2.9), Vector3(0, -0.1, -11.85)) # front lawn, full width (neighbour lawns included — no falling off the world at the street ends)
	_static(statics, Vector3(36.0, 0.2, 10.6), Vector3(0, -0.1, -18.5)) # sidewalk+street+far slab
	_static(statics, Vector3(0.5, 1.0, 2.9), Vector3(-13.45, 0.5, -11.85))
	_static(statics, Vector3(0.5, 1.0, 2.9), Vector3(13.45, 0.5, -11.85))
	_static(statics, Vector3(36.0, 1.2, 0.6), Vector3(0, 0.6, -23.6))
	_static(statics, Vector3(0.6, 1.2, 10.6), Vector3(-17.8, 0.6, -18.5))
	_static(statics, Vector3(0.6, 1.2, 10.6), Vector3(17.8, 0.6, -18.5))
	# REALISM PASS 1 dressing: road wear patches, worn edge lines,
	# sidewalk cracks, front-lawn tufts, hedge-top jitter. Visual only.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 6:
		var wc: Color = asphalt.lightened(0.05) if i % 2 == 0 else asphalt.darkened(0.18)
		_box(env, Vector3(rng.randf_range(1.2, 2.8), 0.008, rng.randf_range(0.8, 1.7)), Vector3(rng.randf_range(-16.0, 16.0), 0.004, rng.randf_range(-18.6, -15.2)), wc)
	for ez: float in [-14.35, -19.45]:
		var ex := -17.0
		var seg := 0
		while ex < 16.0:
			if seg % 3 != 2: # the worn gaps in the paint
				_box(env, Vector3(3.0, 0.01, 0.11), Vector3(ex + 1.5, 0.005, ez), Color(0.72, 0.70, 0.62))
			ex += 4.4
			seg += 1
	for i in 5:
		_box(env, Vector3(0.05, 0.012, 0.86), Vector3(rng.randf_range(-15.0, 15.0), 0.002, -13.65), Color(0.4, 0.4, 0.38))
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = 0.0
	blade_mesh.bottom_radius = 0.018
	blade_mesh.height = 0.24
	blade_mesh.radial_segments = 5
	var blade_mats: Array = [_mat(Color(0.26, 0.44, 0.18)), _mat(Color(0.36, 0.55, 0.24))]
	for c in 8:
		var cx := rng.randf_range(-12.0, 12.0)
		if absf(cx - 7.2) < 1.9:
			cx += 4.0 # keep the driveway mouth clear
		var cz := rng.randf_range(-13.1, -12.7)
		for b in 3:
			var blade := MeshInstance3D.new()
			blade.mesh = blade_mesh
			blade.material_override = blade_mats[rng.randi() % blade_mats.size()]
			blade.position = Vector3(cx + rng.randf_range(-0.08, 0.08), 0.10, cz + rng.randf_range(-0.08, 0.08))
			blade.rotation = Vector3(rng.randf_range(-0.28, 0.28), rng.randf() * TAU, rng.randf_range(-0.28, 0.28))
			blade.scale = Vector3.ONE * rng.randf_range(0.75, 1.4)
			env.add_child(blade)
	for sx: float in [-13.45, 13.45]:
		for i in 2:
			_box(env, Vector3(0.56, 0.2, 0.95), Vector3(sx, 0.98, -12.4 + i * 1.3), hedge.lightened(0.06))


func _build_corolla() -> void:
	# The parked, indestructible silver 2018 Corolla (house lore,
	# from TODO #97): driveway furniture and a mid-crossing island.
	var silver := Color(0.78, 0.79, 0.81)
	var glass := Color(0.13, 0.16, 0.2)
	var g := Node3D.new()
	g.name = "Corolla"
	g.position = OutsideLayout.COROLLA_POS
	g.rotation.y = 0.04
	zone_root.add_child(g)
	_box(g, Vector3(1.7, 0.55, 3.6), Vector3(0, 0.55, 0), silver, Vector3.ZERO, 0.3)
	_box(g, Vector3(1.5, 0.48, 1.8), Vector3(0, 1.04, 0.1), glass, Vector3.ZERO, 0.15)
	_box(g, Vector3(1.54, 0.09, 0.8), Vector3(0, 1.3, 0.1), silver, Vector3.ZERO, 0.3)
	for sx: float in [-0.62, 0.62]:
		_box(g, Vector3(0.3, 0.12, 0.05), Vector3(sx, 0.6, -1.81), Color(1.0, 0.95, 0.7), Vector3.ZERO, 0.2)
	for sx: float in [-0.82, 0.82]:
		for sz: float in [-1.2, 1.2]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.32
			wm.bottom_radius = 0.32
			wm.height = 0.2
			wm.radial_segments = 14
			var w := MeshInstance3D.new()
			w.mesh = wm
			w.material_override = _mat(Color(0.08, 0.08, 0.09), 0.9)
			w.position = Vector3(sx, 0.32, sz)
			w.rotation.z = PI * 0.5
			g.add_child(w)
	var statics := StaticBody3D.new()
	statics.name = "CorollaBody"
	zone_root.add_child(statics)
	_static(statics, Vector3(1.7, 0.95, 3.6), Vector3(OutsideLayout.COROLLA_POS.x, 0.48, OutsideLayout.COROLLA_POS.z))


func _build_fish_treat() -> void:
	_treat_node = Node3D.new()
	_treat_node.name = "FishTreat"
	_treat_node.position = OutsideLayout.FISH_TREAT_POS
	zone_root.add_child(_treat_node)
	var plate := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.3
	pm.bottom_radius = 0.24
	pm.height = 0.045
	pm.radial_segments = 18
	plate.mesh = pm
	plate.material_override = _mat(Color(0.92, 0.92, 0.94), 0.4)
	plate.position = Vector3(0, 0.03, 0)
	_treat_node.add_child(plate)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	var fish := MeshInstance3D.new()
	fish.mesh = sm
	fish.material_override = _mat(Color(0.65, 0.72, 0.78), 0.35)
	fish.scale = Vector3(0.17, 0.09, 0.44)
	fish.position = Vector3(0, 0.1, 0)
	_treat_node.add_child(fish)
	_box(_treat_node, Vector3(0.02, 0.16, 0.14), Vector3(0, 0.1, 0.26), Color(0.55, 0.63, 0.7), Vector3(0, 0.5, 0), 0.35)


func _build_trees() -> void:
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3(0, 0, -1)]
	for i in OutsideLayout.TREE_POSITIONS.size():
		var t: YardTree = TreeScene.new()
		t.name = "Tree%d" % i
		zone_root.add_child(t)
		t.setup(OutsideLayout.TREE_POSITIONS[i], dirs[i])
		trees.append(t)


func _build_feeder() -> void:
	var g := Node3D.new()
	g.name = "BirdFeeder"
	g.position = OutsideLayout.FEEDER_POS
	zone_root.add_child(g)
	var wood := Color(0.45, 0.33, 0.2)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.035
	pm.bottom_radius = 0.045
	pm.height = 1.15
	pm.radial_segments = 10
	var pole := MeshInstance3D.new()
	pole.mesh = pm
	pole.material_override = _mat(wood)
	pole.position = Vector3(0, 0.575, 0)
	g.add_child(pole)
	var tray := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.36
	tm.bottom_radius = 0.36
	tm.height = 0.05
	tm.radial_segments = 18
	tray.mesh = tm
	tray.material_override = _mat(wood)
	tray.position = Vector3(0, 1.15, 0)
	g.add_child(tray)
	_box(g, Vector3(0.5, 0.04, 0.5), Vector3(0, 1.42, 0), Color(0.5, 0.2, 0.14)) # little roof
	# Seed pile.
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	var seed_pile := MeshInstance3D.new()
	seed_pile.mesh = sm
	seed_pile.material_override = _mat(Color(0.85, 0.72, 0.4))
	seed_pile.scale = Vector3(0.4, 0.1, 0.4)
	seed_pile.position = Vector3(0, 1.19, 0)
	g.add_child(seed_pile)
	for off: Vector3 in [Vector3(0.31, 1.18, 0), Vector3(-0.31, 1.18, 0), Vector3(0, 1.18, 0.31)]:
		_feeder_perches.append({"pos": OutsideLayout.FEEDER_POS + off, "bird": null})


func _build_bushes() -> void:
	var leaf := Color(0.15, 0.3, 0.11)
	var leaf2 := Color(0.19, 0.37, 0.14)
	for i in OutsideLayout.BUSH_POSITIONS.size():
		var g := Node3D.new()
		g.name = "AmbushBush%d" % i
		g.position = OutsideLayout.BUSH_POSITIONS[i]
		zone_root.add_child(g)
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 18
		sm.rings = 10
		var blobs := [Vector3(0, 0.42, 0), Vector3(0.4, 0.34, 0.15), Vector3(-0.38, 0.36, -0.12), Vector3(0.05, 0.55, -0.3)]
		for j in blobs.size():
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = _mat(leaf if j % 2 == 0 else leaf2)
			mi.position = blobs[j]
			mi.scale = Vector3(1.15, 0.8, 1.15) * (0.8 if j > 0 else 1.0)
			g.add_child(mi)


func _spawn_squirrels() -> void:
	var anchors := [Vector3(-8.4, 0, 2.6), Vector3(9.2, 0, -0.6), Vector3(-3.4, 0, 5.2)]
	for i in trees.size():
		_spawn_squirrel(i, anchors[i])


func _spawn_squirrel(tree_idx: int, anchor: Vector3) -> void:
	var sq: PvKSquirrel = SquirrelScene.new()
	sq.name = "Squirrel%d" % tree_idx
	zone_root.add_child(sq)
	sq.setup(trees[tree_idx], anchor, 1000 + tree_idx * 77)
	sq.caught.connect(_on_squirrel_caught)
	squirrels.append(sq)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 4
	add_child(_hud_layer)
	_still_label = Label.new()
	_still_label.text = "Still…"
	_still_label.position = Vector2(18, 556)
	_still_label.add_theme_font_size_override("font_size", 20)
	_still_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.8))
	_still_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_still_label.add_theme_constant_override("shadow_offset_x", 2)
	_still_label.add_theme_constant_override("shadow_offset_y", 2)
	_still_label.visible = false
	_hud_layer.add_child(_still_label)
	_still_bar = ProgressBar.new()
	_still_bar.position = Vector2(18, 584)
	_still_bar.size = Vector2(190, 14)
	_still_bar.min_value = 0.0
	_still_bar.max_value = 100.0
	_still_bar.value = 0.0
	_still_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	_still_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.9, 0.4)
	fill.set_corner_radius_all(4)
	_still_bar.add_theme_stylebox_override("fill", fill)
	_still_bar.visible = false
	_hud_layer.add_child(_still_bar)
	_road_label = Label.new()
	_road_label.text = "— MASSEY STREET —"
	_road_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_road_label.add_theme_font_size_override("font_size", 22)
	_road_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	_road_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_road_label.add_theme_constant_override("shadow_offset_x", 2)
	_road_label.add_theme_constant_override("shadow_offset_y", 2)
	_road_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_road_label.offset_left = -300
	_road_label.offset_right = 300
	_road_label.offset_top = 64
	_road_label.offset_bottom = 100
	_road_label.visible = false
	_hud_layer.add_child(_road_label)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 26)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -420
	_toast_label.offset_right = 420
	_toast_label.offset_top = 250
	_toast_label.offset_bottom = 300
	_toast_label.visible = false
	_hud_layer.add_child(_toast_label)


func _toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_t = 3.5


# --- predicates the actors use ----------------------------------------------

func cat_in_front(p: Vector3) -> bool:
	return OutsideLayout.FRONT_REGION.has_point(Vector2(p.x, p.z))


func cat_on_road(p: Vector3) -> bool:
	return p.z <= OutsideLayout.STREET_NEAR and p.z >= OutsideLayout.STREET_FAR and absf(p.x) <= OutsideLayout.STREET_X_END


func cat_sheltered(p: Vector3) -> bool:
	## In the Corolla's shadow: drivers will not aim at a cat here.
	return OutsideLayout.COROLLA_SHELTER.has_point(Vector2(p.x, p.z))


func cat_in_bush(c: Node3D) -> bool:
	if c == null:
		return false
	for b: Vector3 in OutsideLayout.BUSH_POSITIONS:
		if _flat(c.global_position, b) < OutsideLayout.BUSH_RADIUS:
			return true
	return false


func cat_hidden(c: Node3D) -> bool:
	if c == null or not cat_in_bush(c):
		return false
	var v := Vector3.ZERO
	if c is CharacterBody3D:
		v = (c as CharacterBody3D).velocity
	# Flat speed: the foundation cat's ground stick holds
	# velocity.y at -1.0 while standing, which is not "moving".
	return Vector2(v.x, v.z).length() < OutsideLayout.BUSH_HIDE_SPEED or String(c.get("anim_state")) == "stalk"


func cat_climbing_tree() -> Variant:
	if bool(_control["active"]) and String(_control["kind"]) == "climb":
		return _control["tree"]
	return null


func nearest_bush_pos(p: Vector3) -> Vector3:
	var best := OutsideLayout.BUSH_POSITIONS[0]
	var bd := 1e9
	for b: Vector3 in OutsideLayout.BUSH_POSITIONS:
		var d := _flat(p, b)
		if d < bd:
			bd = d
			best = b
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- main loop ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	var pc := player_cat()
	_wire_paw(pc)
	_poll_meow()
	_step_control(delta)
	_step_ambush(pc, delta)
	_step_squirrels(pc)
	_step_birds(pc, delta)
	_step_traffic(pc, delta)
	_step_walkers(pc, delta)
	_step_treat(pc, delta)
	_step_crossings(pc)
	_step_respawns(delta)
	_step_sibling_fence()
	if _bite_cd > 0.0:
		_bite_cd -= delta
	if _cat_iframes > 0.0:
		_cat_iframes -= delta
	if _shake_t > 0.0 and game != null:
		_shake_t -= delta
		var k := clampf(_shake_t / 0.3, 0.0, 1.0)
		game.set("duo_shake", Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1, 1)) * 0.08 * k)
		if _shake_t <= 0.0:
			game.set("duo_shake", Vector3.ZERO)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_label.visible = false
	# HUD: stillness bar lives near the bushes; road label on the road.
	var in_bush := pc != null and cat_in_bush(pc)
	_still_label.visible = in_bush or stillness > 0.02
	_still_bar.visible = _still_label.visible
	if _still_label.visible:
		_still_label.text = "Hidden — pounce!" if (pc != null and cat_hidden(pc) and stillness > 0.65) else "Still…"
		_still_bar.value = stillness * 100.0
	_road_label.visible = pc != null and cat_on_road(pc.global_position)


func _wire_paw(pc: PvKCat) -> void:
	if pc == _wired_cat:
		return
	if _wired_cat != null and is_instance_valid(_wired_cat):
		if _wired_cat.paw_swiped.is_connected(_on_player_paw):
			_wired_cat.paw_swiped.disconnect(_on_player_paw)
	_wired_cat = pc
	if pc != null:
		pc.paw_swiped.connect(_on_player_paw)


func _poll_meow() -> void:
	if game == null or game.get("duo") == null:
		return
	var mc := int(game.duo.get("meow_count"))
	if mc == _last_meow_count:
		return
	_last_meow_count = mc
	# Only the player's meows pass through here in practice for
	# Willie (NPC Willie meows only while the player is Aggie).
	# Willie meowing spooks every bird in earshot — hiding or not.
	# In a bush it also zeroes his stillness: he blew his own cover.
	if player_id() != "willie":
		return
	var pc := player_cat()
	if pc == null:
		return
	if cat_in_bush(pc):
		stillness = 0.0
	for b: Variant in birds.duplicate():
		var bird := b as PvKBird
		if is_instance_valid(bird) and bird.state == "peck" and _flat(bird.global_position, pc.global_position) < 7.0:
			_scatter_bird(bird)


# --- the paw: squirrels, birds, and starting a climb ----------------------------

func _on_player_paw() -> void:
	var pc := player_cat()
	if pc == null or bool(_control["active"]):
		return
	var pp := pc.paw_point()
	# 1) A squirrel mid-climb, caught from the trunk base.
	for s: Variant in squirrels:
		var sq := s as PvKSquirrel
		if not is_instance_valid(sq) or sq.state != "climb":
			continue
		if sq.climb_y < 1.5 and _flat(pc.global_position, sq.home_tree.global_position) < 1.15:
			var roll := _rng.randf()
			if catch_roll_override >= 0.0:
				roll = catch_roll_override
			if roll < OutsideLayout.POUNCE_CLIMB_CATCH:
				sq.take_hit("pounce")
			else:
				sq.state = "taunt" # it scrambles the last stretch and makes it
				sq.global_position = sq.home_tree.perch_pos()
			return
	# 2) Ground squirrels in paw range.
	for s: Variant in squirrels:
		var sq := s as PvKSquirrel
		if is_instance_valid(sq) and sq.state in ["forage", "flee"] and _flat(pp, sq.global_position) < 0.7:
			sq.take_hit("ground")
	# 3) Birds on the ground / at the feeder.
	var hidden := cat_hidden(pc)
	var reach := OutsideLayout.AMBUSH_CATCH_RANGE_HIDDEN if hidden else OutsideLayout.AMBUSH_CATCH_RANGE
	for b: Variant in birds.duplicate():
		var bird := b as PvKBird
		if is_instance_valid(bird) and bird.state == "peck" and _flat(pp, bird.global_position) < reach:
			if hidden:
				ambush_catches += 1
				_obj_progress("ambush_master")
			bird.get_caught()
	# 4) Nothing struck at a trunk with a taunting squirrel: climb it.
	for t: Variant in trees:
		var tree := t as YardTree
		if _flat(pc.global_position, tree.global_position) < 1.15:
			for s: Variant in squirrels:
				var sq := s as PvKSquirrel
				if is_instance_valid(sq) and sq.home_tree == tree and sq.state == "taunt":
					try_start_climb()
					return


func _on_squirrel_caught(sq: PvKSquirrel) -> void:
	squirrels_caught += 1
	squirrels.erase(sq)
	var idx := trees.find(sq.home_tree)
	_respawns.append({"tree": idx, "t": 25.0})


func _on_squirrel_treed(sq: PvKSquirrel) -> void:
	squirrels_treed += 1
	_obj_progress("squirrel_treed")


# --- ambush -----------------------------------------------------------------------

func _step_ambush(pc: PvKCat, delta: float) -> void:
	if pc == null:
		return
	var pid := player_id()
	if cat_hidden(pc):
		stillness = minf(stillness + delta / float(OutsideLayout.STILL_FILL_TIME[pid]), 1.0)
	elif cat_in_bush(pc):
		stillness = maxf(stillness - float(OutsideLayout.STILL_DECAY[pid]) * delta, 0.0)
	else:
		stillness = maxf(stillness - float(OutsideLayout.STILL_DECAY[pid]) * 1.6 * delta, 0.0)


func _scare_radius(pc: PvKCat) -> float:
	var base := OutsideLayout.BIRD_SCARE_WILLIE if player_id() == "willie" else OutsideLayout.BIRD_SCARE_AGGIE
	if cat_hidden(pc):
		return base * 0.12
	var spd := 0.0
	if pc is CharacterBody3D:
		spd = Vector2(pc.velocity.x, pc.velocity.z).length()
	if spd < 0.3:
		return base * 0.45
	match String(pc.get("anim_state")):
		"stalk":
			return base * 0.7
		"sprint":
			return base * 1.35
	return base


# --- squirrels ----------------------------------------------------------------------

func _step_squirrels(pc: PvKCat) -> void:
	for s: Variant in squirrels:
		var sq := s as PvKSquirrel
		if is_instance_valid(sq):
			sq.cat = pc
			if sq.state == "taunt" and not sq.has_meta("treed_counted"):
				sq.set_meta("treed_counted", true)
				_on_squirrel_treed(sq)
			elif sq.state != "taunt" and sq.has_meta("treed_counted"):
				sq.remove_meta("treed_counted")


func _step_respawns(delta: float) -> void:
	for r: Variant in _respawns.duplicate():
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			_respawns.erase(r)
			var idx := int(r["tree"])
			if idx >= 0:
				var anchors := [Vector3(-8.4, 0, 2.6), Vector3(9.2, 0, -0.6), Vector3(-3.4, 0, 5.2)]
				_spawn_squirrel(idx, anchors[idx])


# --- birds ----------------------------------------------------------------------------

func _step_birds(pc: PvKCat, delta: float) -> void:
	_bird_spawn_t -= delta
	if _bird_spawn_t <= 0.0:
		_bird_spawn_t = _rng.randf_range(OutsideLayout.BIRD_SPAWN_MIN, OutsideLayout.BIRD_SPAWN_MAX)
		if birds.size() < OutsideLayout.BIRD_MAX:
			_spawn_bird()
	# Scare rules for landed birds.
	if pc != null:
		var r := _scare_radius(pc)
		for b: Variant in birds.duplicate():
			var bird := b as PvKBird
			if is_instance_valid(bird) and bird.state == "peck" and _flat(bird.global_position, pc.global_position) < r:
				_scatter_bird(bird)


func _spawn_bird() -> void:
	var perch := _pick_perch()
	if perch.is_empty():
		return
	var bird: PvKBird = BirdScene.new()
	bird.name = "Bird"
	zone_root.add_child(bird)
	bird.setup(_rng.randi() % 3, _rng.randi())
	var from := Vector3(_rng.randf_range(-13.0, 13.0), _rng.randf_range(6.0, 7.5), 11.5)
	if _rng.randf() < 0.5:
		from = Vector3(-15.0 if _rng.randf() < 0.5 else 15.0, _rng.randf_range(5.5, 7.0), _rng.randf_range(-6.0, 5.0))
	bird.global_position = from
	bird.peck_time = _rng.randf_range(2.5, 5.0)
	bird.set_meta("visits", _rng.randi_range(1, 3))
	bird.peck_finished.connect(_on_bird_peck_finished)
	bird.departed.connect(_on_bird_gone)
	bird.caught.connect(_on_bird_caught)
	birds.append(bird)
	var to: Vector3 = perch["pos"]
	bird.fly_to(to, clampf(from.distance_to(to) / 6.0, 1.2, 2.8), 1.2, true, String(perch["kind"]))
	if perch.has("slot"):
		_feeder_perches[int(perch["slot"])]["bird"] = bird


func _pick_perch() -> Dictionary:
	# Free feeder slots first (the feeder is the stream's anchor).
	var free_slots: Array = []
	for i in _feeder_perches.size():
		if _feeder_perches[i]["bird"] == null or not is_instance_valid(_feeder_perches[i]["bird"]):
			free_slots.append(i)
	var pc := player_cat()
	var feeder_hot := pc != null and not cat_hidden(pc) and _flat(pc.global_position, OutsideLayout.FEEDER_POS) < 2.2
	if not free_slots.is_empty() and not feeder_hot and _rng.randf() < 0.55:
		var slot := int(free_slots[_rng.randi() % free_slots.size()])
		return {"pos": _feeder_perches[slot]["pos"], "kind": "feeder", "slot": slot}
	# Ground seed below the feeder. While a cat lies hidden and
	# still, birds land bold — close to the bushes, inside pounce
	# range. That is the whole ambush game.
	var ang := _rng.randf() * TAU
	var rad := _rng.randf_range(0.9, 2.6)
	var pos := OutsideLayout.FEEDER_POS + Vector3(cos(ang) * rad, 0, sin(ang) * rad)
	if pc != null and cat_hidden(pc) and stillness > 0.45:
		var bush := nearest_bush_pos(OutsideLayout.FEEDER_POS)
		var dirv := (OutsideLayout.FEEDER_POS - bush)
		dirv.y = 0.0
		pos = bush + dirv.normalized() * _rng.randf_range(0.95, 1.35)
	pos.y = 0.02
	pos.x = clampf(pos.x, -12.0, 12.4)
	pos.z = clampf(pos.z, -9.0, 9.4)
	return {"pos": pos, "kind": "ground"}


func _on_bird_peck_finished(bird: PvKBird) -> void:
	if not is_instance_valid(bird) or bird.state != "peck":
		return
	_release_perch(bird)
	var visits := int(bird.get_meta("visits", 1))
	if visits > 1:
		bird.set_meta("visits", visits - 1)
		var perch := _pick_perch()
		if not perch.is_empty():
			var to: Vector3 = perch["pos"]
			bird.peck_time = _rng.randf_range(2.5, 5.0)
			bird.fly_to(to, 0.55, 0.4, true, String(perch["kind"]))
			if perch.has("slot"):
				_feeder_perches[int(perch["slot"])]["bird"] = bird
			return
	_send_bird_away(bird)


func _send_bird_away(bird: PvKBird) -> void:
	_release_perch(bird)
	var exit := bird.global_position + Vector3(_rng.randf_range(-6.0, 6.0), 6.0, 13.0)
	bird.fly_to(exit, 1.6, 1.0, false)


func _scatter_bird(bird: PvKBird) -> void:
	_release_perch(bird)
	var away := bird.global_position + Vector3(_rng.randf_range(-4.0, 4.0), 5.5, _rng.randf_range(6.0, 12.0))
	bird.burst_off(away)


func _release_perch(bird: PvKBird) -> void:
	for i in _feeder_perches.size():
		if _feeder_perches[i]["bird"] == bird:
			_feeder_perches[i]["bird"] = null


func _on_bird_gone(bird: PvKBird) -> void:
	birds.erase(bird)


func _on_bird_caught(bird: PvKBird) -> void:
	_release_perch(bird)
	birds.erase(bird)
	birds_caught += 1
	_obj_progress("first_bird")


func pecking_birds() -> Array:
	var out: Array = []
	for b: Variant in birds:
		if is_instance_valid(b) and (b as PvKBird).state == "peck":
			out.append(b)
	return out


# --- traffic ----------------------------------------------------------------------------

func _step_traffic(pc: PvKCat, delta: float) -> void:
	_car_spawn_t -= delta
	if _car_spawn_t <= 0.0:
		_car_spawn_t = _rng.randf_range(OutsideLayout.CAR_SPAWN_MIN, OutsideLayout.CAR_SPAWN_MAX)
		if cars.size() < OutsideLayout.CAR_MAX:
			_spawn_car_random()
	for c: Variant in cars.duplicate():
		var car := c as PvKCar
		if not is_instance_valid(car):
			cars.erase(c)
			continue
		if absf(car.global_position.x) > OutsideLayout.STREET_X_END + 0.6:
			cars.erase(c)
			car.queue_free()
			continue
		_drive(car, pc)
		_hit_check(car, pc)


func _spawn_car_random() -> void:
	var near_lane := _rng.randf() < 0.5
	_spawn_car(OutsideLayout.LANE_NEAR_Z if near_lane else OutsideLayout.LANE_FAR_Z, -OutsideLayout.STREET_X_END if near_lane else OutsideLayout.STREET_X_END)


func _spawn_car(lane_z: float, x: float, speed_override := -1.0) -> PvKCar:
	var dir := 1.0 if lane_z == OutsideLayout.LANE_NEAR_Z else -1.0
	# Don't spawn on top of another car in the same lane.
	for c: Variant in cars:
		var other := c as PvKCar
		if is_instance_valid(other) and other.lane_z == lane_z and absf(other.global_position.x - x) < 5.0:
			return null
	var car: PvKCar = CarScene.new()
	car.name = "Car"
	zone_root.add_child(car)
	var spd := OutsideLayout.CAR_SPEED + _rng.randf_range(-OutsideLayout.CAR_SPEED_VAR, OutsideLayout.CAR_SPEED_VAR)
	if speed_override > 0.0:
		spd = speed_override
	car.setup(dir, lane_z, spd, CAR_COLOURS[_rng.randi() % CAR_COLOURS.size()])
	car.global_position = Vector3(x, 0, lane_z)
	cars.append(car)
	return car


func _drive(car: PvKCar, pc: PvKCat) -> void:
	# Default: hold the lane; bias wide around the driveway mouth
	# (the Corolla noses toward the street there).
	var want_z := car.lane_z
	if car.lane_z == OutsideLayout.LANE_NEAR_Z and absf(car.global_position.x - OutsideLayout.COROLLA_POS.x) < 6.5:
		want_z = car.lane_z - 0.8
	car.hostile = false
	car.speed = lerpf(car.speed, car.cruise_speed, 0.06)
	if pc != null and cat_on_road(pc.global_position) and not cat_sheltered(pc.global_position):
		var ahead := (pc.global_position.x - car.global_position.x) * car.dir
		if ahead > 0.2 and ahead < OutsideLayout.CAR_REACTION_AHEAD and absf(pc.global_position.z - car.lane_z) < 2.7:
			car.hostile = true
			want_z = clampf(pc.global_position.z, car.lane_z - OutsideLayout.CAR_SWERVE_BOUND, car.lane_z + OutsideLayout.CAR_SWERVE_BOUND)
			car.speed = car.cruise_speed * OutsideLayout.CAR_HOSTILE_BOOST
			if not car.honked:
				car.honk() # the telegraph
	car.target_z = want_z


func _hit_check(car: PvKCar, pc: PvKCat) -> void:
	if pc == null or car.hit_cd > 0.0 or _cat_iframes > 0.0 or bool(_control["active"]):
		return
	if absf(pc.global_position.x - car.global_position.x) > 2.05 or absf(pc.global_position.z - car.global_position.z) > 1.05:
		return
	car.hit_cd = 1.5
	_cat_iframes = 1.2
	if car.speed >= 4.0:
		apply_damage(OutsideLayout.DMG_VEHICLE_HIT, "vehicle", car.global_position)
		# The launch: dramatic arc to the nearest curb.
		var land_z := -13.0 if pc.global_position.z >= OutsideLayout.LANE_CENTRE_Z else -20.9
		_start_launch(pc, Vector3(pc.global_position.x + car.dir * 1.4, 0, land_z), 1.6, 0.62)
		_shake_t = 0.3
	else:
		apply_damage(OutsideLayout.DMG_VEHICLE_BRUSH, "vehicle_brush", car.global_position)
		var push := signf(pc.global_position.z - car.global_position.z)
		if push == 0.0:
			push = 1.0
		pc.global_position += Vector3(car.dir * 0.5, 0, push * 0.85)


# --- walkers + dogs ---------------------------------------------------------------------

func _step_walkers(pc: PvKCat, delta: float) -> void:
	_walker_t -= delta
	if _walker_t <= 0.0 and walker == null:
		_walker_t = _rng.randf_range(OutsideLayout.WALKER_INTERVAL_MIN, OutsideLayout.WALKER_INTERVAL_MAX)
		_spawn_walker(1.0 if _rng.randf() < 0.5 else -1.0, "small" if _rng.randf() < 0.5 else "big")
	if walker != null and is_instance_valid(walker):
		if dog != null and is_instance_valid(dog):
			dog.cat = pc
		if absf(walker.global_position.x) > OutsideLayout.STREET_X_END + 0.5 and (dog == null or dog.state == "heel"):
			_free_walker_pair()
	elif walker != null:
		walker = null
		dog = null


func _spawn_walker(dir: float, size: String) -> PvKWalker:
	_free_walker_pair()
	walker = WalkerScene.new()
	walker.name = "Walker"
	zone_root.add_child(walker)
	walker.setup(dir, _rng.randi() % 4)
	walker.global_position = Vector3(-OutsideLayout.STREET_X_END * dir, 0, OutsideLayout.WALK_Z)
	dog = DogScene.new()
	dog.name = "Dog"
	zone_root.add_child(dog)
	dog.setup(size, walker, _rng.randi())
	dog.global_position = walker.global_position + Vector3(-0.55 * dir, 0, 0.32)
	dog.sys = self
	dog.attach_leash(zone_root)
	dog.chase_ended.connect(_on_dog_chase_ended)
	return walker


func _free_walker_pair() -> void:
	if dog != null and is_instance_valid(dog):
		var l: Variant = dog.get("_leash")
		if l != null and is_instance_valid(l):
			l.queue_free()
		dog.queue_free()
	if walker != null and is_instance_valid(walker):
		walker.queue_free()
	dog = null
	walker = null


func on_leash_slip(d: PvKDog) -> void:
	_bites.clear()
	d.start_chase()
	if d.human != null:
		d.human.state = "wait"
	_toast("The leash slipped!")


func on_cool_cat(_d: PvKDog) -> void:
	_obj_progress("cool_cat")


func _on_dog_chase_ended(_d: PvKDog, valve: String) -> void:
	if valve != "grab":
		dog_escapes += 1
		_obj_progress("dog_dodger")


func dog_bite_check(d: PvKDog) -> void:
	if d.state != "chase" or _bite_cd > 0.0 or _cat_iframes > 0.0:
		return
	var pc := player_cat()
	if pc == null or bool(_control["active"]):
		return
	if _flat(d.global_position, pc.global_position) > OutsideLayout.DOG_BITE_RANGE:
		return
	_bite_cd = OutsideLayout.DOG_BITE_CD
	apply_damage(float(OutsideLayout.DMG_DOG_BITE[d.size]), "dog_bite", d.global_position)
	_bites.append(_time)
	_bites = _bites.filter(func(t: float) -> bool: return _time - t < OutsideLayout.DOG_GRAB_WINDOW)
	if _bites.size() >= 2:
		_bites.clear()
		# GRAB + shake: heavy damage, then the cat bursts free —
		# a short arc away, and the chase is over. No stunlocks.
		apply_damage(OutsideLayout.DMG_DOG_GRAB, "dog_grab", d.global_position)
		var away := pc.global_position - d.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3(0, 0, 1)
		var land := pc.global_position + away * 2.4
		land.z = clampf(land.z, -21.2, -9.8) if pc.global_position.z < -9.7 else land.z
		land.x = clampf(land.x, -13.0, 13.0)
		_start_launch(pc, land, 1.1, 0.45)
		_shake_t = 0.3
		d.start_return("grab")


# --- damage contract (LOCAL — foundation owns the real profile) ---------------------------

func apply_damage(amount: float, kind: String, from_pos: Vector3) -> void:
	last_damage = amount
	last_damage_kind = kind
	damage_log.append({"amount": amount, "kind": kind, "t": _time})
	var pc := player_cat()
	# INTEGRATION: the foundation cat owns real HP. Forward the
	# hit in this zone's proportions (the ledger numbers are
	# percents of a life): vehicles use the CombatData profile
	# (its 60% damage_frac drives; this zone's own curb launch
	# owns the arc, so the profile's launch flag is off), and a
	# dog's grab bypasses the cat's invulnerability window (a new
	# event, not a repeat hit). The ledger below remains the
	# zone's own bookkeeping for objectives/HUD/tests.
	if pc != null and pc.has_method("take_damage"):
		var prof: Dictionary = {}
		var dmg := amount * (pc.max_hp / OutsideLayout.CAT_HP_MAX)
		if kind == "vehicle":
			prof = CombatData.profile("vehicle_hit").duplicate()
			prof["launch"] = false
			dmg = 0.0 # damage_frac drives
		elif kind == "dog_grab":
			prof = {"ignore_invuln": true}
		pc.take_damage(dmg, from_pos, prof)
	hp = maxf(hp - amount, 0.0)
	if kind == "vehicle":
		crossings_this_life = 0 # a hit ends the life for "Highway cat"
	if hp <= 0.0:
		lives_lost += 1
		hp = OutsideLayout.CAT_HP_MAX
		crossings_this_life = 0
		if pc != null and not pc.is_fainted:
			# Local nine-lives stub: back to the porch, full hearts.
			# (Skipped when the real faint flow already owns the cat.)
			pc.global_position = Vector3(OutsideLayout.DOOR_X, 0.3, -8.7)
			pc.velocity = Vector3.ZERO


func heal_full() -> void:
	hp = OutsideLayout.CAT_HP_MAX
	var pc := player_cat()
	if pc != null and pc.has_method("heal_full"):
		pc.call("heal_full")


# --- crossings + treat ------------------------------------------------------------------------

func _band_of(z: float) -> String:
	if z > OutsideLayout.STREET_NEAR:
		return "back"
	if z < OutsideLayout.STREET_FAR:
		return "far"
	return "road"


func _step_crossings(pc: PvKCat) -> void:
	if pc == null:
		return
	var b := _band_of(pc.global_position.z)
	if b == _band:
		return
	var prev := _band
	_band = b
	if prev == "road" and b == "far":
		crossings_total += 1
		crossings_this_life += 1
		_went_far = true
		_obj_set("highway_cat", crossings_this_life)
	elif prev == "road" and b == "back" and _went_far:
		_went_far = false
		_obj_progress("cross_massey_back")


func _step_treat(pc: PvKCat, delta: float) -> void:
	if _treat_node != null:
		_treat_node.rotation.y += delta * 0.8 # a gentle, tempting spin
		_treat_node.position.y = 0.02 + sin(_time * 2.2) * 0.02
	if not _treat_active:
		_treat_t -= delta
		if _treat_t <= 0.0:
			_treat_active = true
			_treat_node.visible = true
		return
	if pc != null and _flat(pc.global_position, OutsideLayout.FISH_TREAT_POS) < 0.75:
		_treat_active = false
		_treat_node.visible = false
		_treat_t = 45.0
		heal_full()
		_toast("Fish treat! Fully healed.")


func _step_sibling_fence() -> void:
	# The sibling is a backyard cat: it never enters the front
	# zone (and so never meets traffic or dogs). SiblingAI's spots
	# are all in the yard, so this is a belt-and-braces nudge.
	# PLAYTEST FIX (bug 2): the fence is a YARD rule and must only
	# run while the cats are actually outside. The interior stack
	# lives at world z ~ -200, so clamping z >= -9.4 in every zone
	# yanked the sibling out of the house the frame after any
	# indoor travel and pinned her against the house wall.
	if game == null or game.get("duo") == null:
		return
	var zones: Variant = game.get("zones")
	if zones == null or String(zones.get("current_zone")) != HouseSpec.OUTSIDE:
		return
	var sib: Variant = game.duo.sibling_cat()
	if sib != null and is_instance_valid(sib):
		var s := sib as Node3D
		if s.global_position.z < -9.85:
			s.global_position.z = -9.4


# --- objectives ---------------------------------------------------------------------------------

func _obj_progress(id: String) -> void:
	_obj_set(id, int(objectives[id]["progress"]) + 1)


func _obj_set(id: String, value: int) -> void:
	var o: Dictionary = objectives[id]
	o["progress"] = maxi(int(o["progress"]), value)
	if int(o["progress"]) >= int(o["target"]) and not bool(o["done"]):
		o["done"] = true
		_toast("Objective: %s ✓" % String(o["title"]))


# --- the control stub: climb + launch --------------------------------------------------------------

func try_start_climb() -> bool:
	var pc := player_cat()
	if pc == null or bool(_control["active"]):
		return false
	for t: Variant in trees:
		var tree := t as YardTree
		if _flat(pc.global_position, tree.global_position) < 1.15:
			var side := pc.global_position - tree.global_position
			side.y = 0.0
			side = side.normalized() if side.length() > 0.05 else tree.branch_dir
			_control = {"active": true, "kind": "climb", "cat": pc, "tree": tree, "side": side, "y": 0.0, "t": 0.0, "dur": 0.0, "from": pc.global_position, "to": Vector3.ZERO, "arc": 0.0}
			pc.set_physics_process(false)
			pc.set_move_input(Vector3.ZERO, false, false)
			pc.set("anim_state", "stalk")
			return true
	return false


func climbing() -> bool:
	return bool(_control["active"]) and String(_control["kind"]) == "climb"


func climb_y() -> float:
	return float(_control["y"])


func climb_swipe() -> void:
	if not climbing():
		return
	var tree: YardTree = _control["tree"]
	if float(_control["y"]) < tree.branch_y - 0.05:
		return
	for s: Variant in squirrels:
		var sq := s as PvKSquirrel
		if is_instance_valid(sq) and sq.home_tree == tree and sq.state == "taunt":
			sq.take_hit("branch")
			return


func end_climb() -> void:
	if climbing():
		_release_control()


func _start_launch(pc: PvKCat, to: Vector3, arc: float, dur: float) -> void:
	if bool(_control["active"]):
		_release_control()
	_control = {"active": true, "kind": "launch", "cat": pc, "tree": null, "side": Vector3.RIGHT, "y": 0.0, "t": 0.0, "dur": dur, "from": pc.global_position, "to": to, "arc": arc}
	pc.set_physics_process(false)
	pc.set_move_input(Vector3.ZERO, false, false)


func launch_active() -> bool:
	return bool(_control["active"]) and String(_control["kind"]) == "launch"


func _release_control() -> void:
	var pc: PvKCat = _control["cat"]
	_control["active"] = false
	_control["kind"] = ""
	if pc != null and is_instance_valid(pc):
		pc.velocity = Vector3.ZERO
		pc.set_physics_process(true)


func _step_control(delta: float) -> void:
	if not bool(_control["active"]):
		return
	var pc: PvKCat = _control["cat"]
	if pc == null or not is_instance_valid(pc):
		_control["active"] = false
		return
	if String(_control["kind"]) == "launch":
		_control["t"] = float(_control["t"]) + delta
		var k := clampf(float(_control["t"]) / float(_control["dur"]), 0.0, 1.0)
		var from: Vector3 = _control["from"]
		var to: Vector3 = _control["to"]
		var pos := from.lerp(to, k)
		pos.y += sin(k * PI) * float(_control["arc"])
		pc.global_position = pos
		if k >= 1.0:
			_release_control()
		return
	# Climb: W/S (or the test seam) move the cat up/down the trunk;
	# the cat stays pinned to the trunk surface, nose in.
	var tree: YardTree = _control["tree"]
	var axis := climb_axis_debug
	if axis == 0.0:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			axis = 1.0
		elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			axis = -1.0
	var y := clampf(float(_control["y"]) + axis * OutsideLayout.CAT_CLIMB_SPEED * delta, 0.0, tree.branch_y)
	_control["y"] = y
	if y >= tree.branch_y - 0.001:
		var perch := tree.perch_pos()
		var side_off := Vector3(-tree.branch_dir.z, 0, tree.branch_dir.x) * 0.34
		pc.global_position = perch + side_off
	else:
		pc.global_position = tree.surface_point(y, _control["side"])
	var to_trunk := tree.global_position - pc.global_position
	to_trunk.y = 0.0
	if to_trunk.length() > 0.03:
		pc.rotation.y = atan2(-to_trunk.x, -to_trunk.z)
	if y <= 0.0 and axis < 0.0:
		_release_control()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_SPACE and climbing():
			climb_swipe()


# --- debug / staging seams (tests + shots) -----------------------------------------------------------

func debug_spawn_car(lane_z: float, x: float, speed := -1.0) -> PvKCar:
	return _spawn_car(lane_z, x, speed)


func debug_clear_cars() -> void:
	for c: Variant in cars:
		if is_instance_valid(c):
			c.queue_free()
	cars.clear()
	_car_spawn_t = 9999.0 # hold the ambient spawner for staged tests


func debug_spawn_bird_near(pos: Vector3) -> PvKBird:
	var bird: PvKBird = BirdScene.new()
	bird.name = "Bird"
	zone_root.add_child(bird)
	bird.setup(_rng.randi() % 3, _rng.randi())
	bird.global_position = pos + Vector3(1.5, 3.5, 1.0)
	bird.peck_time = 30.0
	bird.set_meta("visits", 99)
	bird.peck_finished.connect(_on_bird_peck_finished)
	bird.departed.connect(_on_bird_gone)
	bird.caught.connect(_on_bird_caught)
	birds.append(bird)
	var to := pos
	to.y = 0.02
	bird.fly_to(to, 0.9, 0.8, true, "ground")
	return bird


func debug_clear_birds() -> void:
	for b: Variant in birds:
		if is_instance_valid(b):
			_release_perch(b)
			b.queue_free()
	birds.clear()


func debug_resume_birds() -> void:
	_bird_spawn_t = 0.3


func debug_spawn_walker(dir: float, size: String) -> PvKWalker:
	_walker_t = 9999.0 # hold the ambient spawner while a staged pair is out
	return _spawn_walker(dir, size)


func debug_clear_walkers() -> void:
	_free_walker_pair()


func debug_reset_road() -> void:
	debug_clear_cars()
	last_damage = 0.0
	last_damage_kind = ""
	_cat_iframes = 0.0
	hp = OutsideLayout.CAT_HP_MAX
	crossings_this_life = 0
	damage_log.clear()
