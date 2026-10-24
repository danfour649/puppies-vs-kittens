# cat_kit — the portable Willow

A self-contained procedural 3D cat for Godot 4.7, built to be lifted
into other projects. No scene files, no external assets: `cat.gd`
builds the whole animal in code.

## What it is

`PvKCat` (a `CharacterBody3D`) is GTA Fredericton's river cat,
**Wolastoq Willow**, defined in `scripts/world/wildlife.gd`:

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

`cat.gd` reproduces that construction part for part (same sizes,
positions, colours, forward axis, scale), so a side-by-side render
against GTA's stray_cat matches. `cat_species.json` carries the
identity, palette, scale, GTA stat block and game tuning.

Kit refinements (geometry identical; wrappers and small additions):
each leg sits under a hip pivot, the head under a neck pivot, and the
tail under a base pivot, so parts can swing; plus tabby stripes, a pale
chest patch, nose and eyes. GTA cats cast no shadows (city perf);
this hero cat leaves shadow casting on.

## Animation states (all in code, poses are functions of state+time)

- `idle` — breathing (body scale-y ±2.5%), slow look-around, tail sway
- `walk` — diagonal-pair leg swings + GTA gait bob `|sin(phase)| * 0.05`
- `stalk` — crouch (body low, scale-y 0.84, tail level) at 1.2 m/s
- `sprint` — bigger swings/bob, tail streamed, stamina-gated
- `strike` — 0.34 s windup -> lunge -> slash; `paw_swiped` signal fires
  at the landing moment (t = 0.10 s); 0.38 s cooldown
- `lounge` — Willow's flop: body scale eases to (1.05, 0.7, 1.0),
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
   branch of `_build_mesh()` with `PvKCat.build_standalone()` — i.e.
   call the kit's builder to produce the same root Node3D GTA
   expects (child 0 = Body group, legs on the root, root scaled
   0.32, forward -Z). GTA's dictionary brain, habitats, hostility
   and hitbox attach unchanged. Willow gets leg swings and a real
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

Scale/units: everything is metres, Y-up, forward -Z, species scale
applied on the model root exactly as GTA does (`root.scale = s`).
Heights: cat stands leg_h * s = 0.11 m to the belly, back at
~0.24 m — a real cat against GTA's 1 m-unit doors and furniture.
