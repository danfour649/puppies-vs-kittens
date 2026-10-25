class_name YardForest
extends Node3D
## Willie and Aggie — MASSEY BACK-YARD FOREST (TODO #121, Daniel
## 2026-10-25): the real 255 Massey back yard is a literal forest,
## so the yard's edges are planted dense — tall trees in the
## YardTree idiom (tapered trunk, ellipsoid canopy blobs) with
## leaf-litter floors and undergrowth, closing the yard in.
## DECORATIVE ONLY: the three climbable YardTrees in
## OutsideSystem.trees keep their gameplay roles (squirrel perches,
## climb harness, dog escape). Forest trunks carry collision so
## cats bump them like any tree, but they are not climbable and
## hold no perches. Planting positions live in
## OutsideLayout.FOREST_POSITIONS, clear of every gameplay point
## (feeder, ambush bushes, chair, crates, porch, door axis) and
## clear of the climbable trees' bases.

var _mats := {}


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func build(positions: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = OutsideLayout.FOREST_SEED
	for i in positions.size():
		_tree(positions[i], rng)


func _tree(p: Vector3, rng: RandomNumberGenerator) -> void:
	var bark := Color(0.36, 0.27, 0.18)
	var bark_dark := Color(0.29, 0.21, 0.13)
	var leaf := Color(0.24, 0.44, 0.17)
	var leaf2 := Color(0.29, 0.5, 0.2)
	var mulch := Color(0.26, 0.21, 0.13)
	var s := rng.randf_range(1.12, 1.42) # girth / canopy scale
	var hs := rng.randf_range(1.15, 1.45) # height scale
	var g := Node3D.new()
	g.position = p
	g.rotation.y = rng.randf() * TAU
	add_child(g)
	# Leaf-litter floor: under the grove the ground reads as forest
	# floor, not mown lawn.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.65 * s
	dm.bottom_radius = 1.65 * s
	dm.height = 0.045
	dm.radial_segments = 18
	disc.mesh = dm
	disc.material_override = _mat(mulch)
	disc.position = Vector3(0, 0.024, 0)
	g.add_child(disc)
	# Trunk + physics body, same read as YardTree: a cat on the
	# ground bumps the trunk instead of walking through it.
	var trunk_h := OutsideLayout.TRUNK_HEIGHT * hs
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = OutsideLayout.TRUNK_RADIUS * 0.65 * s
	cm.bottom_radius = OutsideLayout.TRUNK_RADIUS * 1.25 * s
	cm.height = trunk_h
	cm.radial_segments = 12
	trunk.mesh = cm
	trunk.material_override = _mat(bark)
	trunk.position = Vector3(0, trunk_h * 0.5, 0)
	g.add_child(trunk)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = OutsideLayout.TRUNK_RADIUS * s + 0.03
	cyl.height = trunk_h
	cs.shape = cyl
	cs.position = Vector3(0, trunk_h * 0.5, 0)
	sb.add_child(cs)
	g.add_child(sb)
	# Two limbs reaching up into the canopy.
	_limb(g, Vector3(0, trunk_h * 0.72, 0), Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU), 1.2 * s, bark_dark)
	_limb(g, Vector3(0, trunk_h * 0.88, 0), Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU), 0.95 * s, bark_dark)
	# Canopy: three overlapping blobs at the trunk top, wide enough
	# that neighbouring crowns meet and the yard reads enclosed.
	var cy := trunk_h + 0.55 * s
	_ell(g, Vector3(0, cy, 0), Vector3(3.4, 1.8, 3.4) * s, leaf)
	_ell(g, Vector3(0.85 * s, cy - 0.4 * s, 0.4 * s), Vector3(2.4, 1.4, 2.4) * s, leaf2)
	_ell(g, Vector3(-0.75 * s, cy - 0.3 * s, -0.5 * s), Vector3(2.2, 1.3, 2.2) * s, leaf)
	# Undergrowth at the base of some trunks.
	if rng.randf() < 0.55:
		_ell(g, Vector3(0.75 * s, 0.28, 0.3), Vector3(0.95, 0.55, 0.95), Color(0.18, 0.33, 0.12))


func _limb(parent: Node3D, base: Vector3, dir: Vector3, len_: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.07
	cm.height = len_
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = _mat(c)
	var end := base + dir * len_ * 0.82 + Vector3(0, len_ * 0.34, 0)
	mi.position = (base + end) * 0.5
	mi.look_at_from_position(mi.position, end, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5) # cylinder Y axis onto the span
	parent.add_child(mi)
