class_name YardTree
extends Node3D
## Willie and Aggie — a functional yard tree for the outside zone:
## a tapered trunk the cat can climb (see OutsideSystem's climb
## harness), a first branch that is the squirrel's safe perch, and
## a loose ellipsoid canopy in the kit's smooth-primitive idiom
## (deliberately NOT main.gd's decorative box tree, which stays
## untouched as set dressing at (-8.5, -5.0)).

var branch_y := OutsideLayout.FIRST_BRANCH_Y
var branch_dir := Vector3.RIGHT ## horizontal: which way the first branch reaches

var _mats := {}


func setup(pos: Vector3, p_branch_dir: Vector3) -> void:
	global_position = pos
	branch_dir = p_branch_dir.normalized()
	_build()


func trunk_axis() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Where a squirrel sits to taunt, and where a climbing cat arrives.
func perch_pos() -> Vector3:
	return global_position + branch_dir * 0.55 + Vector3(0, branch_y + 0.05, 0)


## Point on the trunk surface at height y, on the given side.
func surface_point(y: float, side_dir: Vector3) -> Vector3:
	return global_position + side_dir * (OutsideLayout.TRUNK_RADIUS + 0.10) + Vector3(0, y, 0)


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
	sm.radial_segments = 20
	sm.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func _build() -> void:
	var bark := Color(0.36, 0.27, 0.18)
	var bark_dark := Color(0.29, 0.21, 0.13)
	var leaf := Color(0.24, 0.44, 0.17)
	var leaf2 := Color(0.29, 0.5, 0.2)
	# Trunk: one tapered cylinder, plus its physics body so a cat on
	# the ground bumps the trunk instead of walking through it.
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = OutsideLayout.TRUNK_RADIUS * 0.65
	cm.bottom_radius = OutsideLayout.TRUNK_RADIUS * 1.25
	cm.height = OutsideLayout.TRUNK_HEIGHT
	cm.radial_segments = 14
	trunk.mesh = cm
	trunk.material_override = _mat(bark)
	trunk.position = Vector3(0, OutsideLayout.TRUNK_HEIGHT * 0.5, 0)
	add_child(trunk)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = OutsideLayout.TRUNK_RADIUS + 0.03
	cyl.height = OutsideLayout.TRUNK_HEIGHT
	cs.shape = cyl
	cs.position = Vector3(0, OutsideLayout.TRUNK_HEIGHT * 0.5, 0)
	sb.add_child(cs)
	add_child(sb)
	# First branch (the perch) + one higher branch: angled cylinders.
	_branch(Vector3(0, branch_y, 0), branch_dir, 1.15, bark_dark)
	_branch(Vector3(0, branch_y + 0.75, 0), branch_dir.rotated(Vector3.UP, 2.2), 0.95, bark_dark)
	# Canopy: three overlapping blobs, up high where they read as shade.
	_ell(self, Vector3(0, 3.35, 0), Vector3(3.1, 1.7, 3.1), leaf)
	_ell(self, Vector3(0.8, 2.95, 0.4), Vector3(2.2, 1.3, 2.2), leaf2)
	_ell(self, Vector3(-0.7, 3.05, -0.5), Vector3(2.0, 1.2, 2.0), leaf)


func _branch(base: Vector3, dir: Vector3, len_: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.075
	cm.height = len_
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(c)
	var end := base + dir * len_ * 0.82 + Vector3(0, len_ * 0.34, 0)
	mi.position = (base + end) * 0.5
	mi.look_at_from_position(mi.position, end, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5) # cylinder Y axis onto the span
	add_child(mi)
