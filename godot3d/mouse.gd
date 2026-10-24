class_name PvKMouse
extends Node3D
## A field mouse in the GTA wildlife idiom (SPECIES["field_mouse"]:
## colour Color(0.45, 0.36, 0.28), shape "quad"). Built from the same
## unit-frame boxes as wildlife.gd's _build_mesh, glides like GTA
## animals do (no physics body), bobs as it scurries.
## Brain: idle/graze -> wander inside the yard; flee the cat in bursts.
## Scale is 0.10 instead of GTA's 0.07 so a mouse reads at game
## distance; proportions are unchanged.

signal was_caught(m: PvKMouse)

const COAT := Color(0.45, 0.36, 0.28)
const MODEL_SCALE := 0.10
const WANDER_SPEED := 1.2
const FLEE_SPEED := 3.4
const FLEE_TIRED_SPEED := 2.2
const FLEE_RADIUS := 2.4

var state := "idle"
var home := Vector3.ZERO
var bounds := Rect2(-11.5, -8.5, 23.0, 17.0)
var cat: Node3D = null

var _target := Vector3.ZERO
var _timer := 0.0
var _flee_t := 0.0
var _phase := 0.0
var _time := 0.0
var _model: Node3D
var _body: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_timer = _rng.randf_range(0.3, 2.0)
	_target = global_position
	_build_model()


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


func _build_model() -> void:
	var dark := COAT.darkened(0.35)
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var leg_h := 0.35
	_box(_body, Vector3(0.35, 0.35, 0.9), Vector3(0, leg_h + 0.18, 0), COAT)
	_box(_body, Vector3(0.26, 0.26, 0.3), Vector3(0, leg_h + 0.38, -0.55), COAT)
	_box(_body, Vector3(0.12, 0.1, 0.14), Vector3(0, leg_h + 0.32, -0.74), dark)
	for ex: float in [-0.08, 0.08]:
		_box(_body, Vector3(0.05, 0.09, 0.03), Vector3(ex, leg_h + 0.55, -0.5), COAT) # ears
	_box(_body, Vector3(0.03, 0.03, 0.55), Vector3(0, leg_h + 0.15, 0.7), Color(0.6, 0.5, 0.45)) # tail
	for lx: float in [-0.12, 0.12]:
		for lz: float in [-0.32, 0.32]:
			_box(_model, Vector3(0.09, leg_h, 0.09), Vector3(lx, leg_h * 0.5, lz), dark)


func get_caught() -> void:
	if state == "caught":
		return
	state = "caught"
	was_caught.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * MODEL_SCALE * 1.3, 0.07)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.001, 0.16)
	tw.tween_callback(queue_free)


func _clamp_bounds(p: Vector3) -> Vector3:
	p.x = clampf(p.x, bounds.position.x, bounds.position.x + bounds.size.x)
	p.z = clampf(p.z, bounds.position.y, bounds.position.y + bounds.size.y)
	p.y = 0.0
	return p


func _process(delta: float) -> void:
	if state == "caught" or _body == null:
		return
	_time += delta
	_timer -= delta
	var p := global_position
	var speed := 0.0
	# Flee check first, like wildlife.gd _step.
	var fleeing := false
	if cat != null:
		var away := Vector3(p.x - cat.global_position.x, 0, p.z - cat.global_position.z)
		if away.length() < FLEE_RADIUS:
			fleeing = true
			if state != "flee":
				state = "flee"
				_flee_t = 0.0
			_flee_t += delta
			_target = _clamp_bounds(p + away.normalized() * 6.0)
			speed = FLEE_SPEED if _flee_t < 1.2 else FLEE_TIRED_SPEED
	if not fleeing:
		if state == "flee":
			state = "idle"
			_timer = 0.4
		match state:
			"idle":
				if _timer <= 0.0:
					state = "wander"
					_target = _clamp_bounds(home + Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(-3.0, 3.0)))
					_timer = 6.0
			"wander":
				speed = WANDER_SPEED
				if p.distance_to(_target) < 0.15 or _timer <= 0.0:
					state = "idle"
					_timer = _rng.randf_range(0.8, 3.0)
	if speed > 0.0:
		var to := _target - p
		to.y = 0.0
		if to.length() > 0.05:
			var step := to.normalized() * minf(speed * delta, to.length())
			global_position = p + step
			var target_yaw := atan2(-step.x, -step.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
			_phase += delta * speed * 14.0
			_body.position.y = absf(sin(_phase)) * 0.12
		else:
			_body.position.y = 0.0
	else:
		_body.position.y = 0.0
