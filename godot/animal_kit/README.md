# The Animal Kit

A small, data-driven animal system built for Puppies vs Kittens and
designed from the start to be **lifted into GTA Fredericton** when its
animal work (wildlife, TODO #97's indoor cats, bird-mode prey) needs
actors with behaviour — not just sprites.

Design rule: **a species is data, not code.** Every species is one JSON
file; one actor class plays them all; small state-machine "brains" inside
the actor are selected by the data. Adding a species means adding a JSON
file (and sprites), never a new script.

## Layout

- `animal_kit.gd` — loader/cache (`AnimalKit.load_species`,
  `AnimalKit.make_animal`).
- `animal.gd` — the actor (`class_name Animal`, a `Node2D`).
- `species/*.json` — one file per species: `kitten`, `puppy`, `mouse`,
  `bird`.

## The actor

- The node origin is the animal's **ground position**. The visual child is
  lifted by altitude and animation (bobbing, squash-and-stretch on
  strikes); the soft shadow stays on the ground and shrinks/fades with
  altitude — the shadow is the position ground truth for flying animals.
- Signals: `died(animal)`, `hp_changed(animal)`.
- Groups: every animal joins `animals`; prey species also join `prey`
  (strike/snatch resolution iterates that group).
- Player brains read an **input contract**, not devices: the host game
  writes `input_move` (Vector2) and `input_strike` (bool) each tick. This
  is what makes the same actor work with keyboard, touch, or a test
  harness unchanged.
- The host wires the social graph: each animal has `threat` (hunters chase
  it, prey flee it), `flock` (prey separation), `pack_index`, and a
  `tuning` dictionary (difficulty numbers owned by the host — see below).

### Brains

| Brain | Used by | Behaviour |
|---|---|---|
| `player` | kitten (player) | velocity = input × speed; strike on input |
| `player_bird` | bird (player) | flight model + steering; strike = dive |
| `prey` | mouse | wander (random-jitter) / graze pauses / flee threat / flock separation; wounded = 45% speed |
| `pack_hunter` | puppy | proportional chase with per-member stagger, pack-orbit offset when close, `in_attack_range` flag |
| `wanderer` | kitten (while player is the bird) | slow aimless wander |
| `aerial_predator` | wild bird NPC | cruise between waypoints, periodic dive at a live prey animal with lead-pursuit steering |

## Species schema (`species/<id>.json`)

Common fields:

| Field | Type | Meaning |
|---|---|---|
| `id`, `display_name` | string | identity |
| `brain` | string | default brain (host may override per-instance, e.g. `npc_brain`) |
| `npc_brain` | string | brain to use when not player-possessed |
| `max_hp` | number | hit points (prey die via the wound rule instead) |
| `speed` | px/s | ground speed (player/wanderer brains) |
| `body_radius` | px | field-clamp margin basis |
| `sprite_width`, `shadow_width` | px | on-field visual size; shadow ellipse width |
| `sprites.idle/action/dead` | filenames in `res://assets/` | pose set; omit `sprites` entirely for a code-drawn body (bird) |

Kitten (predator): `strike_range` (paw point = position + facing × range
+ a downward bias, mirroring the Java paw offset), `strike_radius`,
`strike_cooldown`, `show_hp_bar`.

Mouse (prey): `wander_reroll` (s between velocity re-rolls — the Java
jitter), `flee_radius`, `flee_speed`, `separation_radius`,
`separation_weight`, `graze_pause_chance`, `wound_ttl` (Java
`timeToLiveAfterHurt` = 3), `wound_speed_factor`.

Puppy (pack hunter): `chase_rate` (the Java chase is `step = distance /
divisor` per frame at 60 fps; at our field scale rate = 120/divisor, so
0.8 ⇔ divisor 150), `attack_range`, `pack_spread`, `speed_cap`,
`contact_damage` (baseline; the host's difficulty tuning overrides it).

Bird (aerial): `flight_speed`, `dive_speed`, `ground_speed`, `turn_rate`,
`cruise_altitude` (0..1), `altitude_offset_px` (visual lift at altitude
1), `climb_rate`, `dive_rate`, `snatch_radius`, `snatch_cooldown`,
`perception_radius`, `body_colors` (for the code-drawn body).

### Difficulty tuning lives with the host, not the species

`main.gd`'s `DIFFICULTY` table (mouse count, puppy count, `mouse_jitter`,
`puppy_rate_mult`, `puppy_damage`, `puppy_speed_cap`) is handed to every
animal as `tuning`. This mirrors GTA Fredericton's `data/tuning.gd`
pattern: one global place where a mode scales base species numbers
(theirs scale bird top speed ×1.8, turn rate, damage immunity windows;
ours scale the Java divisor table 150/100/50 into rate multipliers
1.0/1.5/3.0).

## Fight rules (ported from KvPModel.java)

- A strike wounds one or more prey in radius; a wounded prey dies when
  `wound_ttl` expires. Win/lose bookkeeping belongs to the host.
- Hunters expose `in_attack_range`; the **host** applies damage on its
  1-second tick (Java `checkFightPuppies`: per second, per fighting
  puppy, 5/7/20 by difficulty). The kit deliberately keeps the clock with
  the host, like the original kept it in the model.
- Airborne animals (`altitude > 0.3`) cannot be damaged by ground hunters.

## Bird mode: GTA Fredericton provenance

Studied in GTA Fredericton (read-only) before writing any of this. An
accuracy note first: GTA's bird mode (TODO #87, still unchecked) is a
**demo-stage, pure-logic module set** — it shipped in PR #270 as design
and numbers, with no bird scene, input binding, or camera/flight loop
integrated into the game. What PvK reused is that design, reimplemented
fresh in 2D — not GTA code. The real source files, all under
`scripts/bird/`:

- `bird_mode.gd` — the mode controller: species table, start/end,
  score, landing rules.
- `flight.gd` — velocity + stamina integrator: cruise 10 m/s, dive
  20 m/s, stamina 100 draining 2.0/s while flapping.
- `scoring.gd` — splat table 10/25/40/50/75, direct hits x2, 5-second
  combo x2; hunt scores: fish 100, rabbit/squirrel 60.
- `spawns.gd` — spawn points: nest, airborne, Carleton Park.
- `species.gd` — `BirdSpecies` resource: eagle 1.2x speed and hunts,
  osprey best climb and hunts, gull fastest with a splat cooldown and
  no hunting.
- `bird_hud.gd` — score label only.

Ported concepts: species-as-data driving one controller; the flight and
stamina numbers above as the starting tuning; the dive as a committed
descent to a ground point resolved by proximity (our `snatch_radius`);
the prey discipline (only true prey species can be hunted — our `prey`
group). PvK's own additions, which GTA does not have yet: the possession
swap itself (press B, the kitten stays in the world as an NPC), the
altitude + ground-shadow readability model, dive resolution against
live actors, and NPC dive AI. If this kit is lifted back into GTA, the
bird mode there gains a working flight loop, not just the logic it has
now.

Not ported: the splat scoring table (10/25/40/50/75, direct x2, combo
x2 — PvK counts kills, not score); thermal soaring/energy beyond the
stamina integrator; the 3D pitch-and-bank flight model; grounded bird
states (walk/hop/takeoff). All natural v0.4 extensions if the mode grows.

## Lifting this kit into GTA Fredericton

1. Copy `animal_kit/` into the GTA project. The kit has **no autoloads
   and no project-settings dependencies**; input actions are registered
   by the host at runtime (see `main.gd._setup_input` here).
2. **Name collision warning:** GTA already has `scripts/systems/animal.gd`.
   If that file (or any GTA file) registers a global `Animal` class, rename
   the kit's classes on import (`Animal` → `PvKAnimal`, `AnimalKit` →
   `PvKAnimalKit`) — two small files, a few minutes.
3. Species JSON references sprite filenames under `res://assets/`;
   repoint them at GTA art or add GTA-native species files wholesale —
   e.g. an indoor cat for TODO #97 is `kitten.json` with `wanderer`/
   `prey`-style brains, a smaller `sprite_width`, and mischief weights.
4. **Scale:** kit numbers are tuned for a 1000 px 2D field at px/s. GTA
   works in metres; treat kit speeds/radii as proportions of a body
   length and rescale once, in the species files — the brain code is
   unit-agnostic.
5. The actor itself is 2D (`Node2D`). For GTA's 3D world, the portable
   assets are this schema, the brain/state design, the fight rules, and
   the tuning pattern; a `CharacterBody3D` sibling implementing the same
   brains against the same JSON is the intended 3D form (the brains only
   depend on position, velocity, a threat reference, and the species
   dictionary).
