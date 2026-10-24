# Willie and Aggie — the Massey Outside Zone

Everything outside the back door of 255 Massey Street: the yard's
trees and squirrels, the bird feeder and the bush ambush, the front
lawn, Massey Street itself (whose drivers are *hostile*), and the
neighbours who walk their dogs past the house.

All code lives in this folder (`godot3d/zones/outside/`). The only
edit outside it is one clearly-marked `OUTSIDE` block in `main.gd`'s
`_ready`, which creates an `OutsideSystem` and calls
`outside.setup(game)` right after the duo system — the same shape as
the duo hookup. Actors are procedural (boxes/capsules in the kit
idiom), synth audio is generated in code, and every placement and
tuning number lives in `outside_layout.gd` as a named constant.

## The house footprint (shared ground truth)

Placements are relative to the house as built by `main.gd` on
`origin/main`:

| Feature | Value |
|---|---|
| Back wall plane | z = −10.2, spans x ∈ [−8.5, 8.5] |
| Front wall face | z = −10.4 (the wall is 0.4 deep) |
| Back door | x = 2.5 |
| Back yard (fenced) | x ∈ [−12.4, 12.4], z ∈ [−9.4, 9.4] |
| Porch deck | (2.5, −8.7) |

> **Integration flag:** the foundation lane's `massey-zones.md`
> (branch `massey-foundation`) did not exist on origin when this
> zone was built, so the footprint above was derived from `main.gd`
> itself. If the foundation doc disagrees, reconcile against it —
> every position below is a constant in `outside_layout.gd`, so the
> whole zone moves by editing one file.

## Placements (all in `outside_layout.gd`)

| Thing | Position | Notes |
|---|---|---|
| Tree — west | (−10.6, 2.2) | branch reaches +X over the yard |
| Tree — east | (11.2, −1.8) | branch reaches −X |
| Tree — south | (−3.6, 7.6) | branch reaches −Z, toward the house |
| Bird feeder | (7.6, 3.2) | pole + tray, 3 perch slots |
| Ambush bush A | (6.1, 4.9) | flanks the feeder |
| Ambush bush B | (9.3, 1.7) | flanks the feeder |
| Ambush bush C | (5.9, 1.3) | flanks the feeder |
| Driveway | x ∈ [5.9, 8.5] | front lawn, meets the street |
| 2018 Corolla (silver) | (7.2, −12.6) | parked in the driveway, indestructible |
| Corolla shelter zone | x ∈ [6.0, 8.4], z ∈ [−15.15, −14.1] | the driveway-mouth strip the biased traffic physically clears |
| Fish treat | (2.5, −22.1) | far front yard, on the door axis |

Front bands, walking north from the house: front lawn
z ∈ [−13.2, −10.4] · sidewalk z ∈ [−14.1, −13.2] (walkers travel
z = −13.65) · **Massey Street** z ∈ [−19.7, −14.1] — near lane
z = −15.5 travels +X, far lane z = −18.3 travels −X, centre line
z = −16.9 · far sidewalk z ∈ [−20.6, −19.7] · far front-yard strip
z ∈ [−23.6, −20.6]. The street runs to x = ±18 (spawn/despawn).

## Squirrels + trees

Three trees (tapered trunk, two branches, blob canopy, a real trunk
collider). Squirrels forage on the ground — dig, sit-up lookouts,
little hops — and flee to their home tree when the player cat
closes inside 3.4 m (or lunges inside 5.0 m moving fast): up the
trunk at 2.3 m/s to the first branch (y = 1.3), where they taunt
(tail flicking) until the yard is calm for 4 s. On the branch a
squirrel is **safe from ground paws**. Catchable:

- **on the ground** — a strike within paw range: 1 hit, then it bolts;
- **mid-climb** — a paw at the trunk base while it climbs low
  (below y = 1.5): 75% catch chance per pounce;
- **never on the branch** — unless the cat climbs.

Squirrel HP is 2 strikes. A branch swipe knocks a taunting squirrel
off its perch (and costs it a hit).

**Cat trunk climb (stub harness).** Strike at a trunk base and the
cat takes to the trunk: pinned to the bark, W/S (or ↑/↓) climb at
0.85 m/s, Space swipes at the branch. Reaching the bottom steps off.
This is a local harness — when the foundation lane lands a real
PvKCat jump/pounce/climb, this stub should be replaced by it (the
seams are `OutsideSystem.try_start_climb/climb_swipe/end_climb`).

## Birds + the ambush

A pole feeder draws a constant stream of birds (robins, sparrows,
blue jays — procedural bodies, flapping wings): they curve in, land
on the feeder or the ground below, peck 2.6–4.4 s, hop between
perches, and leave. Endless respawn, capped at 6 concurrent.

The ambush is the cat-perspective core. In one of the three bushes
by the feeder, a cat that stays **still** (or in the kit stalk
state) is *hidden*: its scare radius collapses, the stillness meter
fills (HUD: "Still…" + bar, bottom-left), and birds start landing
close — inside pounce range of the bush. A strike from hiding
(genuine hidden state) reaches 1.8 m and counts as an ambush catch.
Moving early, or a bird spotting motion inside its scare radius,
bursts the flock off.

| Tuning | Willie | Aggie |
|---|---|---|
| Stillness fill time | 2.4 s | 2.0 s |
| Stillness decay (moving in bush) | 0.55 /s | 0.25 /s |
| Bird scare radius (moving) | 3.0 m | 2.3 m |
| … while still | ×0.45 | ×0.45 |
| … while hidden | ×0.12 | ×0.12 |

Aggie is simply better at this. Willie is Willie: **meowing while
hidden scatters every pecking bird within 7 m and empties the
meter** (wired to the duo system's meow — the same meow that winds
Aggie up).

## Massey Street — hostile traffic

Procedural cars (body + cabin + wheels, varied colours) run both
lanes at 7.5 ± 1.5 m/s, capped at 5 concurrent, spawning/despawning
at the street ends. They ignore cats off the road. Put the player
cat **on the road surface** and any car with the cat inside its
reaction window — 13 m ahead, same side — hunts it:

- steers toward the cat's position, swerve bounded to ±1.25 m
  around its lane centre;
- accelerates ×1.25;
- **honks** (synth horn) as the telegraph.

Contact at speed: **60 damage** (≈60% of a cat's HP — two hits cost
a life) plus a dramatic launch arc to the nearest curb and a screen
shake. A slow brush / edge clip: **10 damage** and a shove, no
launch.

The parked silver **2018 Corolla** in the driveway is the safe
island mid-crossing: a cat in its shelter zone is never targeted,
and traffic biases wide around the driveway mouth. Across the
street, the far front-yard strip holds a **fish treat** that fully
heals — crossing is worth the risk.

## Walkers + dogs (the heritage threat)

Every 25–45 s a person strolls the sidewalk with a dog on a visible
leash (4 shirt variants; the dog is small-and-yappy or big, 50/50).
The dog targets the **player cat only**, and only when the cat is
in the front zone (front yard / sidewalk / road):

- **HEEL** — walks, sniffs.
- **ALERT** — cat spotted within 9 m (2.2 m if the cat is hidden):
  ears up, barking (synth bark).
- **STRAIN** — lunges to the end of the 1.7 m leash; the owner
  leans back and skids. Comedic, and a warning.
- **SLIP** — cat within 1.2 m of the straining dog: the leash
  slips and the dog **CHASES** (5.9 m/s small, 5.4 m/s big — faster
  than Willie, about Aggie's pace; it cannot climb trees or enter
  the house).

Bites: small 12 damage, big 20 (≈15% HP standard). Two bites inside
2.5 s → **grab + shake: 30 damage**, then the cat bursts free in an
arc — no stunlock deaths. Escape valves, all real: climb a tree
(the dog circles the trunk ~3.5 s, then gives up), hide *still* in
a bush (one confused circle, ~2 s, then it loses the trail), run
inside the house, or outrun the 16 m / 14 s give-up. The dog then
trots back, the leash "reattaches", and the pair strolls on.

The sibling NPC is a backyard cat and stays out of this system
entirely; `OutsideSystem` additionally nudges it back if it ever
crosses the fence line (belt and braces — SiblingAI's spots are all
in the yard already).

## Damage contract (LOCAL — foundation reconciles)

The foundation lane owns the real cat HP / nine-lives profile.
Until it lands, `OutsideSystem` keeps a local ledger (HP max 100)
with these values in `outside_layout.gd`:

| Event | Damage |
|---|---|
| Vehicle hit at speed | 60 |
| Vehicle brush | 10 |
| Dog bite — small / big | 12 / 20 |
| Dog grab + shake | 30 |

`apply_damage()` duck-types: if PvKCat gains `take_damage(amount,
kind)` the ledger hands off and steps aside. On local death the
stub respawns the cat at the porch with full HP and counts a life
lost. The fish treat calls the same seam (`heal_full`).

## Objectives

| Id | Title | Target |
|---|---|---|
| first_bird | First bird | catch 1 bird |
| squirrel_treed | Squirrel treed x3 | tree 3 squirrels |
| ambush_master | Ambush master: 3 pounce catches | 3 hidden-bush catches |
| cross_massey_back | Cross Massey and back | 1 round trip |
| highway_cat | Highway cat: 3 crossings in one life | 3 crossings, no vehicle hit |
| dog_dodger | Dog dodger: escape 3 chases | 3 escapes, any valve |
| cool_cat | Cool cat | pass a fully-straining dog, no slip |

Progress lives in `OutsideSystem.objectives`; completions toast on
the HUD. (Persistence/tracking UI is the coordinator's layer.)

## Controls (outside additions)

- **Space at a trunk base** — start climbing (or pounce a climbing squirrel)
- **W / S while climbing** — up / down the trunk
- **Space at the branch** — swipe at a taunting squirrel
- **Ctrl/C (stalk) + stay still in a bush** — hide; watch the "Still…" meter
- **M (meow)** — as Willie, in a bush: scatter the flock. You know you want to.

## Tests + shots

```
godot --headless --path godot3d res://zones/outside/tests_outside.tscn
xvfb-run godot --path godot3d res://zones/outside/tools_outside_shots.tscn
```

Shots: `feeder_stream`, `ambush_bush`, `squirrel_taunt`,
`trunk_climb`, `road_crossing`, `dog_strain`, `dog_chase`
(saved to `res://screenshots/`).
