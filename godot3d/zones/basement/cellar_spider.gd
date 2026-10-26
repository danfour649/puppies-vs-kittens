class_name CellarSpider
extends Node3D
## A small spider who had the same idea as Willie and thought
## better of it. Hangs, drops when he walks under, goes back up.
## No bite, no damage — a startle and a retreat, that is all.


var brain: CreatureBrain
var state := "hang"
var anchor := Vector3(0, 1.4, 0)
var cat: Node3D = null
var line := ""
var bumped := false

var _drop := 0.0
var _retreating := false
var _body: Node3D


func _ready() -> void:
	brain = CreatureBrain.new()
	brain.bind_profile("spider", 5)
	global_position = anchor
	_build()


func _process(delta: float) -> void:
	if brain == null:
		return
	var has_cat := cat != null and is_instance_valid(cat)
	var intent: Dictionary = brain.step(delta, {
		"pos": global_position,
		"anchor": anchor,
		"drop": _drop,
		"has_cat": has_cat,
		"cat_pos": cat.global_position if has_cat else anchor + Vector3(0, -2, 4),
		"retreating": _retreating,
	})
	state = String(intent.get("state", state))
	var speed := float(intent.get("speed", 0.0))
	if state == "descend":
		_drop = minf(_drop + speed * delta, 1.05)
		_maybe_bump()
		if _drop >= 1.0:
			_retreating = true
	elif state == "retreat":
		_drop = maxf(_drop - speed * delta, 0.0)
		if _drop <= 0.02:
			_retreating = false
	elif state == "hang":
		_drop = maxf(_drop - delta * 0.4, 0.0)
		_retreating = false
	global_position = anchor + Vector3(0, -_drop, 0)
	if _body != null and state == "hang":
		_body.rotation.y += delta * 0.4


func _maybe_bump() -> void:
	if bumped or cat == null or not is_instance_valid(cat):
		return
	if cat.global_position.distance_to(global_position) > 0.55:
		return
	bumped = true
	line = "A spider had the same idea, and thought better of it."
	if cat is PvKCat:
		(cat as PvKCat).velocity.y += 1.6


func _build() -> void:
	var ink := Color(0.16, 0.14, 0.12)
	var thread := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.004
	tm.bottom_radius = 0.004
	tm.height = 1.0
	thread.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.75, 0.72, 0.66)
	thread.material_override = tmat
	thread.position = Vector3(0, 0.5, 0)
	add_child(thread)
	_body = Node3D.new()
	add_child(_body)
	_ell(_body, Vector3(0, -0.04, 0.02), Vector3(0.07, 0.06, 0.09), ink)
	_ell(_body, Vector3(0, -0.01, -0.05), Vector3(0.045, 0.04, 0.045), ink)
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var z := -0.02 + float(i) * 0.025
			_box(_body, Vector3(0.09, 0.012, 0.012), Vector3(side * 0.06, -0.02, z), ink)


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.scale = dia
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
