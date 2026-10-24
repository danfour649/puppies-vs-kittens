# Puppies vs Kittens 3D — cat-first edition (v0.4)

The 3D revamp of Puppies vs Kittens, rebuilt in Godot 4.7 in the visual
language of GTA Fredericton: procedural flat-colour meshes, real
metre scale, directional sun + sky ambience, light fog — the yard in
GTA's box idiom, the cat modelled smooth from ellipsoids and tapered
cylinders (see `cat_kit/`). The Java v0.2
original and the 2D Godot port (branch `godot-revamp`) are untouched.

**Scope of this edition: play as the cat.** No bird mode, no birds of
any kind. Puppies are Phase 2.

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

## Controls

- **WASD / arrows** — move (camera-relative)
- **Shift** — sprint (stamina drains; it refills when you ease off)
- **Ctrl or C held** — stalk: slow, low crouch at GTA cat speed (1.2 m/s)
- **Space** — paw strike (catches a mouse in the front-paw arc)
- **L** — lounge / get up (Willie's signature flop)
- **R** — restart
- **Mouse drag** — orbit camera, **wheel** — zoom
- **Touch** — virtual joystick (bottom-left) + PAW button (bottom-right)

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
- `godot3d/screenshots/` — standing shots from one Xvfb pass:
  Willie close-up, Aggie close-up, both cats, the lounge.

## Phase 2 (not in this PR)

- Puppies: procedural 3D dogs (GTA `stray_dog` definition, quad frame
  at 0.55 scale), pack hunting, fights using the Java `KvPModel` rules
  and the `HOSTILE` table conventions, player HP.
- More cat polish: pounce from stalk, carrying a caught mouse, indoor
  scene (the #97 house) as a second diorama.
