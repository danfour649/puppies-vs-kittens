class_name OutsideLayout
extends RefCounted
## Willie and Aggie — MASSEY OUTSIDE ZONE: every placement in the
## yard and street frontage, as named constants relative to the
## house footprint, so the yard and the house stay ONE coherent
## model (and the model can be lifted into GTA Fredericton later).
##
## COORDINATE FRAME (inherited from godot3d/main.gd, do not fork):
## the back lawn is x in [-13.2, 13.2], z in [-10.2, 10.2]; the
## fence runs along z = +10 (south) and x = +/-13 (east/west); the
## house sits along the NORTH edge with its back wall plane at
## z = -10.2, spanning x in [-8.5, 8.5], wall height 3.4. The cat
## spawns at (2.5, -6.2); the porch deck is at (2.5, -8.7); the
## garden chair at (4.5, 4.5); crates at (9.9, -6.05). North is -Z.
##
## HOUSE FOOTPRINT (the shared spec — foundation lane's
## massey-zones.md was not yet on origin when this was written;
## these numbers are DERIVED from main.gd's _build_environment and
## must be reconciled with the foundation doc at integration):
const HOUSE_WALL_Z := -10.2 ## back wall plane of the house
const HOUSE_FRONT_Z := -10.4 ## front face of the wall (incl. trim)
const HOUSE_MIN_X := -8.5
const HOUSE_MAX_X := 8.5
const HOUSE_WALL_H := 3.4
const DOOR_X := 2.5 ## the front/back door axis (porch at z -8.7)

## --- back yard (existing diorama) -----------------------------------
const YARD_RECT := Rect2(-12.4, -9.4, 24.8, 18.8) ## inside the fence

## Functional climbable trees. The decorative box tree at
## (-8.5, -5.0) is main.gd set dressing and stays untouched.
const TREE_WEST := Vector3(-10.6, 0, 2.2)
const TREE_EAST := Vector3(11.2, 0, -1.8)
const TREE_SOUTH := Vector3(-3.6, 0, 7.6)
const TREE_POSITIONS: Array[Vector3] = [TREE_WEST, TREE_EAST, TREE_SOUTH]
const TRUNK_RADIUS := 0.22
const TRUNK_HEIGHT := 2.6
const FIRST_BRANCH_Y := 1.3 ## first branch height (cat + squirrel perch)
const CAT_CLIMB_SPEED := 0.85 ## m/s, the stub climb harness
const CAT_CLIMB_PIN := 0.30 ## cat centre distance from trunk axis while climbing

## Bird feeder + ambush bushes (east side of the back yard).
const FEEDER_POS := Vector3(7.6, 0, 3.2)
const BUSH_A := Vector3(6.1, 0, 4.9)
const BUSH_B := Vector3(9.3, 0, 1.7)
const BUSH_C := Vector3(5.9, 0, 1.3)
const BUSH_POSITIONS: Array[Vector3] = [BUSH_A, BUSH_B, BUSH_C]
const BUSH_RADIUS := 1.05 ## cat counts as "in the bush" inside this
const BUSH_HIDE_SPEED := 0.35 ## cat slower than this (or stalking) is hidden

## --- front of the house: lawn, sidewalk, Massey Street -------------
## Everything below is z < HOUSE_FRONT_Z, laid out in bands running
## east-west, all offsets from the house front face.
const FRONT_LAWN_NEAR := -10.4 ## == HOUSE_FRONT_Z
const FRONT_LAWN_FAR := -13.2
const SIDEWALK_NEAR := -13.2
const SIDEWALK_FAR := -14.1
const WALK_Z := -13.65 ## where pedestrians (and their dogs) walk
const STREET_NEAR := -14.1
const STREET_FAR := -19.7
const LANE_NEAR_Z := -15.5 ## near lane centre, traffic travels +X
const LANE_FAR_Z := -18.3 ## far lane centre, traffic travels -X
const LANE_CENTRE_Z := -16.9 ## painted centre line
const FAR_SIDEWALK_NEAR := -19.7
const FAR_SIDEWALK_FAR := -20.6
const FAR_YARD_NEAR := -20.6
const FAR_YARD_FAR := -23.6
const STREET_X_END := 18.0 ## cars/walkers spawn and despawn at |x| here
const FRONT_REGION := Rect2(-18.5, -24.0, 37.0, 14.1) ## the whole street frontage, z from -24 to -9.9: dogs alert here, never in the back yard

## Driveway + the parked, indestructible silver 2018 Corolla: a safe
## island mid-crossing. Cars path around the driveway mouth and will
## not target a cat sheltering in the Corolla's street-side shadow.
const DRIVEWAY_MIN_X := 5.9
const DRIVEWAY_MAX_X := 8.5
const COROLLA_POS := Vector3(7.2, 0, -12.6) ## centre, nose toward the street
const COROLLA_SIZE := Vector3(1.7, 0, 3.6) ## x width, z length (diorama scale)
const COROLLA_SHELTER := Rect2(6.0, -15.15, 2.4, 1.05) ## the driveway-mouth strip: traffic biases wide around the driveway here, so a tucked-in cat is physically clear of the lane ## x 6.0..8.4, z -16.4..-14.1: no targeting inside

## The prize across the street: a fish treat that fully heals,
## on the far front-yard strip, on the door axis.
const FISH_TREAT_POS := Vector3(DOOR_X, 0, -22.1)

## --- tuning: squirrels ----------------------------------------------
const SQUIRREL_FLEE_RADIUS := 3.4 ## cat closer than this -> run for the tree
const SQUIRREL_LUNGE_RADIUS := 5.0 ## cat sprinting/striking within this -> run
const SQUIRREL_RUN_SPEED := 4.3
const SQUIRREL_CLIMB_SPEED := 2.3
const SQUIRREL_HP := 2
const SQUIRREL_CALM_TIME := 4.0 ## cat far for this long -> come back down
const SQUIRREL_CALM_RADIUS := 5.5
const POUNCE_CLIMB_CATCH := 0.75 ## chance a trunk-base pounce catches a climbing squirrel

## --- tuning: birds + ambush ------------------------------------------
const BIRD_MAX := 6 ## concurrent birds, web perf cap
const BIRD_SPAWN_MIN := 2.6
const BIRD_SPAWN_MAX := 4.4
const BIRD_SCARE_WILLIE := 3.0 ## metres, before speed factor
const BIRD_SCARE_AGGIE := 2.3 ## Aggie is smaller, quieter — birds tolerate her closer
const AMBUSH_CATCH_RANGE := 1.5 ## paw-to-bird distance for a catch
const AMBUSH_CATCH_RANGE_HIDDEN := 1.8 ## ... from a hidden pounce
## Stillness meter, per character (Aggie is the ambush model: her
## meter decays slower, so a fidget costs her less).
const STILL_FILL_TIME := {"willie": 2.4, "aggie": 2.0} ## seconds still -> full
const STILL_DECAY := {"willie": 0.55, "aggie": 0.25} ## per second while moving

## --- tuning: traffic --------------------------------------------------
const CAR_MAX := 5
const CAR_SPEED := 7.5
const CAR_SPEED_VAR := 1.5
const CAR_HOSTILE_BOOST := 1.25
const CAR_REACTION_AHEAD := 13.0 ## cat this far ahead (or less) is targeted
const CAR_SWERVE_BOUND := 1.25 ## max lateral drift from lane centre
const CAR_SWERVE_RATE := 1.7 ## m/s of lateral drift
const CAR_SPAWN_MIN := 2.4
const CAR_SPAWN_MAX := 4.2

## --- tuning: damage (LOCAL contract — the foundation lane owns ---
## --- cat HP / nine-lives; the coordinator reconciles these) ---------
const CAT_HP_MAX := 100.0
const DMG_VEHICLE_HIT := 60.0 ## a real hit: ~60% of a life
const DMG_VEHICLE_BRUSH := 10.0 ## a slow brush / edge clip
const DMG_DOG_BITE := {"small": 12.0, "big": 20.0} ## standard enemy bite ~15%
const DMG_DOG_GRAB := 30.0 ## grab + shake, then the cat bursts free

## --- tuning: walkers + dogs -------------------------------------------
const WALKER_INTERVAL_MIN := 25.0
const WALKER_INTERVAL_MAX := 45.0
const WALKER_SPEED := 1.35
const LEASH_LEN := 1.7
const DOG_ALERT_RADIUS := 9.0
const DOG_ALERT_RADIUS_HIDDEN := 2.2 ## a hidden cat is only scented this close
const DOG_SLIP_RADIUS := 1.2 ## cat this close to a straining dog -> leash slips
const DOG_CHASE_SPEED := {"small": 5.9, "big": 5.4} ## faster than Willie (5.0), ~Aggie's pace
const DOG_TURN_RATE := {"small": 3.4, "big": 2.0} ## rad/s
const DOG_BITE_RANGE := 0.55
const DOG_BITE_CD := 0.9
const DOG_GRAB_WINDOW := 2.5 ## two bites inside this -> grab + shake
const DOG_GIVE_UP_DIST := 16.0
const DOG_GIVE_UP_TIME := 14.0
const DOG_TREE_CIRCLE_TIME := 3.5
const DOG_BUSH_CONFUSE_TIME := 2.0

## --- back-yard forest (TODO #121, Daniel 2026-10-25) ----------------
## The real 255 Massey back yard is a literal forest. Decorative
## grove positions (YardForest), planted along the boundary lines
## and in two interior clusters so the canopy closes the yard in.
## Every position keeps >= ~2 m from a gameplay point: the three
## climbable trees keep clear bases (squirrel / climb / dog-circle
## room), and the feeder, ambush bushes, chair, crates, porch and
## door axis stay open. The lawn's middle band stays a glade, and
## the south row leaves a clearing around TREE_SOUTH.
const FOREST_SEED := 25512
const FOREST_POSITIONS: Array[Vector3] = [
	Vector3(-11.5, 0, 8.55), Vector3(-9.3, 0, 8.55), Vector3(-7.1, 0, 8.55),
	Vector3(-5.6, 0, 8.6), Vector3(0.5, 0, 8.55), Vector3(3.3, 0, 8.55),
	Vector3(6.1, 0, 8.55), Vector3(8.7, 0, 8.55), Vector3(11.3, 0, 8.55),
	Vector3(-11.7, 0, -7.6), Vector3(-11.7, 0, -5.0), Vector3(-11.7, 0, -2.4),
	Vector3(-12.1, 0, 0.4), Vector3(-11.7, 0, 5.4),
	Vector3(11.75, 0, -7.4), Vector3(11.75, 0, -4.2), Vector3(11.75, 0, 0.8),
	Vector3(11.75, 0, 5.2),
	Vector3(-7.9, 0, 5.7), Vector3(-5.7, 0, 6.5), Vector3(9.9, 0, 6.7),
]
