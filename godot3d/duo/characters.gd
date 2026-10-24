class_name DuoCharacters
extends RefCounted
## DUO — the two playable cats, as data.
##
## Reads res://cat_kit/cat_species.json DEFENSIVELY: the flat schema
## that ships today (one cat — name/palette/game at the top level) and
## the "characters" structure the appearance lane is moving to.
## Anything missing falls back to the values here, so this code keeps
## working across that schema change. Names always come from the
## data when the data has them; code never hardcodes a cat's name.

const DATA_PATH := "res://cat_kit/cat_species.json"

## The cat chosen on the select screen. Static on purpose: R /
## RESTART reloads the scene, and the choice should survive that.
static var last_choice := ""

const WILLIE_TRAITS := [
	"Big & plush — the handsome boy",
	"Meows CONSTANTLY (M key / MEOW button)",
	"Standard paw strike",
]
const AGGIE_TRAITS := [
	"Small & wiry — half his size, twice the fight",
	"Chill... until Willie's meowing provokes her",
	"Faster, with a burst strike",
]


static func load_all() -> Dictionary:
	var raw: Dictionary = {}
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			raw = parsed
	var chars := {
		"willie": _willie_from_flat(raw),
		"aggie": _aggie_default(),
	}
	# Future schema: a "characters" object (id -> entry) or a list of
	# entries with id/name. Overlay whatever it provides.
	var future: Variant = raw.get("characters", null)
	if typeof(future) == TYPE_DICTIONARY:
		var cd: Dictionary = future
		for key: Variant in cd:
			if typeof(cd[key]) == TYPE_DICTIONARY:
				_overlay(chars, String(key).to_lower(), cd[key])
	elif typeof(future) == TYPE_ARRAY:
		for e: Variant in future:
			if typeof(e) == TYPE_DICTIONARY:
				var ed: Dictionary = e
				_overlay(chars, String(ed.get("id", ed.get("name", ""))).to_lower(), ed)
	return chars


## Push a character's data onto a kit cat. MUST run before the cat is
## added to the tree: the kit builds its model in _ready(). Uses set()
## throughout so a field the kit renames can never crash the game.
static func apply(cat: Object, ch: Dictionary) -> void:
	cat.set("species_name", String(ch.get("name", "Cat")))
	cat.set("coat", ch.get("coat", Color.WHITE))
	cat.set("ginger", ch.get("patch", Color(0.9098, 0.6863, 0.3294)))
	cat.set("nose_color", ch.get("nose", Color(0.851, 0.549, 0.478)))
	cat.set("eye_color", ch.get("eye", Color(0.10, 0.08, 0.07)))
	cat.set("model_scale", float(ch.get("scale", 0.32)))
	cat.set("walk_speed", float(ch.get("walk_speed", 2.4)))
	cat.set("stalk_speed", float(ch.get("stalk_speed", 1.2)))
	cat.set("sprint_speed", float(ch.get("sprint_speed", 5.0)))
	cat.set("strike_range", float(ch.get("strike_range", 0.55)))
	cat.set("strike_cooldown", float(ch.get("strike_cooldown", 0.38)))
	cat.set("stamina_drain", float(ch.get("stamina_drain", 22.0)))
	cat.set("stamina_regen", float(ch.get("stamina_regen", 14.0)))


static func _willie_from_flat(d: Dictionary) -> Dictionary:
	var pal: Dictionary = d.get("palette", {}) if typeof(d.get("palette")) == TYPE_DICTIONARY else {}
	var g: Dictionary = d.get("game", {}) if typeof(d.get("game")) == TYPE_DICTIONARY else {}
	return {
		"id": "willie",
		"name": String(d.get("name", "Willy")),
		"scale": float(d.get("scale", 0.35)),
		"coat": _col(pal.get("coat", d.get("color", [])), Color(1, 1, 1)),
		"patch": _col(pal.get("ginger", []), Color(0.9098, 0.6863, 0.3294)),
		"nose": _col(pal.get("nose", []), Color(0.851, 0.549, 0.478)),
		"eye": _col(pal.get("eye", []), Color(0.10, 0.08, 0.07)),
		"walk_speed": float(g.get("walk_speed", 2.4)),
		"stalk_speed": float(g.get("stalk_speed", 1.2)),
		"sprint_speed": float(g.get("sprint_speed", 5.0)),
		"strike_range": float(g.get("strike_range", 0.55)),
		"strike_cooldown": float(g.get("strike_cooldown", 0.38)),
		"stamina_drain": float(g.get("stamina_drain", 22.0)),
		"stamina_regen": float(g.get("stamina_regen", 14.0)),
		"traits": WILLIE_TRAITS.duplicate(),
		"blurb": "The big boy. Loud, plush, and in everyone's way.",
		"meow": "willie",
	}


static func _aggie_default() -> Dictionary:
	# Daniel's tortoiseshell girl, from her photos: a warm black-brown
	# coat with orange mottling, green-gold eyes. Half Willie's size.
	return {
		"id": "aggie",
		"name": "Aggie",
		"scale": 0.25,
		"coat": Color(0.141, 0.110, 0.090), # #241C17 warm tortie black-brown
		"patch": Color(0.690, 0.431, 0.173), # #B06E2C tortie orange
		"nose": Color(0.30, 0.20, 0.18),
		"eye": Color(0.45, 0.52, 0.20), # green-gold
		"walk_speed": 3.0,
		"stalk_speed": 1.6,
		"sprint_speed": 6.3,
		"strike_range": 0.60,
		"strike_cooldown": 0.20, # the burst strike
		"stamina_drain": 26.0,
		"stamina_regen": 16.0,
		"traits": AGGIE_TRAITS.duplicate(),
		"blurb": "The little terror. Chill — until he starts meowing.",
		"meow": "aggie",
	}


static func _overlay(chars: Dictionary, id: String, e: Dictionary) -> void:
	if id == "":
		return
	var base: Dictionary = chars.get(id, {})
	if base.is_empty():
		base = _aggie_default() if id != "willie" else _willie_from_flat({})
		base["id"] = id
	var pal: Dictionary = e.get("palette", {}) if typeof(e.get("palette")) == TYPE_DICTIONARY else {}
	var g: Dictionary = e.get("game", {}) if typeof(e.get("game")) == TYPE_DICTIONARY else {}
	if e.has("name"):
		base["name"] = String(e["name"])
	if e.has("scale"):
		base["scale"] = float(e["scale"])
	elif e.has("model_scale"):
		base["scale"] = float(e["model_scale"])
	var coat_v: Variant = pal.get("coat", pal.get("base", e.get("coat", e.get("color", []))))
	base["coat"] = _col(coat_v, base["coat"])
	base["patch"] = _col(pal.get("ginger", e.get("patch", e.get("ginger", []))), base["patch"])
	base["nose"] = _col(pal.get("nose", e.get("nose", [])), base["nose"])
	base["eye"] = _col(pal.get("eye", e.get("eye", [])), base["eye"])
	for k in ["walk_speed", "stalk_speed", "sprint_speed", "strike_range", "strike_cooldown", "stamina_drain", "stamina_regen"]:
		if g.has(k):
			base[k] = float(g[k])
		elif e.has(k):
			base[k] = float(e[k])
	if typeof(e.get("traits")) == TYPE_ARRAY:
		var tr: Array = []
		for t: Variant in e["traits"]:
			tr.append(String(t))
		if not tr.is_empty():
			base["traits"] = tr
	if e.has("blurb"):
		base["blurb"] = String(e["blurb"])
	chars[id] = base


static func _col(v: Variant, fallback: Color) -> Color:
	if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	if typeof(v) == TYPE_COLOR:
		return v
	return fallback
