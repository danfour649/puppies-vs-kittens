class_name CatNoise
extends RefCounted
## How loud Willie is, and how much scent he leaves.
## A stalk is a whisper. A walk is a patter. A sprint is a
## thunder of paws. A meow carries the room. Creatures hear
## the events through CreaturePerception; the numbers here are
## the contract (stalk < walk < sprint < meow).


const STALK := 0.07
const WALK := 0.32
const SPRINT := 0.95
const POUNCE := 1.15
const MEOW := 1.8


static func loudness(gait: String) -> float:
	match gait:
		"stalk":
			return STALK
		"walk":
			return WALK
		"sprint":
			return SPRINT
		"pounce":
			return POUNCE
		"meow":
			return MEOW
		_:
			return 0.0


## Idle and a held lounge make no footfall. Stalk still does —
## just barely — so a mouse under his chin can notice.
static func gait_of(moving: bool, sprinting: bool, stalking: bool, pouncing: bool = false) -> String:
	if pouncing:
		return "pounce"
	if not moving:
		return "idle"
	if stalking and not sprinting:
		return "stalk"
	if sprinting:
		return "sprint"
	return "walk"


## {} when the cat is silent, so callers can skip the append.
static func footstep(pos: Vector3, gait: String) -> Dictionary:
	var loud := loudness(gait)
	if loud <= 0.001:
		return {}
	return {"pos": pos, "loudness": loud, "kind": "footstep", "gait": gait}


static func meow(pos: Vector3) -> Dictionary:
	return {"pos": pos, "loudness": loudness("meow"), "kind": "meow", "gait": "meow"}


## Scent left on the floor, per second. A stalk barely marks it.
static func scent_rate(gait: String) -> float:
	match gait:
		"sprint", "pounce":
			return 1.25
		"walk":
			return 0.55
		"stalk":
			return 0.08
		_:
			return 0.02
