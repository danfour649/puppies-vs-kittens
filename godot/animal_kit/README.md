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

Studied in GTA Fredericton (read-only) before writing any of this:

- `scenes/player/bird.gd` — the bird player controller (velocity-aligned
  flight, landing-spot dive, fish snatch).
- `scenes/player/player.gd` — the mode state machine and possession
  broker (switching to the bird leaves the human in the world as an NPC).
- `resources/bird_species.tres` + `data/bird_species.gd` — bird species
  as data: id, tint, scale, max speed, turn rate, per-species dive FX.
- `scripts/systems/animal.gd` — the prey registry (birds strike animals
  through a shared registry, not ad-hoc lookups).
- `scenes/ui/bird_hud.gd`, `data/tuning.gd` — mode HUD and global tuning.

Ported concepts: possession swap with the original creature persisting as
an NPC; species-as-data driving one controller; the dive as a committed
descent to a ground point with a proximity resolution (their talon-splash
radius → our `snatch_radius`); straight-line lead-pursuit steering for
NPC dives; the "helpless prey" list discipline (only true prey species
can be snatched — our `prey` group); altitude + shadow as the readable
ground truth in place of their 3D camera work.

Not ported: poop scoring (+10/+25/+50, moving targets ×2.5) — PvK has no
score, only kills; thermal soaring/energy; the 3D pitch-and-bank flight
model; the grounded bird FSM (walk/hop/takeoff states). All four are
natural v0.4 extensions if the mode grows.

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
