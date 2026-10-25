class_name MasseyModuleManifest
extends RefCounted
## THE MASSEY MODULE AS DATA — the machine-readable index of the
## 255 Massey drop-in module (docs/massey-zones.md §9).
##
## Everything here is DERIVED from HouseSpec at call time — the
## manifest carries no constants of its own, because a manifest
## that forks the spec would defeat §9.1 (layout is canon; hosts
## are realizations). A host game or an integration tool reads
## THIS to enumerate what the module is: its floors, its travel
## pairings, its anchors, the canonical frame, what a host must
## provide (§9.3), and what content the module contains (§9.4).

const MODULE_ID := "massey_255"
const MODULE_NAME := "255 Massey Street — Willie and Aggie cat start"
const MODULE_VERSION := "1.0.0"


## The canonical frame a host renders against (§9.1): GTA's real
## house. PvK's own shell is only the first host realization.
static func canonical_frame() -> Dictionary:
	return {
		"footprint": HouseSpec.GTA_FOOTPRINT, # (x, z) metres, OSM
		"centre_world": HouseSpec.GTA_CENTER, # GTA world (x, z)
		"interior_cell": HouseSpec.GTA_INTERIOR, # fitted cell (x, z)
		"wall_h": HouseSpec.GTA_WALL_H,
		"cell_y": HouseSpec.GTA_CELL_Y,
		"linked_dy": HouseSpec.GTA_LINKED_DY,
		"door_wall": HouseSpec.GTA_DOOR_WALL,
		"street_side": HouseSpec.GTA_STREET_SIDE,
	}


## Floors in display order: the PvK stack height and the GTA cell
## Y each floor lands on in a GTA host (GTA_FLOOR_Y).
static func floors() -> Array:
	var out: Array = []
	for id: String in HouseSpec.ZONE_ORDER:
		out.append({
			"id": id,
			"name": String(HouseSpec.ZONE_NAMES[id]),
			"pvk_floor_y": HouseSpec.floor_y(id),
			"gta_floor_y": float(HouseSpec.GTA_FLOOR_Y.get(id, HouseSpec.GTA_CELL_Y)),
			"scene": String(HouseSpec.ZONE_SCENES.get(id, "")),
		})
	return out


## The travel pairing table (§9.5: the pairing DATA is module
## content even though the travel mechanism is the host's):
## every connector in every zone, as from -> entry.
static func pairings() -> Array:
	var out: Array = []
	for id: String in HouseSpec.ZONE_ORDER:
		for cfg: Variant in HouseSpec.connectors(id):
			var d := cfg as Dictionary
			out.append({
				"from_zone": id,
				"at": d.get("at", Vector3.ZERO),
				"target_zone": String(d.get("target_zone", "")),
				"target_entry": String(d.get("target_entry", "")),
			})
	return out


## The canonical anchors (§9.2): name -> {u, v, floor}. Resolve
## with HouseSpec.anchor(name, "pvk" | "gta").
static func anchors() -> Dictionary:
	return HouseSpec.ANCHORS.duplicate(true)


## What a host must provide (§9.3), with the PvK-realization names
## the module code codes against. See module/DROP-IN.md.
static func host_requirements() -> Array:
	return [
		"shell_registration", # instance a floor's content at a host transform
		"builder_primitives", # flat-colour box kit, cached materials, one static body per floor
		"actor_spawn", # a player-cat actor exposing the §4 cat API (PvK: PvKCat as host var `cat`)
		"duo_surface", # host vars duo/mice/catch_radius the duo system reads and writes
		"paw_sink", # host method _on_paw_swiped(): the paw-strike sink (catch/combat)
		"zone_hook", # host method on_zone_changed(zone_id): camera etc. + sibling rebind via module.zone_root(id)
		"outside_root_api", # the host IS the outside zone root: get_entry/get_lounge_spots/get_wander_rect
		"sinks", # an objectives/score registry with the §5 names (PvK: PvKObjectives)
		"scale_discipline", # real metres; Willie 0.35, Aggie 0.25; humans on the 1.70 m table
	]


## Contents inventory (§9.4), reconciled 2026-10-25 against main.
## state: built | pending (exists only in an open PR, not in tree).
static func contents_inventory() -> Array:
	return [
		{"contents": "Ground floor (kitchen/living, drawer, bowl, sofa)", "state": "built", "where": "house/house_builder.gd via zones/ground_floor"},
		{"contents": "Basement (box labyrinth, rats/spiders/ghosts, litter box)", "state": "built", "where": "zones/basement"},
		{"contents": "Attic (raccoon family, window perch, insulation field)", "state": "built", "where": "zones/attic"},
		{"contents": "Outside yard + street (trees/squirrels, feeder birds, road, dogs)", "state": "built", "where": "main.tscn (the PvK host), zones/outside"},
		{"contents": "Cats (Willie/Aggie: data, controller, health, hiss)", "state": "built", "where": "cat_kit/, duo/"},
		{"contents": "Occupants (Daniel + Folasade NPCs + interactions)", "state": "built", "where": "occupants/"},
		{"contents": "Encounters (rats/spiders/ghosts; raccoon family; squirrels/birds/cars/dogs)", "state": "built", "where": "combat/, zones/*"},
		{"contents": "Damage/score/objective tables", "state": "built", "where": "combat/combat_data.gd, objectives/objectives.gd, zones/*/objectives*.json"},
		{"contents": "Module root + cat start (assembly behind the §9.3 host interface)", "state": "built", "where": "module/massey_module.gd"},
		{"contents": "Glenys (the cat-chaser: pursuit, struggle grab, chocolate, rat poison)", "state": "pending", "where": "PR #14 (branch glenys) — not in this tree yet"},
	]
