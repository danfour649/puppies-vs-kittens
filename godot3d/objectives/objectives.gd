class_name PvKObjectives
extends Node
## OBJECTIVES — the one registry for Willie and Aggie's goals, and
## the game SCORE. Group "objectives": enemies call register_kill
## on death; zones declare their goals at build time; the HUD
## (objectives_hud.gd) renders whatever is registered, grouped by
## zone. The contract is docs/massey-zones.md §5.

signal changed
signal score_changed(score: int)
signal kill_registered(species_id: String)

## Score events (occupants lane): name -> default points.
## INTEGRATION: these are the values the occupants lane SHIPPED
## (Daniel's spec: ankle +25 / underfoot +15 / trip +50 / purr tick
## +5), adopted over the foundation's reserved placeholders.
## Zones may append names in their own branches; never rename these.
const SCORE_EVENTS := {
	"ankle_attack": 25,
	"underfoot": 15,
	"trip_hazard": 50,
	"lap_purr": 5,
	"ankle_shoo": 10,
	"lap_full_heal": 0,
}

var items: Array = [] # {id, zone, title, target, count, done, kill_species}
var total_kills := 0
var score := 0
var version := 0 # bumped on every change; the HUD polls it


func _ready() -> void:
	add_to_group("objectives")


func declare(id: String, zone: String, title: String, target := 1, kill_species := "") -> void:
	if get_item(id) != null:
		return
	items.append({
		"id": id, "zone": zone, "title": title,
		"target": maxi(1, target), "count": 0, "done": false,
		"kill_species": kill_species,
	})
	_bump()


func get_item(id: String) -> Variant:
	for it: Variant in items:
		if String((it as Dictionary).get("id", "")) == id:
			return it
	return null


func is_done(id: String) -> bool:
	var it: Variant = get_item(id)
	return it != null and bool((it as Dictionary).get("done", false))


func set_progress(id: String, n: int) -> void:
	var it: Variant = get_item(id)
	if it == null:
		return
	var d := it as Dictionary
	var nv: int = clampi(n, 0, int(d["target"]))
	if nv == int(d["count"]):
		return
	d["count"] = nv
	d["done"] = nv >= int(d["target"])
	_bump()


func add_progress(id: String, n := 1) -> void:
	var it: Variant = get_item(id)
	if it == null:
		return
	set_progress(id, int((it as Dictionary)["count"]) + n)


## Called by every PvKEnemy on death (call_group from enemy.gd).
func register_kill(species_id: String) -> void:
	total_kills += 1
	kill_registered.emit(species_id)
	for it: Variant in items:
		var d := it as Dictionary
		if String(d.get("kill_species", "")) == species_id and not bool(d["done"]):
			add_progress(String(d["id"]), 1)


## Score only ever moves through named events, so every lane's
## points land in the same counter with the same names.
func add_score(event_name: String, points := -1) -> void:
	var pts := points
	if pts < 0:
		pts = int(SCORE_EVENTS.get(event_name, 0))
	score += pts
	score_changed.emit(score)
	_bump()


func _bump() -> void:
	version += 1
	changed.emit()
