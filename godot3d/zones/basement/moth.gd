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
	root.scale = Vector3.ONE * 0.18
	add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	_box(body, Vector3(0.18, 0.12, 0.42), Vector3.ZERO, Color(0.72, 0.66, 0.48))
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.08, 0.02, 0)
	body.add_child(_wing_l)
	_box(_wing_l, Vector3(0.7, 0.02, 0.38), Vector3(-0.34, 0, 0), Color(0.86, 0.82, 0.7))
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.08, 0.02, 0)
	body.add_child(_wing_r)
	_box(_wing_r, Vector3(0.7, 0.02, 0.38), Vector3(0.34, 0, 0), Color(0.86, 0.82, 0.7))


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
