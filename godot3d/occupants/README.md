# Occupants — the humans of 255 Massey (Willie and Aggie)

Daniel's spec: the house's occupants take GTA Fredericton's main
character as the example, run in NPC mode, and are part of the game —
you score extra points for attacking their ankles or running in front
of them, and you can chill on their lap and be petted, which **heals
hit points**.

This folder is self-contained: `OccupantSystem` + `MasseyOccupant`
actors that the coordinator drops into the real ground-floor hub at
integration. A demo/test room (`occupants_room.tscn`) stands in for
the hub here.

## The occupants

Two residents, built as smooth primitives on GTA Fredericton's human
proportions (~1.72 m standing — the cats are 0.35 / 0.25, and the
size contrast is the game):

- **Daniel** — GTA player-character default look (skin swatch 0,
  dark hair, blue shirt, dark pants).
- **Folasade** — GTA resident NPC look: skin `Color(0.34, 0.20,
  0.13)`, near-black long hair, Ankara gown (top `Color(0.85, 0.42,
  0.08)`, skirt `Color(0.78, 0.33, 0.05)`), gold accents.

### Sources mirrored (GTA Fredericton, /mnt/folaDriveB/vscode/GTAfredericton)

- `scripts/body_proportions.gd` — segment layout: total 1.70 m,
  HEAD_Y 1.565, HEAD_RADIUS 0.115, SHOULDER_Y 1.38 / SHOULDER_X
  0.24, HIP_Y 0.88 / HIP_X 0.125, KNEE_Y 0.47, ANKLE_Y 0.10,
  UPPER_ARM 0.30, FORE_ARM 0.27, THIGH 0.41, SHIN 0.37. The
  occupant builder uses the same numbers (scaled to 1.72 m).
- `scripts/npc/pedestrian.gd` (`_build_body`) — head sphere + torso
  + pivot limbs (shoulder/elbow, hip/knee) construction idiom.
- `scripts/npc/folasade.gd` — SKIN / HAIR / GOLD constants, the
  Ankara gown outfit entry, waypoint-wander resident behaviour
  (WALK_SPEED 0.75 — occupants here walk at 0.9).
- `scripts/player_appearance.gd` — SKIN_SWATCHES[0] for Daniel.

PvK-side idiom (spheres/capsules, `_ell`/`_mat` helpers, poses as
pure functions of state + time) follows `cat_kit/cat.gd`.

## NPC mode

Each occupant loops a station routine: kitchen counter (stand),
hallway (pass), couch (**sit** — the lap state), porch (stand).
Stations are data: `{pos, yaw, action: "stand"|"sit", dwell}`.
Walking is waypoint steering at 0.9 m/s with a turn-rate limit and a
polite sidestep when a cat is directly ahead — the cat's job is to
get in the way anyway. Sitting is long (16 s in the demo room);
standing up is telegraphed (a lean + `about_to_stand`, 0.8 s) so a
cat on the lap is always put down safely first.

## Cat interactions

All scoring flows through one signal on `OccupantSystem`:

```gdscript
signal score_event(event_name: String, points: int, pos: Vector3)
```

plus floating `+N` popups at the event position, a running
`total_score`, and `event_counts` — the foundation HUD consumes the
signal; nothing here draws HUD chrome of its own.

| event         | points | trigger |
|---------------|--------|---------|
| `ankle_attack`| +25    | paw strike lands within 0.5 m of a standing/walking occupant's ankle. Reaction: hop + foot shake + "!" pop. Cooldown 10 s per occupant. |
| `ankle_shoo`  | +10    | same strike against a *seated* occupant: the cat is shooed (gentle pushback) and that occupant's lap locks out briefly. |
| `underfoot`   | +15    | the player cat, moving, genuinely **crosses** the occupant's forward path (lateral sign flip while 0.15–1.25 m ahead, \|lateral\| < 0.38). Beside/behind movement scores nothing. Cooldown 6 s per occupant. |
| `trip_hazard` | +50    | a dead-centre cut-off (crossing at < 0.6 m ahead) with a 50% stumble roll: arms windmill, occupant stays upright, walking pauses. |
| `lap_purr`    | +5     | per 4 s of lap petting, capped at +20 per lap session (no farming). |

### The lap (healing)

While an occupant is seated, their lap spot is active (a `LapSpot`
marker on the thighs; the system pins the cat to it kinematically —
there is deliberately no physics platform, an early one overlapped
the occupant's own capsule and depenetration shoved them around).
`try_mount_lap(cat)`:

- cat settles into its lounge pose on the lap; the occupant pets it
  (animated stroking hand) and a synth purr plays (see
  `purr_audio.gd` — a 2 s seamless loop: ~58 Hz rumble pulsed at
  21 Hz, no audio assets).
- **Healing:** +10% of max HP per second to full, delivered through
  the heal seam below.
- The cat is **safe** on the lap (`cat.get_meta("on_lap") == true`).
- Lap ends when: the cat jumps down (`release_cat(cat)` / the cat
  leaves the spot), the occupant stands (cat is placed on the floor
  in front of the couch *before* the rise finishes), or the cat
  strikes from the lap — session over, cat put down, no score, that
  occupant's lap locks out for 20 s.

### Heal seam (shared contract)

The lap heals through the first available of:

1. `cat.heal(amount)` — the foundation HP system's method, when it
   lands on `PvKCat`;
2. a `CatHealth` child node (`cat_health.gd`, shipped here as the
   interim component: `hp`, `max_hp`, `heal(amount)`, `damage(a)`);
3. a writable `hp` property on the cat (clamped to `max_hp` or 100).

Max HP is read the same way (`max_hp` property / `CatHealth.max_hp`,
default 100).

## Files

- `occupant.gd` — `MasseyOccupant` (CharacterBody3D): build,
  routine state machine, poses (walk/idle/seated/petting/hop/
  stumble/shoo), lap spot, debug seams for tests
  (`place_at`, `set_routine`, `end_dwell_now`).
- `occupant_system.gd` — `OccupantSystem`: interaction detection,
  score events + popups, lap sessions, purr voice.
- `purr_audio.gd` — procedural purr stream (mirrors
  `duo/meow_audio.gd`'s approach).
- `cat_health.gd` — interim HP component (see heal seam).
- `occupants_room.gd` / `.tscn` — stand-in ground floor: counter,
  couch, porch step, both occupants on routines, Willie spawned and
  wired as the player cat.
- `tests_occupants.gd` / `.tscn` — headless test suite:
  `godot --headless --path godot3d res://occupants/tests_occupants.tscn`
- `tools_occupants_shots.gd` / `.tscn` — Xvfb shot pass into
  `res://screenshots/occupants/` (ankle_attack, lap_petting,
  path_cross).
- `objectives.json` — zone objectives for the foundation HUD.

## Tuning

Ankle +25 (cd 10 s) · shoo +10 · underfoot +15 (cd 6 s) ·
trip_hazard +50 (50% on a close crossing) · lap regen 10%/s ·
purr tick +5 / 4 s, session cap +20 · lap lockout 20 s ·
occupant walk 0.9 m/s · stumble/hop pause ~0.5–0.9 s.
