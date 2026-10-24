class_name PvKHarnessCat
extends PvKCat
## TEST/SHOTS STAND-IN ONLY — not game code.
##
## INTEGRATION NOTE: the foundation cat pass has landed (PvKCat
## owns HP, take_damage, pounce and a real jump), so this stand-in
## no longer needs its own hp pool or fake jump — both collided
## with the base class and were removed. What remains is the one
## thing the attic's tests still need: the shared enemy-contract
## signature take_hit(damage, from_pos) that the raccoons call,
## with hit counters the tests assert on. Knockback is a positional
## nudge because PvKCat's physics owns velocity.x/z.

var hits_taken := 0
var last_hit_amount := 0


func take_hit(damage: int, from_pos: Vector3) -> void:
	hp = maxf(0.0, hp - float(damage))
	hits_taken += 1
	last_hit_amount = damage
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		global_position += away.normalized() * 0.22
	if _model != null:
		var tw := create_tween()
		tw.tween_property(_model, "scale", Vector3.ONE * model_scale * 1.12, 0.05)
		tw.tween_property(_model, "scale", Vector3.ONE * model_scale, 0.10)
