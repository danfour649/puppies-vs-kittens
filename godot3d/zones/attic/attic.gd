class_name PvKAttic
extends Node3D
## THE ATTIC of 255 Massey, at cat scale — the raccoons' floor.
## A self-contained zone for Willie and Aggie (Puppies vs Kittens):
## sloped roof, walkable collar beams, insulation piles that slow the
## cat, the hatch-corner entrance, and a raccoon family guarding the
## nest corner. Objective: "Reclaim the attic" — see
## attic_objectives.json and README.md.
##
## =====================================================================
## HOUSE ARCHITECTURE — data first (Daniel's addendum: the Massey house
## model is a playground that should lift into GTA Fredericton later,
## so every dimension lives here as a named constant, not in code
## soup). Zone-local space: origin at the centre of the attic floor,
## floor top at y = 0, ridge running along X. The house hub (foundation
## lane) decides where this origin sits in the world.
##
##   FOOTPRINT   12.0 x 9.0 m (x by z)
##   EAVE_H       0.95 m — knee-wall height where the roof springs
##   RIDGE_H      3.30 m — underside of the ridge
##   ROOF_PITCH  ~27.6 deg, from EAVE_H/RIDGE_H over the half-span
##   HATCH_POS    +x/+z floor corner (entrance from the house below)
##   NEST_POS     -x/-z corner (the raccoons' corner)
##   WINDOW       round window, +x gable, centre y 2.25, radius 0.55
##
## RECONCILIATION FLAG: the foundation lane's massey-zones.md was not
## published when this geometry locked (checked 2026-10-24: no
## massey-foundation branch/PR yet). These dimensions are the attic
## lane's own, documented here and in README.md; reconciling footprint
## / floor levels / hatch position with the shared house contract is
## integration work for the coordinator.
## =====================================================================

const FOOTPRINT := Vector2(12.0, 9.0)
const EAVE_H := 0.95
const RIDGE_H := 3.30
const WALL_T := 0.15
const HATCH_POS := Vector3(5.05, 0.0, 3.55)
const NEST_POS := Vector3(-4.85, 0.0, -3.35)
const WINDOW_POS := Vector3(5.98, 2.25, 0.0)
const WINDOW_R := 0.55
const PERCH_POS := Vector3(5.30, 1.52, 0.0) # top of the window perch
const PAW_DAMAGE := 1
const PAW_REACH := 0.72

const RaccoonScene := preload("res://zones/attic/raccoon.gd")
const OBJECTIVES_PATH := "res://zones/attic/attic_objectives.json"

## Insulation slow-zones: [centre_xz, radii_xz]; inside = wading.
const PILES: Array = [
	[Vector2(0.8, 2.6), Vector2(1.7, 1.15)],
	[Vector2(-2.9, 3.25), Vector2(1.35, 0.85)],
	[Vector2(-4.85, -3.35), Vector2(1.5, 1.1)], # the nest mound itself
]
const PILE_FACTOR := 0.55

signal objective_won

var cat: Node3D = null
var mother: PvKRaccoon
var kits: Array = []
var objective_state := "active" # active -> won
var perch_unlocked := false
var hoard_revealed := false
var objectives: Array = []

var _hoard: Node3D
var _dust: Array = []
var _time := 0.0
var _mats := {}
var _meshes := {}

# Beam layout (x positions of the collar beams; top surface y).
const BEAM_XS: Array = [-3.2, 0.4, 3.6]
const BEAM_TOP := 1.62
# Kit refuges under the eaves.
const REFUGES: Array = [
	Vector3(-5.25, 0.0, 4.0), Vector3(5.25, 0.0, -4.0),
	Vector3(-5.3, 0.0, -3.95), Vector3(0.6, 0.0, 4.1),
]


static func roof_pitch() -> float:
	return atan2(RIDGE_H - EAVE_H, FOOTPRINT.y * 0.5)


## Local ceiling height at a given z — exported for the hub/AI.
func ceiling_height_at(z: float) -> float:
	var t := clampf(absf(z) / (FOOTPRINT.y * 0.5), 0.0, 1.0)
	return lerpf(RIDGE_H, EAVE_H, t)


func speed_factor_at(pos: Vector3) -> float:
	var local := to_local(pos)
	for pile in PILES:
		var c: Vector2 = pile[0]
		var r: Vector2 = pile[1]
		var d := Vector2(local.x - c.x, local.z - c.y) / r
		if d.length() < 1.0:
			return PILE_FACTOR
	return 1.0


func _ready() -> void:
	_load_objectives()
	_build_shell()
	_build_props()
	_build_lights()
	_spawn_family()


func _load_objectives() -> void:
	var f := FileAccess.open(OBJECTIVES_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			objectives = parsed.get("objectives", [])


func get_objective(id: String) -> Dictionary:
	for o in objectives:
		if String(o.get("id", "")) == id:
			return o
	return {}


## Wire the player cat in: paw strikes resolve against the family,
## the family gets the cat as its target.
func setup(p_cat: Node3D) -> void:
	cat = p_cat
	for e in _family():
		e.set_target(cat)
		e.zone = self
	if cat != null and cat.has_signal("paw_swiped"):
		if not cat.paw_swiped.is_connected(_on_cat_paw):
			cat.paw_swiped.connect(_on_cat_paw)


func _family() -> Array:
	var fam: Array = []
	if mother != null:
		fam.append(mother)
	fam.append_array(kits)
	return fam


func _on_cat_paw() -> void:
	if cat == null or not cat.has_method("paw_point"):
		return
	var pp: Vector3 = cat.paw_point()
	for e in _family():
		if e.state != "dead" and e.state != "fled":
			if e.global_position.distance_to(pp) <= PAW_REACH:
				e.take_hit(PAW_DAMAGE, cat.global_position)


func _on_mother_died(_r: PvKRaccoon) -> void:
	if objective_state == "won":
		return
	objective_state = "won"
	perch_unlocked = true
	hoard_revealed = true
	if _hoard != null:
		_hoard.visible = true
		var tw := create_tween()
		_hoard.scale = Vector3.ONE * 0.01
		tw.tween_property(_hoard, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	for k in kits:
		k.flee_final()
	objective_won.emit()


func _on_mother_staggered(_r: PvKRaccoon) -> void:
	for k in kits:
		k.scatter()


# --- family -------------------------------------------------------------------------

func _spawn_family() -> void:
	mother = RaccoonScene.new()
	mother.name = "MotherRaccoon"
	mother.set_role("mother")
	add_child(mother)
	mother.global_position = NEST_POS + Vector3(0.35, 0.05, 0.35)
	mother.rotation.y = -2.2 # facing into the room
	mother.home = mother.global_position
	mother.died.connect(_on_mother_died)
	mother.staggered.connect(_on_mother_staggered)
	var kit_offsets: Array = [Vector3(0.9, 0, 0.5), Vector3(-0.4, 0, 0.95), Vector3(0.55, 0, -0.75)]
	for i in 3:
		var kit: PvKRaccoon = RaccoonScene.new()
		kit.name = "Kit%d" % (i + 1)
		kit.set_role("kit")
		add_child(kit)
		kit.global_position = NEST_POS + kit_offsets[i] + Vector3(0, 0.05, 0)
		kit.mother = mother
		kit.home = kit.global_position
		kit.refuges = REFUGES.duplicate()
		kits.append(kit)


# --- materials / boxes (wildlife.gd idiom, same as main.gd) ---------------------------

func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _glow_mat(c: Color, energy := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func _box_mesh(size: Vector3) -> BoxMesh:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	return _meshes[size]


## A visual box with a matching static collider.
func _solid(parent: Node, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = _mat(c)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


## Visual-only box (no collider — soft or decorative).
func _visual(parent: Node, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = mat if mat != null else _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _ell(parent: Node, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO, rough := 0.95) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# --- the shell --------------------------------------------------------------------------

func _build_shell() -> void:
	var root := Node3D.new()
	root.name = "Shell"
	add_child(root)
	var wood := Color(0.42, 0.32, 0.22)
	var wood_dark := Color(0.30, 0.22, 0.15)
	var roof_col := Color(0.36, 0.27, 0.19)
	var hx := FOOTPRINT.x * 0.5
	var hz := FOOTPRINT.y * 0.5
	var pitch := roof_pitch()

	# Floor (top at y=0) with a darker hatch square + frame in the corner.
	_solid(root, Vector3(FOOTPRINT.x + 0.4, 0.2, FOOTPRINT.y + 0.4), Vector3(0, -0.1, 0), wood)
	_visual(root, Vector3(0.95, 0.03, 0.95), Vector3(HATCH_POS.x, 0.012, HATCH_POS.z), Color(0.10, 0.08, 0.06))
	for e in [[0.0, -0.52], [0.0, 0.52], [-0.52, 0.0], [0.52, 0.0]]:
		var horiz: bool = absf(e[1]) > 0.4
		var sz := Vector3(1.1, 0.045, 0.09) if horiz else Vector3(0.09, 0.045, 1.1)
		_visual(root, sz, Vector3(HATCH_POS.x + e[0], 0.016, HATCH_POS.z + e[1]), wood_dark)

	# Knee walls (up to the eaves) and gable-end low walls.
	for sz_sign: float in [-1.0, 1.0]:
		_solid(root, Vector3(FOOTPRINT.x + 0.4, EAVE_H, WALL_T), Vector3(0, EAVE_H * 0.5, sz_sign * (hz + WALL_T * 0.5)), wood)
		_solid(root, Vector3(WALL_T, EAVE_H, FOOTPRINT.y), Vector3(sz_sign * (hx + WALL_T * 0.5), EAVE_H * 0.5, 0), wood)

	# Gable triangles (visual SurfaceTool prism + convex collision).
	for sx_sign: float in [-1.0, 1.0]:
		_build_gable(root, sx_sign * (hx + WALL_T * 0.5))

	# Roof planes: thin solid slabs on the pitch. +z slope tips down
	# toward +z with rotation.x = +pitch (see header math in README).
	var slope_len := sqrt(hz * hz + (RIDGE_H - EAVE_H) * (RIDGE_H - EAVE_H)) + 0.35
	var mid_y := (EAVE_H + RIDGE_H) * 0.5
	for sz_sign: float in [-1.0, 1.0]:
		_solid(root, Vector3(FOOTPRINT.x + 0.5, 0.12, slope_len), Vector3(0, mid_y, sz_sign * hz * 0.5), roof_col, Vector3(sz_sign * pitch, 0, 0))

	# Rafters: visual ribs just under each roof plane.
	for sz_sign: float in [-1.0, 1.0]:
		for i in range(-3, 4):
			var rx := float(i) * 1.6
			_visual(root, Vector3(0.09, 0.07, slope_len - 0.2), Vector3(rx, mid_y - 0.10, sz_sign * hz * 0.5), wood_dark, Vector3(sz_sign * pitch, 0, 0))

	# Ridge beam + collar beams a cat can walk along.
	_visual(root, Vector3(FOOTPRINT.x + 0.2, 0.16, 0.14), Vector3(0, RIDGE_H - 0.10, 0), wood_dark)
	for bx in BEAM_XS:
		_solid(root, Vector3(0.14, 0.18, FOOTPRINT.y - 0.4), Vector3(bx, BEAM_TOP - 0.09, 0), wood_dark)

	# Round window on the +x gable: frame ring, glowing glass, mullions.
	# (Surface-mounted — cutting a round hole is a GTA-port concern;
	# the light shaft sells it. See README.)
	var win := Node3D.new()
	win.name = "RoundWindow"
	win.position = WINDOW_POS
	win.rotation.y = -PI * 0.5 # face -x, into the room
	add_child(win)
	var torus := TorusMesh.new()
	torus.inner_radius = WINDOW_R - 0.07
	torus.outer_radius = WINDOW_R + 0.03
	torus.rings = 24
	torus.ring_segments = 8
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _mat(Color(0.55, 0.48, 0.40))
	win.add_child(ring)
	var glass := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = WINDOW_R
	cyl.bottom_radius = WINDOW_R
	cyl.height = 0.03
	cyl.radial_segments = 28
	glass.mesh = cyl
	glass.rotation.x = PI * 0.5
	glass.material_override = _glow_mat(Color(1.0, 0.88, 0.66), 2.2)
	win.add_child(glass)
	_visual(win, Vector3(0.05, WINDOW_R * 2.0, 0.03), Vector3.ZERO, Color(0.55, 0.48, 0.40))
	_visual(win, Vector3(WINDOW_R * 2.0, 0.05, 0.03), Vector3.ZERO, Color(0.55, 0.48, 0.40))

	# The light shaft: a translucent frustum from the window down into
	# the room, matched by the SpotLight3D in _build_lights.
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.09)
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = WINDOW_R * 0.95
	cone.bottom_radius = WINDOW_R * 2.1
	cone.height = 4.6
	cone.radial_segments = 24
	var shaft := MeshInstance3D.new()
	shaft.mesh = cone
	shaft.material_override = shaft_mat
	shaft.position = Vector3(3.55, 1.55, 0)
	shaft.rotation.z = -1.12 # lean from the window down toward the floor
	add_child(shaft)
	# Dust motes drifting in the shaft.
	for i in 14:
		var mote := _ell(self, Vector3(3.6 + randf_range(-0.7, 0.7), 1.5 + randf_range(-0.8, 0.9), randf_range(-0.7, 0.7)), Vector3.ONE * 0.022, Color(1, 0.95, 0.8))
		mote.material_override = _glow_mat(Color(1, 0.95, 0.8), 0.8)
		_dust.append(mote)


func _build_gable(parent: Node, x: float) -> void:
	var hz := FOOTPRINT.y * 0.5
	var t := WALL_T * 0.5
	var pts := PackedVector3Array([
		Vector3(x - t, EAVE_H, -hz), Vector3(x - t, EAVE_H, hz), Vector3(x - t, RIDGE_H, 0),
		Vector3(x + t, EAVE_H, -hz), Vector3(x + t, EAVE_H, hz), Vector3(x + t, RIDGE_H, 0),
	])
	var body := StaticBody3D.new()
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	cs.shape = shape
	body.add_child(cs)
	# Visual: the two triangle faces + three side quads, one surface.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := [0, 1, 2, 3, 5, 4, 0, 3, 4, 0, 4, 1, 1, 4, 5, 1, 5, 2, 2, 5, 3, 2, 3, 0]
	for i in idx:
		st.add_vertex(pts[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.40, 0.31, 0.21))
	body.add_child(mi)


# --- props -----------------------------------------------------------------------------

func _build_props() -> void:
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var cardboard := Color(0.62, 0.50, 0.35)
	var cardboard2 := Color(0.55, 0.44, 0.30)

	# Crate stairs by the hatch: floor -> stack -> the x=3.6 beam.
	_solid(root, Vector3(0.62, 0.38, 0.62), Vector3(4.45, 0.19, 2.55), cardboard)
	_solid(root, Vector3(0.58, 0.76, 0.58), Vector3(3.95, 0.38, 1.95), cardboard2)
	_solid(root, Vector3(0.54, 1.14, 0.54), Vector3(3.62, 0.57, 1.30), cardboard)

	# Stored boxes: obstacles and clutter (all solid).
	_solid(root, Vector3(0.9, 0.6, 0.9), Vector3(2.2, 0.30, -3.55), cardboard)
	_solid(root, Vector3(0.7, 0.45, 0.7), Vector3(2.25, 0.825, -3.5), cardboard2, Vector3(0, 0.4, 0))
	_solid(root, Vector3(1.1, 0.8, 0.8), Vector3(-0.7, 0.40, 3.85), cardboard2)
	_solid(root, Vector3(1.3, 1.0, 1.0), Vector3(-3.5, 0.50, -0.7), cardboard)
	_solid(root, Vector3(0.55, 0.55, 0.55), Vector3(1.6, 0.275, 1.9), cardboard, Vector3(0, 0.3, 0))
	_solid(root, Vector3(0.8, 0.5, 0.65), Vector3(-1.9, 0.25, -2.2), cardboard2, Vector3(0, -0.2, 0))

	# The old dresser against the -z knee wall: body, three drawer
	# fronts standing proud, knobs, junk on top. Top is walkable.
	var dresser := Color(0.35, 0.24, 0.16)
	_solid(root, Vector3(1.9, 0.88, 0.55), Vector3(-1.4, 0.44, -4.12), dresser)
	for i in 3:
		var dy := 0.18 + i * 0.27
		_visual(root, Vector3(1.7, 0.22, 0.03), Vector3(-1.4, dy, -3.83), Color(0.40, 0.28, 0.19))
		_ell(root, Vector3(-1.4, dy, -3.80), Vector3(0.05, 0.05, 0.05), Color(0.65, 0.55, 0.3), Vector3.ZERO, 0.4)
	_visual(root, Vector3(0.4, 0.22, 0.3), Vector3(-1.85, 0.99, -4.15), cardboard2, Vector3(0, 0.5, 0))
	_visual(root, Vector3(0.28, 0.16, 0.22), Vector3(-1.0, 0.96, -4.05), Color(0.45, 0.4, 0.35), Vector3(0, -0.3, 0))

	# Insulation piles: soft mounds (VISUAL ONLY — the slow is real,
	# the collision is not; cats wade). Pink, lumpy, overlapping.
	var pink := Color(0.83, 0.55, 0.58)
	var pink2 := Color(0.76, 0.48, 0.52)
	for pile in PILES:
		var c: Vector2 = pile[0]
		var r: Vector2 = pile[1]
		_ell(root, Vector3(c.x, 0.02, c.y), Vector3(r.x * 2.0, 0.42, r.y * 2.0), pink)
		_ell(root, Vector3(c.x + r.x * 0.4, 0.05, c.y - r.y * 0.3), Vector3(r.x * 1.1, 0.34, r.y * 1.1), pink2)
		_ell(root, Vector3(c.x - r.x * 0.45, 0.04, c.y + r.y * 0.35), Vector3(r.x * 0.9, 0.30, r.y * 0.9), pink)

	# The nest: a torn blanket on the biggest mound + shredded paper.
	_visual(root, Vector3(1.5, 0.07, 1.15), Vector3(NEST_POS.x + 0.2, 0.30, NEST_POS.z + 0.2), Color(0.45, 0.22, 0.20), Vector3(0, 0.35, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 255 # Massey
	for i in 7:
		_visual(root, Vector3(0.16, 0.015, 0.11), Vector3(NEST_POS.x + rng.randf_range(-0.7, 0.9), 0.345, NEST_POS.z + rng.randf_range(-0.6, 0.8)), Color(0.85, 0.83, 0.78), Vector3(0, rng.randf() * TAU, 0))

	# The bottle-cap hoard: revealed (with a pop) when the attic is won.
	_hoard = Node3D.new()
	_hoard.name = "BottleCapHoard"
	_hoard.position = Vector3(NEST_POS.x + 0.25, 0.37, NEST_POS.z + 0.25)
	_hoard.visible = false
	add_child(_hoard)
	var cap_cols: Array = [Color(0.75, 0.75, 0.78), Color(0.7, 0.2, 0.15), Color(0.2, 0.45, 0.7), Color(0.85, 0.65, 0.2)]
	for i in 9:
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.038
		cm.bottom_radius = 0.038
		cm.height = 0.014
		cm.radial_segments = 12
		cap.mesh = cm
		var col: Color = cap_cols[i % cap_cols.size()]
		cap.material_override = _glow_mat(col, 0.7) if i == 0 else _mat(col, 0.35)
		cap.position = Vector3(rng.randf_range(-0.3, 0.3), 0.01 + 0.008 * float(i % 3), rng.randf_range(-0.25, 0.25))
		cap.rotation.y = rng.randf() * TAU
		_hoard.add_child(cap)

	# The window perch: a solid ledge under the round window, reached
	# from the x=3.6 beam (jump) — after the win it is a lounge spot.
	_solid(root, Vector3(1.15, 0.07, 0.78), Vector3(PERCH_POS.x, PERCH_POS.y - 0.035, PERCH_POS.z), Color(0.48, 0.38, 0.28))
	_visual(root, Vector3(0.08, 0.5, 0.08), Vector3(5.75, 1.22, -0.3), Color(0.3, 0.22, 0.15), Vector3(0, 0, 0.5))
	_visual(root, Vector3(0.08, 0.5, 0.08), Vector3(5.75, 1.22, 0.3), Color(0.3, 0.22, 0.15), Vector3(0, 0, 0.5))
	# A cushion on the perch (visual): the future lounge spot.
	_visual(root, Vector3(0.95, 0.05, 0.6), Vector3(PERCH_POS.x, PERCH_POS.y + 0.025, PERCH_POS.z), Color(0.52, 0.30, 0.26))


func _build_lights() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.34, 0.26)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)

	# The window shaft light: warm, tight, angled down into the room.
	var spot := SpotLight3D.new()
	spot.position = Vector3(5.55, 2.30, 0)
	spot.light_color = Color(1.0, 0.88, 0.68)
	spot.light_energy = 5.0
	spot.spot_range = 9.0
	spot.spot_angle = 26.0
	spot.shadow_enabled = true
	add_child(spot)
	var aim := Node3D.new()
	aim.position = Vector3(1.4, 0.1, 0)
	add_child(aim)
	spot.look_at_from_position(spot.position, aim.global_position)
	aim.queue_free()

	# A dim warm fill so the far corners stay readable gloom.
	var omni := OmniLight3D.new()
	omni.position = Vector3(-1.0, 2.2, 0)
	omni.light_color = Color(1.0, 0.8, 0.6)
	omni.light_energy = 0.5
	omni.omni_range = 9.0
	add_child(omni)


func _process(delta: float) -> void:
	_time += delta
	# Dust motes drift slowly inside the shaft.
	for i in _dust.size():
		var m := _dust[i] as MeshInstance3D
		m.position.y -= delta * 0.03
		m.position.x += sin(_time * 0.6 + float(i) * 1.7) * delta * 0.02
		if m.position.y < 0.5:
			m.position.y = 2.4
