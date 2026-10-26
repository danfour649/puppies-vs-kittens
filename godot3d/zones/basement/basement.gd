class_name PvKBasement
extends Node3D
## THE BASEMENT of 255 Massey Street — Willie and Aggie's secret
## tunnel/labyrinth under the house: a maze of stacked cardboard
## boxes and shelf units, with rats, drop spiders, three ghosts, and
## one small brown act of defiance beside the litter box.
##
## Self-contained zone (see zones/basement/README.md for the full
## contract): loads standalone with a test cat, or the house hub can
## attach its own cat via attach_cat(). Objectives are declared in
## objectives.json beside this file; the HUD reads get_objectives().
##
## ==================== ARCHITECTURE (house-model data) ====================
## This zone is built to be lifted into GTA Fredericton later, so the
## whole layout is DATA below — no magic numbers in the builders.
## Axes: +x east, +z south, cat forward -Z. Units are metres.
##   Footprint 16.0 x 12.0 (x -8..8, z -6..6), floor top at FLOOR_Y,
##   ceiling at CEILING_H (a low basement). Interior maze on a 1 m
##   grid, GRID_MIN = (-7, -5): cell (c, r) centre is
##   (GRID_MIN.x + c + 0.5, GRID_MIN.y + r + 0.5).
##   Entry: stairs down the south wall (east end), spawn at stair foot.
## RECONCILIATION FLAG (integration): the foundation lane's shared
## house contract (massey-zones.md) was not yet published when this
## was built, so footprint / floor Y / stair position above are this
## zone's own documented values for the coordinator to reconcile.
## Stair position: RECONCILED 2026-10-25 — the fade pairing with the
## ground-floor shaft is ruled INTENTIONAL (see STAIR PAIRING in
## house/house_spec.gd); the stairs stay on the south wall as built.

# --- room ---------------------------------------------------------------------
const ROOM_MIN := Vector2(-8, -6)
## South face meets the house shell (inner z 4.5). The old room ran to z 6.
const ROOM_MAX := Vector2(8, 4.5)
const FLOOR_Y := 0.0
const CEILING_H := 2.3
const WALL_H := 1.9 ## maze box-stack collision height

# --- maze grid ------------------------------------------------------------------
const GRID_MIN := Vector2(-7, -5)
const GRID_COLS := 14
const GRID_ROWS := 10
## Row 9 stays the open south corridor, pulled north so it sits
## inside the shell instead of through the south wall.
const SOUTH_ROW_Z := 4.15
## Legend: '.' open  '#' box stack  'T' tunnel (low ceiling)
##         'G' the Aggie gap   'H' heart chamber floor   'A' alcove floor
const MAP: Array[String] = [
	"..#.##..#...##", # r0  z -5..-4
	"..#..#.##..###", # r1
	"....##.HH..GAA", # r2
	".......HH..#AA", # r3
	"....TTTT...###", # r4
	".#.......#....", # r5
	".#.##.##.##.#.", # r6
	"..............", # r7
	".##....#..##..", # r8
	"..............", # r9  z 4..5
]
const TUNNEL_H := 0.55 ## clear height under the tunnel slabs
## The Aggie gap: a slot in the box wall at cell (11, 2), the ONLY way
## into the NE alcove. Width derived from the character build data
## (see fit_capsule_for): Willie body diameter 0.154, Aggie 0.075 —
## GAP_W sits between them, so Aggie slips through and Willie cannot.
const GAP_CELL := Vector2i(11, 2)
const GAP_W := 0.115
const GAP_LINTEL_Y := 0.55 ## slot clear height

# --- key places -------------------------------------------------------------------
const ENTRY_POS := Vector3(4.35, 0.05, 4.15) ## stair foot, on the south row, inside the shell
const HEART_POS := Vector3(1.0, 0, -2.0) ## maze centre: the rat den
const LITTER_POS := Vector3(-7.35, 0, -3.9) ## NW corner
const GIFT_POS := Vector3(-6.76, 0, -3.76) ## beside the litter box. Not in it.
## RAT POISON (Glenys spec extension, Daniel 2026-10-24 23:32): old
## bait in the SW perimeter corner — OUTSIDE the maze grid, off the
## entry->heart path and every other route. Visible and labelled;
## lethal ONLY on contact with the bait itself (the cat must get
## INTO it): eat_poison, the run-ender. Walking past is safe.
const POISON_POS := Vector3(-7.45, 0, 4.05) ## SW corner, inside the shell, off the corridors
const POISON_RADIUS := 0.32 ## the bait tray's own footprint, nothing more
const SHELF_UNITS: Array = [ ## [position, rot_y] — boards face local +z
	[Vector3(-5.0, 0, -5.45), 0.0],
	[Vector3(0.5, 0, -5.45), 0.0],
	[Vector3(5.0, 0, -5.45), 0.0],
	[Vector3(-7.45, 0, -1.5), PI * 0.5],
	[Vector3(-7.45, 0, 2.5), PI * 0.5],
]
const SHELF_LEVELS: Array[float] = [0.08, 0.52, 0.96] ## board heights (jump ~0.45 apart)
const RAT_SPAWNS: Array = [ ## [position, is_alpha, den]
	[Vector3(1.0, 0.05, -2.0), true, Vector3(1.0, 0, -2.0)],
	[Vector3(0.3, 0.05, -1.3), false, Vector3(1.0, 0, -2.0)],
	[Vector3(1.7, 0.05, -2.7), false, Vector3(1.0, 0, -2.0)],
	[Vector3(-4.5, 0.05, -0.5), false, Vector3(-4.0, 0, 0.0)],
	[Vector3(-3.4, 0.05, 0.6), false, Vector3(-4.0, 0, 0.0)],
]
const SPIDER_ANCHORS: Array = [ ## under shelf boards
	Vector3(5.0, 0.93, -5.28),
	Vector3(-7.28, 0.93, 2.5),
]
const TOY_SPAWNS: Array = [ ## [id, position] — one behind the Aggie gap
	["ball", Vector3(-6.5, 0.07, 1.5)],
	["mouse_toy", Vector3(0.5, 1.05, -5.45)],
	["feather", Vector3(6.3, 0.05, -2.6)],
]
const CHOKE_POINTS: Array = [ ## ghost haunts: passages and tunnel mouths
	Vector3(-3.5, 0, -0.5), Vector3(1.5, 0, -0.5), Vector3(3.5, 0, -2.5),
	Vector3(-1.5, 0, 1.5), Vector3(-4.5, 0, -1.5),
]
const BULB_SPOTS: Array = [Vector3(4.4, 0, 4.15), Vector3(1.0, 0, -2.0), Vector3(-4.5, 0, 0.2)]

# --- tuning -----------------------------------------------------------------------
const CAT_MAX_HP := 9
const CAT_STRIKE_DAMAGE := 1
const STRIKE_HIT_RADIUS := 0.36 ## paw-point distance that lands a hit
const STARTLE_RADIUS := 4.0 ## hiss fallout: rats pause, spiders retreat
const TOY_PICKUP_RADIUS := 0.34

signal objective_completed(id: String)
signal toy_collected(id: String, count: int, total: int)
signal cat_hp_changed(hp: int, max_hp: int)
signal cat_hissed(cat: Node3D)
signal cat_respawned

@export var spawn_standalone_cat := true
@export var standalone_character := "willie"
@export var standalone_drive := true ## keyboard driving of the standalone cat (tests turn this off)
@export var use_follow_cam := true
@export var track_cat_hp := true ## the hub can switch this off and own HP itself

var player_cat: PvKCat = null
var dressing_count := 0 ## GLENYS dressing pass: clutter props built (tests read this)
var _poison_fired := false
var rats: Array = []
var spiders: Array = []
var ghosts: Array = []
var toys: Array = []
var alpha_rat: PvKRat = null
var cat_hp := CAT_MAX_HP
var toys_collected := 0

var _objectives: Array = []
var _done := {}
var _static: StaticBody3D
var _mats := {}
var _meshes := {}
var _bulbs: Array = [] ## [pivot, phase]
var _time := 0.0
var _cam: Camera3D = null
var _input_lock_t := 0.0
var _voice: AudioStreamPlayer3D = null

const CatScript := preload("res://cat_kit/cat.gd")
const RatScript := preload("res://zones/basement/rat.gd")
const SpiderScript := preload("res://zones/basement/spider.gd")
const ToyScript := preload("res://zones/basement/toy.gd")
const GhostScript := preload("res://zones/basement/ghost.gd")


# --- grid helpers (the maze as data — tests use these too) ------------------------

static func cell_center(c: int, r: int) -> Vector3:
	var z := GRID_MIN.y + r + 0.5
	if r == GRID_ROWS - 1:
		z = SOUTH_ROW_Z
	return Vector3(GRID_MIN.x + c + 0.5, 0, z)


static func cell_char(c: int, r: int) -> String:
	if c < 0 or r < 0 or c >= GRID_COLS or r >= GRID_ROWS:
		return "#"
	return MAP[r][c]


static func cell_walkable(c: int, r: int, block_gap: bool) -> bool:
	var ch := cell_char(c, r)
	if ch == "#":
		return false
	if ch == "G" and block_gap:
		return false
	return true


static func bfs_path(from_cell: Vector2i, to_cell: Vector2i, block_gap: bool) -> Array:
	## Breadth-first over the grid; returns cell list incl. both ends,
	## or [] when unreachable.
	if not cell_walkable(from_cell.x, from_cell.y, block_gap) or not cell_walkable(to_cell.x, to_cell.y, block_gap):
		return []
	var prev := {}
	var queue: Array[Vector2i] = [from_cell]
	prev[from_cell] = from_cell
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to_cell:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + d
			if prev.has(n) or not cell_walkable(n.x, n.y, block_gap):
				continue
			prev[n] = cur
			queue.append(n)
	if not prev.has(to_cell):
		return []
	var path: Array = []
	var cur := to_cell
	while cur != from_cell:
		path.push_front(cur)
		cur = prev[cur]
	path.push_front(from_cell)
	return path


## The zone's fit convention: a cat's blocking capsule comes from its
## character BUILD data, not the kit's one-size collision — radius is
## the torso half-width in world units, height the standing height.
## This is what makes the Aggie gap honest.
static func fit_capsule_for(cat: PvKCat) -> Dictionary:
	var radius := cat.torso_dia.x * cat.model_scale * 0.5
	var height := maxf(1.05 * cat.model_scale, radius * 2.0 + 0.05)
	return {"radius": radius, "height": height, "diameter": radius * 2.0}


static func apply_fit_capsule(cat: PvKCat) -> void:
	var fit := fit_capsule_for(cat)
	for child in cat.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			var cap := CapsuleShape3D.new()
			cap.radius = float(fit["radius"])
			cap.height = float(fit["height"])
			(child as CollisionShape3D).shape = cap
			(child as CollisionShape3D).position = Vector3(0, float(fit["height"]) * 0.5, 0)
			return


# --- build --------------------------------------------------------------------------

func _ready() -> void:
	_load_objectives()
	_static = StaticBody3D.new()
	_static.name = "Solids"
	add_child(_static)
	_build_environment()
	_build_room()
	_build_maze()
	_build_shelves()
	_build_props()
	_build_lights()
	HouseSurfaces.dress(self, HouseSpec.BASEMENT)
	HouseProps.dress(self, HouseSpec.BASEMENT)
	FloorAmbience.attach(self, "basement")
	_spawn_actors()
	if not spawn_standalone_cat:
		# INTEGRATION (hub mode): the foundation hub owns the cats,
		# HP and travel. Provide the entry/connector contract from
		# HouseSpec (positions reconciled — docs/massey-zones.md §9).
		HouseBuilder.add_entries(self, HouseSpec.BASEMENT)
		HouseBuilder.add_connectors(self, HouseSpec.BASEMENT)
	if use_follow_cam:
		_cam = Camera3D.new()
		_cam.name = "FollowCam"
		add_child(_cam)
		_cam.current = true
		_cam.position = ENTRY_POS + Vector3(0, 1.6, 2.4)
	if spawn_standalone_cat:
		var cat := CatScript.new() as PvKCat
		cat.set_character(standalone_character)
		add_child(cat)
		attach_cat(cat)


func _load_objectives() -> void:
	var f := FileAccess.open("res://zones/basement/objectives.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			_objectives = (parsed as Dictionary).get("objectives", [])


func get_objectives() -> Array:
	## objectives.json merged with live state — what the HUD renders.
	var out: Array = []
	for o: Dictionary in _objectives:
		var d := o.duplicate()
		d["done"] = objective_done(String(o.get("id", "")))
		if String(o.get("id", "")) == "lost_toys":
			d["progress"] = "%d/%d" % [toys_collected, toys.size()]
		out.append(d)
	return out


func objective_done(id: String) -> bool:
	if id == "lost_toys":
		return toys.size() > 0 and toys_collected >= toys.size()
	return bool(_done.get(id, false))


func _complete_objective(id: String) -> void:
	if _done.get(id, false):
		return
	_done[id] = true
	objective_completed.emit(id)


# --- materials / primitive helpers (PvKMouse idiom) ---------------------------------

func _mat(c: Color, rough := 0.95, metallic := 0.0) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough) + "|" + str(metallic)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metallic
		_mats[key] = m
	return _mats[key]


func _vis_box(parent: Node, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0, rough := 0.95) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _vis_sphere(parent: Node, pos: Vector3, dia: Vector3, c: Color, rough := 0.9) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c, rough)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func _vis_cyl(parent: Node, pos: Vector3, radius: float, height: float, c: Color, rot := Vector3.ZERO, metallic := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(c, 0.6, metallic)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _solid(size: Vector3, pos: Vector3, rot_y := 0.0, body: StaticBody3D = null) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = rot_y
	(body if body != null else _static).add_child(cs)
	return cs


# --- room shell -----------------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.025, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.30, 0.23)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.34, 0.22)
	env.fog_density = 0.03
	VisualQuality.apply_environment(env, "basement")
	we.environment = env
	add_child(we)


func _build_room() -> void:
	var concrete := Color(0.40, 0.39, 0.38)
	var dark_concrete := Color(0.23, 0.22, 0.21)
	var w := ROOM_MAX.x - ROOM_MIN.x
	var d := ROOM_MAX.y - ROOM_MIN.y
	var cx := (ROOM_MIN.x + ROOM_MAX.x) * 0.5
	var cz := (ROOM_MIN.y + ROOM_MAX.y) * 0.5
	# Floor + ceiling.
	_vis_box(self, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(cx, -0.1, cz), concrete.lightened(0.04))
	_solid(Vector3(w + 0.6, 0.2, d + 0.6), Vector3(cx, -0.1, cz))
	_vis_box(self, Vector3(w + 0.6, 0.15, d + 0.6), Vector3(cx, CEILING_H + 0.075, cz), dark_concrete)
	# Perimeter walls.
	_vis_box(self, Vector3(w + 0.6, CEILING_H, 0.3), Vector3(cx, CEILING_H * 0.5, ROOM_MIN.y - 0.15), concrete)
	_solid(Vector3(w + 0.6, CEILING_H, 0.3), Vector3(cx, CEILING_H * 0.5, ROOM_MIN.y - 0.15))
	_vis_box(self, Vector3(w + 0.6, CEILING_H, 0.3), Vector3(cx, CEILING_H * 0.5, ROOM_MAX.y + 0.15), concrete)
	_solid(Vector3(w + 0.6, CEILING_H, 0.3), Vector3(cx, CEILING_H * 0.5, ROOM_MAX.y + 0.15))
	_vis_box(self, Vector3(0.3, CEILING_H, d + 0.6), Vector3(ROOM_MIN.x - 0.15, CEILING_H * 0.5, cz), concrete)
	_solid(Vector3(0.3, CEILING_H, d + 0.6), Vector3(ROOM_MIN.x - 0.15, CEILING_H * 0.5, cz))
	_vis_box(self, Vector3(0.3, CEILING_H, d + 0.6), Vector3(ROOM_MAX.x + 0.15, CEILING_H * 0.5, cz), concrete)
	_solid(Vector3(0.3, CEILING_H, d + 0.6), Vector3(ROOM_MAX.x + 0.15, CEILING_H * 0.5, cz))


func _cardboard(seed_v: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	return Color(0.62, 0.48, 0.30).lightened(rng.randf_range(-0.05, 0.09))


func _build_maze() -> void:
	for r in GRID_ROWS:
		for c in GRID_COLS:
			var ch := cell_char(c, r)
			var ctr := cell_center(c, r)
			match ch:
				"#":
					_box_stack(ctr, c * 73 + r * 149)
					var solid_z := ctr.z
					var solid_d := 1.0
					# The row just north of the south corridor gives that
					# lane a little air, so Willie is not squeezed into the wall.
					if r == GRID_ROWS - 2:
						solid_d = 0.82
						solid_z -= 0.09
					_solid(Vector3(1.0, WALL_H, solid_d), Vector3(ctr.x, WALL_H * 0.5, solid_z))
				"T":
					# The tunnel: a slab at TUNNEL_H with boxes above it.
					_vis_box(self, Vector3(1.0, 0.1, 1.0), Vector3(ctr.x, TUNNEL_H + 0.05, ctr.z), _cardboard(c * 31 + r * 7))
					_solid(Vector3(1.0, 0.12, 1.0), Vector3(ctr.x, TUNNEL_H + 0.04, ctr.z))
					_vis_box(self, Vector3(0.94, 0.8, 0.94), Vector3(ctr.x, TUNNEL_H + 0.5, ctr.z), _cardboard(c * 17 + r * 3))
					_solid(Vector3(1.0, 0.85, 1.0), Vector3(ctr.x, TUNNEL_H + 0.52, ctr.z))
				"G":
					_build_gap(ctr)


func _box_stack(ctr: Vector3, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h1 := rng.randf_range(0.75, 0.95)
	_vis_box(self, Vector3(0.96, h1, 0.96), Vector3(ctr.x, h1 * 0.5, ctr.z), _cardboard(seed_v), rng.randf_range(-0.03, 0.03))
	var h2 := rng.randf_range(0.7, 0.95)
	_vis_box(self, Vector3(0.88, h2, 0.88), Vector3(ctr.x, h1 + h2 * 0.5, ctr.z), _cardboard(seed_v + 5), rng.randf_range(-0.06, 0.06))
	if rng.randf() < 0.3:
		_vis_box(self, Vector3(0.5, 0.34, 0.5), Vector3(ctr.x, h1 + h2 + 0.17, ctr.z), _cardboard(seed_v + 9), rng.randf_range(-0.15, 0.15))


func _build_gap(ctr: Vector3) -> void:
	## The slot wall: two box runs leave a GAP_W hole on the cell
	## centreline, roofed by a lintel at GAP_LINTEL_Y.
	var card := _cardboard(4242)
	var side := (1.0 - GAP_W) * 0.5
	var z_off := GAP_W * 0.5 + side * 0.5
	_vis_box(self, Vector3(1.0, WALL_H, side), Vector3(ctr.x, WALL_H * 0.5, ctr.z - z_off), card)
	_solid(Vector3(1.0, WALL_H, side), Vector3(ctr.x, WALL_H * 0.5, ctr.z - z_off))
	_vis_box(self, Vector3(1.0, WALL_H, side), Vector3(ctr.x, WALL_H * 0.5, ctr.z + z_off), card.lightened(0.04))
	_solid(Vector3(1.0, WALL_H, side), Vector3(ctr.x, WALL_H * 0.5, ctr.z + z_off))
	var lintel_h := WALL_H - GAP_LINTEL_Y
	_vis_box(self, Vector3(1.0, lintel_h, GAP_W + 0.05), Vector3(ctr.x, GAP_LINTEL_Y + lintel_h * 0.5, ctr.z), card.darkened(0.08))
	_solid(Vector3(1.0, lintel_h, GAP_W + 0.05), Vector3(ctr.x, GAP_LINTEL_Y + lintel_h * 0.5, ctr.z))


# --- shelves ----------------------------------------------------------------------------

func _build_shelves() -> void:
	var wood := Color(0.42, 0.30, 0.17)
	for i in SHELF_UNITS.size():
		var spec: Array = SHELF_UNITS[i]
		var holder := Node3D.new()
		holder.position = spec[0]
		holder.rotation.y = float(spec[1])
		add_child(holder)
		var body := StaticBody3D.new()
		holder.add_child(body)
		for sx: float in [-0.92, 0.92]:
			_vis_box(holder, Vector3(0.06, 1.02, 0.5), Vector3(sx, 0.51, 0), wood.darkened(0.1))
		for lvl: float in SHELF_LEVELS:
			_vis_box(holder, Vector3(1.9, 0.05, 0.5), Vector3(0, lvl, 0), wood)
			_solid(Vector3(1.9, 0.05, 0.5), Vector3(0, lvl, 0), 0.0, body)
		# Clutter on the boards (visual only).
		var rng := RandomNumberGenerator.new()
		rng.seed = 700 + i * 13
		for lvl: float in SHELF_LEVELS:
			var n := rng.randi_range(1, 3)
			for j in n:
				var s := rng.randf_range(0.10, 0.22)
				_vis_box(holder, Vector3(s, s * rng.randf_range(0.7, 1.3), s), Vector3(rng.randf_range(-0.75, 0.75), lvl + 0.03 + s * 0.5, rng.randf_range(-0.12, 0.12)), _cardboard(rng.randi()), rng.randf_range(-0.2, 0.2))
	# Step boxes up to the shelves (jump ~0.45 between levels).
	_vis_box(self, Vector3(0.5, 0.28, 0.5), Vector3(-0.35, 0.14, -4.72), _cardboard(11))
	_solid(Vector3(0.5, 0.28, 0.5), Vector3(-0.35, 0.14, -4.72))
	_vis_box(self, Vector3(0.45, 0.55, 0.45), Vector3(0.42, 0.275, -4.78), _cardboard(12))
	_solid(Vector3(0.45, 0.55, 0.45), Vector3(0.42, 0.275, -4.78))
	_vis_box(self, Vector3(0.5, 0.28, 0.5), Vector3(-6.72, 0.14, 2.5), _cardboard(13))
	_solid(Vector3(0.5, 0.28, 0.5), Vector3(-6.72, 0.14, 2.5))


# --- props: stairs, furnace, pipes, litter corner -----------------------------------------

func _build_props() -> void:
	var wood := Color(0.40, 0.29, 0.16)
	# Entry stairs: up the south wall, in the southeast corner, inside the shell.
	for i in 4:
		var h := (i + 1) * 0.30
		var pos := Vector3(6.2 + i * 0.36, h * 0.5, 4.32)
		_vis_box(self, Vector3(0.36, h, 0.32), pos, wood)
		_solid(Vector3(0.36, h, 0.32), pos)
	_vis_box(self, Vector3(0.08, 1.0, 0.7), Vector3(7.55, 1.6, 4.28), Color(0.16, 0.12, 0.09)) # door slab
	_vis_box(self, Vector3(0.7, 0.08, 0.55), Vector3(7.15, 1.2, 4.28), wood.darkened(0.15)) # landing
	_solid(Vector3(0.7, 0.08, 0.55), Vector3(7.15, 1.2, 4.28))
	# Furnace + water heater against the east wall.
	var metal := Color(0.45, 0.47, 0.50)
	_vis_cyl(self, Vector3(7.35, 0.75, -1.2), 0.52, 1.5, metal, Vector3.ZERO, 0.55)
	_vis_box(self, Vector3(0.7, 0.45, 0.7), Vector3(7.35, 1.72, -1.2), metal.darkened(0.12))
	_solid(Vector3(1.1, 1.95, 1.1), Vector3(7.35, 0.97, -1.2))
	_vis_cyl(self, Vector3(7.4, 0.62, 1.3), 0.38, 1.25, Color(0.55, 0.57, 0.60), Vector3.ZERO, 0.55)
	_solid(Vector3(0.85, 1.3, 0.85), Vector3(7.4, 0.65, 1.3))
	# Overhead pipes: two runs along the north wall, one down the east.
	_vis_cyl(self, Vector3(0, 2.12, -5.62), 0.05, 15.6, metal, Vector3(0, 0, PI * 0.5), 0.7)
	_vis_cyl(self, Vector3(0, 2.12, -5.36), 0.04, 15.6, metal.darkened(0.1), Vector3(0, 0, PI * 0.5), 0.7)
	_vis_cyl(self, Vector3(7.72, 2.05, 0), 0.06, 11.0, metal, Vector3(PI * 0.5, 0, 0), 0.7)
	_build_litter_corner()
	_build_poison()
	_build_dressing()


func _build_litter_corner() -> void:
	var plastic := Color(0.33, 0.44, 0.60)
	var g := Node3D.new()
	g.name = "LitterCorner"
	g.position = LITTER_POS
	add_child(g)
	_vis_box(g, Vector3(0.62, 0.15, 0.45), Vector3(0, 0.075, 0), plastic)
	_vis_box(g, Vector3(0.54, 0.05, 0.37), Vector3(0, 0.135, 0), Color(0.76, 0.68, 0.50), 0.0, 1.0) # litter fill
	_solid(Vector3(0.62, 0.15, 0.45), LITTER_POS + Vector3(0, 0.075, 0))
	# The gift. Beside the box. On the floor. (See README.)
	var gift := Node3D.new()
	gift.name = "TheGift"
	gift.position = GIFT_POS
	add_child(gift)
	_vis_sphere(gift, Vector3.ZERO, Vector3(0.11, 0.05, 0.09), Color(0.30, 0.19, 0.09), 1.0)
	_vis_sphere(gift, Vector3(0.07, -0.005, 0.03), Vector3(0.06, 0.032, 0.05), Color(0.26, 0.16, 0.08), 1.0)


## The rat poison bait (Glenys extension): a tipped old bait box,
## its tray, and spilled pellets in the SW perimeter corner. It is
## LABELLED in-world — a cat player can read exactly what it is —
## and it is the only lethal thing down here.
func _build_poison() -> void:
	var g := Node3D.new()
	g.name = "RatPoison"
	g.position = POISON_POS
	add_child(g)
	# The bait tray — the contact footprint (POISON_RADIUS) is this.
	_vis_box(g, Vector3(0.52, 0.03, 0.40), Vector3(0, 0.015, 0), Color(0.16, 0.15, 0.13))
	# Poison pellets, an unwholesome green, heaped in the tray.
	var pellet := Color(0.36, 0.58, 0.24)
	for p: Vector3 in [Vector3(-0.12, 0.045, -0.06), Vector3(0.02, 0.05, 0.05), Vector3(0.13, 0.045, -0.09), Vector3(-0.04, 0.055, -0.12), Vector3(0.09, 0.04, 0.11)]:
		_vis_sphere(g, p, Vector3(0.075, 0.05, 0.075), pellet, 1.0)
	# A few spilled on the concrete beside the tray (visual only —
	# the lethal footprint stays the tray itself).
	for p: Vector3 in [Vector3(0.38, 0.02, 0.18), Vector3(0.44, 0.02, -0.05)]:
		_vis_sphere(g, p, Vector3(0.05, 0.035, 0.05), pellet, 1.0)
	# The old box it came in, tipped against the wall, warning stripe.
	_vis_box(g, Vector3(0.36, 0.26, 0.10), Vector3(-0.18, 0.13, -0.33), Color(0.55, 0.48, 0.20), 0.35)
	_vis_box(g, Vector3(0.37, 0.07, 0.105), Vector3(-0.18, 0.20, -0.33), Color(0.75, 0.28, 0.14), 0.35)
	# The label: readable from across the corner, because fair's fair.
	var label := Label3D.new()
	label.text = "RAT POISON"
	label.font_size = 64
	label.pixel_size = 0.0035
	label.modulate = Color(0.95, 0.35, 0.18)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.55, -0.1)
	g.add_child(label)


## DRESSING (Glenys extension, Daniel 2026-10-24): more old tools
## and stored junk — a full workbench, paint cans, shelf jars, wall
## tools, a ladder, a hose. HARD CONSTRAINT: none of it touches the
## maze. Every piece sits in the perimeter strip, on a shelf board,
## or on the workbench (the one new solid, also perimeter) — the
## MAP grid, the entrance->heart walk and the Aggie gap are exactly
## as they were. dressing_count lets the tests prove it landed.
func _build_dressing() -> void:
	var wood := Color(0.40, 0.29, 0.16)
	var metal := Color(0.45, 0.47, 0.50)
	# The workbench: west wall, between the litter corner and the
	# west shelves. Top + the lane's one dressing solid.
	_vis_box(self, Vector3(0.55, 0.07, 1.9), Vector3(-7.68, 0.80, 1.2), wood.darkened(0.1))
	_solid(Vector3(0.55, 0.07, 1.9), Vector3(-7.68, 0.80, 1.2))
	for dz: float in [-0.85, 0.85]:
		_vis_box(self, Vector3(0.5, 0.78, 0.08), Vector3(-7.68, 0.39, 1.2 + dz), wood.darkened(0.25))
	dressing_count += 1
	# Tools ON the bench: hammer, saw, wrench, oil can, a jar of nails.
	_vis_cyl(self, Vector3(-7.70, 0.86, 0.75), 0.02, 0.30, wood.lightened(0.25), Vector3(PI * 0.5, 0, 0.3))
	_vis_box(self, Vector3(0.16, 0.07, 0.06), Vector3(-7.70, 0.875, 0.62), metal.darkened(0.2))
	dressing_count += 1 # hammer
	_vis_box(self, Vector3(0.03, 0.02, 0.55), Vector3(-7.66, 0.845, 1.35), metal.lightened(0.15))
	_vis_box(self, Vector3(0.07, 0.09, 0.16), Vector3(-7.66, 0.87, 1.62), Color(0.62, 0.16, 0.12))
	dressing_count += 1 # saw + grip
	_vis_box(self, Vector3(0.05, 0.03, 0.24), Vector3(-7.60, 0.85, 1.95), metal.darkened(0.05), 0.5)
	dressing_count += 1 # wrench
	_vis_cyl(self, Vector3(-7.78, 0.93, 2.15), 0.055, 0.19, Color(0.55, 0.20, 0.14), Vector3.ZERO, 0.4)
	_vis_cyl(self, Vector3(-7.78, 1.02, 2.15), 0.012, 0.09, metal, Vector3(0, 0, 0.5), 0.5)
	dressing_count += 1 # oil can
	_vis_cyl(self, Vector3(-7.55, 0.90, 0.35), 0.05, 0.13, Color(0.75, 0.78, 0.72), Vector3.ZERO, 0.15)
	dressing_count += 1 # jar
	# Paint cans, NE perimeter corner: two up, one tipped.
	_vis_cyl(self, Vector3(7.55, 0.16, -5.60), 0.13, 0.32, Color(0.62, 0.58, 0.50), Vector3.ZERO, 0.35)
	_vis_cyl(self, Vector3(7.25, 0.13, -5.72), 0.11, 0.26, Color(0.30, 0.42, 0.55), Vector3.ZERO, 0.35)
	_vis_cyl(self, Vector3(7.62, 0.11, -5.18), 0.12, 0.30, Color(0.55, 0.30, 0.16), Vector3(PI * 0.5, 0, 0.2), 0.35)
	dressing_count += 3
	# Jars + a spray bottle on the north shelf boards.
	for jx: float in [-5.25, -4.95, -4.68]:
		_vis_cyl(self, Vector3(jx, 1.03, -5.45), 0.045, 0.13, Color(0.78, 0.80, 0.74), Vector3.ZERO, 0.15)
		dressing_count += 1
	_vis_cyl(self, Vector3(0.32, 1.02, -5.45), 0.04, 0.17, Color(0.25, 0.45, 0.65), Vector3.ZERO, 0.3)
	_vis_box(self, Vector3(0.05, 0.06, 0.05), Vector3(0.32, 1.13, -5.45), Color(0.85, 0.80, 0.70))
	dressing_count += 1 # spray bottle
	# Wall tools on the east wall: shovel + rake, hung high.
	_vis_cyl(self, Vector3(7.86, 1.25, -2.9), 0.022, 1.15, wood.lightened(0.2), Vector3(0, 0, 0.06))
	_vis_box(self, Vector3(0.04, 0.34, 0.20), Vector3(7.86, 0.60, -2.88), metal.darkened(0.15))
	dressing_count += 1 # shovel
	_vis_cyl(self, Vector3(7.86, 1.30, -3.35), 0.02, 1.05, wood.lightened(0.2), Vector3(0, 0, -0.05))
	_vis_box(self, Vector3(0.04, 0.05, 0.34), Vector3(7.86, 0.80, -3.37), metal.darkened(0.1))
	dressing_count += 1 # rake
	# A ladder leaning on the north wall, west of the heart.
	for dx: float in [-0.22, 0.22]:
		_vis_box(self, Vector3(0.05, 2.0, 0.05), Vector3(-2.5 + dx, 1.02, -5.80), wood.darkened(0.05), 0.0)
	for i in 4:
		_vis_box(self, Vector3(0.44, 0.045, 0.045), Vector3(-2.5, 0.35 + i * 0.42, -5.79), wood)
	dressing_count += 1
	# A coiled hose on the west wall.
	var hose := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.26
	hose.mesh = tm
	hose.material_override = _mat(Color(0.20, 0.32, 0.20), 1.0)
	hose.position = Vector3(-7.88, 1.05, -0.9)
	hose.rotation = Vector3(0, PI * 0.5, 0)
	add_child(hose)
	dressing_count += 1
	# Cardboard pile on the south strip, west of the entry stairs.
	_vis_box(self, Vector3(0.8, 0.4, 0.45), Vector3(0.4, 0.2, 4.32), _cardboard(31))
	_vis_box(self, Vector3(0.65, 0.35, 0.4), Vector3(0.45, 0.57, 4.30), _cardboard(32), 0.3)
	_vis_box(self, Vector3(0.5, 0.3, 0.36), Vector3(-0.35, 0.15, 4.34), _cardboard(33), -0.2)
	dressing_count += 3


## The bait's local position (tests + the Glenys README read this).
func poison_pos() -> Vector3:
	return POISON_POS


func _build_lights() -> void:
	for i in BULB_SPOTS.size():
		var spot: Vector3 = BULB_SPOTS[i]
		var pivot := Node3D.new()
		pivot.position = Vector3(spot.x, CEILING_H, spot.z)
		add_child(pivot)
		_vis_cyl(pivot, Vector3(0, -0.25, 0), 0.008, 0.5, Color(0.1, 0.1, 0.1))
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.85, 0.58)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.78, 0.45)
		bulb_mat.emission_energy_multiplier = 2.2
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		bulb.mesh = sm
		bulb.material_override = bulb_mat
		bulb.position = Vector3(0, -0.53, 0)
		pivot.add_child(bulb)
		var omni := OmniLight3D.new()
		omni.position = Vector3(0, -0.56, 0)
		omni.light_color = Color(1.0, 0.78, 0.50)
		omni.light_energy = 1.25
		omni.omni_range = 7.5
		omni.shadow_enabled = i == 0 and VisualQuality.is_high()
		if VisualQuality.is_high():
			omni.light_volumetric_fog_energy = 0.8
		pivot.add_child(omni)
		_bulbs.append([pivot, float(i) * 1.93])
	# Dust in the bulb light. One shaft is enough; more would wash the maze.
	if BULB_SPOTS.size() > 0:
		var spot: Vector3 = BULB_SPOTS[0]
		VisualQuality.add_dust_shaft(self, Vector3(spot.x, CEILING_H - 0.15, spot.z), -75.0, 15.0)


# --- actors --------------------------------------------------------------------------------

func _spawn_actors() -> void:
	for spec: Array in RAT_SPAWNS:
		var rat := RatScript.new() as PvKRat
		if bool(spec[1]):
			rat.is_alpha = true
			rat.max_hp = 10
			rat.bite_damage = 2
			rat.model_scale = 0.34
			rat.chase_speed = 2.9
			alpha_rat = rat
		rat.add_to_group("basement_rats")
		rat.position = spec[0] # set before entering the tree: _ready reads it
		rat.den = spec[2]
		rat.bite.connect(_on_enemy_bite)
		rat.died.connect(_on_rat_died)
		add_child(rat)
		rats.append(rat)
	for anchor: Vector3 in SPIDER_ANCHORS:
		var sp := SpiderScript.new() as PvKSpider
		sp.position = anchor
		sp.bite.connect(_on_enemy_bite)
		add_child(sp)
		spiders.append(sp)
	for spec: Array in TOY_SPAWNS:
		var toy := ToyScript.new() as PvKToy
		toy.toy_id = String(spec[0])
		toy.position = spec[1]
		add_child(toy)
		toys.append(toy)
	for i in 3:
		var ghost := GhostScript.new() as PvKGhost
		ghost.tint_index = i
		ghost.flipped = i == 1
		ghost.chokes = CHOKE_POINTS.duplicate()
		var start_choke: int = [0, 2, 3][i]
		ghost.set("_choke_i", start_choke)
		ghost.position = CHOKE_POINTS[start_choke]
		ghost.hiss_triggered.connect(_on_hiss_triggered)
		add_child(ghost)
		ghosts.append(ghost)


## Place the player cat (hub entry point). Replaces any standalone cat.
func attach_cat(cat: PvKCat) -> void:
	if player_cat != null and is_instance_valid(player_cat) and player_cat != cat:
		player_cat.queue_free()
	player_cat = cat
	apply_fit_capsule(cat)
	cat.global_position = ENTRY_POS
	cat.rotation.y = 0.0
	if not cat.paw_swiped.is_connected(_on_paw_swiped):
		cat.paw_swiped.connect(_on_paw_swiped)
	for rat: PvKRat in rats:
		rat.target_cat = cat
	for sp: PvKSpider in spiders:
		sp.target_cat = cat
	for g: PvKGhost in ghosts:
		g.target_cat = cat
	if _voice == null:
		_voice = HissAudio.make_voice(self)


# --- combat / interaction ---------------------------------------------------------------------


# --- hub integration (the foundation game) -------------------------------------------------------

## The zone-root contract (docs/massey-zones.md §2), provided
## directly rather than via ZoneRoot: this zone predates the base
## class and builds its own shell; the entry/connector nodes come
## from HouseSpec (see _ready).
func get_entry(entry_name: String) -> Node3D:
	return get_node_or_null(entry_name) as Node3D


## Sibling lounge spots: all on fully open rows of the MAP, so the
## sibling can always amble to one through the corridors.
func get_lounge_spots() -> Array:
	var out: Array = []
	for p: Vector3 in [Vector3(2.2, 0.02, SOUTH_ROW_Z), Vector3(-6.5, 0.02, 2.5), Vector3(6.5, 0.02, 0.5)]:
		out.append(to_global(p))
	return out


func get_wander_rect() -> Rect2:
	var r := Rect2(-7.6, -5.6, 15.2, 9.85)
	return Rect2(r.position + Vector2(global_position.x, global_position.z), r.size)


var _hub_fit_cat: PvKCat = null ## cat currently wearing the fit capsule
var _hub_orig_capsule := {} ## cat -> [shape, position] before the fit swap


## Hub registration: track the game's player cat WITHOUT placing
## it (the ZoneManager owns placement) and without freeing the
## previous cat (it is the game's other cat, not a stand-in).
func register_hub_cat(cat: PvKCat) -> void:
	if player_cat == cat:
		return
	if player_cat != null and is_instance_valid(player_cat) and player_cat.paw_swiped.is_connected(_on_paw_swiped):
		player_cat.paw_swiped.disconnect(_on_paw_swiped)
	player_cat = cat
	if cat == null:
		return
	if not cat.paw_swiped.is_connected(_on_paw_swiped):
		cat.paw_swiped.connect(_on_paw_swiped)
	if _voice == null:
		_voice = HissAudio.make_voice(self)


var _foe_target: PvKCat = null ## who the foes are wired to (in-zone only)


func _poll_hub() -> void:
	if spawn_standalone_cat:
		return
	var pc := get_tree().get_first_node_in_group("player_cat") as PvKCat
	if pc != player_cat:
		register_hub_cat(pc)
	# The Aggie gap is honest only while the player wears the
	# build-data fit capsule; swap it in for this zone and restore
	# the kit capsule on the way out.
	var mgr := get_tree().get_first_node_in_group("zone_manager")
	var in_zone := mgr != null and String(mgr.get("current_zone")) == HouseSpec.BASEMENT
	# Foes hunt only while the player is actually down here. Their
	# steering is flat-XZ by design (same-floor maze), so a wired
	# rat would otherwise bite ankles through the ceiling and a
	# guarding ghost would hiss at the floorboards.
	var want: PvKCat = pc if in_zone else null
	if _foe_target != want:
		_foe_target = want
		for rat: PvKRat in rats:
			rat.target_cat = want
		for sp: PvKSpider in spiders:
			sp.target_cat = want
		for g: PvKGhost in ghosts:
			g.target_cat = want
	if in_zone and pc != null and _hub_fit_cat != pc:
		_hub_apply_fit(pc)
	elif not in_zone and _hub_fit_cat != null:
		_hub_restore_fit()


func _hub_apply_fit(cat: PvKCat) -> void:
	_hub_restore_fit()
	for child in cat.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			_hub_orig_capsule[cat] = [(child as CollisionShape3D).shape, (child as CollisionShape3D).position]
			break
	apply_fit_capsule(cat)
	_hub_fit_cat = cat


func _hub_restore_fit() -> void:
	var cat := _hub_fit_cat
	_hub_fit_cat = null
	if cat == null or not is_instance_valid(cat) or not _hub_orig_capsule.has(cat):
		return
	var saved: Array = _hub_orig_capsule[cat]
	for child in cat.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			(child as CollisionShape3D).shape = saved[0]
			(child as CollisionShape3D).position = saved[1]
			break

func _on_paw_swiped() -> void:
	if player_cat == null:
		return
	var pp := player_cat.paw_point()
	var foes: Array = []
	foes.append_array(rats)
	foes.append_array(spiders)
	for foe in foes:
		if foe.is_dead():
			continue
		if absf(foe.global_position.y - pp.y) > 1.2:
			continue # another floor: the paw does not reach through it
		var d := Vector2(foe.global_position.x - pp.x, foe.global_position.z - pp.z).length()
		if d <= STRIKE_HIT_RADIUS:
			foe.take_hit(CAT_STRIKE_DAMAGE, player_cat.global_position)
	# Ghosts are deliberately NOT in the foe list: the paw passes
	# through them and nothing changes — on either side.


func _on_enemy_bite(_target: Node3D, damage: int) -> void:
	if not track_cat_hp:
		# Hub mode: the foundation cat owns HP. Forward the bite in
		# this zone's own proportion of a life (damage / CAT_MAX_HP).
		var t := _target as PvKCat
		if t != null and t.has_method("take_damage"):
			t.take_damage(float(damage) * t.max_hp / float(CAT_MAX_HP), t.global_position)
		return
	cat_hp = maxi(0, cat_hp - damage)
	cat_hp_changed.emit(cat_hp, CAT_MAX_HP)
	if cat_hp <= 0 and player_cat != null:
		player_cat.global_position = ENTRY_POS
		player_cat.velocity = Vector3.ZERO
		cat_hp = CAT_MAX_HP
		cat_hp_changed.emit(cat_hp, CAT_MAX_HP)
		cat_respawned.emit()


func _on_rat_died(rat: PvKRat) -> void:
	if rat == alpha_rat:
		_complete_objective("clear_labyrinth_heart")


func _on_hiss_triggered(ghost: PvKGhost, cat: Node3D) -> void:
	# The foundation cat contract: hiss() if the cat has one.
	if cat != null and cat.has_method("hiss"):
		cat.hiss()
	_input_lock_t = 1.5 # zone-side lock for cats without their own
	cat_hissed.emit(cat)
	var voiced := cat != null and cat.get_node_or_null("CatVoice") != null
	if _voice != null and not voiced:
		_voice.global_position = cat.global_position if cat != null else _voice.global_position
		_voice.play()
	# The hiss is LOUD: spiders bolt up their threads, rats freeze.
	for sp: PvKSpider in spiders:
		if not sp.is_dead() and sp.global_position.distance_to(ghost.global_position) <= STARTLE_RADIUS:
			sp.force_retreat()
	for rat: PvKRat in rats:
		if not rat.is_dead() and rat.global_position.distance_to(ghost.global_position) <= STARTLE_RADIUS:
			rat.startle(1.2)


# --- per-frame --------------------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_input_lock_t = maxf(0.0, _input_lock_t - _delta)
	if not spawn_standalone_cat or not standalone_drive or player_cat == null:
		return
	# Standalone driving: WASD/arrows + Shift sprint + Space strike.
	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if _input_lock_t > 0.0:
		mv = Vector2.ZERO
	var dir := Vector3(mv.x, 0, -mv.y)
	player_cat.set_move_input(dir, Input.is_physical_key_pressed(KEY_SHIFT), false)
	if Input.is_physical_key_pressed(KEY_SPACE) and _input_lock_t <= 0.0:
		player_cat.strike()


func _process(delta: float) -> void:
	_poll_hub()
	_time += delta
	for pair: Array in _bulbs:
		var pivot := pair[0] as Node3D
		pivot.rotation.z = sin(_time * 0.85 + float(pair[1])) * 0.055
		pivot.rotation.x = cos(_time * 0.63 + float(pair[1])) * 0.04
	# Toy pickup.
	if player_cat != null and is_instance_valid(player_cat):
		for toy_v in toys:
			if not is_instance_valid(toy_v):
				continue
			var toy := toy_v as PvKToy
			if toy == null or toy.collected_flag:
				continue
			var d := Vector2(toy.global_position.x - player_cat.global_position.x, toy.global_position.z - player_cat.global_position.z).length()
			if d <= TOY_PICKUP_RADIUS and absf(toy.global_position.y - player_cat.global_position.y) < 0.6:
				toy.collect()
				toys_collected += 1
				toy_collected.emit(toy.toy_id, toys_collected, toys.size())
				if objective_done("lost_toys"):
					_complete_objective("lost_toys")
	# RAT POISON: contact with the bait itself — and nothing else
	# down here — is lethal. The check runs in LOCAL space, so it
	# can only fire for a cat physically in this room, and the
	# radius is the tray's own footprint: beside it is safe.
	if not _poison_fired and player_cat != null and is_instance_valid(player_cat) and player_cat.has_method("eat_poison"):
		var lp := to_local(player_cat.global_position)
		if absf(lp.y) < 0.9 and Vector2(lp.x - POISON_POS.x, lp.z - POISON_POS.z).length() <= POISON_RADIUS:
			_poison_fired = true
			player_cat.eat_poison("rat_poison")
	# Standalone follow camera.
	if _cam != null and player_cat != null:
		var want := player_cat.global_position + Vector3(0, 1.6, 2.4)
		_cam.global_position = _cam.global_position.lerp(want, 1.0 - exp(-6.0 * delta))
		_cam.look_at(player_cat.global_position + Vector3(0, 0.15, 0), Vector3.UP)
