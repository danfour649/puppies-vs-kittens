class_name YardLife
extends Node3D
## The back yard, a little more lived-in: a vegetable garden, a
## shed with room for a cat, a garden feeder, and low fence-top
## routes. The boundary stays the wild-rose hedge (Daniel, the
## fence came down). These rails are inside the lawn, tops under
## half a metre, so a cat can jump up and walk them.
##
## The gameplay feeder, trees, chair, porch and door axis are
## left alone. New collision is listed in collision_plan() so the
## clearance test and the meshes cannot drift apart.


const GARDEN := Rect2(-4.85, 0.6, 3.15, 2.05) # x -4.85..-1.7, z 0.6..2.65
const SHED_CENTER := Vector3(-6.2, 0.0, -7.1)
const SHED_SIZE := Vector3(2.1, 1.8, 1.6)
const GARDEN_FEEDER := Vector3(-1.35, 0.0, 2.95)
const FENCE_TOP := 0.46


static func collision_plan() -> Array:
	var boxes: Array = []
	var c := SHED_CENTER
	var s := SHED_SIZE
	# Floor, then three walls and a front wall split by a cat door.
	boxes.append(_box(Vector3(s.x, 0.08, s.z), c + Vector3(0, 0.04, 0), "floor"))
	boxes.append(_box(Vector3(s.x, s.y, 0.1), c + Vector3(0, s.y * 0.5, -s.z * 0.5), "wall"))
	boxes.append(_box(Vector3(0.1, s.y, s.z), c + Vector3(-s.x * 0.5, s.y * 0.5, 0), "wall"))
	boxes.append(_box(Vector3(0.1, s.y, s.z), c + Vector3(s.x * 0.5, s.y * 0.5, 0), "wall"))
	var door_w := 0.66
	var side_w := (s.x - door_w) * 0.5
	var front_z := c.z + s.z * 0.5
	boxes.append(_box(Vector3(side_w, s.y, 0.1), Vector3(c.x - (door_w + side_w) * 0.5, s.y * 0.5, front_z), "wall"))
	boxes.append(_box(Vector3(side_w, s.y, 0.1), Vector3(c.x + (door_w + side_w) * 0.5, s.y * 0.5, front_z), "wall"))
	boxes.append(_box(Vector3(door_w, s.y - 1.05, 0.1), Vector3(c.x, (s.y + 1.05) * 0.5, front_z), "lintel"))
	# Roof you can stand on, reached by the crates against the east wall.
	boxes.append(_box(Vector3(s.x + 0.12, 0.08, s.z + 0.12), c + Vector3(0, s.y + 0.04, 0), "roof"))
	var step_x := c.x + s.x * 0.5 + 0.38
	for i in 4:
		var tread := 0.42 * float(i + 1)
		var tz := c.z - 0.48 + float(i) * 0.36
		boxes.append(_box(Vector3(0.42, tread, 0.36), Vector3(step_x, tread * 0.5, tz), "climb"))
	# Fence-top route, south of the shed, clear of the door.
	boxes.append(_box(Vector3(0.42, 0.40, 0.42), Vector3(-4.55, 0.20, -5.85), "step"))
	boxes.append(_box(Vector3(1.05, 0.08, 0.26), Vector3(-3.85, FENCE_TOP - 0.04, -5.85), "rail"))
	boxes.append(_box(Vector3(1.05, 0.08, 0.26), Vector3(-2.75, FENCE_TOP - 0.04, -5.85), "rail"))
	boxes.append(_box(Vector3(0.9, 0.08, 0.26), Vector3(-1.75, FENCE_TOP - 0.04, -5.85), "rail"))
	boxes.append(_box(Vector3(0.42, 0.40, 0.42), Vector3(-1.15, 0.20, -5.85), "step"))
	# Garden fence, with a gap so the beds stay walk-in.
	boxes.append(_box(Vector3(1.15, 0.08, 0.22), Vector3(-4.15, 0.40, 0.48), "rail"))
	boxes.append(_box(Vector3(0.42, 0.36, 0.42), Vector3(-4.7, 0.18, 0.48), "step"))
	boxes.append(_box(Vector3(1.05, 0.08, 0.22), Vector3(-2.15, 0.40, 0.48), "rail"))
	boxes.append(_box(Vector3(0.42, 0.36, 0.42), Vector3(-1.55, 0.18, 0.48), "step"))
	# Garden feeder pole. Thin, so it reads and doesn't wall the lawn.
	boxes.append(_box(Vector3(0.1, 1.35, 0.1), GARDEN_FEEDER + Vector3(0, 0.68, 0), "feeder"))
	return boxes


static func clearance_problems() -> Array[String]:
	var reasons: Array[String] = []
	var door := Rect2(1.55, -10.3, 1.9, 4.6) # porch and the walk up to the spawn
	var spawn := Rect2(1.4, -7.0, 2.2, 1.8)
	var crates := Rect2(8.7, -6.9, 2.5, 1.7)
	var points: Array[Vector3] = [
		OutsideLayout.FEEDER_POS, OutsideLayout.TREE_WEST, OutsideLayout.TREE_EAST,
		OutsideLayout.TREE_SOUTH, Vector3(4.5, 0, 4.5), Vector3(-8.5, 0, -5.0),
	]
	points.append_array(OutsideLayout.BUSH_POSITIONS)
	for p: Vector3 in OutsideLayout.FOREST_POSITIONS:
		points.append(p)
	for spec: Variant in collision_plan():
		var sd: Dictionary = spec
		var pos: Vector3 = sd["pos"]
		var size: Vector3 = sd["size"]
		var box := Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z)
		if pos.x < -12.15 or pos.x > 12.15 or pos.z < -9.35 or pos.z > 9.2:
			reasons.append("outside the lawn: %s" % sd["kind"])
		if pos.z - size.z * 0.5 < -9.45:
			reasons.append("meets the house wall: %s" % sd["kind"])
		if box.intersects(door) or box.intersects(spawn) or box.intersects(crates):
			reasons.append("crosses a route: %s at %s" % [sd["kind"], pos])
		for p: Vector3 in points:
			var nearest := Vector2(
				clampf(p.x, box.position.x, box.position.x + box.size.x),
				clampf(p.z, box.position.y, box.position.y + box.size.y))
			if nearest.distance_to(Vector2(p.x, p.z)) < 1.35:
				reasons.append("too close to %s: %s" % [p, sd["kind"]])
				break
		if String(sd["kind"]) == "rail":
			var top := pos.y + size.y * 0.5
			if top < 0.35 or top > 0.55:
				reasons.append("rail top %.2f is not a cat step" % top)
	# The shed door is a real opening: a cat's chest height just
	# outside the threshold is not inside a collider.
	var threshold := Vector3(SHED_CENTER.x, 0.4, SHED_CENTER.z + SHED_SIZE.z * 0.5 + 0.12)
	var inside := Vector3(SHED_CENTER.x, 0.45, SHED_CENTER.z)
	if _inside_any(threshold) or _inside_any(inside):
		reasons.append("the shed door or its inside is walled shut")
	return reasons


static func route_is_walkable() -> bool:
	var rails: Array[Vector3] = []
	for spec: Variant in collision_plan():
		var sd: Dictionary = spec
		if String(sd["kind"]) != "rail" and String(sd["kind"]) != "step":
			continue
		if (sd["pos"] as Vector3).z < -4.0:
			rails.append(sd["pos"])
	if rails.size() < 4:
		return false
	rails.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	for i in rails.size() - 1:
		if rails[i].distance_to(rails[i + 1]) > 1.25:
			return false
	return true


func build() -> void:
	var shed := SHED_CENTER
	var s := SHED_SIZE
	_visuals(shed, s)
	var body := StaticBody3D.new()
	body.name = "YardLifeSolids"
	add_child(body)
	for spec: Variant in collision_plan():
		var sd: Dictionary = spec
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sd["size"]
		cs.shape = shape
		cs.position = sd["pos"]
		body.add_child(cs)


func _visuals(shed: Vector3, s: Vector3) -> void:
	var wood := Color(0.46, 0.34, 0.22)
	var wood_d := Color(0.34, 0.24, 0.16)
	var soil := Color(0.28, 0.20, 0.12)
	var leaf := Color(0.30, 0.48, 0.18)
	var leaf2 := Color(0.22, 0.40, 0.14)
	# Garden bed. Visual only — cats walk the rows.
	_mesh(Vector3(GARDEN.size.x, 0.06, GARDEN.size.y), Vector3(GARDEN.get_center().x, 0.03, GARDEN.get_center().y), soil, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 25519
	for row in 3:
		var z := GARDEN.position.y + 0.4 + float(row) * 0.6
		var x := GARDEN.position.x + 0.3
		while x < GARDEN.position.x + GARDEN.size.x - 0.2:
			var h := rng.randf_range(0.18, 0.34)
			_cyl(0.02, h, Vector3(x, h * 0.5, z), leaf2)
			_ball(Vector3(x, h + 0.04, z), rng.randf_range(0.06, 0.1), leaf if row != 1 else Color(0.72, 0.22, 0.16))
			x += 0.42
	# A few flowers along the front lip.
	for i in 5:
		var fx := GARDEN.position.x + 0.35 + float(i) * 0.55
		_ball(Vector3(fx, 0.1, GARDEN.position.y + 0.12), 0.07, Color(0.93, 0.72, 0.28) if i % 2 == 0 else Color(0.86, 0.28, 0.38))
	# Shed shell, matching the collision plan.
	_mesh(Vector3(s.x, 0.08, s.z), shed + Vector3(0, 0.04, 0), Color(0.40, 0.32, 0.24), false)
	_mesh(Vector3(s.x, s.y, 0.1), shed + Vector3(0, s.y * 0.5, -s.z * 0.5), wood, false)
	_mesh(Vector3(0.1, s.y, s.z), shed + Vector3(-s.x * 0.5, s.y * 0.5, 0), wood, false)
	_mesh(Vector3(0.1, s.y, s.z), shed + Vector3(s.x * 0.5, s.y * 0.5, 0), wood_d, false)
	var door_w := 0.66
	var side_w := (s.x - door_w) * 0.5
	var front_z := shed.z + s.z * 0.5
	_mesh(Vector3(side_w, s.y, 0.1), Vector3(shed.x - (door_w + side_w) * 0.5, s.y * 0.5, front_z), wood, false)
	_mesh(Vector3(side_w, s.y, 0.1), Vector3(shed.x + (door_w + side_w) * 0.5, s.y * 0.5, front_z), wood, false)
	_mesh(Vector3(door_w, s.y - 1.05, 0.1), Vector3(shed.x, (s.y + 1.05) * 0.5, front_z), wood_d, false)
	_mesh(Vector3(s.x + 0.16, 0.1, s.z + 0.16), shed + Vector3(0, s.y + 0.05, 0), Color(0.32, 0.28, 0.26), false)
	# A little window, dusk-coloured, and a nest inside that doesn't block the door.
	var win_col: Color = LightMood.window_color("outside")
	var pane := _mesh(Vector3(0.04, 0.32, 0.42), shed + Vector3(0, 1.15, -s.z * 0.5 - 0.02), win_col, false)
	var pm := pane.material_override as StandardMaterial3D
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.emission_enabled = true
	pm.emission = win_col
	pm.emission_energy_multiplier = 0.6
	_mesh(Vector3(0.28, 0.05, 0.22), shed + Vector3(-0.35, 0.1, 0.1), Color(0.55, 0.42, 0.28), false)
	var nest := Label3D.new()
	nest.text = "pots, and a nest in the spare wool"
	nest.font_size = 26
	nest.pixel_size = 0.003
	nest.position = shed + Vector3(0, 0.35, 0.15)
	nest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nest.modulate = Color(0.96, 0.93, 0.86)
	nest.outline_size = 6
	nest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nest)
	var lamp := OmniLight3D.new()
	lamp.position = shed + Vector3(0, 1.2, 0)
	lamp.light_color = win_col
	lamp.light_energy = 0.7
	lamp.omni_range = 3.2
	lamp.shadow_enabled = false
	add_child(lamp)
	# Climb crates (visual; collision is in the plan).
	var step_x := shed.x + s.x * 0.5 + 0.38
	for i in 4:
		var tread := 0.42 * float(i + 1)
		var tz := shed.z - 0.48 + float(i) * 0.36
		_mesh(Vector3(0.42, tread, 0.36), Vector3(step_x, tread * 0.5, tz), wood.lightened(0.04 * float(i)), false)
	# Rails.
	for spec: Variant in collision_plan():
		var sd: Dictionary = spec
		var kind := String(sd["kind"])
		if kind == "rail" or kind == "step":
			_mesh(sd["size"], sd["pos"], Color(0.62, 0.58, 0.5) if kind == "rail" else wood, false)
		elif kind == "feeder":
			_mesh(sd["size"], sd["pos"], Color(0.45, 0.34, 0.22), false)
	_mesh(Vector3(0.32, 0.04, 0.32), GARDEN_FEEDER + Vector3(0, 1.38, 0), Color(0.55, 0.5, 0.4), false)
	_ball(GARDEN_FEEDER + Vector3(0, 1.42, 0), 0.035, Color(0.82, 0.7, 0.28))
	# Birdbath, visual, in the garden.
	_cyl(0.22, 0.08, Vector3(-4.15, 0.08, 1.7), Color(0.55, 0.58, 0.6))
	_cyl(0.16, 0.02, Vector3(-4.15, 0.12, 1.7), Color(0.45, 0.62, 0.72))


static func _box(size: Vector3, pos: Vector3, kind: String) -> Dictionary:
	return {"size": size, "pos": pos, "kind": kind}


static func _inside_any(p: Vector3) -> bool:
	for spec: Variant in collision_plan():
		var sd: Dictionary = spec
		var pos: Vector3 = sd["pos"]
		var size: Vector3 = sd["size"]
		if absf(p.x - pos.x) <= size.x * 0.5 and absf(p.y - pos.y) <= size.y * 0.5 and absf(p.z - pos.z) <= size.z * 0.5:
			return true
	return false


func _mesh(size: Vector3, pos: Vector3, color: Color, _solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ball(pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.94
	return m
