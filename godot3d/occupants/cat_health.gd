class_name CatHealth
extends Node
## Occupants — interim hit-point component for a cat.
##
## The foundation lane is building the game's real HP system; until
## it lands on PvKCat, attach this to a cat to give it hp. The
## OccupantSystem heal seam prefers, in order: cat.heal(amount),
## a CatHealth child (this), then a writable hp property — so when
## the foundation system arrives, this file can simply be deleted
## and the lap keeps healing.

signal hp_changed(hp: float, max_hp: float)

@export var max_hp := 100.0

var hp := 100.0


func _ready() -> void:
	hp = max_hp


func heal(amount: float) -> void:
	if amount <= 0.0 or hp >= max_hp:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)


func is_full() -> bool:
	return hp >= max_hp - 0.001
