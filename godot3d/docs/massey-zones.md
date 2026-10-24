# Willie and Aggie — the Massey zones contract

**Iteration 2 design (Daniel, 2026-10-24).** The game diverges from
the GTA Fredericton implementation and becomes the world of **255
Massey Street from the cats' perspective**: one house, four zones,
connected in-game. Willie and Aggie play; the house is the hub.

| Zone | What lives there |
|---|---|
| **Outside** — the yard + Massey Street frontage | The shipped backyard: mice to catch, trees to climb, squirrels to chase up them, a bird feeder with a constant stream of birds to ambush from the bushes — and the road, where cars actively try to hit a cat crossing (honk = telegraph; the parked silver Corolla is a safe island). |
| **Ground floor** — the hub | Kitchen + living room at cat scale. The open kitchen drawer (Aggie's), Willie's water bowl, the sofa, the scratch post he ignores. Stairs down, hatch up, front door out. Respawning after a faint lands here. |
| **Basement** — the labyrinth | A secret tunnel / maze of old boxes and shelves: shelf platforms to climb, rat packs, spiders that drop from the ceiling, an Alpha Rat at the heart, an Aggie-only gap (she's half his size), the litter box with Willie's "gift" beside it — and ghosts: floating people who cannot hurt the cat but block passages and force a hiss. |
| **Attic** — raccoon country | A family of raccoons: a Mother boss with a telegraphed charge and an HP bar, three kits that nip and scatter, and the window perch as the zone's reward spot. |

This document is the **contract the zone lanes build against**. The
foundation (branch `massey-foundation`) owns everything in §1–§5;
zone lanes own their zone's interior content only.

---

## 1. The house is one spec — `house/house_spec.gd`

All geometry derives from `HouseSpec`. **Never hardcode a house
dimension in a zone scene** — read it from the spec, so a change
there moves every zone together.

House-local frame: origin at the centre of the footprint, on the
ground floor's top surface. +X east, +Z south (toward the yard and
the street). A zone scene's root sits at `HouseSpec.zone_origin(id)`;
inside a zone, local (x, z) are house-local and local y is height
above that zone's own floor.

### Shared dimensions (the published contract)

| What | Value |
|---|---|
| Footprint | 17.0 m (x) × 9.6 m (z), walls 0.3 m |
| Interior stack world position | z = **−200** (the yard is untouched at the origin) |
| Floor Y (world) | basement **−2.6** · ground **0.0** · attic **+2.9** |
| Ceiling heights | basement 2.4 · ground 2.7 · attic 2.3 (+ roof ridge) |
| Slab thickness | 0.25 |
| Front door | x = **2.5** (matches the yard porch), 1.1 wide, 2.15 high |
| Stairwell opening | Rect2(−7.7, −4.3, 2.4, 2.6), centre **(−6.5, −3.0)** |
| Attic hatch opening | Rect2(5.9, −3.6, 1.2, 1.2), centre **(6.5, −3.0)** |
| Kitchen / living split | divider at x = −1.8, doorway gap z ∈ [−0.6, 0.6] |
| The drawer | (−5.2, ·, −4.15), its top is a sibling lounge spot (y 0.50) |
| Willie's water bowl | (−2.35, ·, 2.7) |
| The sofa (the LAP seat) | (4.8, ·, −3.85), seat top y 0.60 — the occupants' seated/lap state targets this spot; keep it clear of other props |

Zone origins: outside (0, 0, 0) · ground floor (0, 0, −200) ·
basement (0, −2.6, −200) · attic (0, +2.9, −200). The interior stack
is vertically honest — stairs and hatch line up in world space.

### Entry points (names are contract — do not rename)

| Zone | Entries (local pos, facing) |
|---|---|
| outside | `EntryFrontDoor` (2.5, 0.30, −8.45), faces the yard |
| ground_floor | `EntryFrontDoor` (2.5, 0, 3.55) · `EntryStairsTop` (−6.5, 0, −1.55) · `EntryHatchBottom` (6.5, 0, −1.7) |
| basement | `EntryStairs` (−6.5, 0, −1.55) |
| attic | `EntryHatch` (6.5, 0, −1.7) |

### Connector volumes (walk-in triggers, local to each zone)

outside door → ground `EntryFrontDoor`; ground door → outside;
ground stairwell → basement `EntryStairs`; basement stairs → ground
`EntryStairsTop`; ground hatch → attic `EntryHatch`; attic hatch →
ground `EntryHatchBottom`. Volumes/sizes live in
`HouseSpec.connectors(zone)`. Every entry stands clear of its own
zone's volumes, and travel has a 1.2 s grace, so arrivals never
bounce back. The street lives entirely inside the outside zone —
**no** hub connector for it.

---

## 2. Zone scene contract

- Location: `godot3d/zones/<zone_id>/<zone_id>.tscn` with a root
  script extending `zones/zone_root.gd` (`ZoneRoot`). Outside is the
  exception: it is `main.tscn` itself.
- The root's `_build()` constructs the zone's content **in code**
  (the project's idiom: procedural, cached materials/meshes via
  `HouseBuilder.kit(self)`), inside the shell from
  `HouseSpec.shell_cfg(zone)` / your own run of
  `HouseBuilder.build_shell()`. Basement and attic ship as foundation
  **stubs** (entry room + shell) — replace the stub dressing freely,
  keep the shell/entry/connector contract.
- `ZoneRoot` already provides: entry nodes built from the spec,
  connector volumes built from the spec, `get_entry(name)`,
  `get_lounge_spots()` / `get_wander_rect()` (global; the sibling AI
  rebinds to these on every travel — your zone must return sane
  spots inside its own walkable area).
- Zone roots are instanced by `main.gd` at `HouseSpec.zone_origin`.
  Do not add your own copy of the cats, the duo system, the camera,
  HUD, lights rig (WorldEnvironment), or the zone manager — the
  foundation owns all of those. A zone may add a few **local**
  OmniLight3D (shadows OFF) for interior mood.
- Both cats must fit your geometry: Willie is 0.35 scale (~0.85 m
  long, capsule r 0.15 h 0.46 at scale 1 → his body is ~0.16 m wide);
  doorways ≥ 0.6 m wide, cat shelves/ledges reachable by a 0.8 m
  jump (see §4). An "Aggie-only" gap is ~0.35 m wide/high — Willie
  physically cannot fit, Aggie can.

## 3. Enemies — `combat/enemy.gd` (`PvKEnemy`)

One reusable actor for rats, spiders, raccoons, squirrels, birds,
dogs — configure it, don't fork it:

```gdscript
var rat := PvKEnemy.new()
rat.configure({
    "species_id": "rat", "max_hp": 30.0, "damage": 8.0,
    "wander_speed": 1.1, "chase_speed": 3.0,
    "detection_radius": 6.5, "attack_range": 0.55,
    "attack_cooldown": 0.9, "flee_at_frac": 0.25,
    "color": Color(0.35, 0.3, 0.28), "scale": 0.8,
})
add_child(rat) # position it inside your zone
```

- States: `idle → wander → chase → attack` (a lunge; damage lands on
  contact during the lunge, once per lunge, then the attack
  cooldown) and `flee` when HP ≤ `flee_at_frac` × max (0 = never).
- `take_hit(damage, from_position)`: HP loss, knockback away from
  `from_position`, red hit-flash; at 0 HP the enemy falls over,
  fades, emits `died(enemy)`, and calls
  `Objectives.register_kill(species_id)` for you.
- Damage the enemy deals is a number in its config; what it *means*
  (knockback, launch) comes from the shared profiles in
  `combat/combat_data.gd` (`CombatData.PROFILES`) — notably
  **`vehicle_hit`: 60% of the cat's max HP, `launch: true`** (the
  outside lane's cars call `cat.take_damage(0, car_pos,
  CombatData.profile("vehicle_hit"))`; their honk is the telegraph,
  and two hits ≈ one of the nine lives).
- The cat's paw hits your enemies automatically: the foundation's
  paw sweep (`CombatDirector`) checks the "enemies" group on every
  player `paw_swiped`, using the paw profile for the current cat
  (mid-pounce the arc is longer). Enemies join the group themselves.
- Visuals: the base builds a simple critter (body/head/eyes/tail)
  from `color`/`scale`. To reskin, subclass and override
  `_build_visual()` — set `visual` and `body_mat` (the flash target)
  and keep node counts low (see §6).
- Enemies target the node in group **`player_cat`** (the duo system
  keeps membership current across character swaps). They only sense
  within `detection_radius` in 3D, so zone separation (200 m) keeps
  them honest — set radii accordingly (≤ ~10 m).

## 4. The zone-facing cat API (`cat_kit/cat.gd`, `PvKCat`)

Both cats expose (zone lanes may rely on all of these):

- `hp` / `max_hp` (Willie 120, Aggie 80 — from `cat_species.json`),
  `health_changed(hp, max_hp)`, `is_fainted`.
- `take_damage(amount, from_position, profile := {}) -> bool` —
  brief invulnerability (0.8 s) + knockback; `profile` may carry
  `damage_frac` and `launch` (see `vehicle_hit`). At HP 0 the cat
  flops, `fainted` fires, and the **game** respawns him/her at the
  ground-floor hub with HP restored and the nine-lives counter
  decremented (flavour — never a game-over). Don't implement your
  own death handling.
- `jump()` — a real jump (apex ≈ 0.8 m for Willie, ≈ 1.0 m for
  Aggie); platforming should be built to a **0.5 m standard ledge**.
- `pounce()` — mid-jump only: the paw strike with a forward lunge
  and ~1.6× paw range. Space = jump / pounce; F or the PAW button =
  ground strike; POUNCE touch button mirrors Space.
- `heal(amount) -> float` — partial heal (returns what actually
  landed). THE heal seam: the occupants' lap petting and the
  outside lane's fish treat both call this. Never un-faints.
- `hiss() -> bool` — the startle state (the basement's ghosts force
  it): full arched-back pose — spine arched up, tail puffed, head
  low — ~**1.5 s control lock**, **no damage**, then back to normal.
  Emits `hissed(cat)` (the audio hook). Call it; don't fake the pose.
- `strike()`, `paw_swiped`, `paw_point()`, `set_lounge(bool)`,
  `anim_state` — unchanged from the duo build. The sibling's brain
  is `duo/sibling_ai.gd`; its lounge spots/wander rect follow the
  zone (see §2), and the outside lane hard-bounds it from the road.

## 5. Objectives — `objectives/objectives.gd` (`PvKObjectives`)

One registry (group `objectives`), one HUD panel (Tab or the
OBJECTIVES button toggles it; items are grouped by zone with ☐/☑).

Declare yours from your zone's `_ready` (or first build):

```gdscript
var obj := get_tree().get_first_node_in_group("objectives")
obj.declare("basement:alpha_rat", "basement", "Defeat the Alpha Rat", 1, "alpha_rat")
obj.declare("attic:raccoons", "attic", "Run off the raccoon family", 4, "raccoon")
```

- `declare(id, zone, title, target := 1, kill_species := "")` — with
  a `kill_species`, every `PvKEnemy` death with that `species_id`
  advances it automatically (foundation wires the signal path).
- `set_progress(id, n)` / `add_progress(id, n)` for non-kill goals.
- IDs are namespaced `"<zone>:<thing>"`. The foundation ships
  `outside:mice` wired to the yard game; zones add theirs.
- Kill counting also lands in `Objectives.total_kills` if a zone
  wants a "vicious animals defeated" flavour line.

### Score events (reserved for the occupants lane)

The registry also owns the game **score**: `Objectives.score`,
advanced ONLY through named events —
`add_score("ankle_attack")` (points default from the table;
`add_score(name, points)` overrides). Reserved event names:

| Event | Default points | Emitter |
|---|---|---|
| `ankle_attack` | 50 | occupants (a paw lands on an ankle) |
| `underfoot` | 25 | occupants (cat darts in front of a walker) |
| `trip_hazard` | 100 | occupants (the stumble bonus) |
| `lap_purr` | 10 | occupants (per lap-petting tick; heals via `cat.heal()`) |

Emission is `get_tree().call_group("objectives", "add_score",
"ankle_attack")` or a direct call on the registry node. The
objectives HUD shows the running score; zones may add their own
event names to this table in their PRs (append, never rename).

## 6. Lighting & performance budgets (the web build is the target)

- GL Compatibility renderer; the whole game must stay web-exportable
  at a smooth frame rate on modest hardware.
- Per zone: ≤ ~400 visible nodes, ≤ ~40 physics bodies (statics
  merged into ONE `StaticBody3D` per zone with many shapes — the
  builder does this), ≤ 4 local `OmniLight3D`, **no** local light
  shadows, **no** custom shaders, **no** per-frame allocations in
  hot paths. Shared/cached materials and meshes only (the builder
  kit caches by colour/size — use it).
- Enemies: ≤ 12 live per zone. Ambient critter dressing should be
  `Node3D` visuals, not physics actors.
- Textures: none — flat colour is the house style (and GTA's).

## 7. Reuse in GTA Fredericton (documentation-level mapping)

This house model is the playground for improving the house model —
built to be liftable into GTA Fredericton later (TODO #97's Massey
house among them). How it maps onto GTA's interiors approach:

- **Cell instancing:** GTA instances interior cells at a fixed cell
  height (`CELL_Y`, interiors as offset copies of a fitted room).
  The Massey stack is the same idea with a *vertical* offset per
  floor (`HouseSpec.FLOOR_Y` + one shared (x, z) footprint) instead
  of GTA's horizontal cell grid. Lifting = take `HouseSpec`'s
  footprint/room tables, register one cell per floor at the target
  `CELL_Y` band, and let GTA's cell manager own placement.
- **FITTED-style registration:** GTA registers a fitted interior as
  data (a FITTED dict entry + SPECS + a hand-built `build()` branch
  in `landmark_interiors.gd` / `interior_cells.gd`). The Massey
  equivalent is already data-shaped: `HouseSpec` (footprint, rooms,
  openings) + `HouseBuilder.build_shell()/build_ground_floor()` are
  exactly the "spec + builder branch" pair a FITTED entry needs —
  port the spec tables, re-implement the builder calls against
  GTA's `_box/_mat` helpers (same idiom, it came from there).
- **Scale conventions:** the cats here follow GTA's
  `scripts/world/wildlife.gd` actor conventions (unit ~1 m frame,
  forward −Z, Body as child 0, root scale from data) because the kit
  cat was built to them; the house is real-metre scale throughout
  (door 2.15 m, counters 0.85 m), so room geometry transfers 1:1
  into GTA's world units with no rescale. GTA steps its wildlife
  centrally (`Wildlife._step()`) rather than per-actor physics —
  the zone/enemy state machines here are deliberately simple enough
  to re-host in that step loop if the cats move in as residents.
- **What does NOT transfer:** the PvK zone manager/teleport fade
  (GTA streams its world), the objectives HUD (GTA has its own UI
  idiom), and any PvK-only flavour (nine lives). The transferable
  assets are the spec tables, the room builders, and the cats.

## 8. Names

The cats are **Willie** and **Aggie**; the game is **"Willie and
Aggie"**. New text, data and UI use those names. (Pre-existing files
keep their current names until the coordinator's single rename pass
at integration — do not do piecemeal renames in a zone branch.)


---

## 9. THE MODULE CONTRACT — 255 Massey as a drop-in module

Daniel's direction (2026-10-24): *"I want to be able to develop
this as a separate, drop in module for GTA Fredericton — keep the
framework and we'll iterate here on the fine inner and outer
details of 255 Massey St."*

So this game is the module's **first host and test bed**. The
module is the Massey detail itself — floors, rooms, props,
occupants, cats, encounters — authored ONCE as data + builders
against a host interface, renderable in PvK today and in GTA
Fredericton's interiors system when the re-fit happens at
integration. This section is the contract that makes that true;
§1–§8 above remain the PvK-host realization rules.

### 9.1 The canonical frame is GTA's real house

The canon is not PvK's stage set. From GTA's `god_mode.gd`,
`landmark_interiors.gd` (FITTED) and `interior_cells.gd` (SPECS),
via the 2026-10-24 mergeability eval:

| Fact | Canonical (GTA) | PvK host realization |
|---|---|---|
| Footprint | **11.79 m (x) × 15.64 m (z)**, OSM, centre (−99.75, 2307.51) | 17.0 × 9.6 m, house-local |
| Long axis | **z** | x (transposed) |
| Street face | **north** (Massey St) | — (yard diorama) |
| Entry door | **west** wall, under the carport | south (yard) face, x 2.5 |
| Fitted interior | 10.8 × 14.6 m cell, wall_h 3.1 | three honest floor shells |
| Instancing | cells at **CELL_Y 300**, LINKED floors **+40/storey** | stack at world z −200, real floor heights |
| Ground rooms | living north, kitchen/dining, bedroom SE | kitchen west ‖ living east |
| Basement/attic | **do not exist in GTA yet** | stub shells (§2) → zone lanes |

Layout therefore travels as **anchors**, never as host metres:
`(u, v)` fractions of footprint — u west→east, v north→south —
plus a floor id. `HouseSpec.ANCHORS` holds them;
`HouseSpec.anchor(name, "pvk" | "gta")` resolves a named anchor to
a host-local Vector3. Anchor fractions are the SAME in every host;
walls and doors are host realizations (the entry function lives on
GTA's west/carport face and on PvK's south/yard face — same anchor,
different wall). New layout data from any lane should be recorded
as anchors (or as fractions of a room rect) wherever practical —
absolute PvK metres are the one avoidable re-fit cost.

### 9.2 The mapping table (foundation anchors)

PvK local (x, z) ↔ (u, v) ↔ GTA cell-local (x, z), computed by
`HouseSpec.anchor_uv / uv_to_pvk / uv_to_gta`. GTA cell-local is
centred on the fitted 10.8 × 14.6 cell; floors map to
`HouseSpec.GTA_FLOOR_Y` (ground 300, attic 340 = the proven
above-cell LINKED pattern, basement 260 = below-grade LINKED,
**expressible but unverified in GTA**).

| Anchor | PvK local | (u, v) | GTA cell-local |
|---|---|---|---|
| front door | (2.5, +4.8 wall) | (0.647, 1.000) | (1.59, 7.30) — realized on the west wall |
| stairwell | (−6.5, −3.0) | (0.118, 0.188) | (−4.13, −4.56) |
| hatch | (6.5, −3.0) | (0.882, 0.188) | (4.13, −4.56) |
| kitchen centre | (−5.15, 0) | (0.197, 0.500) | (−3.27, 0.00) |
| living centre | (3.35, 0) | (0.697, 0.500) | (2.13, 0.00) |
| the drawer | (−5.2, −4.15) | (0.194, 0.068) | (−3.30, −6.31) |
| water bowl | (−2.35, 2.7) | (0.362, 0.781) | (−1.49, 4.10) |
| sofa / lap seat | (4.8, −3.85) | (0.782, 0.099) | (3.05, −5.85) |
| scratch post | (7.9, 0.9) | (0.965, 0.594) | (5.02, 1.37) |
| attic perch | (7.3, −0.6) | (0.929, 0.438) | (4.63, −0.91) |

Vertical mapping: PvK floor heights are honest (−2.6 / 0 / +2.9)
because PvK stacks real storeys; in GTA each floor is its own
cell at its `GTA_FLOOR_Y` with the cell's own wall_h — the module
carries floor *content* and relative heights of furniture, the
host carries the storey placement.

### 9.3 Host interface — what a host provides, what the module provides

A host game that wants 255 Massey must provide:

1. **A cell/shell registration** — a way to instance a floor's
   content at a host transform (GTA: FITTED/SPECS registration +
   LINKED cells; PvK: a ZoneRoot scene at `HouseSpec.zone_origin`).
2. **Builder primitives in the host idiom** — `_box/_mat`-style
   helpers (GTA's interior kit; PvK: `HouseBuilder.Kit`). Module
   builders are written against the *pattern* (flat-colour boxes,
   cached materials, one static body per room/floor), and are
   re-implemented per host — builders are cheap, layout is canon.
3. **Actor spawn + the cat API** — a player-cat actor exposing the
   §4 surface (`take_damage`, `heal`, `hiss`, `strike/pounce`,
   HP) or an adapter for it (GTA: MasseyCat/cat mode; PvK: PvKCat).
4. **Sinks** — damage numbers read `CombatData` profiles; kills,
   objectives and score events land in a registry with the §5
   names (GTA: its own objective/balance systems read the same
   tables as data).
5. **Scale discipline** — real-world metres; Willie 0.35, Aggie
   0.25; humans on the 1.70 m body-proportions table. Identical
   on both sides already — do not fork these numbers.

The module provides, as data first and code second:

- The floor/room/prop **spec tables** (HouseSpec + ANCHORS) and
  the per-floor builders against (2).
- The **encounter designs + numbers**: CombatData profiles,
  enemy configs per species, boss patterns (attic), the ghost
  block/hiss rule (basement), the road/vehicle tuning (outside).
- The **cat + occupant rule data**: species JSON (coats, scales,
  provocation numbers), ankle/underfoot/lap tuning + score table.
- **Objectives text + ids** in the §5 shape.

### 9.4 Module contents inventory (as of this PR)

| Contents | State | Where |
|---|---|---|
| Ground floor (kitchen/living, drawer, bowl, sofa) | built (PvK host) | house_builder.gd |
| Basement shell + entry room | stub; lane content in flight | zones/basement |
| Attic shell + perch block | stub; lane content in flight | zones/attic |
| Outside yard + street frontage | existing yard; lane in flight | main.tscn, zones/outside (lane) |
| Cats (Willie/Aggie: data, controller, health, hiss) | built (PvK host) | cat_kit/, duo/ |
| Occupants (Daniel + Folasade NPCs + interactions) | lane in flight, contract §4/§5 | occupants lane |
| Encounters (rats/spiders/ghosts; raccoon family; squirrels/birds/cars) | enemy base built; species are lane content | combat/, zone lanes |
| Damage/score/objective tables | built, host-agnostic data | combat_data.gd, objectives.gd |

### 9.5 What is NOT module-shaped yet (the honest re-fit list)

- PvK's zone travel (ZoneManager/ZoneConnector) is a PvK host
  mechanism — GTA uses its door/cell streaming instead. The
  *pairing data* (which entry leads where) is module content;
  the mechanism is not.
- PvKCat as a controller (touch, duo sibling, nine lives) is
  PvK's game machinery. The module surface is the §4 API + the
  species data; GTA's MasseyCat already proves the data ports.
- The PvK ground floor's exact furniture placement is in PvK
  metres inside house_builder.gd; anchors (§9.2) are the
  portable form, and new placement work should go anchor-first.
