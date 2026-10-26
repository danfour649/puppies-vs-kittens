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
const FLEE_SPEED := 3.05
const FLEE_TIRED_SPEED := 1.95
const FLEE_RADIUS := 2.4

var state := "idle"
var home := Vector3.ZERO
var bounds := Rect2(-11.5, -8.5, 23.0, 17.0)
var cat: Node3D = null
## World hour the shared brain reads. The yard has no clock; evening
## keeps the mice awake (they are nocturnal). The basement night
## passes its own hour.
var world_hour := 21.0
var scent_map: CatScentMap = null
var wall_query: Callable = Callable()
var nibble_anchors: Array = []
var heard_sounds: Array = []
## Wall cracks and box-corners she can vanish into. Empty in the
## open yard, so the chase there is unchanged.
var cracks: Array = []

var _target := Vector3.ZERO
var _timer := 0.0
var _flee_t := 0.0
var _brain: CreatureBrain
var _phase := 0.0
var _time := 0.0
var _model: Node3D
var _body: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}
var _squeak: AudioStreamPlayer3D
var _scurry: AudioStreamPlayer3D
var _squeak_cd := 0.0
var _heard_state := ""


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_timer = _rng.randf_range(0.3, 2.0)
	_target = global_position
	_brain = CreatureBrain.new()
	_brain.bind_profile("mouse", _rng.randi())
	_build_model()
	_squeak = HouseAudio.make_player(self, "squeak", false)
	_scurry = HouseAudio.make_player(self, "scurry", true)


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
	_vanish()


## Aggie reached it first. It is not Willie's gift — no score signal.
func taken_by_rival() -> void:
	if state == "caught":
		return
	state = "caught"
	_vanish()


func _vanish() -> void:
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * MODEL_SCALE * 1.3, 0.07)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.001, 0.16)
	tw.tween_callback(queue_free)


func _clamp_bounds(p: Vector3) -> Vector3:
	p.x = clampf(p.x, bounds.position.x, bounds.position.x + bounds.size.x)
	p.z = clampf(p.z, bounds.position.y, bounds.position.y + bounds.size.y)
	p.y = 0.0
	return p


func _brain_intent(delta: float) -> Dictionary:
	if _brain == null:
		_brain = CreatureBrain.new()
		_brain.bind_profile("mouse", 1)
	# A harness can pin state back to idle; the shared machine follows.
	if state == "idle" and _brain.fsm.state in ["flee", "freeze", "crack", "return"]:
		_brain.fsm.change_to("idle")
		_brain.forget_alert()
		_flee_t = 0.0
	_brain.flee_t = _flee_t
	var p := global_position
	var scent := 0.0
	if scent_map != null:
		scent = scent_map.danger_at(p)
	var pull := Vector3.ZERO
	if wall_query.is_valid():
		pull = wall_query.call(p)
	else:
		pull = _edge_pull(p)
	var novel := {}
	if scent_map != null:
		novel = scent_map.nearest_novel(p, 1.5)
	var has_cat := cat != null and is_instance_valid(cat)
	var gait := ""
	var sounds: Array = heard_sounds.duplicate()
	if has_cat:
		gait = String(cat.get("anim_state"))
		if cat.has_meta("meow_until_msec") and Time.get_ticks_msec() < int(cat.get_meta("meow_until_msec")):
			sounds.append(CatNoise.meow(cat.global_position))
	var intent: Dictionary = _brain.step(delta, {
		"pos": p,
		"forward": CreaturePerception.forward_from_yaw(rotation.y),
		"hour": world_hour,
		"has_cat": has_cat,
		"cat_pos": cat.global_position if has_cat else p,
		"gait": gait,
		"scent": scent,
		"sounds": sounds,
		"wall_pull": pull,
		"home": home,
		"flee_range": FLEE_RADIUS,
		"novel": novel,
		"nibble_anchors": nibble_anchors,
		"cracks": cracks,
		"bounds_min": Vector3(bounds.position.x, 0.0, bounds.position.y),
		"bounds_max": Vector3(bounds.position.x + bounds.size.x, 0.0, bounds.position.y + bounds.size.y),
	})
	_flee_t = _brain.flee_t
	if state != "caught":
		# The yard still says "wander" for a mouse that is out nibbling
		# or reusing a runway, so older readers keep working.
		var brain_state := String(intent.get("state", "idle"))
		if brain_state == "nibble" or brain_state == "runway":
			state = "wander"
		else:
			state = brain_state
	intent["target"] = _clamp_bounds(intent.get("target", p))
	return intent


func _edge_pull(p: Vector3) -> Vector3:
	var min_x := bounds.position.x
	var max_x := bounds.position.x + bounds.size.x
	var min_z := bounds.position.y
	var max_z := bounds.position.y + bounds.size.y
	var best := 1.4
	var pull := Vector3.ZERO
	var edges := [
		[min_x - p.x, Vector3(-1, 0, 0)],
		[p.x - max_x, Vector3(1, 0, 0)],
		[min_z - p.z, Vector3(0, 0, -1)],
		[p.z - max_z, Vector3(0, 0, 1)],
	]
	for edge: Array in edges:
		var gap := absf(float(edge[0]))
		if gap < best:
			best = gap
			var dir: Vector3 = edge[1]
			pull = dir * clampf(1.0 - gap / 1.4, 0.0, 1.0)
	return pull


func _process(delta: float) -> void:
	if state == "caught" or _body == null:
		return
	_time += delta
	_squeak_cd = maxf(0.0, _squeak_cd - delta)
	var intent := _brain_intent(delta)
	_voice_for(float(intent.get("speed", 0.0)))
	var speed := float(intent.get("speed", 0.0))
	_target = intent.get("target", global_position)
	var p := global_position
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


func _voice_for(speed: float) -> void:
	if _squeak != null and _squeak.stream != null and _squeak_cd <= 0.0:
		if state == "flee" or state == "freeze":
			if _heard_state != state:
				_squeak.play()
				_squeak_cd = 0.55
	_heard_state = state
	if _scurry == null or _scurry.stream == null:
		return
	var patter := speed > 0.35 and state != "freeze" and state != "caught"
	if patter and not _scurry.playing:
		_scurry.play()
	elif not patter and _scurry.playing:
		_scurry.stop()
