class_name HeatSystem
extends Node
## DUO — Aggie's heat cycle (Daniel's spec, 2026-10-24 22:43).
##
## Aggie goes into heat FREQUENTLY: ~30–60 s stretches in which she
## hunts Willie down wherever he is and solicits — rolling,
## presenting, tail aside, and a loud synth YOWL. Willie is
## NEUTERED. His responses are pure comedy: a blank stare, pointed
## self-grooming, wandering off to knock a drink over, and the
## occasional half-hearted mount attempt that goes nowhere.
## NO KITTENS, EVER — the game states that punchline in a popup.
##
## - Aggie is the NPC: SiblingAI heat modes (seek / solicit) run her.
## - Aggie is the player: an urge meter + "Find Willie" objective,
##   plus occasional involuntary roll-and-yowl interrupts.
## - Willie is the player: her pursuit is a hazard to dodge.
##
## Dignity rules: heat never starts or runs its behaviours while the
## provocation system is mid-flurry/buff, while a cat is fainted,
## while the player cat is on an occupant's lap, or while the
## character select is up. Cartoonish throughout — comedy in
## behaviour, never anatomy.

## state: off | heat | post
var state := "off"
var heat_time_left := 0.0
var cycle_time_left := 0.0
## Player-Aggie: 0..100, climbs during heat (faster far from Willie).
var urge := 0.0
## Test seam: every yowl Aggie makes lands here.
var yowl_count := 0
## How many times Willie has tried the half-hearted mount.
var mount_attempts := 0
## The punchline popup has been shown (shown once per session).
var punchline_shown := false

var duo: Node = null # DuoSystem (untyped: no cyclic class refs)
var aggie: PvKCat = null
var willie: PvKCat = null


func setup(d: Node, a: PvKCat, w: PvKCat) -> void:
	duo = d
	aggie = a
	willie = w


func heat_active() -> bool:
	return state == "heat"


## Character-select role swap: drop back to a clean off state.
func reset() -> void:
	state = "off"
	heat_time_left = 0.0
	urge = 0.0


## Test seam / debug: start a heat stretch right now.
func force_heat() -> void:
	pass # filled in by the implementation commit


## Test seam / debug: end the current heat stretch.
func end_heat() -> void:
	pass # filled in by the implementation commit


func _physics_process(_delta: float) -> void:
	pass # filled in by the implementation commit
