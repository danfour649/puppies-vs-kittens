class_name HouseBuilder
extends RefCounted
## HOUSE BUILDER — constructs 255 Massey from HouseSpec, in the
## cat_kit idiom: procedural flat-colour boxes, cached materials and
## meshes, ONE StaticBody3D per zone. Every interior zone is built
## by this file (shells for all three floors; full furniture for the
## ground floor) so the zones can never disagree about the house.
##
## Usage from a zone root:
##   var kit := HouseBuilder.kit(self)
##   HouseBuilder.build_ground_floor(kit)   # or build_stub(kit, id)

class Kit:
	extends RefCounted
	var root: Node3D
	var statics: StaticBody3D = null
	var _mats := {}
	var _meshes := {}

	func _init(p: Node3D) -> void:
		root = p

	func mat(c: Color) -> StandardMaterial3D:
		var key := c.to_html()
		if not _mats.has(key):
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = 0.95
			_mats[key] = m
		return _mats[key]

	func _statics() -> StaticBody3D:
		if statics == null:
			statics = StaticBody3D.new()
			statics.name = "Statics"
			root.add_child(statics)
		return statics

	func box(size: Vector3, pos: Vector3, color: Color, is_static := false, rot := Vector3.ZERO) -> MeshInstance3D:
		if not _meshes.has(size):
			var bm := BoxMesh.new()
			bm.size = size
			_meshes[size] = bm
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[size]
		mi.material_override = mat(color)
		mi.position = pos
		mi.rotation = rot
		root.add_child(mi)
		if is_static:
			static_box(size, pos, rot)
		return mi

	func static_box(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.position = pos
		cs.rotation = rot
		_statics().add_child(cs)

	func cyl(radius: float, height: float, pos: Vector3, color: Color, is_static := false) -> MeshInstance3D:
		var key := "cyl|%s|%s" % [radius, height]
		if not _meshes.has(key):
			var cm := CylinderMesh.new()
			cm.top_radius = radius
			cm.bottom_radius = radius
			cm.height = height
			cm.radial_segments = 20
			_meshes[key] = cm
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[key]
		mi.material_override = mat(color)
		mi.position = pos
		root.add_child(mi)
		if is_static:
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = height
			cs.shape = shape
			cs.position = pos
			_statics().add_child(cs)
		return mi

	func omni(pos: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
		var o := OmniLight3D.new()
		o.position = pos
		o.light_color = color
		o.light_energy = energy
		o.omni_range = range_m
		o.shadow_enabled = false
		root.add_child(o)
		return o

	func sign(text: String, pos: Vector3, color := Color(0.95, 0.9, 0.8)) -> Label3D:
		var l := Label3D.new()
		l.text = text
		l.font_size = 72
		l.pixel_size = 0.008
		l.modulate = color
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.65)
		l.position = pos
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(l)
		return l


static func kit(parent: Node3D) -> Kit:
	return Kit.new(parent)


# --- shells ---------------------------------------------------------------------

## Floor/ceiling slab with rectangular holes, tiled from boxes.
static func _slab(k: Kit, y_center: float, holes: Array, color: Color) -> void:
	var w := HouseSpec.FOOTPRINT_W
	var d := HouseSpec.FOOTPRINT_D
	var xs: Array = [-w / 2.0, w / 2.0]
	var zs: Array = [-d / 2.0, d / 2.0]
	for h: Variant in holes:
		var r := h as Rect2
		xs.append(r.position.x)
		xs.append(r.position.x + r.size.x)
		zs.append(r.position.y)
		zs.append(r.position.y + r.size.y)
	xs.sort()
	zs.sort()
	for xi in xs.size() - 1:
		for zi in zs.size() - 1:
			var x0 := float(xs[xi])
			var x1 := float(xs[xi + 1])
			var z0 := float(zs[zi])
			var z1 := float(zs[zi + 1])
			if x1 - x0 < 0.01 or z1 - z0 < 0.01:
				continue
			var c := Vector2((x0 + x1) / 2.0, (z0 + z1) / 2.0)
			var in_hole := false
			for h: Variant in holes:
				var r := h as Rect2
				if r.grow(-0.005).has_point(c):
					in_hole = true
					break
			if in_hole:
				continue
			k.box(Vector3(x1 - x0, HouseSpec.SLAB_T, z1 - z0),
				Vector3(c.x, y_center, c.y), color, true)


static func build_shell(k: Kit, zone_id: String) -> void:
	var cfg := HouseSpec.shell_cfg(zone_id)
	var w := HouseSpec.FOOTPRINT_W
	var d := HouseSpec.FOOTPRINT_D
	var t := HouseSpec.WALL_T
	var ch := HouseSpec.ceil_h(zone_id)
	var wall := cfg["wall_color"] as Color
	# Floor (top at local y=0) and ceiling/roof.
	_slab(k, -HouseSpec.SLAB_T / 2.0, cfg["floor_holes"], cfg["floor_color"])
	if bool(cfg["roof"]):
		var ang := 0.245
		var slope := 4.95
		var roof_col := Color(0.36, 0.30, 0.27)
		k.box(Vector3(w + 0.8, 0.12, slope), Vector3(0, ch + 0.6, -2.4), roof_col, false, Vector3(-ang, 0, 0))
		k.box(Vector3(w + 0.8, 0.12, slope), Vector3(0, ch + 0.6, 2.4), roof_col, false, Vector3(ang, 0, 0))
	else:
		_slab(k, ch + HouseSpec.SLAB_T / 2.0, cfg["ceiling_holes"], wall.darkened(0.08))
	# Walls: north + east + west solid; south carries the front door
	# gap on the ground floor only.
	k.box(Vector3(w, ch, t), Vector3(0, ch / 2.0, -d / 2.0 + t / 2.0), wall, true)
	k.box(Vector3(t, ch, d), Vector3(-w / 2.0 + t / 2.0, ch / 2.0, 0), wall, true)
	k.box(Vector3(t, ch, d), Vector3(w / 2.0 - t / 2.0, ch / 2.0, 0), wall, true)
	if bool(cfg["door_gap"]):
		var dx := HouseSpec.FRONT_DOOR_X
		var dw := HouseSpec.FRONT_DOOR_W
		var dh := HouseSpec.FRONT_DOOR_H
		var lx0 := -w / 2.0
		var lx1 := dx - dw / 2.0
		k.box(Vector3(lx1 - lx0, ch, t), Vector3((lx0 + lx1) / 2.0, ch / 2.0, d / 2.0 - t / 2.0), wall, true)
		var rx0 := dx + dw / 2.0
		var rx1 := w / 2.0
		k.box(Vector3(rx1 - rx0, ch, t), Vector3((rx0 + rx1) / 2.0, ch / 2.0, d / 2.0 - t / 2.0), wall, true)
		k.box(Vector3(dw, ch - dh, t), Vector3(dx, (ch + dh) / 2.0, d / 2.0 - t / 2.0), wall, true)
	else:
		k.box(Vector3(w, ch, t), Vector3(0, ch / 2.0, d / 2.0 - t / 2.0), wall, true)
	if bool(cfg["roof"]):
		# Stub gable infill panels just inside the eaves ends (the
		# attic lane may sculpt real gables; see the zones doc).
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.2, 1.15, 4.6), Vector3(sx * (w / 2.0 - 0.35), ch + 0.55, 0), wall, false)


# --- ground floor: the hub --------------------------------------------------------

static func build_ground_floor(k: Kit) -> Dictionary:
	build_shell(k, HouseSpec.GROUND_FLOOR)
	var wood := Color(0.62, 0.50, 0.36)
	var counter := Color(0.48, 0.40, 0.33)
	var counter_top := Color(0.78, 0.74, 0.68)
	var fabric := Color(0.52, 0.42, 0.52)
	var fabric_lt := Color(0.60, 0.50, 0.60)
	# Kitchen | living divider, with its doorway gap.
	var dz := HouseSpec.DIVIDER_GAP
	var x := HouseSpec.DIVIDER_X
	k.box(Vector3(0.18, 2.7, 4.2), Vector3(x, 1.35, -2.7), Color(0.83, 0.78, 0.68), true)
	k.box(Vector3(0.18, 2.7, 4.2), Vector3(x, 1.35, 2.7), Color(0.83, 0.78, 0.68), true)
	k.box(Vector3(0.18, 0.6, dz.size.y), Vector3(x, 2.4, dz.get_center().y), Color(0.83, 0.78, 0.68), true)
	# Kitchen: counters along the north + west walls, stove, fridge.
	k.box(Vector3(5.4, 0.85, 0.62), Vector3(-5.3, 0.425, -4.45), counter, true)
	k.box(Vector3(5.5, 0.05, 0.7), Vector3(-5.3, 0.875, -4.45), counter_top, false)
	k.box(Vector3(0.62, 0.85, 3.6), Vector3(-8.15, 0.425, -2.6), counter, true)
	k.box(Vector3(0.7, 0.05, 3.7), Vector3(-8.15, 0.875, -2.6), counter_top, false)
	k.box(Vector3(0.6, 0.02, 0.55), Vector3(-8.15, 0.91, -1.5), Color(0.12, 0.12, 0.13), false)
	for bx: float in [-0.14, 0.14]:
		for bz: float in [-0.13, 0.13]:
			k.cyl(0.085, 0.014, Vector3(-8.15 + bx, 0.925, -1.5 + bz), Color(0.05, 0.05, 0.06), false)
	var fridge := k.box(Vector3(0.95, 1.9, 0.85), Vector3(-7.85, 0.95, 1.4), Color(0.82, 0.84, 0.86), true)
	fridge.name = "Fridge"
	fridge.set_meta("house_prop", "fridge")
	k.box(Vector3(0.05, 0.5, 0.05), Vector3(-7.32, 1.15, 1.05), Color(0.5, 0.52, 0.55), false)
	# THE DRAWER — pulled open under the north counter, cat-sized.
	# Aggie sits in it; its top panel is a sibling lounge spot.
	var dp := HouseSpec.DRAWER_POS
	var drawer := k.box(Vector3(0.66, 0.04, 0.5), Vector3(dp.x, 0.46, -4.02), wood.lightened(0.12), true)
	drawer.name = "AggieDrawer"
	k.box(Vector3(0.66, 0.16, 0.04), Vector3(dp.x, 0.40, -3.79), wood, false)
	k.box(Vector3(0.04, 0.13, 0.5), Vector3(dp.x - 0.31, 0.415, -4.02), wood, false)
	k.box(Vector3(0.04, 0.13, 0.5), Vector3(dp.x + 0.31, 0.415, -4.02), wood, false)
	k.box(Vector3(0.66, 0.13, 0.04), Vector3(dp.x, 0.415, -4.25), wood, false)
	# Willie's water bowl (+ his food bowl) by the kitchen door.
	var bp := HouseSpec.WATER_BOWL_POS
	var bowl := k.cyl(0.17, 0.08, Vector3(bp.x, 0.04, bp.z), Color(0.60, 0.62, 0.65), true)
	bowl.name = "WaterBowl"
	k.cyl(0.135, 0.015, Vector3(bp.x, 0.075, bp.z), Color(0.30, 0.50, 0.80), false)
	k.cyl(0.16, 0.08, Vector3(bp.x + 0.42, 0.04, bp.z), Color(0.55, 0.45, 0.35), true)
	k.cyl(0.125, 0.02, Vector3(bp.x + 0.42, 0.075, bp.z), Color(0.42, 0.30, 0.18), false)
	# Living room: sofa (the LAP seat — occupants target the spot at
	# HouseSpec SOFA_POS, seat top y 0.60), coffee table, rug, TV.
	var sp := HouseSpec.SOFA_POS
	var sofa := k.box(Vector3(2.3, 0.48, 1.0), Vector3(sp.x, 0.24, sp.z), fabric, false)
	sofa.name = "Sofa"
	sofa.set_meta("house_prop", "recliner")
	# INTEGRATION: the sofa's collider is a seat slab whose front
	# edge stops 0.2 short of the visual front — an occupant walking
	# to the sit station at the cushion edge can arrive (their
	# capsule meets the slab, not a full-depth block), while the
	# seat top (y 0.60, the cushion tops) stays solid for the cats.
	k.static_box(Vector3(2.3, 0.60, 0.80), Vector3(sp.x, 0.30, sp.z - 0.10))
	k.box(Vector3(1.05, 0.12, 0.88), Vector3(sp.x - 0.55, 0.54, sp.z), fabric_lt, false).set_meta("house_prop", "recliner")
	k.box(Vector3(1.05, 0.12, 0.88), Vector3(sp.x + 0.55, 0.54, sp.z), fabric_lt, false).set_meta("house_prop", "recliner")
	k.box(Vector3(2.3, 0.85, 0.24), Vector3(sp.x, 0.68, sp.z - 0.42), fabric, true).set_meta("house_prop", "recliner")
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.25, 0.38, 1.0), Vector3(sp.x + sx * 1.02, 0.67, sp.z), fabric, false).set_meta("house_prop", "recliner")
	k.box(Vector3(3.2, 0.02, 2.2), Vector3(4.6, 0.012, -2.4), Color(0.45, 0.22, 0.25), false)
	k.box(Vector3(1.2, 0.05, 0.6), Vector3(4.8, 0.32, -2.2), wood.darkened(0.15), false)
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.22, 0.22]:
			k.box(Vector3(0.05, 0.30, 0.05), Vector3(4.8 + sx, 0.15, -2.2 + sz), wood.darkened(0.25), false)
	var tv_stand := k.box(Vector3(1.8, 0.45, 0.45), Vector3(4.8, 0.225, -4.45), wood.darkened(0.2), true)
	tv_stand.set_meta("house_prop", "tv")
	var tv := k.box(Vector3(1.6, 0.95, 0.06), Vector3(4.8, 1.08, -4.5), Color(0.10, 0.12, 0.16), false)
	tv.name = "Television"
	tv.set_meta("house_prop", "tv")
	# Bookshelf with book strips, east wall.
	k.box(Vector3(0.35, 1.8, 1.6), Vector3(8.25, 0.9, -1.5), wood.darkened(0.1), true)
	var book_cols: Array = [Color(0.6, 0.25, 0.2), Color(0.2, 0.35, 0.55), Color(0.25, 0.5, 0.3), Color(0.65, 0.5, 0.2)]
	for i in 4:
		k.box(Vector3(0.06, 0.34, 1.3), Vector3(8.05, 0.55 + i * 0.42, -1.5), book_cols[i], false)
	# The scratch post he ignores.
	var post := k.cyl(0.09, 0.85, Vector3(HouseSpec.SCRATCH_POST_POS.x, 0.425, HouseSpec.SCRATCH_POST_POS.z), Color(0.72, 0.62, 0.45), true)
	post.name = "ScratchPost"
	k.cyl(0.2, 0.04, Vector3(HouseSpec.SCRATCH_POST_POS.x, 0.02, HouseSpec.SCRATCH_POST_POS.z), wood.darkened(0.2), false)
	# Stairwell dressing: railing along the hole + two descending steps.
	for px: float in [-7.6, -6.5, -5.4]:
		k.box(Vector3(0.06, 0.55, 0.06), Vector3(px, 0.275, -1.72), wood.darkened(0.2), false)
	k.box(Vector3(2.4, 0.06, 0.08), Vector3(-6.5, 0.56, -1.72), wood.darkened(0.2), false)
	k.box(Vector3(2.2, 0.16, 0.4), Vector3(-6.5, -0.10, -2.0), wood, true)
	k.box(Vector3(2.2, 0.16, 0.4), Vector3(-6.5, -0.38, -2.35), wood, true)
	# Hatch ladder (visual — the connector does the travelling).
	for sx: float in [-0.22, 0.22]:
		k.box(Vector3(0.05, 2.7, 0.05), Vector3(6.5 + sx, 1.35, -2.42), wood.darkened(0.15), false)
	var rung_y := 0.3
	while rung_y < 2.6:
		k.box(Vector3(0.44, 0.045, 0.045), Vector3(6.5, rung_y, -2.42), wood.darkened(0.15), false)
		rung_y += 0.32
	# Window light panels (visual insets on the inside faces).
	k.box(Vector3(1.7, 1.2, 0.06), Vector3(5.5, 1.6, 4.62), Color(0.92, 0.9, 0.85), false)
	k.box(Vector3(1.55, 1.05, 0.04), Vector3(5.5, 1.6, 4.60), Color(0.65, 0.78, 0.88), false)
	k.box(Vector3(1.4, 1.1, 0.06), Vector3(-5.0, 1.6, -4.62), Color(0.92, 0.9, 0.85), false)
	k.box(Vector3(1.25, 0.95, 0.04), Vector3(-5.0, 1.6, -4.60), Color(0.65, 0.78, 0.88), false)
	# Interior light: three warm omnis, shadows off.
	k.omni(Vector3(-5.0, 2.3, -1.0), Color(1.0, 0.9, 0.75), 0.85, 7.5)
	k.omni(Vector3(4.5, 2.3, 0.5), Color(1.0, 0.92, 0.78), 0.85, 7.5)
	k.omni(Vector3(2.5, 2.3, 3.6), Color(1.0, 0.95, 0.82), 0.5, 5.0)
	# Wainscot + picture frames on the living-room south wall.
	# The floor and wallpaper are real textures (HouseSurfaces);
	# the old plank strips and kitchen tile checker are gone.
	k.box(Vector3(10.1, 0.5, 0.04), Vector3(3.35, 0.25, 4.70), Color(0.83, 0.78, 0.68), false)
	for fx: float in [1.8, 6.9]:
		k.box(Vector3(0.8, 1.0, 0.05), Vector3(fx, 1.7, 4.70), wood.darkened(0.1), false)
		k.box(Vector3(0.66, 0.86, 0.055), Vector3(fx, 1.7, 4.70), Color(0.75, 0.72, 0.6), false)
	return {"drawer": drawer, "water_bowl": bowl, "sofa": sofa}


# --- stubs (basement + attic entry shells; zone lanes replace) -----------------

static func build_stub(k: Kit, zone_id: String) -> void:
	build_shell(k, zone_id)
	var box_col := Color(0.60, 0.48, 0.32)
	if zone_id == HouseSpec.BASEMENT:
		# The stair flight up to the ground-floor hole (dressing —
		# the connector does the travelling; steps are climbable).
		for i in 9:
			k.box(Vector3(2.2, 0.30, 0.36), Vector3(-6.5, 0.15 + i * 0.29, -1.95 - i * 0.30), Color(0.5, 0.44, 0.36), true)
		k.box(Vector3(0.75, 0.75, 0.75), Vector3(-7.4, 0.375, 2.6), box_col, true)
		k.box(Vector3(0.75, 0.75, 0.75), Vector3(-6.6, 0.375, 2.65), box_col.darkened(0.08), true)
		k.box(Vector3(0.75, 0.75, 0.75), Vector3(-7.0, 1.12, 2.62), box_col.lightened(0.08), true)
		k.box(Vector3(1.4, 0.9, 0.9), Vector3(5.5, 0.45, -3.6), box_col.darkened(0.15), true)
		k.sign("BASEMENT\nthe labyrinth is coming", Vector3(-2.0, 1.7, -4.55))
		k.omni(Vector3(-6.5, 2.0, -2.0), Color(0.95, 0.8, 0.6), 0.4, 6.0)
		k.omni(Vector3(1.0, 2.0, 0.5), Color(0.9, 0.75, 0.55), 0.5, 9.0)
	elif zone_id == HouseSpec.ATTIC:
		# Window perch block + blanket pile + stored boxes + hatch rim.
		k.box(Vector3(0.9, 0.55, 0.9), Vector3(7.3, 0.275, -0.6), box_col.darkened(0.1), true)
		k.box(Vector3(1.4, 0.07, 1.1), Vector3(0.2, 0.035, 1.6), Color(0.55, 0.35, 0.4), false)
		k.box(Vector3(0.8, 0.8, 0.8), Vector3(-6.8, 0.4, -3.4), box_col, true)
		k.box(Vector3(0.7, 0.7, 0.7), Vector3(-6.7, 1.15, -3.35), box_col.lightened(0.07), true)
		for sx: float in [-0.66, 0.66]:
			k.box(Vector3(0.08, 0.06, 1.32), Vector3(6.5 + sx, 0.03, -3.0), box_col.darkened(0.25), false)
		k.box(Vector3(1.24, 0.05, 1.24), Vector3(6.5, 0.55, -4.42), box_col.darkened(0.2), false, Vector3(-1.85, 0, 0))
		k.sign("ATTIC\nraccoon country (soon)", Vector3(-2.0, 1.6, -4.55))
		k.omni(Vector3(0.0, 1.9, 0.0), Color(1.0, 0.85, 0.62), 0.65, 9.0)


# --- entries + connectors (ZoneRoot calls these) ---------------------------------

static func add_entries(parent: Node3D, zone_id: String) -> void:
	var es := HouseSpec.entries(zone_id)
	for entry_name: String in es:
		var n := Node3D.new()
		n.name = entry_name
		n.transform = es[entry_name]
		parent.add_child(n)


static func add_connectors(parent: Node3D, zone_id: String) -> void:
	for cfg: Variant in HouseSpec.connectors(zone_id):
		var c := ZoneConnector.new()
		parent.add_child(c)
		c.setup(cfg)
