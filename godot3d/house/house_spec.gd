class_name HouseSpec
extends RefCounted
## HOUSE SPEC — 255 Massey Street as ONE data-driven model.
##
## Every zone of Willie and Aggie (outside yard, ground floor,
## basement, attic) derives its geometry from this file: footprint,
## floor levels, ceiling heights, stair + hatch positions, entry
## points, connector volumes, lounge spots. Change a number here and
## every zone moves together — that is the point. The house is a
## reusable model, not scenery: see docs/massey-zones.md for the
## zone contract and the GTA Fredericton reuse mapping.
##
## House-local frame: origin at the centre of the footprint, on the
## GROUND floor's top surface. +X is east, +Z is south (toward the
## yard and Massey Street). A zone scene's root sits at
## zone_origin(id); inside the zone, local (x, z) are house-local
## and local y is height above that zone's own floor.
##
## The interior stack (ground/basement/attic) lives at world
## z = INTERIOR_Z so the yard stays exactly as shipped; the stack is
## vertically honest — basement below ground floor below attic, at
## the real floor levels — so stairs and the hatch line up in world
## space just as they do in the house.

# --- zones -------------------------------------------------------------------

const OUTSIDE := "outside"
const GROUND_FLOOR := "ground_floor"
const BASEMENT := "basement"
const ATTIC := "attic"

## HUD / doc display order and names.
const ZONE_ORDER: Array = [OUTSIDE, GROUND_FLOOR, BASEMENT, ATTIC]
const ZONE_NAMES := {
	OUTSIDE: "Outside — the yard",
	GROUND_FLOOR: "Ground floor — the hub",
	BASEMENT: "Basement — the labyrinth",
	ATTIC: "Attic — raccoon country",
}
const ZONE_SCENES := {
	GROUND_FLOOR: "res://zones/ground_floor/ground_floor.tscn",
	BASEMENT: "res://zones/basement/basement.tscn",
	ATTIC: "res://zones/attic/attic.tscn",
}

# --- the building --------------------------------------------------------------

const FOOTPRINT_W := 17.0 # x span (matches the yard's house wall)
const FOOTPRINT_D := 9.6 # z span
const WALL_T := 0.3 # exterior wall thickness
const INTERIOR_Z := -200.0 # world z of the interior stack

const FLOOR_Y := {BASEMENT: -2.6, GROUND_FLOOR: 0.0, ATTIC: 2.9}
const CEIL_H := {BASEMENT: 2.4, GROUND_FLOOR: 2.7, ATTIC: 2.3}
const SLAB_T := 0.25 # floor/ceiling slab thickness

## Ground floor rooms (house-local Rect2, x/z).
const KITCHEN := Rect2(-8.5, -4.8, 6.7, 9.6)
const LIVING := Rect2(-1.8, -4.8, 10.3, 9.6)
const DIVIDER_X := -1.8 # kitchen | living partition
const DIVIDER_GAP := Rect2(-1.95, -0.6, 0.3, 1.2) # doorway in it

## Openings.
const FRONT_DOOR_X := 2.5 # matches the yard: porch + door sit here
const FRONT_DOOR_W := 1.1
const FRONT_DOOR_H := 2.15
const STAIRWELL := Rect2(-7.7, -4.3, 2.4, 2.6) # centre (-6.5, -3.0)
const HATCH := Rect2(5.9, -3.6, 1.2, 1.2) # centre (6.5, -3.0)

## Signature props (ground floor) — the zone lanes leave these be.
const DRAWER_POS := Vector3(-5.2, 0.0, -4.15) # the open kitchen drawer
const WATER_BOWL_POS := Vector3(-2.35, 0.0, 2.7) # Willie's water bowl
const SOFA_POS := Vector3(4.8, 0.0, -3.85)
const SCRATCH_POST_POS := Vector3(7.9, 0.0, 0.9) # (he ignores it)


static func zone_origin(id: String) -> Vector3:
	if id == OUTSIDE:
		return Vector3.ZERO
	return Vector3(0.0, float(FLOOR_Y[id]), INTERIOR_Z)


static func floor_y(id: String) -> float:
	return float(FLOOR_Y.get(id, 0.0))


static func ceil_h(id: String) -> float:
	return float(CEIL_H.get(id, 2.7))


## Entry points per zone: name -> LOCAL transform (position + facing).
## Facing is a y-rotation; the cat model faces -Z at rot 0, +Z at PI.
## Every entry stands clear of its own zone's connector volumes, so a
## cat never bounces straight back through the door it arrived by.
static func entries(id: String) -> Dictionary:
	match id:
		OUTSIDE:
			return {"EntryFrontDoor": Transform3D(Basis(Vector3.UP, PI), Vector3(2.5, 0.30, -8.45))}
		GROUND_FLOOR:
			return {
				"EntryFrontDoor": Transform3D(Basis(), Vector3(2.5, 0.0, 3.55)),
				"EntryStairsTop": Transform3D(Basis(Vector3.UP, PI), Vector3(-6.5, 0.0, -1.55)),
				"EntryHatchBottom": Transform3D(Basis(Vector3.UP, PI), Vector3(6.5, 0.0, -1.7)),
			}
		BASEMENT:
			return {"EntryStairs": Transform3D(Basis(Vector3.UP, PI), Vector3(-6.5, 0.0, -1.55))}
		ATTIC:
			return {"EntryHatch": Transform3D(Basis(Vector3.UP, PI), Vector3(6.5, 0.0, -1.7))}
	return {}


## Connector (trigger) volumes per zone: walk in -> travel.
## "at"/"size" are LOCAL to the zone (outside: world/yard coords).
static func connectors(id: String) -> Array:
	match id:
		OUTSIDE:
			return [{
				"at": Vector3(2.5, 0.9, -9.85), "size": Vector3(1.7, 1.8, 1.2),
				"target_zone": GROUND_FLOOR, "target_entry": "EntryFrontDoor",
			}]
		GROUND_FLOOR:
			return [
				{"at": Vector3(2.5, 0.9, 4.35), "size": Vector3(1.7, 1.8, 1.1),
					"target_zone": OUTSIDE, "target_entry": "EntryFrontDoor"},
				{"at": Vector3(-6.5, 0.7, -3.0), "size": Vector3(2.3, 1.4, 2.5),
					"target_zone": BASEMENT, "target_entry": "EntryStairs"},
				{"at": Vector3(6.5, 0.7, -3.0), "size": Vector3(1.7, 1.4, 1.7),
					"target_zone": ATTIC, "target_entry": "EntryHatch"},
			]
		BASEMENT:
			return [{
				"at": Vector3(-6.5, 0.7, -3.0), "size": Vector3(2.3, 1.4, 2.5),
				"target_zone": GROUND_FLOOR, "target_entry": "EntryStairsTop",
			}]
		ATTIC:
			return [{
				"at": Vector3(6.5, 0.7, -3.0), "size": Vector3(1.7, 1.4, 1.7),
				"target_zone": GROUND_FLOOR, "target_entry": "EntryHatchBottom",
			}]
	return []


## Sibling lounge spots per zone (LOCAL; y is the resting height).
static func lounge_spots(id: String) -> Array:
	match id:
		GROUND_FLOOR:
			return [
				Vector3(-5.2, 0.50, -4.05), # in the open drawer
				Vector3(4.8, 0.60, -3.85), # the sofa
				Vector3(4.2, 0.02, -2.3), # the rug
				Vector3(-3.2, 0.02, 3.4), # kitchen sun patch
			]
		BASEMENT:
			return [
				Vector3(-4.0, 0.02, 0.8),
				Vector3(3.2, 0.02, 2.2),
				Vector3(-7.4, 0.77, 2.6), # on a storage box (stub dressing)
			]
		ATTIC:
			return [
				Vector3(7.3, 0.57, -0.6), # the window perch (stub block)
				Vector3(0.2, 0.08, 1.6), # a blanket pile
				Vector3(-5.5, 0.02, -2.0),
			]
	return []


## Sibling wander bounds per zone (LOCAL x/z Rect2).
static func wander_rect(id: String) -> Rect2:
	match id:
		GROUND_FLOOR, BASEMENT, ATTIC:
			return Rect2(-8.0, -4.3, 16.0, 8.6)
	return Rect2(-11.6, -8.6, 23.2, 17.2) # the yard (sibling's home rect)


## Shell recipe per interior zone (see house_builder.gd).
static func shell_cfg(id: String) -> Dictionary:
	match id:
		BASEMENT:
			return {
				"floor_color": Color(0.42, 0.40, 0.38),
				"wall_color": Color(0.55, 0.50, 0.45),
				"floor_holes": [],
				"ceiling_holes": [STAIRWELL],
				"door_gap": false,
				"roof": false,
			}
		GROUND_FLOOR:
			return {
				"floor_color": Color(0.62, 0.50, 0.36),
				"wall_color": Color(0.85, 0.80, 0.70),
				"floor_holes": [STAIRWELL],
				"ceiling_holes": [HATCH],
				"door_gap": true,
				"roof": false,
			}
		ATTIC:
			return {
				"floor_color": Color(0.55, 0.44, 0.30),
				"wall_color": Color(0.80, 0.74, 0.64),
				"floor_holes": [HATCH],
				"ceiling_holes": [],
				"door_gap": false,
				"roof": true,
			}
	return {}
