class_name PvKHarnessCat
extends PvKCat
## TEST/SHOTS STAND-IN ONLY — not game code.
##
## The foundation lane owns the real cat combat pass (HP, pounce,
## knockback) and PvKCat's jump. Until that lands, the attic's
## standalone tests and shot pass need a cat that can take a hit and
## leave the ground, so this subclass adds the minimum:
##   hp / hits_taken via take_hit(damage, from_pos) — the shared
##     enemy-contract signature; knockback is a positional nudge
##     because PvKCat's physics owns velocity.x/z (the real thing
##     belongs to the foundation pass).
##   jump() — teleports a half-metre up and hands PvKCat's own
##     gravity a real upward velocity on the next airborne frame,
##     so the arc, the fall and the landing are genuine physics.

var hp_max := 10
var hp := 10
var hits_taken := 0
var last_hit_amount := 0

var _jump_v := -1.0


func take_hit(damage: int, from_pos: Vector3) -> void:
	hp = maxi(0, hp - damage)
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


func jump() -> void:
	if is_on_floor():
		global_position.y += 0.5
		_jump_v = 6.8


func _physics_process(delta: float) -> void:
	if _jump_v > 0.0 and not is_on_floor():
		velocity.y = _jump_v
		_jump_v = -1.0
	super(delta)
