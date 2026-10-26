class_name HoarderDressing
extends Node3D
## Lived-in clutter for a floor HoarderGenerator built.
##
## Collision boxes are narrower than a cell, so the carved spine
## stays wide enough for Willie's capsule. Signature furniture,
## doors, stairs, the hatch, and the attic's raccoon floor are
## keep-out rects: the generator's graph can still be a maze while
## the real routes through the house stay open.
##
## Lights are few and unshadowed. The web export is GL Compatibility.


const WALL_XZ := 0.56
const STEP_RISE := 0.40

const GROUND_KEEP: Array[Rect2] = [
	Rect2(-8.2, -4.75, 3.6, 4.0), # stairs, and the sibling's landing
	Rect2(5.15, -4.05, 2.9, 3.4), # hatch
	Rect2(1.45, 2.15, 2.3, 2.8), # front door
	Rect2(-2.55, -1.35, 1.5, 2.7), # kitchen doorway
	Rect2(-2.2, -4.85, 0.75, 4.2), # divider, north of the door
	Rect2(-2.2, 0.55, 0.75, 4.3), # divider, south of the door
	Rect2(-8.4, -4.9, 6.4, 1.15), # north counter
	Rect2(-8.6, -4.5, 1.15, 4.3), # west counter
	Rect2(-8.55, 0.8, 1.4, 1.4), # fridge
	Rect2(-6.05, -4.75, 1.7, 1.3), # the open drawer
	Rect2(-3.15, 2.0, 1.9, 1.5), # the bowls
	Rect2(3.15, -4.75, 3.3, 1.9), # sofa
	Rect2(7.25, 0.25, 1.3, 1.4), # scratch post
]

const ATTIC_KEEP: Array[Rect2] = [
	Rect2(2.55, -4.4, 3.7, 3.6), # hatch, crate stairs, both cats' landing
	Rect2(-6.15, -4.6, 3.3, 2.6), # the raccoons' corner
	Rect2(-2.0, 0.45, 5.4, 4.15), # insulation the cat wades, and that walk
	Rect2(-5.2, 1.55, 4.4, 3.3), # the second pile
	Rect2(-2.05, 0.0, 3.8, 1.2), # open-floor speed check
	Rect2(4.35, -1.05, 1.9, 2.1), # window perch
	Rect2(-4.55, -1.65, 2.1, 1.9),
	Rect2(-2.7, -2.9, 1.6, 1.4),
	Rect2(0.95, 1.15, 1.4, 1.4),
	Rect2(-1.8, 3.0, 2.1, 1.6),
	Rect2(-2.8, -4.65, 2.8, 1.35), # dresser
	Rect2(1.35, -4.35, 1.9, 1.55),
]


var _motes: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _t := 0.0

const LABEL_MARGIN := 16.0


static func build(parent: Node3D, level: Dictionary) -> HoarderDressing:
	var node := HoarderDressing.new()
	node.name = "Keepsakes"
	parent.add_child(node)
	node._apply(level)
	return node


static func keep_rects(floor_id: String) -> Array[Rect2]:
	if floor_id == "attic":
		return ATTIC_KEEP
	return GROUND_KEEP


static func plan(level: Dictionary) -> Dictionary:
	var floor_id := String(level.get("floor", "ground_floor"))
	var rects := keep_rects(floor_id)
	var rows := int(level.get("rows", 8))
	var cols := int(level.get("cols", 14))
	var solids: Array = []
	var stacked := {}
	for s: Variant in level.get("stacks", []):
		var sd: Dictionary = s
		var cell: Vector2i = sd["cell"]
		var h := float(sd["height"])
		var pos := HoarderGenerator.world_pos(level, cell.x, cell.y) + Vector3(0, h * 0.5, 0)
		var size := Vector3(WALL_XZ, h, WALL_XZ)
		if overlaps_keep(pos, size, rects):
			continue
		solids.append({
			"pos": pos, "size": size,
			"color": _decade_color(HoarderGenerator.decade_for_row(cell.y, rows)),
			"kind": "stack", "cell": cell, "height": h,
		})
		stacked[cell] = true
	var map: Array = level.get("map", [])
	for r in map.size():
		var row := String(map[r])
		for c in row.length():
			if row.substr(c, 1) != "#":
				continue
			var cell := Vector2i(c, r)
			if stacked.has(cell):
				continue
			var h := 0.72 + 0.28 * (1.0 - float(r) / float(maxi(1, rows - 1)))
			var pos := HoarderGenerator.world_pos(level, c, r) + Vector3(0, h * 0.5, 0)
			var size := Vector3(WALL_XZ, h, WALL_XZ)
			if overlaps_keep(pos, size, rects):
				continue
			solids.append({
				"pos": pos, "size": size,
				"color": _decade_color(HoarderGenerator.decade_for_row(r, rows)).darkened(0.04),
				"kind": "wall", "cell": cell, "height": h,
			})
	var steps: Array = []
	for route: Variant in level.get("vertical_routes", []):
		var rd: Dictionary = route
		var stack_cell: Vector2i = rd["stack_cell"]
		if not stacked.has(stack_cell):
			continue
		var floor_cell: Vector2i = rd["floor_cell"]
		var stack_h := float(rd["height"])
		var from := HoarderGenerator.world_pos(level, floor_cell.x, floor_cell.y)
		var to := HoarderGenerator.world_pos(level, stack_cell.x, stack_cell.y)
		var dir := to - from
		dir.y = 0.0
		if dir.length() < 0.01:
			continue
		dir = dir.normalized()
		var rise := STEP_RISE
		var n := 1
		while rise < stack_h - 0.15 and n <= 4:
			var pos := from.lerp(to, 0.62) + Vector3(0, rise - STEP_RISE * 0.5, 0)
			var size := Vector3(0.34, STEP_RISE, 0.34)
			if not overlaps_keep(pos, size, rects):
				steps.append({
					"pos": pos, "size": size,
					"color": _decade_color(HoarderGenerator.decade_for_row(stack_cell.y, rows)).lightened(0.08),
					"kind": "step", "height": rise,
				})
			rise += STEP_RISE
			n += 1
	var props: Array = []
	var labelled := {}
	for item: Variant in level.get("items", []):
		var it: Dictionary = item
		var cell: Vector2i = it["cell"]
		var decade := int(it["decade"])
		var show_label := not labelled.has(decade)
		labelled[decade] = true
		props.append({
			"pos": _tuck(level, cell) + Vector3(0, 0.1, 0),
			"decade": decade,
			"name": String(it["name"]),
			"kind": _kind_for(decade),
			"label": show_label,
			"color": _decade_color(decade),
		})
	# A keep-rect means "no collision", not "no nest". The pocket is a
	# flat visual, so a cat still wades the insulation and walks the test.
	var nests: Array = []
	for n: Variant in level.get("nests", []):
		var cell: Vector2i = n
		var pos := HoarderGenerator.world_pos(level, cell.x, cell.y)
		nests.append({"pos": pos + Vector3(0, 0.03, 0)})
	_promote_stacks(level, solids, steps, rects, rows)
	var mood := String(level.get("mood", LightMood.for_zone(floor_id)))
	var pal := LightMood.palette(mood)
	var lights: Array = []
	var windows: Array = []
	if floor_id == "attic":
		lights.append({"pos": Vector3(4.55, 1.85, 0.15), "color": pal["window"], "energy": pal["energy"], "range": 6.5})
		lights.append({"pos": Vector3(-1.2, 1.7, 0.4), "color": pal["fill"], "energy": pal["fill_energy"], "range": 5.5})
		windows.append({"pos": Vector3(5.15, 1.7, 0.0), "size": Vector3(0.08, 0.7, 0.7), "color": pal["window"]})
	else:
		lights.append({"pos": Vector3(5.4, 1.7, 3.9), "color": pal["window"], "energy": pal["energy"], "range": 6.0})
		lights.append({"pos": Vector3(-4.8, 1.75, -3.6), "color": pal["fill"], "energy": pal["fill_energy"], "range": 5.5})
		windows.append({"pos": Vector3(5.5, 1.55, 4.48), "size": Vector3(1.15, 0.85, 0.04), "color": pal["window"]})
		windows.append({"pos": Vector3(-5.0, 1.55, -4.48), "size": Vector3(1.05, 0.75, 0.04), "color": pal["window"]})
	return {
		"floor": floor_id,
		"mood": mood,
		"solids": solids,
		"steps": steps,
		"props": props,
		"nests": nests,
		"lights": lights,
		"windows": windows,
	}


static func overlaps_keep(pos: Vector3, size: Vector3, rects: Array) -> bool:
	var box := Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z)
	for rect: Variant in rects:
		var r: Rect2 = rect
		if box.intersects(r):
			return true
	return false


static func _promote_stacks(level: Dictionary, solids: Array, steps: Array, rects: Array, rows: int) -> void:
	var have := 0
	for s: Variant in solids:
		if String((s as Dictionary).get("kind", "")) == "stack":
			have += 1
	if have >= 3:
		return
	for s: Variant in solids:
		if have >= 3:
			return
		var sd: Dictionary = s
		if String(sd.get("kind", "")) != "wall":
			continue
		var cell: Vector2i = sd["cell"]
		var floor_cell := Vector2i(-1, -1)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if HoarderGenerator.cell_walkable(level, cell.x + d.x, cell.y + d.y, false):
				floor_cell = cell + d
				break
		if floor_cell.x < 0:
			continue
		var old_h := float(sd["height"])
		var old_size: Vector3 = sd["size"]
		var old_pos: Vector3 = sd["pos"]
		var h := maxf(old_h, 1.35)
		sd["height"] = h
		sd["size"] = Vector3(WALL_XZ, h, WALL_XZ)
		sd["pos"] = HoarderGenerator.world_pos(level, cell.x, cell.y) + Vector3(0, h * 0.5, 0)
		sd["kind"] = "stack"
		if overlaps_keep(sd["pos"], sd["size"], rects):
			sd["kind"] = "wall"
			sd["height"] = old_h
			sd["size"] = old_size
			sd["pos"] = old_pos
			continue
		var from := HoarderGenerator.world_pos(level, floor_cell.x, floor_cell.y)
		var to := HoarderGenerator.world_pos(level, cell.x, cell.y)
		var dir := to - from
		dir.y = 0.0
		if dir.length() < 0.01:
			have += 1
			continue
		var pos := from.lerp(to, 0.62) + Vector3(0, STEP_RISE * 0.5, 0)
		var size := Vector3(0.34, STEP_RISE, 0.34)
		if not overlaps_keep(pos, size, rects):
			steps.append({
				"pos": pos, "size": size,
				"color": _decade_color(HoarderGenerator.decade_for_row(cell.y, rows)).lightened(0.08),
				"kind": "step", "height": STEP_RISE,
			})
		have += 1


static func stack_count(planned: Dictionary) -> int:
	var n := 0
	for s: Variant in planned.get("solids", []):
		if String((s as Dictionary).get("kind", "")) == "stack":
			n += 1
	return n


func _apply(level: Dictionary) -> void:
	var planned := plan(level)
	var mood := String(planned["mood"])
	var pal := LightMood.palette(mood)
	for s: Variant in planned["solids"]:
		_box(s)
	for s: Variant in planned["steps"]:
		_box(s)
	for p: Variant in planned["props"]:
		_prop(p)
	var nest_i := 0
	for n: Variant in planned["nests"]:
		_nest((n as Dictionary)["pos"], nest_i == 0)
		nest_i += 1
	for w: Variant in planned["windows"]:
		var wd: Dictionary = w
		var pane := _mesh(wd["size"], wd["pos"], wd["color"], false)
		var mat := pane.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = wd["color"]
		mat.emission_energy_multiplier = 0.85
	for L: Variant in planned["lights"]:
		var ld: Dictionary = L
		var o := OmniLight3D.new()
		o.position = ld["pos"]
		o.light_color = ld["color"]
		o.light_energy = float(ld["energy"])
		o.omni_range = float(ld["range"])
		o.shadow_enabled = false
		add_child(o)
	var windows: Array = planned["windows"]
	var origin := Vector3(0, 1.6, 0)
	if not windows.is_empty():
		origin = windows[0]["pos"]
	var yaw := -90.0 if String(planned["floor"]) == "attic" else 12.0
	VisualQuality.add_dust_shaft(self, origin + Vector3(0, 0.35, 0), -58.0, yaw)
	_motes_for(origin, pal["window"])


func _box(spec: Variant) -> void:
	var sd: Dictionary = spec
	var mi := _mesh(sd["size"], sd["pos"], sd["color"], true)
	mi.name = String(sd.get("kind", "box"))


func _prop(spec: Variant) -> void:
	var pd: Dictionary = spec
	var pos: Vector3 = pd["pos"]
	var col: Color = pd["color"]
	match String(pd["kind"]):
		"radio":
			_mesh(Vector3(0.22, 0.14, 0.12), pos, col, false)
			_cyl(0.035, 0.02, pos + Vector3(0.04, 0.08, 0.04), Color(0.85, 0.78, 0.55))
		"teapot":
			_cyl(0.07, 0.08, pos, col)
			_mesh(Vector3(0.06, 0.03, 0.08), pos + Vector3(0.08, 0.02, 0), col.lightened(0.1), false)
		"frame":
			_mesh(Vector3(0.16, 0.2, 0.02), pos + Vector3(0, 0.06, 0), col, false)
			_mesh(Vector3(0.11, 0.14, 0.015), pos + Vector3(0, 0.06, 0.012), Color(0.75, 0.7, 0.6), false)
		"album":
			_mesh(Vector3(0.2, 0.03, 0.16), pos, col, false)
			_mesh(Vector3(0.2, 0.03, 0.16), pos + Vector3(0, 0.035, 0), col.darkened(0.12), false)
		"blanket":
			_mesh(Vector3(0.26, 0.06, 0.2), pos, col, false)
		_:
			_mesh(Vector3(0.18, 0.1, 0.14), pos, col, false)
	if bool(pd.get("label", false)):
		_name_label(String(pd["name"]), pos + Vector3(0, 0.22, 0), 28, 0.0032)


func _nest(pos: Vector3, labelled: bool) -> void:
	_cyl(0.16, 0.035, pos, Color(0.42, 0.32, 0.22))
	_mesh(Vector3(0.08, 0.02, 0.05), pos + Vector3(0.04, 0.02, 0.02), Color(0.75, 0.7, 0.62), false)
	_mesh(Vector3(0.05, 0.015, 0.07), pos + Vector3(-0.05, 0.018, -0.02), Color(0.82, 0.78, 0.7), false)
	if labelled:
		_name_label("a nest, lined with a scrap of wool", pos + Vector3(0, 0.16, 0), 26, 0.003)


func _motes_for(origin: Vector3, col: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.4
	for i in 8:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = mat
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.position = origin + Vector3(sin(float(i) * 1.7) * 0.35, 0.4 - float(i) * 0.12, cos(float(i) * 1.3) * 0.28)
		add_child(mote)
		_motes.append(mote)


func _name_label(text: String, pos: Vector3, size: int, px: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = size
	lab.pixel_size = px
	lab.width = 200.0
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.position = pos
	lab.set_meta("home", pos)
	lab.set_meta("px", px)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(0.97, 0.94, 0.88)
	lab.outline_size = 6
	lab.outline_modulate = Color(0.1, 0.07, 0.05, 0.8)
	lab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lab)
	_labels.append(lab)


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var m := _motes[i]
		m.position.y += sin(_t * 0.7 + float(i)) * delta * 0.04
		m.position.x += cos(_t * 0.4 + float(i) * 1.4) * delta * 0.02
	_clamp_names()


## Long keepsake names wrap, then the whole block is kept on screen.
func _clamp_names() -> void:
	if _labels.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	for lab: Label3D in _labels:
		if not is_instance_valid(lab):
			continue
		var home: Vector3 = lab.get_meta("home")
		var base_px := float(lab.get_meta("px"))
		lab.position = home
		lab.pixel_size = base_px
		var world := lab.global_position
		if cam.is_position_behind(world):
			continue
		if cam.global_position.distance_to(world) > 9.0:
			continue
		var depth := _view_depth(cam, world)
		if depth <= cam.near:
			continue
		var screen := cam.unproject_position(world)
		if screen.x < -vp.x or screen.x > vp.x * 2.0 or screen.y < -vp.y or screen.y > vp.y * 2.0:
			continue
		var half := _screen_half(lab, cam, depth, vp)
		var avail := vp - Vector2(LABEL_MARGIN, LABEL_MARGIN) * 2.0
		var fit := 1.0
		if half.x * 2.0 > avail.x and half.x > 0.0:
			fit = minf(fit, avail.x / (half.x * 2.0))
		if half.y * 2.0 > avail.y and half.y > 0.0:
			fit = minf(fit, avail.y / (half.y * 2.0))
		if fit < 0.999:
			lab.pixel_size = base_px * fit
			half *= fit
		var clamped := _clamp_screen(screen, half, vp, LABEL_MARGIN)
		if clamped.distance_squared_to(screen) > 0.25:
			lab.global_position = cam.project_position(clamped, depth)


func _view_depth(cam: Camera3D, world: Vector3) -> float:
	var local: Vector3 = cam.global_transform.affine_inverse() * world
	return -local.z


func _screen_half(lab: Label3D, cam: Camera3D, depth: float, vp: Vector2) -> Vector2:
	var font_px := _font_px(lab.text, lab.width, lab.font_size, lab.outline_size)
	var world := font_px * lab.pixel_size
	var center := cam.project_position(vp * 0.5, depth)
	var edge := center + cam.global_transform.basis.x.normalized() * world.x * 0.5
	edge += cam.global_transform.basis.y.normalized() * world.y * 0.5
	if cam.is_position_behind(center) or cam.is_position_behind(edge):
		var ppm := vp.y / maxf(0.05, 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5))
		return world * 0.5 * ppm
	return (cam.unproject_position(edge) - cam.unproject_position(center)).abs()


func _font_px(text: String, width: float, font_size: int, outline: int) -> Vector2:
	var measured := Vector2(minf(width, maxf(1.0, text.length()) * font_size * 0.55), font_size * 1.4)
	var font := ThemeDB.fallback_font
	if font != null and text.length() > 0:
		var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, -1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		if size.x > 1.0 and size.y > 1.0:
			measured = size
	measured += Vector2(outline, outline) * 2.0
	return measured * 1.08


func _clamp_screen(point: Vector2, half: Vector2, vp: Vector2, margin: float) -> Vector2:
	var lo := Vector2(margin + half.x, margin + half.y)
	var hi := Vector2(vp.x - margin - half.x, vp.y - margin - half.y)
	if lo.x > hi.x:
		point.x = vp.x * 0.5
	else:
		point.x = clampf(point.x, lo.x, hi.x)
	if lo.y > hi.y:
		point.y = vp.y * 0.5
	else:
		point.y = clampf(point.y, lo.y, hi.y)
	return point


func _mesh(size: Vector3, pos: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.position = pos
		body.add_child(cs)
		add_child(body)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.94
	return m


static func _decade_color(decade: int) -> Color:
	match decade:
		1960:
			return Color(0.42, 0.28, 0.16)
		1970:
			return Color(0.72, 0.52, 0.20)
		1980:
			return Color(0.36, 0.42, 0.50)
		1990:
			return Color(0.55, 0.40, 0.30)
		2000:
			return Color(0.60, 0.38, 0.36)
		_:
			return Color(0.76, 0.68, 0.50)


static func _kind_for(decade: int) -> String:
	match decade:
		1960:
			return "radio"
		1970:
			return "teapot"
		1980:
			return "frame"
		1990:
			return "tin"
		2000:
			return "album"
		_:
			return "blanket"


static func _tuck(level: Dictionary, cell: Vector2i) -> Vector3:
	var pos := HoarderGenerator.world_pos(level, cell.x, cell.y)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not HoarderGenerator.cell_walkable(level, cell.x + d.x, cell.y + d.y, false):
			return pos + Vector3(d.x, 0, d.y) * 0.22
	return pos + Vector3(0.18, 0, 0.14)
