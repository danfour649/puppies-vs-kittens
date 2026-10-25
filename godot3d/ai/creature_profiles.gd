class_name CreatureProfiles
extends RefCounted
## Species behaviour, from the natural-history notes the game is
## built on. Numbers are the knobs; the brain interprets them.
##
## Mice: wall-hugging, runway reuse, nocturnal, many nibble spots
## (they do not cache), freeze or flee on cat scent or sound, and
## they are NOT strongly wary of new objects.
## Rats: the same senses, but they ARE wary of new things.
## Songbirds: forage, flock, alarm, mob outdoors; indoors they
## panic-fly toward light.
## The other cat: territorial, crepuscular, perches high, and
## hunts stalk → crouch → pounce.


static func get_profile(id: String) -> Dictionary:
	match id:
		"mouse":
			return mouse()
		"rat":
			return rat()
		"songbird":
			return songbird()
		"other_cat":
			return other_cat()
		_:
			return mouse()


static func mouse() -> Dictionary:
	return {
		"id": "mouse",
		"nocturnal": true,
		"thigmotaxis": 1.7,
		"runway_reuse": 0.7,
		"cache_food": false,
		"neophobia": 0.12,
		"freeze_danger": 0.42,
		"flee_danger": 0.70,
		"sight_range": 2.4,
		"sight_fov": 220.0,
		"hearing_range": 2.4,
		"wander_speed": 1.2,
		"flee_speed": 3.05,
		"flee_tired": 1.95,
		"flee_burst": 1.2,
		"states": ["idle", "nibble", "runway", "freeze", "flee"],
	}


static func rat() -> Dictionary:
	return {
		"id": "rat",
		"nocturnal": true,
		"thigmotaxis": 1.1,
		"runway_reuse": 0.55,
		"cache_food": true,
		"neophobia": 0.88,
		"freeze_danger": 0.55,
		"flee_danger": 0.85,
		"sight_range": 4.5,
		"sight_fov": 200.0,
		"hearing_range": 4.5,
		"wander_speed": 0.8,
		"flee_speed": 3.4,
		"chase_speed": 2.7,
		"states": ["idle", "wander", "avoid", "chase", "flee"],
	}


static func songbird() -> Dictionary:
	return {
		"id": "songbird",
		"flock": true,
		"alarm": true,
		"mob_range": 4.5,
		"sight_range": 7.0,
		"sight_fov": 280.0,
		"hearing_range": 8.0,
		"forage_speed": 0.7,
		"flock_speed": 1.6,
		"panic_speed": 4.2,
		"mob_speed": 2.1,
		"states": ["forage", "flock", "alarm", "mob", "panic_light"],
	}


static func other_cat() -> Dictionary:
	return {
		"id": "other_cat",
		"crepuscular": true,
		"territorial": true,
		"sight_range": 8.0,
		"sight_fov": 150.0,
		"hearing_range": 6.0,
		"stalk_speed": 0.85,
		"pounce_speed": 4.4,
		"crouch_range": 1.65,
		"pounce_range": 0.85,
		"crouch_time": 0.35,
		"pounce_time": 0.32,
		"states": ["perch", "patrol", "stalk", "crouch", "pounce", "recover"],
	}


static func neophobia_of(id: String) -> float:
	return float(get_profile(id).get("neophobia", 0.0))


## Mice investigate a new teapot. Rats do not.
static func investigates_novel(id: String) -> bool:
	return neophobia_of(id) < 0.4


## 1 at midnight, 0 at noon.
static func nocturnal_activity(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	return clampf((cos(h / 24.0 * TAU) + 1.0) * 0.5, 0.0, 1.0)


## Peaks near 06:30 and 18:30. Low at noon and in the deep night.
static func crepuscular_activity(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	var dawn := exp(-pow(_hour_distance(h, 6.5), 2.0) / 4.2)
	var dusk := exp(-pow(_hour_distance(h, 18.5), 2.0) / 4.2)
	return clampf(maxf(dawn, dusk), 0.0, 1.0)


static func _hour_distance(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 24.0 - d)
