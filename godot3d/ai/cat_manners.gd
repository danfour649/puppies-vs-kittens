class_name CatManners
extends RefCounted
## Feline ethology as gameplay knobs. No research file lives in the
## repo, so these follow the well-known patterns: chatter at prey
## behind glass, a butt-wiggle that lines up the pounce, zoomies
## after the tray or at dusk, slow blink and allogrooming as trust,
## kneading then loafing while resting, a tail-up greeting, batting
## objects off a ledge, and an ambush from under the furniture.
##
## Clip names are optional. CatSculpt blends one in when the rig has
## it, and leaves the pose alone when it does not.


const CLIP_NAMES: Array[String] = [
	"chatter", "wiggle", "zoomies", "blink", "groom", "knead", "loaf", "greet", "ambush",
]


## A full wiggle is a true pounce. No wiggle, and the landing scatters.
static func wiggle_accuracy(wiggle: float) -> float:
	return lerpf(0.42, 1.0, clampf(wiggle, 0.0, 1.0))


## Sideways miss, in metres. `unit` is -1..1 from the caller.
static func pounce_offset(forward: Vector3, wiggle: float, unit: float) -> Vector3:
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length() < 0.01:
		fwd = Vector3(0, 0, -1)
	else:
		fwd = fwd.normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var miss := (1.0 - wiggle_accuracy(wiggle)) * 1.15
	return side * clampf(unit, -1.0, 1.0) * miss


## The bird he can see past the glass, or INF when none qualifies.
## He has to be at the window and facing it. The bird stays outside
## his paw: chatter is what a cat does instead of a catch.
static func chatter_bird(cat_pos: Vector3, cat_fwd: Vector3, window_pos: Vector3, birds: Array, near := 1.7, sight := 6.5) -> Vector3:
	var to_glass := Vector3(window_pos.x - cat_pos.x, 0.0, window_pos.z - cat_pos.z)
	if to_glass.length() > near or to_glass.length() < 0.05:
		return Vector3.INF
	var fwd := Vector3(cat_fwd.x, 0.0, cat_fwd.z)
	if fwd.length() < 0.05 or fwd.normalized().dot(to_glass.normalized()) < 0.35:
		return Vector3.INF
	var best := Vector3.INF
	var best_d := sight
	for b: Variant in birds:
		var bp: Vector3 = b
		var d := Vector2(bp.x - window_pos.x, bp.z - window_pos.z).length()
		if d < best_d:
			best_d = d
			best = bp
	return best


## After the litter tray, or when the light is crepuscular and he is awake.
static func zoomies_wants(used_litter: bool, hour: float) -> bool:
	if used_litter:
		return true
	return CreatureProfiles.crepuscular_activity(hour) >= 0.72


static func blink_ready(dist: float, trust: float, calm: bool) -> bool:
	return calm and dist < 1.4 and trust < 1.0


static func blink_gain() -> float:
	return 0.2


static func groom_ready(dist: float, trust: float, calm: bool) -> bool:
	return calm and dist < 0.95 and trust >= 0.34


static func groom_heal() -> float:
	return 6.0


static func rest_heal(manner: String, delta: float) -> float:
	if manner == "knead":
		return 2.4 * delta
	if manner == "loaf":
		return 4.5 * delta
	return 0.0


## Tail up, walking toward her. Not a grab, and not a joke.
static func greeting(cat_pos: Vector3, cat_fwd: Vector3, glenys: Vector3, moving: bool) -> bool:
	if not moving:
		return false
	var to := Vector3(glenys.x - cat_pos.x, 0.0, glenys.z - cat_pos.z)
	var dist := to.length()
	if dist > 2.3 or dist < 0.25:
		return false
	var fwd := Vector3(cat_fwd.x, 0.0, cat_fwd.z)
	if fwd.length() < 0.05:
		return false
	return fwd.normalized().dot(to.normalized()) > 0.4


static func knock_mess() -> float:
	return 9.0


## Cover he should slip under on the way to prey. INF if none is useful.
static func ambush_cover(cat_pos: Vector3, prey_pos: Vector3, covers: Array) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var prey_from_cat := Vector2(prey_pos.x - cat_pos.x, prey_pos.z - cat_pos.z).length()
	for c: Variant in covers:
		var cp: Vector3 = c
		var from_cat := Vector2(cat_pos.x - cp.x, cat_pos.z - cp.z).length()
		if from_cat > 4.5:
			continue
		var d := Vector2(prey_pos.x - cp.x, prey_pos.z - cp.z).length()
		var useful := from_cat < 0.55 or d + 0.2 < prey_from_cat
		if useful and d < best_d:
			best_d = d
			best = cp
	return best
