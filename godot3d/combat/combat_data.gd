class_name CombatData
extends RefCounted
## COMBAT DATA — the shared damage table for Willie and Aggie.
##
## One place where every damage number and knockback style lives,
## so the zone lanes and the cats' health system can never drift
## apart. Enemy configs carry their own raw `damage` number; the
## PROFILES below describe what a hit *means* when it lands on a cat
## (knockback strength, launch) and what the cats' paws deal out.
##
## Profile keys:
##   damage      flat HP (ignored when damage_frac is present)
##   damage_frac fraction of the VICTIM's max HP (vehicle_hit)
##   knockback   horizontal impulse speed (m/s) away from the source
##   launch      true = pop the victim up hard (vehicle_hit)

const PROFILES := {
	# What the cats deal.
	"paw_willie": {"damage": 12.0, "knockback": 3.0},
	"paw_aggie": {"damage": 9.0, "knockback": 3.6},
	# What the world deals to the cats (zone lanes: pass these to
	# cat.take_damage(amount, from_pos, CombatData.profile(id)) —
	# or just configure your PvKEnemy with the matching damage).
	"rat_bite": {"damage": 8.0, "knockback": 2.0},
	"spider_bite": {"damage": 6.0, "knockback": 1.5},
	"spider_drop": {"damage": 8.0, "knockback": 1.0},
	"raccoon_swipe": {"damage": 12.0, "knockback": 3.5},
	"raccoon_charge": {"damage": 18.0, "knockback": 5.0},
	"squirrel_scratch": {"damage": 4.0, "knockback": 1.5},
	"bird_peck": {"damage": 3.0, "knockback": 1.0},
	"dog_bite": {"damage": 14.0, "knockback": 4.0},
	# The road (outside lane): a car that connects takes ~60% of a
	# cat's HP and LAUNCHES him — two hits ≈ one of the nine lives.
	# The honk is the telegraph; the parked Corolla is the safe island.
	"vehicle_hit": {"damage_frac": 0.6, "knockback": 9.0, "launch": true},
}


static func profile(id: String) -> Dictionary:
	var p: Variant = PROFILES.get(id, {})
	return (p as Dictionary).duplicate() if typeof(p) == TYPE_DICTIONARY else {}


## The paw profile for whichever cat is swinging.
static func paw_profile(cat: PvKCat) -> Dictionary:
	return profile("paw_aggie" if cat.character_id == "aggie" else "paw_willie")
