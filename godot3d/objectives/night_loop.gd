class_name NightLoop
extends RefCounted
## One night's ledger: gifts, catch combos, and how stirred-up
## the house got. Glenys reads it when the gift arrives.
## The mess is a fact about the basement. It is never a verdict
## on Willie, and never a joke at Glenys's expense.


const CATCH_BASE := 100
const COMBO_STEP := 40
const QUIET_BONUS := 15
const COMBO_WINDOW := 4.0
const GIFT_BASE := 80

var score := 0
var catches := 0
var combo := 0
var best_combo := 0
var mess := 0.0
var gifts := 0
var quiet_catches := 0
var objectives: Array = []
var _last_catch_t := -999.0


func setup() -> void:
	objectives = [
		{"id": "mice", "title": "Three mice for Glenys", "done": false},
		{"id": "combo", "title": "Two catches in a breath", "done": false},
		{"id": "gift", "title": "Bring her the gift", "done": false},
		{"id": "tidy", "title": "Leave the house mostly as you found it", "done": false},
	]


func note_catch(t: float, quiet: bool) -> Dictionary:
	catches += 1
	if quiet:
		quiet_catches += 1
	var chained := _last_catch_t >= 0.0 and (t - _last_catch_t) <= COMBO_WINDOW
	combo = combo + 1 if chained else 1
	best_combo = maxi(best_combo, combo)
	_last_catch_t = t
	var pts := CATCH_BASE + (combo - 1) * COMBO_STEP
	if quiet:
		pts += QUIET_BONUS
	score += pts
	_mark("mice", catches >= 3)
	_mark("combo", best_combo >= 2)
	return {"points": pts, "combo": combo, "score": score}


## `amount` is seconds of a gait, or 1 for a single meow.
func note_noise(gait: String, amount: float) -> void:
	var rate := 0.0
	match gait:
		"sprint":
			rate = 7.5
		"pounce":
			rate = 5.0
		"meow":
			rate = 18.0
		"walk":
			rate = 1.1
		"stalk":
			rate = 0.12
		_:
			rate = 0.0
	mess = clampf(mess + rate * amount, 0.0, 100.0)


## A quiet cat, the house lets it go.
func settle(delta: float, gait: String) -> void:
	if gait == "idle" or gait == "stalk" or gait == "lounge":
		mess = maxf(0.0, mess - 1.1 * delta)


func mess_word() -> String:
	if mess < 18.0:
		return "tidy"
	if mess < 40.0:
		return "a little stirred"
	if mess < 70.0:
		return "properly busy"
	return "the house noticed"


func deliver_gift() -> Dictionary:
	gifts += 1
	var tone := "pleased"
	var bonus := GIFT_BASE
	if best_combo >= 3 and mess < 68.0:
		tone = "delighted"
		bonus += 50
	elif best_combo >= 3:
		tone = "delighted"
		bonus += 20
	elif mess <= 22.0:
		tone = "quiet_pride"
		bonus += 30
	elif mess >= 68.0:
		tone = "fond_exasperation"
		bonus -= 25
	elif best_combo >= 2:
		bonus += 20
	score += bonus
	_mark("gift", true)
	_mark("tidy", mess < 40.0)
	return {
		"points": bonus,
		"tone": tone,
		"line": glenys_line(tone, best_combo, mess),
		"score": score,
		"mess_word": mess_word(),
	}


static func glenys_line(tone: String, combo_n: int, mess_now: float) -> String:
	if tone == "delighted" and mess_now >= 68.0:
		return "Three in a row. The basement can settle while we admire these."
	match tone:
		"delighted":
			return "Three, quick as that. You always were the thorough one."
		"quiet_pride":
			return "Not a cushion out of place. I raised a gentleman."
		"fond_exasperation":
			return "The gift is lovely. The rest of the basement can wait until morning."
		_:
			if combo_n >= 2:
				return "Two in a row, and you thought of me. Come here."
			return "For me? You dreadful, perfect boy."


func objective_done(id: String) -> bool:
	for o: Variant in objectives:
		var d: Dictionary = o
		if String(d.get("id", "")) == id:
			return bool(d.get("done", false))
	return false


func _mark(id: String, done: bool) -> void:
	if not done:
		return
	for i in objectives.size():
		var d: Dictionary = objectives[i]
		if String(d.get("id", "")) == id:
			d["done"] = true
			objectives[i] = d
			return
