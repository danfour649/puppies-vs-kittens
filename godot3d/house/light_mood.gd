class_name LightMood
extends RefCounted
## Three hours at 255 Massey. The yard and the ground floor sit at
## dusk, the basement is the night, the attic is dawn through the
## round window. Travel fades through that colour instead of a
## loading black, so a doorway feels like a change of light.


const ZONE_MOOD := {
	"outside": "dusk",
	"ground_floor": "dusk",
	"basement": "night",
	"attic": "dawn",
}


static func for_zone(zone_id: String) -> String:
	return String(ZONE_MOOD.get(zone_id, "dusk"))


static func palette(mood: String) -> Dictionary:
	match mood:
		"night":
			return {
				"ambient": Color(0.07, 0.09, 0.16),
				"window": Color(0.62, 0.74, 0.98),
				"fill": Color(1.0, 0.74, 0.46),
				"energy": 1.05,
				"fill_energy": 0.55,
			}
		"dawn":
			return {
				"ambient": Color(0.55, 0.40, 0.34),
				"window": Color(1.0, 0.78, 0.58),
				"fill": Color(0.96, 0.84, 0.70),
				"energy": 1.55,
				"fill_energy": 0.42,
			}
		_:
			return {
				"ambient": Color(0.40, 0.22, 0.14),
				"window": Color(1.0, 0.52, 0.26),
				"fill": Color(1.0, 0.78, 0.50),
				"energy": 1.35,
				"fill_energy": 0.48,
			}


static func fade_tint(zone_id: String) -> Color:
	var ambient: Color = palette(for_zone(zone_id))["ambient"]
	return ambient.darkened(0.42)


static func window_color(zone_id: String) -> Color:
	return palette(for_zone(zone_id))["window"]
