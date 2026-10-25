class_name PvKGhost
extends AnimatableBody3D
## A Massey basement ghost — one of GTA Fredericton's Red visions,
## let out of the trip and into the house.
##
## DESIGN PROVENANCE (mirrored, per Daniel's direction):
##   GTA Fredericton scripts/world/red_visions.gd — the fake walkers
##   that sprout while the Red mood class is up (scripts/systems/
##   mood.gd, CLASS_RED: hue-warped hallucinogen, tint (1.15, 0.62,
##   1.25)). Source look: UNSHADED figures in wrong colours (magenta
##   #F226BF, acid green, cyan, yellow), a big sphere head, box torso
##   lightened a step, ONE dark leg, one arm stuck up, some of them
##   floating UPSIDE DOWN (rotation.z = PI), drifting sideways with a
##   slow spin (0.45 rad/s) and a wide bob, hovering off the ground.
##   Source behaviour: no collision, harms nothing, gone when Red is.
## Here the same figure is rebuilt in the cat kit's smooth-primitive
## idiom (ellipsoids, not boxes), paler and translucent — and given
## the one power a basement ghost needs: it is SOLID TO THE CAT.
##
## Behaviour: drifts slowly between choke points (passages, tunnel
## mouths, the Aggie-gap approach), phasing straight through boxes
## and shelves — it is a ghost. In a passage it shadows a near cat
## laterally, holding the block. Sustained contact (~1 s) forces the
## cat into a HISS (the zone performs it: cat.hiss() + startles);
## the ghost then yields — rises, fades, lets the cat through — and
## cannot trigger again for hiss_cooldown seconds. Ghosts have NO
## take_hit and emit no damage: a paw strike passes through them,
## and they can never cost the cat a single hit point.

signal hiss_triggered(ghost: PvKGhost, cat: Node3D)

@export var drift_speed := 0.32
@export var shadow_speed := 0.55 ## lateral blocking speed near a cat
@export var shadow_range := 1.7 ## cat distance that wakes the shadow
@export var contact_radius := 0.60 ## centre distance that counts as contact
@export var hiss_after := 1.0 ## seconds of contact that force a hiss
@export var hiss_cooldown := 8.0
@export var yield_time := 3.2
@export var guard_time := 9.0 ## seconds holding one choke before drifting on
@export var tint_index := 0
@export var flipped := false ## the upside-down one (rotation.z = PI, like the source)

var target_cat: Node3D = null
var chokes: Array = [] ## Array[Vector3], world points (y ignored)
var mode := "drift" ## drift, guard, yield

# Paler, redder takes on RedVisions.PED_COLORS (magenta first, per Red).
const TINTS: Array[Color] = [
	Color(0.98, 0.55, 0.86),
	Color(1.0, 0.60, 0.52),
	Color(0.84, 0.62, 1.0),
]
const ALPHA := 0.55

var _choke_i := 0
var _guard_t := 0.0
var _contact_t := 0.0
var _hiss_cd := 0.0
var _yield_t := 0.0
var _rise := 0.0
var _bob_phase := 0.0
var _model: Node3D
var _col: CollisionShape3D
var _mats: Array = []


func _ready() -> void:
	_build_model()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30
	shape.height = 1.0
	_col = CollisionShape3D.new()
	_col.shape = shape
	_col.position = Vector3(0, 0.55, 0)
	add_child(_col)
	_bob_phase = float(tint_index) * 1.37


func _mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, a)
	_mats.append(m)
	return m


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, a := ALPHA) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c, a)
	mi.position = pos
	mi.scale = dia
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	var ink: Color = TINTS[tint_index % TINTS.size()]
	_model = Node3D.new()
	_model.name = "Model"
	_model.position.y = 0.15 # hover: nothing touches the ground
	if flipped:
		_model.rotation.z = PI # one of them hangs upside down, like the source
	add_child(_model)
	# RedVisions ped, kit-smoothed: big head, torso a step lighter,
	# ONE dark leg, one arm stuck up. No second leg. No feet.
	_ell(_model, Vector3(0, 1.72, 0), Vector3(0.44, 0.44, 0.44), ink)
	_ell(_model, Vector3(0, 1.12, 0), Vector3(0.52, 0.62, 0.30), ink.lightened(0.25))
	_ell(_model, Vector3(0.12, 0.42, 0), Vector3(0.16, 0.72, 0.16), Color(0.10, 0.10, 0.12), 0.7)
	_ell(_model, Vector3(-0.32, 1.52, 0), Vector3(0.12, 0.55, 0.12), ink)


func choke_target() -> Vector3:
	if chokes.is_empty():
		return global_position
	return chokes[_choke_i % chokes.size()]


# --- behaviour ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_hiss_cd = maxf(0.0, _hiss_cd - delta)
	var flat := Vector3(global_position.x, 0, global_position.z)
	match mode:
		"drift":
			var tgt := choke_target()
			tgt.y = 0.0
			var to := tgt - flat
			if to.length() < 0.15:
				mode = "guard"
				_guard_t = guard_time
			else:
				global_position += to.normalized() * drift_speed * delta
		"guard":
			_guard_t -= delta
			_shadow_cat(delta)
			if _guard_t <= 0.0:
				_choke_i += 1
				mode = "drift"
		"yield":
			_yield_t -= delta
			_rise = minf(_rise + delta * 0.9, 0.85)
			if _yield_t <= 0.0:
				mode = "drift"
				_choke_i += 1
				_set_blocking(true)
	if mode != "yield":
		_rise = maxf(_rise - delta * 0.9, 0.0)
	_model.position.y = 0.15 + _rise
	_update_contact(delta)


func _shadow_cat(delta: float) -> void:
	# In a passage, slide toward the cat's line: hold the block.
	if target_cat == null or not is_instance_valid(target_cat):
		return
	var to_cat := target_cat.global_position - global_position
	if absf(to_cat.y) > 1.2:
		return # another floor: the haunting stays downstairs
	to_cat.y = 0.0
	if to_cat.length() > shadow_range or to_cat.length() < 0.45:
		return
	# Move a step toward the cat's line, but never retreat: at
	# haunting distance it HOLDS, and the cat's own capsule does the
	# rest. The ghost guards the passage; it does not chase.
	var step := maxf(0.0, minf(to_cat.length() - 0.45, shadow_speed * delta))
	var want := global_position + to_cat.normalized() * step
	# Assign the whole vector at once: component-wise global_position
	# writes (.x = / .z =) never reach an AnimatableBody3D physics
	# transform - the server keeps its own copy and the shadow step
	# silently went nowhere (probe-proven, 2026-10-25).
	global_position = want


func _update_contact(delta: float) -> void:
	if mode == "yield" or _hiss_cd > 0.0 or target_cat == null or not is_instance_valid(target_cat):
		_contact_t = 0.0
		return
	if absf(target_cat.global_position.y - global_position.y) > 1.2:
		_contact_t = 0.0
		return # another floor: no contact through it
	var d := Vector2(target_cat.global_position.x - global_position.x, target_cat.global_position.z - global_position.z).length()
	var lounging := bool(target_cat.get("is_lounging")) if target_cat != null else false
	if d <= contact_radius and not lounging:
		_contact_t += delta
		if _contact_t >= hiss_after:
			_contact_t = 0.0
			_trigger_hiss()
	else:
		_contact_t = maxf(0.0, _contact_t - delta * 2.0)


func _trigger_hiss() -> void:
	_hiss_cd = hiss_cooldown
	_yield_t = yield_time
	mode = "yield"
	_set_blocking(false)
	hiss_triggered.emit(self, target_cat)


func _set_blocking(on: bool) -> void:
	_col.set_deferred("disabled", not on)
	# Fade while yielded so the yield reads.
	var a := ALPHA if on else 0.22
	for m: StandardMaterial3D in _mats:
		m.albedo_color.a = a


func _process(delta: float) -> void:
	# The source's slow spin and wide bob, at basement scale.
	_model.rotation.y += 0.45 * delta
	_bob_phase += delta * 1.4
	_model.position.y = 0.15 + _rise + sin(_bob_phase) * 0.05


## Zone/test introspection: is this ghost able to force a hiss now?
func can_hiss() -> bool:
	return mode != "yield" and _hiss_cd <= 0.0


## Public wrapper for the blocking toggle (zone staging, tests).
func set_solid(on: bool) -> void:
	_set_blocking(on)
