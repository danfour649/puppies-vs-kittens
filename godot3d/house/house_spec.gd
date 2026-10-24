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
			# INTEGRATION: the built labyrinth's stairs are on the
			# SOUTH wall (its ENTRY_POS stair foot at (4.35, 5.35));
			# the landing stands on the fully open south row west
			# of the stair foot — clear of the return volume, with
			# open floor around it (things hunt you down here).
			return {"EntryStairs": Transform3D(Basis(), Vector3(2.85, 0.0, 4.5))}
		ATTIC:
			# INTEGRATION: the built attic's hatch is its SE floor
			# corner (HATCH_POS (5.05, 3.55)); the landing stands on
			# clear floor just west of it, clear of the crate stairs
			# and of the return volume below, facing into the room.
			return {"EntryHatch": Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(3.9, 0.0, 3.9))}
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
				"at": Vector3(4.35, 0.7, 5.35), "size": Vector3(2.3, 1.4, 2.5),
				"target_zone": GROUND_FLOOR, "target_entry": "EntryStairsTop",
			}]
		ATTIC:
			return [{
				"at": Vector3(5.05, 0.7, 3.55), "size": Vector3(1.7, 1.4, 1.7),
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


# ============================================================================
# THE MODULE FRAME — 255 Massey as a drop-in module (Daniel, 2026-10-24:
# "develop this as a separate, drop in module for GTA Fredericton").
#
# The CANONICAL frame is GTA's real house (scripts/world/god_mode.gd +
# landmark_interiors.gd FITTED + interior_cells.gd SPECS, via the
# mergeability eval of 2026-10-24): OSM footprint 11.79 m (x) by
# 15.64 m (z) centred (-99.75, 2307.51), Massey St along the NORTH
# face, door on the WEST wall under the carport, fitted interior
# cell 10.8 x 14.6 m with wall_h 3.1, cells instanced at CELL_Y 300
# with LINKED floors at +40 per storey (MacTavish precedent; a
# below-grade LINKED cell is expressible but UNVERIFIED in GTA).
#
# PvK's local shell (17.0 x 9.6, door on the yard/south face) is the
# module's FIRST HOST realization, not the canon. Layout therefore
# travels as ANCHORS: (u, v) fractions of footprint — u west->east,
# v north->south — plus a floor id. Anchor fractions are identical
# in every host; each host realizes walls/doors in its own frame
# (GTA: entry function on the west/carport face; PvK: south/yard).
# ============================================================================

const GTA_FOOTPRINT := Vector2(11.79, 15.64) # (x, z) metres, OSM
const GTA_CENTER := Vector2(-99.75, 2307.51) # world (x, z)
const GTA_INTERIOR := Vector2(10.8, 14.6) # fitted cell (x, z)
const GTA_WALL_H := 3.1
const GTA_CELL_Y := 300.0
const GTA_LINKED_DY := 40.0
const GTA_DOOR_WALL := "west" # under the carport
const GTA_STREET_SIDE := "north" # Massey St itself

## Where each PvK floor lands in GTA's cell stack. Attic rides the
## proven above-cell LINKED pattern; basement is the same pattern
## below grade — data-expressible, not yet verified in GTA.
const GTA_FLOOR_Y := {BASEMENT: 260.0, GROUND_FLOOR: 300.0, ATTIC: 340.0}

## Canonical anchors: name -> {u, v, floor}. Derived from the PvK
## local constants above via anchor_uv() (the tests round-trip
## them); a host rendering the module reads THESE, never PvK metres.
const ANCHORS := {
	"front_door": {"u": 0.647, "v": 1.0, "floor": GROUND_FLOOR}, # on the entry wall
	"stairwell": {"u": 0.118, "v": 0.188, "floor": GROUND_FLOOR}, # centre
	"hatch": {"u": 0.882, "v": 0.188, "floor": GROUND_FLOOR}, # centre
	"kitchen": {"u": 0.197, "v": 0.5, "floor": GROUND_FLOOR}, # room centre
	"living": {"u": 0.697, "v": 0.5, "floor": GROUND_FLOOR}, # room centre
	"drawer": {"u": 0.194, "v": 0.068, "floor": GROUND_FLOOR}, # Aggie's drawer
	"water_bowl": {"u": 0.362, "v": 0.781, "floor": GROUND_FLOOR},
	"sofa": {"u": 0.782, "v": 0.099, "floor": GROUND_FLOOR}, # the lap seat
	"scratch_post": {"u": 0.965, "v": 0.594, "floor": GROUND_FLOOR},
	"basement_entry": {"u": 0.668, "v": 0.969, "floor": BASEMENT}, # built entry (2.85, 4.5)
	"attic_entry": {"u": 0.729, "v": 0.906, "floor": ATTIC}, # built entry (3.9, 3.9)
	"attic_perch": {"u": 0.812, "v": 0.500, "floor": ATTIC}, # built perch (5.30, 0.0)
}


## PvK-local (x, z) -> canonical anchor fractions.
static func anchor_uv(local_xz: Vector2) -> Vector2:
	return Vector2(
		(local_xz.x + FOOTPRINT_W / 2.0) / FOOTPRINT_W,
		(local_xz.y + FOOTPRINT_D / 2.0) / FOOTPRINT_D)


## Canonical fractions -> PvK-local (x, z) on the given floor.
static func uv_to_pvk(uv: Vector2) -> Vector2:
	return Vector2(
		uv.x * FOOTPRINT_W - FOOTPRINT_W / 2.0,
		uv.y * FOOTPRINT_D - FOOTPRINT_D / 2.0)


## Canonical fractions -> GTA fitted-cell local (x, z). The plan is
## TRANSPOSED between hosts (PvK's long axis is x, GTA's is z), but
## u always runs west->east and v north->south, so the mapping is
## axis-aligned in (u, v) space: GTA x takes u across its short
## span, GTA z takes v along its long span.
static func uv_to_gta(uv: Vector2) -> Vector2:
	return Vector2(
		uv.x * GTA_INTERIOR.x - GTA_INTERIOR.x / 2.0,
		uv.y * GTA_INTERIOR.y - GTA_INTERIOR.y / 2.0)


## A named anchor in whichever host frame a builder needs:
## "pvk" -> Vector3 local on its floor; "gta" -> Vector3 cell-local
## at the GTA_FLOOR_Y for its floor.
static func anchor(name_: String, host: String) -> Vector3:
	var a: Dictionary = ANCHORS.get(name_, {})
	if a.is_empty():
		return Vector3.ZERO
	var uv := Vector2(float(a["u"]), float(a["v"]))
	var floor_id := String(a["floor"])
	if host == "gta":
		var p := uv_to_gta(uv)
		return Vector3(p.x, float(GTA_FLOOR_Y[floor_id]), p.y)
	var p2 := uv_to_pvk(uv)
	return Vector3(p2.x, floor_y(floor_id), p2.y)
