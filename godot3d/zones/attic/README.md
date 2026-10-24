# The Attic — 255 Massey (Willie and Aggie)

A self-contained zone: the top floor of the Massey house at cat scale,
held by a family of raccoons. Built to be lifted later — every
dimension is data (see the constants block at the top of `attic.gd`),
and the enemy + combat code follows the shared contract so the
foundation hub can wire it in without surgery.

## The room

Zone-local space: origin at the centre of the attic floor, floor top
at y = 0, ridge along X.

| Constant (attic.gd) | Value | Notes |
|---|---|---|
| `FOOTPRINT` | 12.0 × 9.0 m | x by z |
| `EAVE_H` | 0.95 m | knee-wall height; the roof springs here |
| `RIDGE_H` | 3.30 m | underside of the ridge |
| roof pitch | ≈ 27.6° | derived: `atan2(RIDGE_H-EAVE_H, FOOTPRINT.y/2)` |
| `HATCH_POS` | (+5.05, 0, +3.55) | floor hatch, entrance from below |
| `NEST_POS` | (−4.85, 0, −3.35) | the raccoons' corner |
| `WINDOW_POS` / `WINDOW_R` | (+5.98, 2.25, 0), r 0.55 | round window, +x gable |
| `PERCH_POS` | (+5.30, 1.52, 0) | ledge under the window |
| `BEAM_XS` / `BEAM_TOP` | x = −3.2, 0.4, 3.6 / top y 1.62 | walkable collar beams |

- Headroom shrinks toward the eaves: the roof planes are real
  colliders; `ceiling_height_at(z)` gives the profile.
- Crate stairs by the hatch climb to the x = 3.6 beam; the perch is a
  jump from that beam.
- Insulation piles (`PILES` in attic.gd) are soft — no collision, but
  `speed_factor_at(pos)` returns 0.55 inside them; actors that ask
  the zone (the raccoons do) wade. Player-side application is a hub
  wiring job.
- The round window is surface-mounted on the gable (ring + glowing
  glass + mullions) with a matched SpotLight and a translucent shaft
  cone; cutting a true round hole is a GTA-port concern.
- Dusty warm gloom: dim warm ambient, the window shaft is the key
  light, dust motes drift in it.

## Objective — "Reclaim the attic"

Data: `attic_objectives.json`. Defeat **Mother Raccoon** (the kits
are optional, but they defend her). On her fall: the objective flips
to `won`, the kits flee to the eaves for good, the **window perch**
unlocks as a lounge spot, and her **bottle-cap hoard** pops out of
the nest (collectible hook for the hub).

## The family (raccoon.gd — PvKRaccoon)

One procedural builder in the cat-kit's smooth-primitive idiom:
grey ellipsoids, a black mask band worn across the eyes with glossy
bead eyes and pale brow patches, ringed tail, dark "sock" legs.
`set_role()` before `add_child`, like the cat's `set_character()`.

- **Mother** (scale 0.40, HP 12, HP bar overhead). Guards the nest.
  Approaches inside 5.2 m; **swipes** inside 0.95 m (1 dmg); at
  1.6–4.4 m she **telegraphs** — a 0.65 s crouched paw-scrape — then
  **charges** in a straight line at 5.0 m/s (2 dmg on contact; the
  rush ends on a wall, a hit, or 0.85 s). Staggers 0.9 s at 75/50/25%
  HP (her kits scatter). Under 30% she **enrages**: faster, shorter
  telegraph, red eyes. Death is a flop.
- **Kits ×3** (scale 0.20, HP 2). Hover-orbit Mother. If the cat
  faces them inside 1.25 m they **scatter** to the eaves; if the
  cat's back is turned inside 2.8 m they **nip** — a 3.8 m/s dart,
  1 dmg, instant retreat. They scatter when Mother staggers and
  **flee to the eaves permanently when she falls**.
- Speeds are tuned against the cat (walk 2.4, sprint 5.0): the
  charge is dodgeable on foot and out-runnable on sprint.

## Combat contract (shared with the foundation enemy base)

`hp`/`hp_max`; `take_hit(damage, from_pos)` → knockback + 0.08 s hit
flash + death flop / kit flee; damage out through the target's own
`take_hit(damage, from_pos)` when it has one, gated by a shared
1.0 s contact cooldown; `damaged_target` signal always emitted for
HUD listeners (display only — never re-apply). The zone resolves the
cat's paw: `attic.setup(cat)` connects `paw_swiped` and applies
`PAW_DAMAGE` to any family member within `PAW_REACH` of
`cat.paw_point()`.

`harness_cat.gd` is a **test stand-in only** (PvKCat + minimal
HP/take_hit/jump) until the foundation lane's cat combat pass lands;
it is not game code.

## Verify

    godot --headless --path godot3d res://zones/attic/tests_attic.tscn
    xvfb-run godot --path godot3d res://zones/attic/tools_attic_shots.tscn

Tests load the zone standalone with the harness cat and assert on
state: family composition, insulation factors, contact cooldown, the
jump arc, wall/beam collision, kit scatter + nip, telegraph strictly
before charge, charge speed and its 2-damage hit, stagger thresholds
+ kit scatter, paw kill → objective/perch/hoard, kits fled, lounge on
the perch. Shots land in `screenshots/`.

## Integration notes

- **House contract reconciliation is outstanding**: the foundation
  lane's `massey-zones.md` was not published when this geometry
  locked (no `massey-foundation` branch/PR as of 2026-10-24), so the
  footprint/floor/hatch values above are this lane's own, documented
  for the coordinator to reconcile.
- The hub should place this scene at the house's attic floor level,
  route the player through `HATCH_POS`, call `setup(cat)`, and read
  `objective_state` / `perch_unlocked` / `hoard_revealed` (or the
  `objective_won` signal) for its objectives HUD.
