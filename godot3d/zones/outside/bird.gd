class_name PvKBird
extends Node3D
## Willie and Aggie — a feeder bird (robin/sparrow/jay colourways),
## procedural in the mouse idiom. Dumb on purpose: it flies where
## it is told (arrival arcs, perch hops, panic exits), pecks for a
## while, and reports back — OutsideSystem runs the stream, the
## scare rules and the ambush math.
##
## States: "arrive" (flying to a perch), "peck" (landed, feeding),
## "leave" (departing calmly), "flee" (burst-off panic), "caught".

signal peck_finished(b: PvKBird)
signal departed(b: PvKBird)
signal caught(b: PvKBird)

const MODEL_SCALE := 0.22

const SKINS := [
	{"back": Color(0.42, 0.40, 0.38), "breast": Color(0.78, 0.36, 0.18)}, # robin
	{"back": Color(0.55, 0.45, 0.32), "breast": Color(0.82, 0.76, 0.62)}, # sparrow
	{"back": Color(0.30, 0.42, 0.62), "breast": Color(0.80, 0.83, 0.86)}, # blue jay
]

## arrive / peck / leave / flee / caught — names on the shared machine.
## Feeder birds are still commanded (fly_to / burst_off). Songbirds
## that think for themselves live in songbird.gd and opt in with
## flock_brain_enabled.
var _fsm: CreatureFSM
var state: String:
	get:
		return _fsm.state if _fsm != null else "arrive"
	set(value):
		if _fsm != null:
			_fsm.change_to(value)
var flock_brain_enabled := false
var perch_kind := "" ## "feeder" or "ground"
var perch_pos := Vector3.ZERO
var peck_time := 3.0
var _song: CreatureBrain

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 1.0
var _arc := 1.0
var _flying := false
var _peck_t := 0.0
var _time := 0.0
var _skin := 0
var _model: Node3D
var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func setup(skin: int, seed_: int) -> void:
	_skin = clampi(skin, 0, SKINS.size() - 1)
	_rng.seed = seed_


func _init() -> void:
	_fsm = CreatureFSM.new()
	for s: String in ["arrive", "peck", "leave", "flee", "caught"]:
		_fsm.add_state(s)
	_fsm.change_to("arrive")


func _ready() -> void:
	_song = CreatureBrain.new()
	_song.bind_profile("songbird", _rng.randi())
	_build_model()


## Fly an arc to `target`. On landing: peck (perch) or depart.
func fly_to(target: Vector3, dur: float, arc: float, then_peck: bool, kind := "") -> void:
	_from = global_position
	_to = target
	_t = 0.0
	_dur = maxf(dur, 0.05)
	_arc = arc
	_flying = true
	if then_peck:
		state = "arrive"
		perch_pos = target
		perch_kind = kind
	else:
		state = "leave"


## Panic: burst off toward an exit point and despawn there.
func burst_off(exit: Vector3) -> void:
	if state in ["flee", "caught"]:
		return
	state = "flee"
	_from = global_position
	_to = exit
	_t = 0.0
	_dur = 1.05
	_arc = 1.6
	_flying = true


func get_caught() -> void:
	if state == "caught":
		return
	state = "caught"
	caught.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * MODEL_SCALE * 1.3, 0.06)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.001, 0.14)
	tw.tween_callback(queue_free)


var _flap_ph := 0.0 # REALISM PASS 1
var _glide := 0.0 # REALISM PASS 1: 0 = flapping, 1 = gliding


func _physics_process(delta: float) -> void:
	if state == "caught" or _body == null:
		return
	_time += delta
	if _flying:
		_t += delta / _dur
		var k := clampf(_t, 0.0, 1.0)
		var pos := _from.lerp(_to, k)
		pos.y += sin(k * PI) * _arc
		var vel := pos - global_position
		global_position = pos
		if vel.length() > 0.01:
			var yaw := atan2(-vel.x, -vel.z)
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-10.0 * delta))
		# REALISM PASS 1: flap / glide cycle. The arc's rise works
		# the wings; the top and the descent glide on a held
		# dihedral; arrivals flare — wings wide, body pitched up.
		var vspeed := vel.y / maxf(delta, 0.001)
		var glide_want := 1.0 if (vspeed < -0.35 or _t > 0.8) else 0.0
		_glide = move_toward(_glide, glide_want, delta * 1.6)
		_flap_ph += delta * (24.0 + 10.0 * (1.0 - _glide))
		var flap_amt := clampf(1.0 - _glide * 0.88 + clampf(vspeed * 0.25, -0.1, 0.3), 0.08, 1.0)
		var flap := sin(_flap_ph) * 0.78 * flap_amt
		var dihedral := 0.15 + _glide * 0.22
		_wing_l.rotation.z = dihedral + flap
		_wing_r.rotation.z = -dihedral - flap
		_body.rotation.x = lerpf(_body.rotation.x, -0.30 if (state == "arrive" and _t > 0.85) else 0.0, 0.3)
		if _t >= 1.0:
			_flying = false
			if state == "arrive":
				state = "peck"
				_peck_t = 0.0
				global_position = perch_pos
			else:
				departed.emit(self)
				queue_free()
	elif state == "peck":
		if flock_brain_enabled:
			var intent := _song.step(delta, {
				"pos": global_position,
				"forward": CreaturePerception.forward_from_yaw(rotation.y),
				"has_cat": false,
				"indoor": false,
				"lights": [],
				"flock": [],
				"sounds": [],
			})
			if String(intent.get("state", "")) == "panic_light":
				burst_off(intent.get("target", global_position + Vector3(0, 2, 0)))
				return
		_peck_t += delta
		# Peck-peck-peck: the front dips in little bursts.
		var burst := fmod(_time * 1.4, 1.0)
		_body.rotation.x = 0.55 * maxf(0.0, sin(burst * PI * 2.0)) if burst < 0.45 else 0.0
		_body.position.y = absf(sin(_time * 7.0)) * 0.02
		_wing_l.rotation.z = lerpf(_wing_l.rotation.z, 0.95, 1.0 - exp(-8.0 * delta)) # folded
		_wing_r.rotation.z = lerpf(_wing_r.rotation.z, -0.95, 1.0 - exp(-8.0 * delta))
		if _peck_t > peck_time:
			peck_finished.emit(self)


# --- model --------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	var skin: Dictionary = SKINS[_skin]
	var back: Color = skin["back"]
	var breast: Color = skin["breast"]
	var dark := back.darkened(0.35)
	_model = Node3D.new()
	_model.name = "Model"
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_body = Node3D.new()
	_body.name = "Body"
	_model.add_child(_body)
	var leg_h := 0.22
	_box(_body, Vector3(0.34, 0.32, 0.62), Vector3(0, leg_h + 0.16, 0), back) # body
	_box(_body, Vector3(0.28, 0.26, 0.20), Vector3(0, leg_h + 0.12, -0.16), breast) # breast
	_box(_body, Vector3(0.24, 0.24, 0.24), Vector3(0, leg_h + 0.42, -0.34), back) # head
	_box(_body, Vector3(0.05, 0.05, 0.16), Vector3(0, leg_h + 0.40, -0.52), Color(0.15, 0.12, 0.1)) # beak
	_box(_body, Vector3(0.16, 0.03, 0.42), Vector3(0, leg_h + 0.22, 0.48), dark, Vector3(-0.28, 0, 0)) # tail, cocked
	# Wings on shoulder pivots so flight can flap them.
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.17, leg_h + 0.26, -0.05)
	_body.add_child(_wing_l)
	_box(_wing_l, Vector3(0.52, 0.03, 0.30), Vector3(-0.27, 0, 0.02), dark)
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.17, leg_h + 0.26, -0.05)
	_body.add_child(_wing_r)
	_box(_wing_r, Vector3(0.52, 0.03, 0.30), Vector3(0.27, 0, 0.02), dark)
	for lx: float in [-0.07, 0.07]:
		_box(_model, Vector3(0.03, leg_h, 0.03), Vector3(lx, leg_h * 0.5, 0), dark) # legs
