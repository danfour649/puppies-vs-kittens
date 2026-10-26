# DROP-IN — consuming the 255 Massey module

The module is **255 Massey Street as a drop-in package**: the
house (floors, rooms, props, occupants, encounters), the two
cats, and the **cat start** — character select → spawn as Willie
or Aggie inside the ground floor with the house's systems live.
It implements the contract in `docs/massey-zones.md` §9. This
file is the consumption contract for a host — written for the
GTA Fredericton side (TODO #108, eighth row: the cat start), with
the PvK game (`main.gd`) as the working reference host.

Machine-readable index: `module/module_manifest.gd`
(`MasseyModuleManifest`) — floors, travel pairings, anchors,
canonical frame, host requirements, contents inventory, all
**derived from `HouseSpec` at call time**. The manifest forks
nothing; if a number matters, it lives in `house/house_spec.gd`.

---

## 1. What to copy

The module package (PvK realization, `godot3d/` paths):

| Path | What it is |
|---|---|
| `module/` | The module root (`massey_module.gd`), this file, the manifest |
| `house/` | `HouseSpec` (the spec tables + anchors + GTA constants) and `HouseBuilder` (the PvK builder kit) |
| `zones/` | The four zone scenes + `zone_root.gd` / `zone_manager.gd` / `zone_connector.gd` |
| `cat_kit/` | The cats: `cat.gd` (PvKCat) + `cat_species.json` — **the single source for appearance/species data** |
| `duo/` | Duo system: sibling AI, character select, provocation, meows, character data |
| `combat/` | Enemy base + `CombatData` damage profiles |
| `objectives/` | The objectives/score registry + HUD |
| `occupants/` | Daniel + Folasade NPCs, their system, interaction tuning data |
| `docs/massey-zones.md` | The contract (§1–§9) this package implements |

Do NOT copy (PvK *game* machinery, not module content):
`main.gd` / `main.tscn` (the reference host itself), `mouse.gd`,
`joystick_3d.gd`, `touch_controls_3d.gd`, `tools/`, screenshots.
`tests/test_module.*` + `tests/module_host.gd` are worth taking
as the reference proof: an empty host playing the cat start.

For a GTA host, per §9.3 item 2 the per-floor **builders are
re-implemented in the host idiom** (GTA's `_box`/`_mat` interior
kit) against the spec tables — layout is canon, builders are
cheap. The PvK copies above are the reference realization.

## 2. The host interface (§9.3, exact names)

A PvK-idiom host provides this surface; `MasseyModule`,
`DuoSystem` and `ZoneManager` code against exactly these names
(the reference host stub is `tests/module_host.gd`):

| Surface | Kind | Semantics |
|---|---|---|
| `cat` | var (PvKCat) | The player-cat actor, spawned by the HOST (§9.3 item 3), exposing the §4 API (`take_damage`, `heal`, `hiss`, `strike`/`pounce`, HP). The module's `choose_cat` may replace it (duo swap assigns `host.cat`). |
| `duo` | var | Filled by `MasseyModule.setup()`; the host reads it (input lock, sibling). |
| `mice` | var (Array) | The host's yard-game mice; the duo rewires their `cat` on a swap. `[]` in a house-only host. |
| `catch_radius` | var (float) | Written by the duo's provoked buff (0.42 base / 0.80 provoked). |
| `_on_paw_swiped()` | method | The paw-strike SINK (§9.3 item 4): the host's catch/combat resolution. The duo reconnects it to whichever cat is the player. A minimal host may no-op it. |
| `on_zone_changed(zone_id)` | method | The zone hook: host concerns (camera snap in PvK) **plus** the sibling rebind — `duo.relocate_sibling(module.zone_root(zone_id))`. |
| `get_entry(name)` / `get_lounge_spots()` / `get_wander_rect()` | methods | The host IS the outside zone root (§2 API). The module mounts the outside `EntryFrontDoor` node and the front-door `ZoneConnector` onto the host. |

Assembly sequence (from `main.gd`, the reference host):

```gdscript
module = MasseyModule.new()
add_child(module)
module.setup(self)            # duo + zones + ZoneManager + registry
objectives = module.objectives
objectives.declare(...)       # host's own objectives (PvK: outside:mice)
module.build_occupants()      # Daniel + Folasade move into the hub
# ... later, the start:
module.choose_cat("willie")   # or "aggie": select + spawn in the ground floor
```

`choose_cat(id)` is the **cat start**: it runs the duo swap (the
unchosen cat becomes the sibling) and instantly travels both
cats to the ground floor's `EntryFrontDoor` — player at the
entry, sibling beside them, rebound to the hub's lounge spots.
`module.start_pending()` reports whether a choice is outstanding.

## 3. Canonical constants a host passes (§9.1)

From `HouseSpec` (GTA frame — the canon; PvK's 17.0 × 9.6 shell
is only the first host realization):

| Constant | Value |
|---|---|
| `GTA_FOOTPRINT` | 11.79 m (x) × 15.64 m (z), OSM |
| `GTA_CENTER` | (−99.75, 2307.51) world (x, z) |
| `GTA_INTERIOR` | fitted cell 10.8 × 14.6 m |
| `GTA_WALL_H` | 3.1 |
| `GTA_CELL_Y` | 300 |
| `GTA_LINKED_DY` | +40 per storey |
| `GTA_FLOOR_Y` | basement 260 · ground 300 · attic 340 |
| `GTA_DOOR_WALL` | west (under the carport) |
| `GTA_STREET_SIDE` | north (Massey St) |

Layout travels as anchors: `HouseSpec.ANCHORS` (name → {u, v,
floor}); resolve with `HouseSpec.anchor(name, "pvk" | "gta")`,
`anchor_uv` / `uv_to_pvk` / `uv_to_gta`. The §9.2 mapping table
is locked by asserts in `tests/test_module.gd` (re-verified
2026-10-25; the basement Aggie-gap row is amended — see §9.6).

Caveat carried from §9.2: the basement's GTA cell at
`GTA_FLOOR_Y` 260 is the below-grade LINKED pattern —
**expressible in data, not yet verified in GTA**. GTA has no
basement or attic yet; both floors land as LINKED cells.

## 4. Known deltas vs GTA's current `massey_cat.gd` lift

GTA's `scripts/npc/massey_cat.gd` already carries a data lift of
the cats (coats/scales/provocation as constants). Against the
module as it now stands:

- **Appearance data — read from `cat_kit`, never from a lift.**
  The module references species/coat data live
  (`cat_kit/cat_species.json`, `duo/` character data); no coat
  values are quoted in the module or in §9. Per Daniel's ruling
  (2026-10-25) Willie's canonical appearance is his recorded
  spec — ginger **#E8AF54**, **dark eyes**, tail **white with
  ginger rear/underside** — and Aggie is a **tortoiseshell**
  (tortie; Daniel confirmed the coat name on 2026-10-26,
  correcting the calico word in this 2026-10-25 note). The
  photo-tuned values (#C97020/#975417, green-gold eyes, ringed
  tail) that an older lift may carry are **superseded**; the
  canonical values live in `cat_kit` (revert owned by the
  burn-down lane, with spec-lock assertions). Any re-lift into
  GTA must take the data from `cat_kit` at integration time.
- **The house itself is new.** `massey_cat.gd` lifts the cats
  only; the module adds the full house (four floors/zones,
  occupants, encounters, objectives) plus the start flow.
- **HP is a module-side expectation.** The §4 cat API includes
  `take_damage`/`heal`/HP (Willie 120, Aggie 80); GTA's cats
  currently have no HP system, so a GTA host needs the §9.3
  item-3 adapter (or PvKCat itself) for damage-bearing content.
- **Layout frame differs.** GTA's Massey is the real OSM
  footprint with its fitted ground-floor cell; the module's
  ground floor is the PvK realization (kitchen west ‖ living
  east). Anchors carry the layout intent across; room tables in
  `HouseSpec` are the portable form (§9.5).
- **Occupants depth differs.** GTA's Folasade (god mode) is a
  deeper NPC than the module's hub occupants; the module's
  occupant *data* (station pattern, interaction/score table,
  §5) is the portable part — the actors re-host.
- **Not module content (§9.5):** the PvKCat controller (touch,
  duo sibling, nine lives), the zone-travel *mechanism* (the
  pairing data ships in the manifest), and PvK's objectives HUD
  idiom. GTA re-hosts all three in its own systems.

## 5. Verification

`tests/test_module.tscn` (64 checks at this writing): §9.2
table recomputed from source constants; an empty host assembles
the module, plays both cat starts, travels every floor, trips a
real connector, and lands an occupant score event — with no
`main.tscn` anywhere in the tree.
