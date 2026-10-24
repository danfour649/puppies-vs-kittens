# cat_kit — the portable cats

A self-contained procedural 3D cat for Godot 4.7, built to be lifted
into other projects. No scene files, no external assets: `cat.gd`
builds the whole animal in code.

## What it is

`PvKCat` (a `CharacterBody3D`) is the kit actor for Daniel's two
cats — **Willie**, his boy cat, and Willie's sister **Aggie** —
built to GTA Fredericton's stray_cat construction — the construction
GTA's river cat **Wolastoq Willow** is defined with, in
`scripts/world/wildlife.gd`:

- `SPECIES["stray_cat"]` (line 33): `hab URBAN, w 4.0, spd 1.2,
  flee 3.5, s 0.32, c Color(0.85, 0.55, 0.25), shape "quad"`
- `HOSTILE["stray_cat"]` (line 79): `chance 0.04, notice 8.0, dmg 4.0,
  cd 1.0, hp 18.0, chase 2.4, reach 0.9`
- `_spawn_river_cat()` (line 217): Willow is that cat spawned with
  `persistent = true, chill = true, leash 3.0, idle_bias 4.0`, renamed
  "RiverCat", given a name Label3D, and posed lounging with
  `body.scale = (1.05, 0.7, 1.0)` — "low and long, tail wrapped".
- `_build_mesh()` quad branch (line 776): unit (~1 m) frame, forward
  -Z, `leg_h = 0.35`; torso box (0.35, 0.35, 0.9) at y 0.53; head
  (0.26, 0.26, 0.3) at (0, 0.73, -0.55); snout (0.12, 0.1, 0.14) darkened
  at (0, 0.67, -0.74); legs (0.09, leg_h, 0.09) darkened, parented to
  the model root at (±0.12, ±0.32); for stray_cat also a tail box
  (0.08, 0.08, 0.5) at (0, 0.65, 0.65) and ear boxes (0.06, 0.1, 0.04) at
  (±0.08, 0.90, -0.5); whole model scaled by `s`. Materials are shared
  flat `StandardMaterial3D` (roughness 0.95) via a colour-keyed cache;
  meshes are cached `BoxMesh`es keyed by size (`_mat` / `_box`,
  lines 739-763).

`cat.gd` keeps that construction's architecture — same unit frame,
forward axis, anchor positions (head, hips, tail base), per-character
scale, Body-group-as-child-0 and legs-on-the-root structure — so the
port path below is unchanged. The parts are **smooth primitives**,
not boxes — ellipsoid torso with blended chest and haunch spheres, a
sphere skull with muzzle, pinched-sphere ears, tapered-cylinder legs
with capsule paws, and a tail made of a curved chain of shrinking
spheres. `cat_species.json` carries the shared GTA stat block plus a
`characters` map with each cat's identity, palette, build profile,
temperament and game tuning (see Characters).

Colouring is each cat's own, taken from Daniel's photos of the
real cats (the `reference/` folder beside this README, which also
keeps the v0.1 hand-drawn sprite, `reference-willy-v01.png`) — see
the Characters section below for palettes and provenance. It is
deliberately **not** GTA stray_cat's solid orange (0.85, 0.55,
0.25): that is a different cat, recorded in the JSON
(`gta.coat_in_gta`) as provenance only.

Kit refinements over the GTA original: each leg sits under a hip
pivot, the head under a neck pivot, and the tail under a base pivot,
so parts can swing. GTA cats cast no shadows (city perf); this hero
cat leaves shadow casting on.

## Characters

`cat_species.json` was restructured in the appearance-refinement
pass: the shared species data (GTA stat block, construction source)
stays top-level, and everything per-cat — name, sex, scale, palette,
build profile, temperament, game tuning — now lives under
`characters.<id>`. `PvKCat` defaults to `willie`; call
`set_character("aggie")` before `add_child()` for the sister. The
schema change is data-only: Willie's entries carry the same meaning
as the old single-cat file, with the appearance values refined as
below.

### Willie — the big plush boy (player cat, scale 0.35)

Daniel's boy, and the game's player character. Photo truth (from
`reference/reference-willie-basket.jpg` and
`reference/reference-willie-table.jpg`; these override the v0.1
hand-drawn sprite where they differ): pure white face blaze,
muzzle, chest, belly, legs and paws; **rich orange tabby** — a cap
wrapping the top of the head around the ears and down the sides of
the cheeks, a **large saddle** over the whole back and upper sides,
and a substantially ginger, ringed tail; green-gold eyes; pink
nose.

- Palette: coat `#FFFFFF`; ginger `#C97020` (inside the
  #C26D1E–#CD7A2A band Daniel specified — "definitely darker
  orange" than the v0.1 art's #E8AF54); tabby striping
  `ginger_dark #975417` — a faint, darker banding laid as thin
  flattened shells across the saddle, two on the cap, and
  alternating into the tail rings; eyes `#8A9A3B`; nose `#D98C7A`.
- Tonemapping compensation: raw photo medians sample muted
  (#A68041-ish) under indoor light and shadow, and the game's ACES
  tonemapper + midday sun desaturate further (the old #E8AF54 build
  rendered pale gold). The albedo is therefore set rich and tuned
  by eye against the photos in the standing `willie_closeup` shot.
- Build: **plush** — thick torso (0.44 unit wide), full chest and
  haunches, legs a touch shorter relative to the body, tail 1.3×
  thick. Scale **0.35**, up from the GTA stray's 0.32: he is a big
  boy.
- Character: a total asshole (owner's field report): knocks drinks
  and his own water bowl over, scratches the furniture, shits right
  beside the litter box in the basement, and **meows constantly** —
  `meowing: "constant"` in his record, which matters because it is
  Aggie's attack trigger (below). Behaviour lands in the later GTA
  slices; this kit carries the definition.

### Aggie — the wiry tortie (NPC, scale 0.25)

Willie's much smaller sister — "chill but vicious". Daniel calls
her a calico; the photos (`reference/reference-aggie-drawer.jpg`,
`reference/reference-aggie-plant.jpg`) show a **dark
tortoiseshell**: warm black-brown base with irregular orange and
cream mottling everywhere, a mostly dark face with orange mottling
and a cream/orange throat and chest, a dark tail with orange
running through it, green-gold eyes like his.

- Palette: base `#241C17` (photo median); mottle orange `#B06E2C`;
  mottle cream `#BFA87A`; eyes `#8A9A3B`; nose near-black brown.
- Tortie technique: a **seeded scatter** of small flattened
  ellipsoid shells in the two tones, hugging the torso (denser),
  head, legs and tail over the dark base — irregular sizes,
  rotations and placement driven by `palette.mottle.seed`
  (20261024), so she builds identically every run; the smoke test
  asserts patch count and scatter signature across two builds.
  Primitives have no fur texture, so the mottle reads as patchy
  colour rather than individual hairs — the honest limit of the
  technique.
- Build: **wiry** — a lean, slim torso (0.30 unit wide vs Willie's
  0.44), narrow chest and haunches, slim legs, thin tail. Not a
  scaled-down Willie: the silhouette differs in the data
  (`build.profile: "wiry"`), and at scale **0.25** she stands
  visibly smaller than him.
- Character (definition only — no fight AI in this kit): she
  weighs **half** what Willie does (`weight_vs_willie: 0.5`) but
  **always wins their fights** (`wins_vs_willie: true`); her style
  is `fight_style: "burst_and_flee"` — dart in, brief flurry, run
  away; she is chill until provoked, and the provocation trigger
  is `provocation_trigger: "willie_meowing"` — his constant
  meowing is literally what sets her off.

## Animation states (all in code, poses are functions of state+time)

- `idle` — breathing (body scale-y ±2.5%), slow look-around, tail sway
- `walk` — diagonal-pair leg swings + GTA gait bob `|sin(phase)| * 0.05`
- `stalk` — crouch (body low, scale-y 0.84, tail level) at 1.2 m/s
- `sprint` — bigger swings/bob, tail streamed, stamina-gated
- `strike` — 0.34 s windup -> lunge -> slash; `paw_swiped` signal fires
  at the landing moment (t = 0.10 s); 0.38 s cooldown
- `lounge` — the flop: body scale eases to (1.05, 0.7, 1.0),
  tail wraps (yaw 0.85), head rests, legs tuck

## Controller contract

Call `set_move_input(world_dir, sprint, stalk)` every physics frame;
`strike()`, `set_lounge(bool)` / `toggle_lounge()` on events; read
`anim_state`, `stamina`, `is_lounging`, `forward_dir()`, `paw_point()`.

## Port path back into GTA Fredericton

GTA's animal system is `scripts/world/wildlife.gd` (there is no
`scripts/systems/animal.gd` in the game): animals are Dictionaries
`{sp, node, pos, target, state, timer, ...}` stepped centrally by
`Wildlife._step()`, and hittable animals carry an
`animal_hitbox.gd` StaticBody3D on layer 10 whose `animal_hit(dir,
damage)` forwards to `Wildlife.hurt_animal(animal, dir, damage)`.

Three ways in, in increasing order of ambition:

1. **Model swap (mechanical, an afternoon):** replace the stray_cat
   branch of `_build_mesh()` with the kit's builder to produce the
   same root Node3D GTA expects (child 0 = Body group, legs on the
   root, root scaled by the character's scale — Willie 0.35 / Aggie
   0.25 here; GTA's own strays use 0.32 — forward -Z). GTA's dictionary brain, habitats, hostility
   and hitbox attach unchanged. The palette travels as data
   (`cat_species.json`), so the port is unaffected by colouring: a
   swapped-in cat can wear Willie's white-and-ginger or be restyled
   per species without touching the builder. Willow gets leg swings and a real
   lounge for free, because the kit's pivots accept the same
   body-bob writes `_step()` already makes.
2. **Brain transplant:** keep GTA's Dictionary entry but drive the
   kit's pose layer from `_step()` state (idle/wander/flee/hostile
   map onto idle/walk/stalk/strike). GTA cats gain stalk and strike
   poses, which is what TODO #97's house cats need to be annoying
   on furniture: the kit cat is a `CharacterBody3D`, so in an interior
   it can hop onto the porch/chair collision the same way it does in
   this diorama.
3. **Full adoption (PvK-side only):** in this game the cat is a
   physics body with its own controller. GTA would keep its cheap
   glide-stepped dictionaries for crowds and use full kit cats only
   for named animals (Willow, the #97 pair), which matches how GTA
   already special-cases her (`persistent`, `chill`, name tag).

Scale/units: everything is metres, Y-up, forward -Z, character
scale applied on the model root exactly as GTA does
(`root.scale = s`). Heights: a cat stands leg_h * s to the belly —
0.12 m for Willie at 0.35, 0.09 m for Aggie at 0.25 — backs at
~0.27 m / ~0.19 m: real cats against GTA's 1 m-unit doors and
furniture.
