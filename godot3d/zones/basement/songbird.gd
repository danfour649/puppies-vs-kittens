class_name Songbird
extends Node3D
## One indoor songbird. Forages, keeps with the flock, gives an
## alarm call, and — because this is a basement, not a hedge —
## panic-flies toward the brightest light instead of mobbing.


const MODEL_SCALE := 0.22

var brain: CreatureBrain
var state := "forage"
var indoor := true
var cat: Node3D = null
var lights: Array = []
## Windows beat lamps. Indoors, panic flies at these first.
var windows: Array = []
var flock: Array = []
var sounds: Array = []
var sound_sink: Array = []
var hour := 23.0

var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _rng := RandomNumberGenerator.new()
var _flap := 0.0
var _alarm: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D
var _alarm_cd := 0.0


func _ready() -> void:
	_rng.randomize()
	brain = CreatureBrain.new()
	brain.bind_profile("songbird", _rng.randi())
	_build()
	_alarm = HouseAudio.make_player(self, "alarm", false)
	_wings = HouseAudio.make_player(self, "wingbeat", true)


func _process(delta: float) -> void:
	if brain == null:
		return
	var others: Array = []
	for b: Variant in flock:
		if b == self or not is_instance_valid(b):
			continue
		others.append((b as Node3D).global_position)
	var has_cat := cat != null and is_instance_valid(cat)
	var intent: Dictionary = brain.step(delta, {
		"pos": global_position,
		"forward": CreaturePerception.forward_from_yaw(rotation.y),
		"has_cat": has_cat,
		"cat_pos": cat.global_position if has_cat else global_position,
		"indoor": indoor,
		"lights": lights,
		"windows": windows,
		"flock": others,
		"sounds": sounds,
		"hour": hour,
	})
	state = String(intent.get("state", state))
	_alarm_cd = maxf(0.0, _alarm_cd - delta)
	if bool(intent.get("alarm", false)) and _alarm != null and _alarm.stream != null and _alarm_cd <= 0.0:
		_alarm.play()
		_alarm_cd = 0.7
	if _wings != null and _wings.stream != null:
		var flushing := state == "panic_light"
		if flushing and not _wings.playing:
			_wings.play()
		elif not flushing and _wings.playing:
			_wings.stop()
	if bool(intent.get("alarm", false)) and sound_sink != null:
		sound_sink.append({
			"pos": global_position,
			"loudness": 0.85,
			"kind": "alarm",
		})
	var speed := float(intent.get("speed", 0.0))
	var target: Vector3 = intent.get("target", global_position)
	if state == "panic_light":
		target.y = maxf(target.y, global_position.y)
	var to := target - global_position
	if speed > 0.05 and to.length() > 0.05:
		var step := to.normalized() * minf(speed * delta, to.length())
		global_position += step
		var yaw := atan2(-step.x, -step.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-10.0 * delta))
		_flap += delta * (22.0 if state == "panic_light" else 8.0)
		var flap := sin(_flap) * (0.7 if state != "forage" else 0.1)
		if _wing_l != null:
			_wing_l.rotation.z = 0.4 + flap
			_wing_r.rotation.z = -0.4 - flap
	elif _body != null and state == "forage":
		_body.rotation.x = 0.4 * maxf(0.0, sin(_flap))
		_flap += delta * 6.0


func _build() -> void:
	var root := Node3D.new()
	root.scale = Vector3.ONE * MODEL_SCALE
	add_child(root)
	_body = Node3D.new()
	root.add_child(_body)
	_box(_body, Vector3(0.34, 0.28, 0.55), Vector3(0, 0.35, 0), Color(0.55, 0.42, 0.28))
	_box(_body, Vector3(0.22, 0.2, 0.2), Vector3(0, 0.55, -0.28), Color(0.45, 0.32, 0.22))
	_box(_body, Vector3(0.08, 0.06, 0.16), Vector3(0, 0.52, -0.42), Color(0.85, 0.62, 0.2))
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.16, 0.4, 0)
	_body.add_child(_wing_l)
	_box(_wing_l, Vector3(0.46, 0.04, 0.24), Vector3(-0.22, 0, 0), Color(0.35, 0.28, 0.22))
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.16, 0.4, 0)
	_body.add_child(_wing_r)
	_box(_wing_r, Vector3(0.46, 0.04, 0.24), Vector3(0.22, 0, 0), Color(0.35, 0.28, 0.22))


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
