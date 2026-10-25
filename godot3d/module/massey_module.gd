class_name MasseyModule
extends Node3D
## THE MASSEY MODULE ROOT — 255 Massey Street as a drop-in module
## (docs/massey-zones.md §9; consumption contract: module/DROP-IN.md).
##
## This node is the ONE assembly path for the module's content in
## a PvK-idiom host. A host instantiates it, calls setup(host)
## with the §9.3 host surface, and gets back the assembled house:
##
##   - the duo (sibling cat, character select, meows, provocation)
##   - the three interior zone scenes at HouseSpec.zone_origin,
##     with the basement in hub mode (no stand-in cat)
##   - the outside entry node + front-door connector ON THE HOST
##     (the host IS the outside zone root — §9.3 item 1)
##   - the ZoneManager (travel) and the PvKObjectives registry
##   - the occupants (build_occupants(): Daniel + Folasade in the
##     ground-floor hub, score events wired to the registry)
##
## ...and the CAT START (GTA TODO #108, eighth row):
## choose_cat(id) runs the duo's character select for "willie" or
## "aggie" and spawns BOTH cats inside the ground floor — the
## player at EntryFrontDoor, the sibling beside them, rebound to
## the hub's lounge spots — with every house system live.
##
## The host provides (§9.3, PvK realization — see DROP-IN.md):
##   var cat: PvKCat        the player-cat actor (§4 API), spawned
##   var duo                filled by setup(); read by the host
##   var mice: Array        the yard game's mice ([] in a house-only host)
##   var catch_radius       written by the duo's provoked buff
##   _on_paw_swiped()       the paw-strike sink (host's catch/combat)
##   on_zone_changed(id)    camera etc. + sibling rebind (zone_root(id))
##   get_entry / get_lounge_spots / get_wander_rect — outside root API
##
## What deliberately stays HOST machinery (§9.5): the PvKCat
## controller itself, the zone-travel MECHANISM (ZoneManager is
## instanced here but its pairing data is the module content),
## nine lives, camera/HUD/touch. Cat coat/species data is read
## live from cat_kit — never copied into the module.

const DuoScene := preload("res://duo/duo_system.gd")
const OccupantScript := preload("res://occupants/occupant.gd")
const OccupantSystemScript := preload("res://occupants/occupant_system.gd")
const OccupantsRoomScript := preload("res://occupants/occupants_room.gd")

var host: Node = null
var duo: DuoSystem = null
var zones: ZoneManager = null
var objectives: PvKObjectives = null
var occupants: OccupantSystem = null

var _zone_roots := {} # id -> root node (the host itself for outside)


## Assemble the module against the host's §9.3 surface. Call
## build_occupants() afterwards (the host declares its own
## objectives first if it wants them listed ahead of the
## occupants' — main.gd does exactly that with outside:mice).
func setup(host_node: Node) -> void:
	host = host_node
	# The duo: sibling cat, character select, meow + provocation.
	duo = DuoScene.new()
	duo.name = "DuoSystem"
	host.add_child(duo)
	host.set("duo", duo)
	duo.setup(host)
	# Enemies hunt the "player_cat" group; the duo keeps membership
	# current across character swaps from here on.
	var cat := host.get("cat") as PvKCat
	if cat != null:
		cat.add_to_group("player_cat")
	_build_zones()


## The ground-floor occupants: Daniel + Folasade move into the
## hub — routines on stations routed through the divider gap, the
## sit station at the sofa's cushion edge (HouseSpec SOFA_POS).
## Score events land in the module's objectives registry with the
## shipped values (docs/massey-zones.md §5).
func build_occupants() -> void:
	var gf := _zone_roots[HouseSpec.GROUND_FLOOR] as Node3D
	var origin := HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
	var daniel := OccupantScript.new() as MasseyOccupant
	daniel.name = "Daniel"
	gf.add_child(daniel)
	daniel.place_at(origin + Vector3(-1.5, 0, 2.8), 0.0)
	daniel.setup(OccupantsRoomScript.daniel_look(), _occupant_stations(4.25, origin))
	var folasade := OccupantScript.new() as MasseyOccupant
	folasade.name = "Folasade"
	gf.add_child(folasade)
	folasade.place_at(origin + Vector3(3.9, 0, -0.4), PI)
	var f_stations := _occupant_stations(5.35, origin)
	f_stations.push_front(f_stations.pop_at(2)) # she starts at the couch
	folasade.setup(OccupantsRoomScript.folasade_look(), f_stations)
	occupants = OccupantSystemScript.new() as OccupantSystem
	occupants.name = "OccupantSystem"
	gf.add_child(occupants)
	occupants.register_occupant(daniel)
	occupants.register_occupant(folasade)
	occupants.set_player_cat(host.get("cat") as PvKCat)
	occupants.score_event.connect(_on_occupant_score)
	objectives.declare("occupants:ankle_assassin", HouseSpec.GROUND_FLOOR, "Ankle assassin x5", 5)
	objectives.declare("occupants:trip_hazard", HouseSpec.GROUND_FLOOR, "Trip hazard x3", 3)
	objectives.declare("occupants:lap_full_heal", HouseSpec.GROUND_FLOOR, "Full heal from lap pets", 1)


# --- the cat start ---------------------------------------------------------------

## THE CAT START: pick your cat, wake up in the house. Runs the
## duo's swap (the unchosen cat becomes the sibling), then travels
## both cats into the ground floor, instantly — player at the
## front-door entry, sibling beside them (ZoneManager._do_move),
## and the host's on_zone_changed rebinds the sibling to the
## hub's lounge spots and wander rect.
func choose_cat(id: String) -> void:
	if duo == null or zones == null:
		return
	duo.choose(id)
	zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)


## True while the character select is still up (no cat chosen yet).
func start_pending() -> bool:
	return duo != null and duo.input_locked()


## A zone's root node (the host itself for the outside zone).
func zone_root(id: String) -> Node:
	return _zone_roots.get(id) as Node


# --- assembly -----------------------------------------------------------------------

func _build_zones() -> void:
	var house := Node3D.new()
	house.name = "HouseInterior"
	add_child(house)
	_zone_roots[HouseSpec.OUTSIDE] = host
	for id: String in [HouseSpec.GROUND_FLOOR, HouseSpec.BASEMENT, HouseSpec.ATTIC]:
		var inst := (load(String(HouseSpec.ZONE_SCENES[id])) as PackedScene).instantiate()
		inst.position = HouseSpec.zone_origin(id)
		if id == HouseSpec.BASEMENT:
			# The hub owns the cats, HP and travel: the basement
			# runs in hub mode (no stand-in cat, no local HP ledger).
			inst.set("spawn_standalone_cat", false)
			inst.set("standalone_drive", false)
			inst.set("use_follow_cam", false)
			inst.set("track_cat_hp", false)
		house.add_child(inst)
		_zone_roots[id] = inst
	# The outside entry (on the porch) — the host IS the outside zone.
	var entry := Node3D.new()
	entry.name = "EntryFrontDoor"
	var et: Transform3D = HouseSpec.entries(HouseSpec.OUTSIDE)["EntryFrontDoor"]
	entry.transform = et
	host.add_child(entry)
	var door := ZoneConnector.new()
	host.add_child(door)
	door.setup(HouseSpec.connectors(HouseSpec.OUTSIDE)[0])
	zones = ZoneManager.new()
	zones.name = "ZoneManager"
	add_child(zones)
	zones.setup(host)
	for id: String in _zone_roots:
		zones.register_zone(id, _zone_roots[id])
	objectives = PvKObjectives.new()
	objectives.name = "Objectives"
	add_child(objectives)


## Station loop in HouseSpec-local points (converted to world):
## kitchen counter -> the divider gap -> the sofa -> the front
## door -> the gap again -> the kitchen sun patch. Legs never
## cross the divider away from its gap.
func _occupant_stations(seat_x: float, origin: Vector3) -> Array:
	var local: Array = [
		{"pos": Vector3(-4.3, 0, -3.85), "yaw": 0.0, "action": "stand", "dwell": 6.0},
		{"pos": Vector3(-1.8, 0, 0.0), "yaw": -PI / 2.0, "action": "stand", "dwell": 1.5},
		{"pos": Vector3(seat_x, 0, -3.45), "yaw": PI, "action": "sit", "dwell": 16.0},
		{"pos": Vector3(2.5, 0, 2.9), "yaw": PI, "action": "stand", "dwell": 5.0},
		{"pos": Vector3(-1.8, 0, 0.0), "yaw": PI / 2.0, "action": "stand", "dwell": 1.5},
		{"pos": Vector3(-3.2, 0, 3.2), "yaw": 0.0, "action": "stand", "dwell": 2.5},
	]
	var out: Array = []
	for st: Variant in local:
		var d := (st as Dictionary).duplicate()
		d["pos"] = origin + (d["pos"] as Vector3)
		out.append(d)
	return out


func _on_occupant_score(event_name: String, points: int, _pos: Vector3) -> void:
	if objectives == null:
		return
	objectives.add_score(event_name, points)
	match event_name:
		"ankle_attack":
			objectives.add_progress("occupants:ankle_assassin", 1)
		"trip_hazard":
			objectives.add_progress("occupants:trip_hazard", 1)
		"lap_full_heal":
			objectives.set_progress("occupants:lap_full_heal", 1)
