# CHECKPOINT — playtest fix wave (box reboot, 2026-10-24 ~22:40 ADT)

Branch: playtest-fixes (off main 6b221d7). State: all four bugs
REPRODUCED in the integrated main scene via scripted probes
(godot3d/tools/probe_playtest*.gd/.tscn, logs /tmp/pvk-pt-probe*.log).
NO source fixes applied yet — every fix below is designed and ready
to apply. Unedited copies of the files to patch are VM-side at
~/workspace/kvp-revival/pt-edits/.

## Bug 1 — mice impossible to catch: REPRODUCED (as a measurement)
Optimal scripted bot CAN catch, but the human window is a sliver.
Sprint press-distance sweep (3 trials each, catch within the trial):
press 1.10 -> 0/3 (lat 0.0), 0/3 (lat 0.3); press 0.90 -> 2/3, 3/3;
press 0.70 -> 2/3, 0/3 (lat 0.3); press 0.50 -> 0/3, 0/3.
Walk-only: press 0.90 -> 0/3, 0.70 -> 0/3.
Root cause: paw swipe resolves 0.10 s after the press against a
mouse fleeing at FLEE_SPEED 3.4; paw_point sits 0.602 m ahead of
Willie; catch_radius is 0.42. Effective window is only press
distance ~0.85-1.0 dead-ahead and collapses with any lateral
offset. Willie walk 2.4 < flee burst 3.4, so walking can never run
a mouse down in the open (walk catch in probe 1 took 13.5 s and
needed a cornered mouse).
FIX (planned): main.gd catch_radius 0.42 -> 0.62 AND
duo/duo_system.gd CATCH_RADIUS_BASE 0.42 -> 0.62 (provoked stays
0.80; tests_duo asserts provoked > 0.43, still fine);
mouse.gd FLEE_SPEED 3.4 -> 3.05, FLEE_TIRED_SPEED 2.2 -> 1.95
(still > walk when fresh, tired mouse now catchable at walk).
Then re-run the sweep probe to verify the window widened.

## Bug 2 — z axis: ROOT CAUSE FOUND + REPRODUCED
OutsideSystem._step_sibling_fence() (zones/outside/
outside_system.gd, ~line 1090) runs every physics frame in EVERY
zone: if sibling global z < -9.85 then z = -9.4. The interior
stack lives at world z ~ -200, so the frame after any indoor
travel the sibling z is yanked back to the yard; she falls onto
the porch and pins against the house wall (probe 3: after
yard->attic travel Aggie sat at (4.52, 0.24, -9.55), driving
toward her attic lounge target through the wall). Probe 4 proved
travel itself places her correctly (4.50, 2.95, -196.70) with
per-frame writers frozen.
FIX (planned): gate the nudge on the ZoneManager current_zone
== HouseSpec.OUTSIDE; yard behaviour unchanged (tests_outside
asserts sibling z > -9.9 in the yard context).
SECONDARY, proven at data level: the hatch shaft is z-flipped —
ground floor hatch connector + ceiling hole at house-local
(6.5, -3.0) (north) vs attic hatch/entry at z +3.55/+3.9 (south),
delta z ~ 6.9. FIX (planned): attic.gd HATCH_POS z 3.55 -> -3.55
(+ header comment), mirror the crate stairs
(4.45,2.55)/(3.95,1.95)/(3.62,1.30) to negative z, REFUGES
(5.25,0,-4.0) -> (5.25,0,4.0); HouseSpec connectors(ATTIC) at
z -> -3.55; entries(ATTIC) EntryHatch -> (3.9,0,-3.9) with
Basis(UP, PI) (PI so the sibling offset lands at (3.05,.,-3.9)
open floor, not in the knee wall); tests_attic three _place
calls z 3.55 -> -3.55; attic README HATCH_POS row;
docs/massey-zones.md line 61 + mapping rows (attic hatch v
0.130, GTA z -5.40; attic entry v 0.094, GTA z -5.93).
THIRD candidate, DOCUMENTED ONLY (not fixing): basement stair
shaft misaligned in both axes — GF STAIRWELL centre (-6.5,-3.0)
vs basement stair foot (4.35, 5.35) / EntryStairs (2.85, 4.5).
Relocating it is a maze redesign; needs a Daniel/coordinator
decision.

## Bug 3 — raccoons outside: REPRODUCED + ROOT CAUSE
attic.gd _spawn_family sets mother/kit global_position =
NEST_POS + offset AFTER add_child. NEST_POS (-4.85,0,-3.35) is
attic-LOCAL; in the integrated scene the attic root sits at
(0, 2.9, -200), so the family lands at world (-4.5, 0, -3.0) —
the yard (probe 1 census: mother global (-4.5,0,-3.0),
attic-local (-4.5,-2.9,+197)). Kits REFUGES are also local
coords that raccoon.gd consumes as world targets. Standalone
attic tests passed because the root sits at the origin there.
FIX (planned): in _spawn_family set position (local) instead of
global_position for mother + kits; convert kit refuges with
global_transform * r. home reads stay global (correct after
placement).

## Bug 4 — Aggie never attacks Willie: REPRODUCED + ROOT CAUSE
Sibling lounge-lock. SiblingAI._arrive_lounge calls
cat.set_lounge(true); nothing in SiblingAI ever calls
set_lounge(false) when leaving lounge mode (wander/dash/flee),
and PvKCat refuses to move or strike while is_lounging.
Probe 1 (no manual un-lounge): meter 32->65->97->100, prov
state triggered, sibling mode dash then flee, Aggie
displacement 0.00, 0 flurry hits, still lounging at the end.
The duo suite masked it: tests_duo.gd line 91 manually calls
aggie.set_lounge(false) before the provocation test.
FIX (planned): at the top of SiblingAI._physics_process, if
mode != "lounge" and cat.is_lounging: cat.set_lounge(false).
(Bug 2 fence clamp independently strands her outdoors, so
indoor provocation was doubly dead.)

## Remaining after the fixes
1. Apply the edits above (files: zones/outside/outside_system.gd,
   duo/sibling_ai.gd, zones/attic/attic.gd, house/house_spec.gd,
   zones/attic/tests_attic.gd, zones/attic/README.md,
   docs/massey-zones.md, main.gd, duo/duo_system.gd, mouse.gd).
2. Re-run probe sweep (bug 1) + probe 1 scenarios (bugs 3/4) to
   verify; then delete or convert the probes.
3. Write the permanent regression suite tests/test_playtest.gd
   (+ .tscn): raccoon world positions at boot; sibling stays in
   the ground floor after travel (fence regression); provocation
   WITHOUT manual un-lounge reaches flurry with >= 1 hit; staged
   strikes at 0.9 m and 0.7 m + 0.3 lateral catch; scripted
   sprint chase (10 Hz steering, press < 0.95) catches within
   30 s; shaft data assert (attic entry/connector/HATCH_POS z
   all < 0) + travel landing within 1.6 m of HATCH_POS.
4. Full battery on the branch: smoke 52, duo 51, massey 61,
   basement 53, attic 49, outside 67, occupants 51 + new suite,
   zero script errors; web export RC=0.
5. PR (not yet opened), merge to main when green, refresh the
   desktop install (pvk-godot-work checkout main + pull, then
   ~/games/puppies-vs-kittens/update.sh), launch-verify.
Process discipline: all Godot runs so far were setsid timeout
runs with PIDs recorded (359628, 360590, 362453, 363349 — all
finished, none running at checkpoint time).
