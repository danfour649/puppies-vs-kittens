class_name CellarMoth
extends Node3D
## A moth on a lamp. Orbits the light, startles off a loud paw
## or a cat who walks into the pool, then settles back.
## The shared brain does the choosing. This body only flies.


var brain: CreatureBrain
var state := "orbit"
var lamp := Vector3(0, 1.4, 0)
var cat: Node3D = null
var sounds: Array = []

var _wing_l: Node3D
var _wing_r: Node3D
var _flap := 0.0
## Wing tip to wing tip, in metres. Big enough to read beside a lamp.
const WING_SPAN := 0.7
var wing_span := WING_SPAN
var wings_emissive := false
var wing_material: StandardMaterial3D


func _ready() -> void:
	brain = CreatureBrain.new()
	brain.bind_profile("moth", 3)
	_build()


func _process(delta: float) -> void:
	if brain == null:
		return
	var has_cat := cat != null and is_instance_valid(cat)
	var intent: Dictionary = brain.step(delta, {
		"pos": global_position,
		"lamp": lamp,
		"has_cat": has_cat,
		"cat_pos": cat.global_position if has_cat else global_position,
		"sounds": sounds,
	})
	state = String(intent.get("state", state))
	var speed := float(intent.get("speed", 0.0))
	var target: Vector3 = intent.get("target", lamp)
	var to := target - global_position
	if speed > 0.02 and to.length() > 0.04:
		global_position += to.normalized() * minf(speed * delta, to.length())
	_flap += delta * (28.0 if state == "startle" else 16.0)
	var flap := sin(_flap) * (0.7 if state != "orbit" else 0.45)
	if _wing_l != null:
		_wing_l.rotation.z = flap
		_wing_r.rotation.z = -flap


func _build() -> void:
	var root := Node3D.new()
	root.name = "Body"
	add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	_box(body, Vector3(0.07, 0.05, 0.16), Vector3.ZERO, Color(0.55, 0.40, 0.26))
	wing_material = _wing_mat()
	wings_emissive = wing_material.emission_enabled and wing_material.emission_energy_multiplier >= 1.5
	_wing_l = _wing(body, -1.0)
	_wing_r = _wing(body, 1.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.72, 0.32)
	glow.light_energy = 0.85
	glow.omni_range = 1.5
	glow.shadow_enabled = false
	body.add_child(glow)


func _wing(parent: Node3D, sign: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(sign * 0.035, 0.012, 0.0)
	parent.add_child(pivot)
	# Two crossed quads, so the wing still reads when the camera
	# sees it edge-on. A single thin card disappears from the side.
	for yaw: float in [0.2, 1.05]:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.2)
		mi.mesh = quad
		mi.position = Vector3(sign * 0.16, 0.0, 0.0)
		mi.rotation.y = yaw * sign
		mi.material_override = wing_material
		pivot.add_child(mi)
	return pivot


func _wing_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.46)
	mat.roughness = 0.42
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.62, 0.18)
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
