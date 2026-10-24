# Puppies vs Kittens 3D — cat-first edition (v0.4)

The 3D revamp of Puppies vs Kittens, rebuilt in Godot 4.7 in the visual
language of GTA Fredericton: procedural flat-colour meshes, real
metre scale, directional sun + sky ambience, light fog — the yard in
GTA's box idiom, the cat modelled smooth from ellipsoids and tapered
cylinders (see `cat_kit/`). The Java v0.2
original and the 2D Godot port (branch `godot-revamp`) are untouched.

**Scope of this edition: play as the cat.** No bird mode, no birds of
any kind. Puppies are Phase 2.

You are **Willy** — a boy cat, built by `cat_kit/` to GTA Fredericton's
`stray_cat` construction from `scripts/world/wildlife.gd` (0.32 scale,
quad-frame anchors) — the same construction GTA's river cat Willow
uses, but Willy is his own cat, and he wears his own colouring from
the original v0.1 hand-drawn art: a white coat with ginger patches,
not GTA's orange. Catch all 7 mice in the backyard. Win,
and he does his lounge flop.

The cat is the real deliverable: `cat_kit/` is a self-contained package
designed to be lifted back into GTA Fredericton (for example for TODO
#97's annoying house cats). See `cat_kit/README.md` for the port path.

## The DUO iteration (this branch)

Two cats, one yard — see `duo/README.md` for the full tour.

- **Character select** at game start: play as **Willy** (big, plush,
  meows constantly) or as his sister **Aggie** (small, wiry, chill
  but vicious — faster, with a burst strike). Keys **1 / 2**, mouse,
  or touch. The other cat is in the yard with you as a sibling NPC,
  lounging and wandering.
- **Meow** — **M** key or the **MEOW** touch button. Procedural
  audio, no assets. NPC Willy meows on his own every 6–10 s.
- **Provocation** — Willie's meowing fills Aggie's meter (watch the
  bar, top-left). At the threshold, NPC Aggie dashes in, flurries
  him (he drops a catch), and flees; player Aggie instead gets a
  ~5 s **PROVOKED!** window: +40% speed and a wider catch arc.

## Controls

- **WASD / arrows** — move (camera-relative)
- **Shift** — sprint (stamina drains; it refills when you ease off)
- **Ctrl or C held** — stalk: slow, low crouch at GTA cat speed (1.2 m/s)
- **Space** — paw strike (catches a mouse in the front-paw arc)
- **M** — meow
- **L** — lounge / get up (Willy's signature flop)
- **R** — restart
- **Mouse drag** — orbit camera, **wheel** — zoom
- **Touch** — virtual joystick (bottom-left) + PAW button (bottom-right) + MEOW button

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
  strike, and reaches the win state. Asserts on state, never on
  rendered pixels.
- `godot3d/duo/tests_duo.tscn` — headless DUO tests: character
  select, role swap, sibling pathing, and the full provocation
  simulation in both directions. `godot3d/screenshots/gameplay/`
  holds the duo shot pass (`duo/tools_duo_shots.tscn` under Xvfb).
- `godot3d/screenshots/` — standing shots from one Xvfb pass:
  cat close-up, wide gameplay, the lounge.

## Phase 2 (not in this PR)

- Puppies: procedural 3D dogs (GTA `stray_dog` definition, quad frame
  at 0.55 scale), pack hunting, fights using the Java `KvPModel` rules
  and the `HOSTILE` table conventions, player HP.
- More cat polish: pounce from stalk, carrying a caught mouse, indoor
  scene (the #97 house) as a second diorama.
