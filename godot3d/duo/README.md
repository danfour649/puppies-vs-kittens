# duo — the two-cat iteration

Everything here hangs off `main.gd` (which stays the boss of the
yard) via the `DuoSystem` node it creates at the end of `_ready()`.
New files only, except for a handful of small, `DUO`-commented
edits in `main.gd`.

## What's in the box

- **Character select** (`character_select.gd`) — two cards over the
  live yard at game start: play as the big plush boy or as his
  small wiry sister. Touch, mouse, or keys **1 / 2**. Trait text
  comes from the character data. The choice survives R-restarts
  (a static in `characters.gd`), so restarting keeps your cat.
  Whoever you don't pick becomes the sibling NPC.
- **Character data** (`characters.gd`) — reads
  `cat_kit/cat_species.json` defensively: today's flat schema and
  the appearance lane's coming `characters` structure both work,
  with built-in fallbacks per field. The kit cat is data-driven the
  same way — the sibling is a second `PvKCat` whose data is applied
  before she enters the tree, so the kit builds her model itself.
- **Sibling NPC** (`sibling_ai.gd`) — default behaviour is chill:
  lounge flop on a favourite spot (chair, porch, tree shade, sunny
  patch, fence corner), slow wanders between spots, steering that
  bends around the player's cat instead of through it.
- **Meows** (`meow_audio.gd`) — procedural, no assets: a two-tone
  falling meow (~0.45 s, 825→425 Hz with vibrato and a breath of
  noise) synthesised into an `AudioStreamWAV` at runtime, played on
  a positional voice per cat. Hers is a short, high chirp. Player
  meow: **M** key or the **MEOW** touch button. NPC Willie meows on
  his own every 6–10 s, because of course he does.
- **Provocation** (`provocation.gd`) — the signature dynamic.
  Aggie's meter fills when she hears Willie meow within ~8 m and
  decays slowly. At the threshold:
  - NPC Aggie **dashes** in, lands a flurry of paw strikes
    (knockback + brief slow + a little screen shake, and Willie
    **drops a catch** — the counter ticks down and the mouse
    escapes back into the yard, so the win stays reachable), then
    **flees** to the far lounge spot and cools down.
  - Player Aggie gets a **PROVOKED!** window (~5 s): +40% speed, a
    wider one-hit catch arc, and a visible aura.
  The meter + a "PROVOKED!" flash live in the HUD (`duo_system.gd`).

## Verification

    godot --headless --path godot3d res://duo/tests_duo.tscn

Headless state tests (select builds both options, role swap,
sizes, sibling pathing, the full provocation simulation both
directions, the mice loop still completing) plus the standing
shots under `godot3d/screenshots/gameplay/` from:

    xvfb-run godot --path godot3d res://duo/tools_duo_shots.tscn

The original `tests/smoke.tscn` still passes untouched: the duo
input lock deliberately does not block main's `input_override`
seam, and the default game (no choice made) is Willie playing,
Aggie lounging.
