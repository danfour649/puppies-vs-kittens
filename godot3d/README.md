# Willie and Aggie — the Massey Street cat game

The cats own 3D game, rebuilt in Godot 4.7 in the visual
language of GTA Fredericton: procedural flat-colour meshes, real
metre scale, directional sun + sky ambience, light fog — the yard in
GTA's box idiom, the cat modelled smooth from ellipsoids and tapered
cylinders (see `cat_kit/`). The Java v0.2
original and the 2D Godot port (branch `godot-revamp`) are untouched.

**Scope of this edition: play as the cat.** No bird mode — you only
ever play as the cats — but birds exist in the world: the outside
feeder draws a constant stream of them, and they are prey.
Puppies are Phase 2.

You are **Willie** — a big white-and-ginger boy cat (scale 0.35),
built by `cat_kit/` to GTA Fredericton's `stray_cat` construction
from `scripts/world/wildlife.gd` (quad-frame anchors) — the same
construction GTA's river cat Willow uses, but Willie is his own
cat, coloured from Daniel's photos of the real cat: a white coat
with a rich-orange tabby cap and saddle, not GTA's orange and not
the v0.1 drawing's paler ginger. His sister **Aggie** — a small,
wiry dark tortoiseshell (scale 0.25) — has an NPC cameo, lounging
on the garden chair. She is chill. For now. Catch all 7 mice in
the backyard. Win, and he does his lounge flop.

The cat is the real deliverable: `cat_kit/` is a self-contained package
designed to be lifted back into GTA Fredericton (for example for TODO
#97's annoying house cats). See `cat_kit/README.md` for the port path.

## The DUO iteration (this branch)

Two cats, one yard — see `duo/README.md` for the full tour.

- **Character select** at game start: play as **Willie** (big, plush,
  meows constantly) or as his sister **Aggie** (small, wiry, chill
  but vicious — faster, with a burst strike). The highlighted cat
  is rendered live on a spotlight stage, its start marked on a
  minimap; arrows / mouse move, Enter / click or keys **1 / 2**
  pick. The other cat is in the yard with you as a sibling NPC,
  lounging and wandering.
- **Meow** — **M** key or the **MEOW** touch button. Procedural
  audio, no assets. NPC Willie meows on his own every 6–10 s.
- **Provocation** — Willie's meowing fills Aggie's meter (watch the
  bar, top-left). At the threshold, NPC Aggie dashes in, flurries
  him (he drops a catch), and flees; player Aggie instead gets a
  ~5 s **PROVOKED!** window: +40% speed and a wider catch arc.

## The MASSEY iteration — Willie and Aggie at 255 Massey St

The game is now the house at 255 Massey Street from the cats'
perspective, built as a **drop-in module** whose canonical frame
is the real house in GTA Fredericton (see `docs/massey-zones.md`
§9, the module contract). The zone contract for all Massey work
is `docs/massey-zones.md` — read it before touching a zone.

- **Zones** — OUTSIDE (the yard), the GROUND FLOOR hub (kitchen +
  living room at cat scale: the open drawer Aggie sits in,
  Willie's water bowl, the sofa), BASEMENT and ATTIC shells. Walk
  into a door / stair / hatch volume and both cats fade-travel to
  the paired entry. All geometry derives from one data spec,
  `house/house_spec.gd` (HouseSpec), rendered by
  `house/house_builder.gd`; layout also travels as (u,v) anchor
  fractions (`HouseSpec.ANCHORS`) so it re-fits GTA's real
  11.79 × 15.64 m footprint.
- **Combat/health** — cats have HP (Willie 120, Aggie 80), take
  damage with a brief invulnerability window, and faint at 0:
  dramatic flop, then wake at the ground-floor hub with a life
  spent off the nine-lives counter (flavour — never a game-over).
  `combat/` holds the reusable PvKEnemy base (HP, knockback +
  hit flash, wander/chase/lunge/flee states, death → objectives
  kill hook) and CombatData, the shared damage table (paw
  profiles, rat/raccoon bites, `vehicle_hit` = 60% HP + launch
  for Massey St traffic). **Space** jumps; mid-air Space is a
  **pounce** (longer paw reach). Ghosts can force a **hiss**
  (arched back, puffed tail, ~1.5 s startle lock, no damage).
  Lap petting and fish treats heal through `cat.heal(amount)`.
- **Objectives + score** — Tab or the OBJECTIVES button toggles
  the checklist panel (per-zone objectives with done states);
  the score counter is fed by named events (`ankle_attack`,
  `underfoot`, `trip_hazard`, `lap_purr`).

## Controls

- **WASD / arrows** — move (camera-relative)
- **Shift** — sprint (stamina drains; it refills when you ease off)
- **Ctrl or C held** — stalk: slow, low crouch at GTA cat speed (1.2 m/s)
- **Space** — jump; mid-air, a **pounce** (paw strike with longer reach)
- **F** — paw strike (catches a mouse in the front-paw arc)
- **Tab** — objectives panel
- **M** — meow
- **L** — lounge / get up (Willie's signature flop)
- **R** — restart
- **Mouse drag** — orbit camera, **wheel** — zoom
- **Touch** — virtual joystick (bottom-left) + PAW and POUNCE buttons (bottom-right) + MEOW button + OBJECTIVES button

## Run / export

Open `godot3d/` in Godot 4.7, or headless:

    godot --headless --path godot3d --import
    godot --path godot3d

Web (primary target; build output is git-ignored):

    godot --headless --path godot3d --export-release "Web" build/web/index.html

An Android preset is defined (arm64, unsigned build not produced here).

## Verification

- `godot3d/tests/smoke.tscn` — headless smoke test: instantiates the
  real game, drives the cat by scripted input, catches a mouse with a
  strike, and reaches the win state. Also builds both cats and asserts
  Willie's photo palette/scale/striping and Aggie's tortie base,
  wiry build, scale and deterministic mottle. Asserts on state and
  data, never on rendered pixels.
- `godot3d/duo/tests_duo.tscn` — headless DUO tests: character
  select, role swap, sibling pathing, and the full provocation
  simulation in both directions. `godot3d/screenshots/gameplay/`
  holds the duo shot pass (`duo/tools_duo_shots.tscn` under Xvfb).
- `godot3d/tests/test_massey.tscn` — headless MASSEY tests: zone
  travel between every pair (real door trigger + instant), the
  enemy base (hits/knockback/flee/death → kill hook), cat damage
  + vehicle launch + heal seam, hiss timing, jump apex + 0.5 m
  ledge landing, pounce range, faint → hub respawn with a life
  spent, and the module anchor mapping (61 checks).
- `godot3d/tests/test_playtest.tscn` — headless PLAYTEST tests:
  the four bugs Daniel's 2026-10-24 playtest found in the
  integrated game while every other suite was green — the mouse
  catch window (staged strikes + a scripted sprint chase), the
  sibling fence clamping the sibling's z indoors, the z-flipped
  attic hatch shaft, the raccoon family spawning in the yard, and
  the provocation lounge-lock (Aggie must attack with NO manual
  un-lounge).
- `godot3d/screenshots/` — standing shots from one Xvfb pass:
  Willie close-up, Aggie close-up, both cats, the lounge, plus
  the Massey hub + front door (`tools/massey_shots.tscn`).

## The Massey outside zone — "Willie and Aggie" outdoors

`godot3d/zones/outside/` grows the backyard into the full 255 Massey
outside: three climbable trees with squirrels that flee up the trunk
and taunt from the branch (the cat can climb up after them), a bird
feeder with a constant bird stream and a bush-ambush mechanic
(stillness meter; Willie meowing in the bush scatters the flock),
the Massey Street frontage — where the traffic actively tries to
hit a cat on the road, honking as it swerves, with the parked 2018
Corolla as a safe island and a healing fish treat across the
street — and neighbours walking dogs that alert, strain at the
leash, slip it, and chase. Full placements, tuning and the local
damage contract: `godot3d/zones/outside/README.md`. Headless checks:
`godot3d/zones/outside/tests_outside.tscn` (67 assertions); shot
pass: `godot3d/zones/outside/tools_outside_shots.tscn`.

## Phase 2 (not in this PR)

- Puppies: procedural 3D dogs (GTA `stray_dog` definition, quad frame
  at 0.55 scale), pack hunting, fights using the Java `KvPModel` rules
  and the `HOSTILE` table conventions, player HP.
- More cat polish: pounce from stalk, carrying a caught mouse, indoor
  scene (the #97 house) as a second diorama.
