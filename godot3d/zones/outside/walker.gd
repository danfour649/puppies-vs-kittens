class_name PvKWalker
extends Node3D
## Willie and Aggie — a person walking a dog along the Massey
## sidewalk. Background detail with one job in the system: be the
## anchor the leash hangs off, lean back and skid (comedy) while
## the dog strains, and wait patiently when the leash slips.
## Simple procedural build: swinging legs, a torso, one arm down
## holding the leash, big silhouette, a few shirt colours.

var dir := 1.0
var speed := OutsideLayout.WALKER_SPEED
var state := "walk" ## "walk" along the sidewalk, "wait" while the dog is loose
var skidding := false ## set by the dog while it strains at the leash

var _phase := 0.0
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_free: Node3D
var _model: Node3D
var _mats := {}
var _meshes := {}

const SHIRTS := [Color(0.62, 0.30, 0.22), Color(0.20, 0.42, 0.45), Color(0.72, 0.58, 0.22), Color(0.35, 0.33, 0.55)]


func setup(p_dir: float, variant: int) -> void:
	dir = p_dir
	_build(SHIRTS[clampi(variant, 0, SHIRTS.size() - 1)])
	rotation.y = -PI * 0.5 if dir > 0.0 else PI * 0.5 # face travel dir (forward -Z)


## Where the leash is held: forward hand, waist height.
func hand_pos() -> Vector3:
	return global_position + Vector3(0.28 * dir, 1.02, 0.20)


func _physics_process(delta: float) -> void:
	if state == "walk" and not skidding:
		global_position.x += dir * speed * delta
		_phase += delta * speed * 3.4
	elif skidding:
		_phase += delta * 9.0 # planted feet, shuffling
	# Walk cycle + the strain lean (top tips AWAY from the dog).
	var swing := sin(_phase) * (0.16 if skidding else 0.5)
	if _leg_l != null:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_free.rotation.x = -swing * 0.7
		var lean := -0.26 if skidding else 0.0
		_model.rotation.z = lerpf(_model.rotation.z, lean * dir, 1.0 - exp(-8.0 * delta))


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build(shirt: Color) -> void:
	var pants := Color(0.16, 0.16, 0.2)
	var skin := Color(0.76, 0.58, 0.44)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	# Legs on hip pivots (front of the model is -Z, like the cats).
	for sx: float in [-0.11, 0.11]:
		var hip := Node3D.new()
		hip.position = Vector3(sx, 0.84, 0)
		_model.add_child(hip)
		_box(hip, Vector3(0.15, 0.8, 0.17), Vector3(0, -0.4, 0), pants)
		_box(hip, Vector3(0.15, 0.07, 0.26), Vector3(0, -0.8, -0.04), Color(0.1, 0.1, 0.1)) # shoe
		if sx < 0.0:
			_leg_l = hip
		else:
			_leg_r = hip
	_box(_model, Vector3(0.46, 0.62, 0.24), Vector3(0, 1.16, 0), shirt) # torso
	# Leash arm: angled down-forward toward the dog side (+Z local
	# is the lawn side when walking either way on this sidewalk).
	var arm := Node3D.new()
	arm.position = Vector3(0.20 * dir, 1.38, -0.28)
	arm.rotation.x = 0.7
	_model.add_child(arm)
	_box(arm, Vector3(0.11, 0.55, 0.11), Vector3(0, -0.26, 0), shirt)
	# Free arm on a shoulder pivot, swings with the walk.
	_arm_free = Node3D.new()
	_arm_free.position = Vector3(-0.29, 1.42, 0)
	_model.add_child(_arm_free)
	_box(_arm_free, Vector3(0.11, 0.55, 0.11), Vector3(0, -0.26, 0), shirt)
	_box(_model, Vector3(0.23, 0.25, 0.23), Vector3(0, 1.66, 0), skin) # head
	_box(_model, Vector3(0.25, 0.06, 0.25), Vector3(0, 1.80, 0), shirt.darkened(0.25)) # cap
	_box(_model, Vector3(0.25, 0.04, 0.14), Vector3(0, 1.77, -0.17), shirt.darkened(0.25)) # brim
