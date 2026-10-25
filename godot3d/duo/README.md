# duo — the two-cat iteration

Everything here hangs off `main.gd` (which stays the boss of the
yard) via the `DuoSystem` node it creates at the end of `_ready()`.
New files only, except for a handful of small, `DUO`-commented
edits in `main.gd`.

## What's in the box

- **Character select** (`character_select.gd` + `select_stage.gd`
  + `select_minimap.gd`) — a Mortal Kombat-pattern select: the
  highlighted cat stands rendered on a spotlight stage (the real
  model, idle-animated), its name and one trait line beside it,
  its start marked on a house-and-yard minimap. One decision:
  arrows / hover move, Enter / click picks, **1 / 2** pick
  directly. Name, line and start all come from the character
  data. The choice survives R-restarts (a static in
  `characters.gd`), so restarting keeps your cat.
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

## The heat system (`heat_system.gd`)

Aggie goes into **heat**, frequently (Daniel's spec, 2026-10-24):
the cycle runs off 16–30 s → heat 30–60 s → a short settle. In heat
she hunts Willie down wherever he is and **solicits** — the cat
kit's courtship pose (a rocking roll, front dipped in a present,
tail swung aside) plus the **yowl**, a 1.15 s synth variant in
`meow_audio.gd` (`aggie_yowl`: louder and longer than her chirp,
unmistakable across the yard).

Willie is **neutered**. When he is the NPC and she comes near, he
performs from the comedy response table (SiblingAI heat modes):
the **blank stare**, **pointed self-grooming** (the kit's groom
pose), wandering off to **knock his water bowl over** (the bowl by
the porch tips, splash and all, and is set upright after the heat),
and the occasional **half-hearted mount attempt** — hop on, hold a
beat, lose interest. The first attempt fires the popup: *"He's
neutered. There will be NO kittens."* There are never kittens;
the tests assert the cat count stays two.

- **Player is Willie:** Aggie NPC runs `heat_seek` / `heat_solicit`
  at him — a moving hazard to dodge while hunting.
- **Player is Aggie:** an **urge meter** and a *Find Willie*
  objective show during heat, and every 8–14 s an **involuntary
  roll-and-yowl interrupt** wobbles her controls for 0.9 s via
  main's `input_override` seam (brief, never a lockout).

Dignity rules: heat never starts, and its behaviours suspend,
while the provocation system is mid-flurry/buff, while a cat is
fainted, while the player cat is on a lap (or held — the `caught`
meta seam), or while character select is up. Provocation wins any
overlap and heat resumes after it.

## Verification

    godot --headless --path godot3d res://duo/tests_duo.tscn
    godot --headless --path godot3d res://duo/tests_heat.tscn

Headless state tests (select builds both options, role swap,
sizes, sibling pathing, the full provocation simulation both
directions, the mice loop still completing) plus the standing
shots under `godot3d/screenshots/gameplay/` from:

    xvfb-run godot --path godot3d res://duo/tools_duo_shots.tscn

The original `tests/smoke.tscn` still passes untouched: the duo
input lock deliberately does not block main's `input_override`
seam, and the default game (no choice made) is Willie playing,
Aggie lounging.
