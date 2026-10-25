class_name CreaturePerception
extends RefCounted
## Sight cone + hearing falloff. Pure maths: no physics queries, so
## the suites can drive it with positions alone. Callers that have a
## world pass `blocked` when a wall sits on the line of sight.


var sight_range := 4.0
var sight_fov_deg := 160.0
var hearing_range := 6.0


## Model forward is -Z. yaw is Node3D.rotation.y, matching the
## atan2(-step.x, -step.z) facing used by the yard mouse.
static func forward_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func can_see(eye: Vector3, forward: Vector3, target: Vector3, blocked: bool = false) -> bool:
	if blocked:
		return false
	var to := target - eye
	to.y = 0.0
	var dist := to.length()
	if dist > sight_range or dist < 0.001:
		return dist < 0.001 and not blocked
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length() < 0.001:
		return true
	fwd = fwd.normalized()
	var dot := clampf(fwd.dot(to.normalized()), -1.0, 1.0)
	var half := deg_to_rad(sight_fov_deg * 0.5)
	return dot >= cos(half)


## Perceived loudness in 0..loudness. Zero at and beyond `range`
## (pass -1 to use hearing_range). A creature directly on the sound
## hears the full loudness.
func hear_loudness(ear: Vector3, sound_pos: Vector3, loudness: float, range_override: float = -1.0) -> float:
	if loudness <= 0.0:
		return 0.0
	var range := hearing_range if range_override < 0.0 else range_override
	var d := Vector2(ear.x - sound_pos.x, ear.z - sound_pos.z).length()
	if d >= range:
		return 0.0
	return loudness * (1.0 - d / range)


func hears(ear: Vector3, sound_pos: Vector3, loudness: float, range_override: float = -1.0) -> bool:
	return hear_loudness(ear, sound_pos, loudness, range_override) > 0.001


## Loudest of a list of {pos, loudness, kind} events at this ear.
func loudest(ear: Vector3, sounds: Array, range_override: float = -1.0) -> Dictionary:
	var best := {"loudness": 0.0, "kind": "", "pos": ear}
	for s: Variant in sounds:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = s
		var pos: Vector3 = sd.get("pos", ear)
		var loud := hear_loudness(ear, pos, float(sd.get("loudness", 0.0)), range_override)
		if loud > float(best["loudness"]):
			best = {"loudness": loud, "kind": String(sd.get("kind", "")), "pos": pos}
	return best
