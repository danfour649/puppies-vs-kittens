class_name PvKHissCat
extends PvKCat
## Standalone seam for the foundation lane's PvKCat.hiss().
##
## The foundation lane is adding a hiss state to the kit cat itself
## (arched pose + control lock). Until that lands on main, this
## subclass provides the same contract for the basement's standalone
## scene and tests:
##   hiss()          — start the hiss (no-op while already hissing)
##   is_hissing()    — state query
##   hiss_duration   — the lock/pose length (matches the zone tuning)
## The zone calls cat.hiss() via has_method(), so when the foundation
## version lands the zone uses it unchanged and this file can retire.
##
## Pose (applied as an overlay AFTER the kit's own pose pass, so it
## always wins within the frame): full Halloween arch — spine up
## (body scale Y swells, XZ pinches), head dropped low, tail puffed
## to ~1.7x and flagged, legs stiffened. Movement input is zeroed
## for the duration: the cat is locked, hissing at the ghost.

signal hissed(cat: PvKHissCat)

const HISS_DURATION := 1.5

var hiss_t := -1.0 ## >= 0 while hissing (seconds since hiss start)

var _voice: AudioStreamPlayer3D = null


func _ready() -> void:
	super._ready()
	_voice = HissAudio.make_voice(self)


func hiss() -> void:
	if hiss_t >= 0.0:
		return
	hiss_t = 0.0
	if _voice != null:
		_voice.play()
	hissed.emit(self)


func is_hissing() -> bool:
	return hiss_t >= 0.0


func _physics_process(delta: float) -> void:
	if hiss_t >= 0.0:
		_input_dir = Vector3.ZERO # control lock: the cat stands its ground
		_input_sprint = false
		_input_stalk = false
	super._physics_process(delta)


func _process(delta: float) -> void:
	super._process(delta)
	if hiss_t < 0.0:
		return
	hiss_t += delta
	var k := clampf(hiss_t / HISS_DURATION, 0.0, 1.0)
	var env := sin(PI * k) # smooth in/out
	if k >= 1.0:
		hiss_t = -1.0
		_tail.scale = Vector3.ONE
		return
	# The arch. _body scale/pos were set by the kit pose pass above;
	# multiply the arch on top.
	_body.scale.y *= 1.0 + 0.22 * env
	_body.scale.x *= 1.0 - 0.07 * env
	_body.position.y += 0.055 * env
	_head.rotation.x += 0.38 * env # head low, chin tucked
	_head.rotation.y *= 1.0 - env # stare straight at the ghost
	_tail.scale = Vector3(1.0 + 0.75 * env, 1.0 + 0.75 * env, 1.0 + 0.35 * env) # puffed
	_tail.rotation.z += 0.5 * env # flagged up
	# Stiff straight legs (the kit pose pass leaves idle hips near 0).
	for key in _hips:
		var hip := _hips[key] as Node3D
		hip.rotation.x += (0.10 if key.begins_with("F") else -0.10) * env
