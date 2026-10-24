# The Basement — under 255 Massey Street

A zone of **Willie and Aggie**: the secret
tunnel/labyrinth in the basement of the cats' own house. A maze of
stacked cardboard boxes and shelf units, moody bulb light, things
that bite in the dark — and things that can't bite at all, which is
worse.

Built self-contained: it loads standalone with a test cat
(`basement.tscn`), or the house hub attaches its own cat with
`attach_cat(cat)`. Everything is procedural (PvKMouse / cat-kit
idiom); there are no scene-baked meshes, so the whole zone rebuilds
from the data tables in `basement.gd`.

## Run it

- Play standalone: `godot --path godot3d res://zones/basement/basement.tscn`
  (WASD/arrows move, Shift sprint, Space paw strike)
- Tests: `godot --headless --path godot3d res://zones/basement/tests_basement.tscn`
- Shots: `xvfb-run godot --path godot3d res://zones/basement/tools_basement_shots.tscn`
  → `screenshots/` (maze_overview, rat_pack, litter_box_corner, aggie_gap, ghost_block)

## Architecture — the house-model data

Daniel's direction: this house is a playground for improving THE
house model, reusable in GTA Fredericton later — so the layout is
**data at the top of `basement.gd`**, not magic numbers in builders:

| Thing | Value |
|---|---|
| Footprint | 16.0 × 12.0 m (x −8..8, z −6..6), +x east, +z south |
| Floor / ceiling | floor top y = 0.0, ceiling y = 2.3 (a low basement) |
| Maze grid | 1 m cells, 14 × 10, origin (−7, −5); layout in the `MAP` strings |
| Maze walls | cardboard box stacks, collision height 1.9 m |
| Tunnel | 4 cells (row 4) roofed at `TUNNEL_H` = 0.55 m clear |
| Entry | stairs down the south wall (east end); spawn `ENTRY_POS` at the stair foot |
| Shelf units | 5 (3 north wall, 2 west), boards at 0.08 / 0.52 / 0.96 — jumpable ~0.45 steps, box steps provided |
| Lights | 3 swaying bare bulbs (warm omni pools) + low warm ambient |

**Reconciliation flag for integration:** the foundation lane's shared
house contract (`massey-zones.md`) was not yet published when this
zone was built. The footprint / floor-Y / stair position above are
this zone's own documented values — the coordinator reconciles them
against the contract at integration.

### The Aggie gap (cell 11,2)

The NE alcove's only entrance is a slot in a box wall, roofed by a
lintel at 0.55 m. The width is *derived from the character build
data* (`cat_kit/cat_species.json`), via the zone's fit convention —
a cat's blocking capsule comes from its build, not the kit's
one-size collision:

- Willie: torso 0.44 × scale 0.35 → body diameter **0.154 m**
- Aggie: torso 0.30 × scale 0.25 → body diameter **0.075 m**
- `GAP_W` = **0.115 m** — between them. Aggie slips through; Willie
  takes the long way. The feather toy is in the alcove.

`PvKBasement.fit_capsule_for(cat)` / `apply_fit_capsule(cat)`
implement the convention; the tests assert the derivation and the
physical result for both cats.

## Objectives (`objectives.json`)

- **Clear the labyrinth heart** — defeat the Alpha Rat (10 HP, HP
  bar) and its den pack at the maze centre.
- **Find the 3 lost toys** — ball (west floor), mouse toy (top
  shelf, north), feather (behind the Aggie gap).
- **Unspooked** (optional) — reach the heart without hissing.

State is exposed via `get_objectives()` / `objective_done(id)` and
the signals `objective_completed`, `toy_collected`, `cat_hp_changed`,
`cat_hissed`, `cat_respawned`.

## The dangers

**Rats** (`rat.gd`, `PvKRat`) — CharacterBody3D pack animals in the
PvKMouse model idiom, scaled 0.22 (alpha 0.34, cat-sized). Brain:
wander near den → chase inside 4.5 m → bite on contact (1 dmg,
alpha 2, 0.9 s cooldown) → **flee when alone at 1 HP** (packmates
within 3 m keep a hurt rat brave). Contract: `take_hit(damage,
from_pos)` (flash, knockback, death flop), `bite` / `died` /
`hp_changed` signals, `startle(t)` (hiss fallout).

**Spiders** (`spider.gd`, `PvKSpider`) — hang under two shelf boards.
A cat passing within 1.05 m wakes one: it drops on its thread, bites
once, scurries back up, cools down 5 s. 1 HP. `force_retreat()` is
the hiss side effect.

**Ghosts** (`ghost.gd`, `PvKGhost`) — see provenance below. They
drift slowly between choke points (tunnel mouths, the gap approach,
passages), phasing through boxes — but they are **solid to the cat**
(an AnimatableBody3D capsule), and in a passage they shadow a near
cat's line to hold the block. Tuning:

| Knob | Value |
|---|---|
| Drift / shadow speed | 0.32 / 0.55 m/s |
| Contact radius | 0.60 m (centre distance) |
| Contact → hiss | 1.0 s sustained |
| Hiss length (control lock) | 1.5 s |
| After a hiss | ghost yields (rises, fades, unblocks) 3.2 s |
| Hiss cooldown per ghost | 8.0 s (no hiss-spam) |
| Hiss fallout radius | 4.0 m — rats `startle`, spiders `force_retreat` |

Ghosts have **no `take_hit` and no damage, ever**: paw strikes pass
through them, and they cannot cost the cat a single hit point.
Counter-play is routing and baiting (their drift is slow; draw one
off a choke and slip by) — and Aggie's small capsule edges past
where Willie gets held.

**The hiss** — when a ghost's contact timer fills, the zone calls
`cat.hiss()`: full Halloween arch (spine up, head low, tail puffed)
+ synthesized hiss audio (`hiss_audio.gd`, band-swept noise, the
MeowAudio approach) + ~1.5 s control lock. *Seam:* the foundation
lane is adding `hiss()` to PvKCat itself; the zone prefers it via
`has_method()`. Until it lands, the standalone scene spawns
`PvKHissCat` (`hiss_cat.gd`), a kit-cat subclass providing the same
contract — it retires at integration.

## Ghost design provenance (GTA Fredericton)

Per Daniel's direction, the ghosts reuse the "crazy floating people"
of GTA Fredericton's **Red mode**:

- `scripts/world/red_visions.gd` — RedVisions: fake walkers that
  sprout while the Red mood class is up. Unshaded figures in wrong
  colours (magenta `Color(0.95, 0.15, 0.75)`, acid green, cyan,
  yellow), big sphere head (r 0.22 @ y 1.72), torso a shade lighter,
  **one** dark leg, one arm stuck up, some floating **upside down**
  (`rotation.z = PI`), sideways drift, slow spin (0.45 rad/s), a
  wide bob, hovering off the ground, no collision, harming nothing.
- `scripts/systems/mood.gd` — `CLASS_RED`, the hallucinogen profile:
  hue 0.82, warp 1.0, tint `Color(1.15, 0.62, 1.25)`.

The basement ghosts mirror that figure in the cat kit's
smooth-primitive idiom (ellipsoids instead of boxes), paler and
translucent (alpha 0.55), tints leaning red/magenta after the Red
profile. What changed for the basement: they keep the drift, spin,
bob and wrongness — and gain a collision capsule, choke-point
manners, and the hiss. In GTA they were hallucinations that
couldn't touch you. Here they're hallucinations that can — just
never with damage.

## Set dressing that matters

NW corner: **the litter box**. Beside it, on the floor — not in it,
never in it — is a small brown lump, node name `TheGift`. Willie
knows what he did. Also: furnace + water heater (east wall),
overhead pipes, entry stairs with a door at the top, and three
dangling bulbs that sway.

## Files

- `basement.gd` / `basement.tscn` — builder + zone controller
- `rat.gd`, `spider.gd`, `ghost.gd`, `toy.gd` — the cast
- `hiss_cat.gd`, `hiss_audio.gd` — the hiss (standalone seam + synth)
- `objectives.json` — objective declarations for the HUD
- `tests_basement.gd` / `tests_basement.tscn` — headless test suite
- `tools_basement_shots.gd` / `.tscn` — the standing-shot pass
