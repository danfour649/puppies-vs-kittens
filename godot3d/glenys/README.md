# Glenys — the cat-chaser

Daniel's locked spec (2026-10-24 23:30 + the 23:32 mechanics
extension, filed in `godot3d/TODO.md`): a demented woman with a
cane who chases and grabs the cats. She is Daniel's mother Glenys —
master's degree in computer science in the 1960s — and the tone is
affectionate warm comedy. Never mockery, never horror. The ONLY
lethal hazards in her design are the two poisons, and only when
the cat actually eats / gets into them.

## How she plays

- **Pursuit.** She targets the PLAYABLE cat only (`main.cat`, which
  `DuoSystem.choose()` swaps) and walks at a cane-paced 0.8 m/s —
  below occupant walk, far below any cat speed — but she never
  tires, never gives up, and steers predictively: her steer point
  leads the cat by its velocity (corner-cutting), routes through
  the kitchen divider's doorway gap instead of into the wall, and
  sidesteps when she snags on furniture. She corners; she does
  not chase.
- **The forget-pause.** Every 9–16 s of pursuit she stops, looks
  around confused for 2.5–4 s ("…Where was I?"), then remembers.
  That pause is the player's breathing room — and her heart.
- **Zone following.** When the cat travels, she waits a beat
  (6 s) and arrives through the SAME connector the cat used
  (front door / stairs / hatch mapping in `ENTRY_FOR_ZONE`), then
  resumes. Nowhere is safe forever.
- **She plays fair.** Three rules keep her inside her own design
  and out of the other systems' way. (1) *Reach:* she grabs cats
  at her own level — a cat up on a ledge, counter or sofa back
  (Δy > 0.45 m) is a refuge she cannot snatch from. (2) *The
  vanish:* a cat who suddenly isn't where he was (zone travel,
  respawn, any relocation > 0.9 m in a frame — no cat moves that
  far in a frame) has given her the slip: any grab ends on the
  spot (unscored) and she breaks off blinking for a couple of
  seconds instead of beelining to the new position; a grab never
  pins a cat across the world. (3) *Scripted sequences:* while
  main's `input_override` test seam is driving the cat (something
  real play never does), she stands aside entirely — she is part
  of the game, not an obstacle to its own regression contract,
  and every pre-existing suite stays green with her live.
- **The grab = a struggle, never an injury.** On contact the cat
  is CAUGHT: held up at her chest, controls locked, an on-screen
  prompt up. Rapid direction changes (WASD/arrows/stick flips)
  fill the struggle meter; ~6 flips (≈2–3 s) and the cat is
  dropped with a short positional pop away while she resets
  (3 s, no re-grab; 6 s mercy auto-release, unscored, if the
  player never struggles). A grab costs control and time —
  **never hit points** (asserted by test). A carried mouse catch
  is dropped and respawns, per the duo rule, so wins stay
  reachable. Escapes score +25 (`glenys_escape`) and feed the
  "Escape Glenys ×3" objective.
- **Chocolate.** Every ~40–55 s of pursuit, at conversational
  distance, she offers a plate of chocolate: "Here, kitty —
  chocolate!" She means it as a treat. Eating it KILLS — and
  eating is a deliberate act, telegraphed the whole time by a HUD
  warning: the cat must stand at the plate and HOLD paw (F), or
  paw-tap it, for a sustained moment. Standing next to it,
  walking past it, being grabbed next to it: all safe. Refusing
  costs nothing; the offer expires and the pursuit resumes.
- **Rat poison.** An old bait tray in the basement's south-west
  corner — pellets, a tipped bait box, an orange warning stripe
  and a floating RAT POISON label. Same lethality, only when the
  cat gets INTO the tray itself (contact radius is the tray, not
  the corner). Owned by the basement; the death flow is shared.

## The poison death and the nine lives (design reconciliation)

The game otherwise has no game-over: faints cost a life and
respawn at the hub, and lives wrap at 0. Daniel specced poison
deaths as RUN-ENDING, so they are: `PvKCat.eat_poison()` sets a
`poisoned` state that bypasses the faint flow entirely;
`main._on_cat_poisoned()` sets `run_over`, freezes input and the
clock, and banners the ending. No life is spent, no respawn
happens; R restarts the run (the existing reload). This is the
spec as written, not a softening of it.

## Choices where the spec was silent

- **Activation.** She wakes the first time the player enters the
  ground floor (her home turf) and stays awake. Yard-only play
  never meets her; every existing suite is undisturbed.
- **A cat on an occupant's lap is SAFE** (the brief's
  recommendation): even Glenys won't take a cat off a lap. The
  `on_lap` meta the occupant system already maintains gates her
  grab.
- **Struggle input** = movement-direction flips (the natural
  "wiggle"), polled from keys + the touch stick, with a
  `struggle_wiggle()` seam for tests/touch. Paw presses also add
  a little (the cat is swiping at the air, bless it).
- **Escape burst is positional** (a 0.55 m pop away from her):
  the cat controller consumes external velocity, so a velocity
  burst would be eaten; the duo flurry makes the same choice.
- **Follow entries** map zone → the connector the cat used:
  outside/ground floor → front door, basement → stairs, attic →
  hatch.
- **Cane taps** are synthesized (a filtered noise knock + a low
  thock, pitch-wandered), one per gait half-cycle — you hear her
  coming before you see her.
- **Basement dressing** (the extension's clutter ask): 20 props —
  a workbench with hammer/saw/wrench/oil can/jar, paint cans,
  shelf jars, hung shovel and rake, a ladder, a coiled hose,
  cardboard boxes — all on perimeter/shelf/bench spots, all
  visual-only except the workbench's one matching solid. The
  maze MAP, every BFS path and the Aggie-gap physics are
  untouched (tests_basement proves it).

## Files

- `glenys.gd` — the actor (`Glenys`, CharacterBody3D): procedural
  stooped build in the occupants' idiom, the cane, pose system,
  the cane-tap synth.
- `glenys_system.gd` — the brain (`GlenysSystem`): states
  dormant/pursue/forget/grab/reset/offer/follow_wait/distraught,
  steering, struggle, offers, zone following, HUD.
- `tests_glenys.gd/.tscn` — the suite (43 checks) driving the
  real game: both-cat targeting, steering/divider asserts,
  pursuit catch, grab/struggle/HP, lap safety, forget, follow,
  chocolate eaten vs refused, bait contact, dressing count.
- `tools_glenys_shots.gd` + scene — the shot pass
  (`screenshots/glenys/pursuit.png`, `grab.png`).
- Touch points outside this folder: `main.gd` (build + poison
  flow + objective), `cat_kit/cat.gd` (`poisoned` signal,
  `is_held`, `eat_poison`), `objectives.gd` (`glenys_escape`
  score event), `zones/basement/basement.gd` (the bait + the
  dressing).
