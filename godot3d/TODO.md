# Willie and Aggie — TODO

Repo-local TODO list for the godot3d game. (This file was created
2026-10-24 with the Glenys entry as its first item — the repo had no
TODO file before; GTA-side items live in GTA Fredericton's TODO.md.)

## Glenys — the cat-chaser (Daniel, 2026-10-24 23:30 + 23:32, LOCKED SPEC)

Daniel's mother Glenys, as an NPC in 255 Massey. His framing is
affectionate — she earned a master's degree in computer science in
the 1960s, and he reckons she'd appreciate being in a computer game
if she still knew what one was. Tone: warm comedy. Never mockery,
never horror.

- [x] **The chaser.** A demented woman with a cane who chases and
  grabs the cats. In this game she chases the PLAYABLE cat (Willie
  or Aggie, whoever the player controls). Cane-paced pursuit: not
  fast (~0.8 m/s), but relentless — predictive corner-cutting, she
  follows across zone travel (arriving through the same connector
  after a delay), and she occasionally forgets mid-pursuit, pauses
  confused for a few seconds, then resumes.
- [x] **Grab = struggle, never injury.** A grab is a caught state:
  the cat is held, controls locked, and the player FIGHTS to get
  away (wiggle/struggle escape, ~2–3 s of effort), gets dropped,
  and gets a short escape burst. A grab costs control and time —
  NEVER hit points. If the cat was carrying a mouse catch, the grab
  drops it (the mouse respawns; wins stay reachable). A cat on an
  occupant's lap is safe from her.
- [x] **Chocolate (extension, 23:32).** She tries to feed the cat
  chocolate — she means it as a treat; the hazard is the chocolate.
  Eating it KILLS the cat: a run-ending death state (Daniel's
  words), NOT a normal nine-lives faint. The feeding attempt must
  be avoidable/refusable: proximity or her offering never
  auto-kills; death happens only when the cat actually EATS — a
  deliberate, clearly-telegraphed act by the cat (labelled poison,
  hold-to-eat with a visible progress cue).
- [x] **Rat poison (extension, 23:32).** Old rat poison in the
  basement — same lethality if the cat gets INTO it. Visible and
  avoidable: a clearly-readable poison bait (labelled), placed off
  every required path; death only on contact with the bait itself,
  never an invisible or unavoidable trigger.
- [x] **Basement dressing (extension, 23:32).** Raise the
  basement's prop/clutter density — more old tools and stored junk.
  Hard constraint: dressing must not break the basement suite (the
  maze MAP, the entrance→heart BFS walk, the Aggie-gap physics) —
  props sit clear of paths or carry no collision.

The ONLY lethal hazards in her design are the two poisons, and only
on eating/getting into them. Everything else about Glenys is
inconvenience and comedy.

Status: DONE on branch `glenys` (PR #14, lane closed 2026-10-25). Glenys suite 44/44; full battery green with her live (smoke 52, duo 51, massey 61, basement 53, attic 49, outside 67, occupants 51).
