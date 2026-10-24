class_name PvKToy
extends Node3D
## A lost toy — the basement's collectible. Three kinds, built to the
## objective file's item list: "ball", "mouse_toy", "feather". Idle
## bob-and-spin so a player spots them; the zone polls distance and
## calls collect(). Pure prop: no brain, no collision.

signal collected(toy: PvKToy)

@export var toy_id := "ball"

var collected_flag := false
var _t := 0.0
var _phase := 0.0
var _base_y := 0.0
var _model: Node3D


func _ready() -> void:
	_phase = float(toy_id.hash() % 100) * 0.37
	_base_y = position.y
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	match toy_id:
		"ball":
			_ball(_model)
		"mouse_toy":
			_mouse_toy(_model)
		"feather":
			_feather(_model)
		_:
			_ball(_model)


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rough := 0.7) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 10
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D) -> void:
	_ell(parent, Vector3.ZERO, Vector3(0.11, 0.11, 0.11), Color(0.78, 0.16, 0.14), 0.45)
	_ell(parent, Vector3.ZERO, Vector3(0.114, 0.05, 0.114), Color(0.92, 0.90, 0.85), 0.45) # stripe band


func _mouse_toy(parent: Node3D) -> void:
	var grey := Color(0.45, 0.44, 0.48)
	_ell(parent, Vector3(0, 0, 0), Vector3(0.07, 0.055, 0.11), grey, 0.9)
	_ell(parent, Vector3(0, 0.012, -0.055), Vector3(0.045, 0.04, 0.045), grey, 0.9) # head
	_ell(parent, Vector3(0.02, 0.035, -0.045), Vector3(0.018, 0.018, 0.01), Color(0.75, 0.55, 0.55)) # ear
	_ell(parent, Vector3(-0.02, 0.035, -0.045), Vector3(0.018, 0.018, 0.01), Color(0.75, 0.55, 0.55))
	var tail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.003
	cm.bottom_radius = 0.003
	cm.height = 0.09
	cm.radial_segments = 6
	tail.mesh = cm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.65, 0.5, 0.48)
	tail.material_override = tm
	tail.position = Vector3(0, 0.01, 0.09)
	tail.rotation.x = 1.2
	parent.add_child(tail)


func _feather(parent: Node3D) -> void:
	var teal := Color(0.15, 0.55, 0.55)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.035
	cm.height = 0.17
	cm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = teal
	m.roughness = 0.8
	mi.material_override = m
	mi.scale = Vector3(1.0, 1.0, 0.32) # flattened plume
	mi.position = Vector3(0, 0.02, 0)
	mi.rotation = Vector3(1.35, 0.4, 0) # lying tipped on the floor
	parent.add_child(mi)


func collect() -> void:
	if collected_flag:
		return
	collected_flag = true
	collected.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * 1.35, 0.08)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.001, 0.18)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if collected_flag or _model == null:
		return
	_t += delta
	_model.position.y = sin(_t * 2.2 + _phase) * 0.008
	_model.rotation.y += delta * 0.8
