class_name HouseAudio
extends RefCounted
## Positional voices for the house. The clips are self-generated
## (tools/synth_house_audio.py): no third-party samples.
##
## Web loads res://audio/web at 24 kbit/s mono. Desktop loads
## res://audio/desktop at 64 kbit/s. The web export excludes the
## desktop folder so the pack stays inside its budget.
##
## Mouse cues are the loudest nearby sounds a stalking cat hears.
## A squeak reaches MOUSE_REACH metres and then falls off; the
## fridge, the wind and the drip sit about 18 dB under that, so
## they do not cover the scurry.


const WEB_BITRATE := 24
const DESKTOP_BITRATE := 64
const MOUSE_REACH := 6.5
const MOUSE_UNIT := 0.85

const MIX := {
	"meow": {"db": -7.0, "unit": 2.5, "reach": 22.0},
	"chirp": {"db": -8.0, "unit": 2.0, "reach": 16.0},
	"chatter": {"db": -11.0, "unit": 1.3, "reach": 8.0},
	"trill": {"db": -9.0, "unit": 1.6, "reach": 10.0},
	"purr": {"db": -16.0, "unit": 1.1, "reach": 5.5},
	"hiss": {"db": -4.0, "unit": 1.6, "reach": 16.0},
	"scrabble": {"db": -8.0, "unit": 1.4, "reach": 9.0},
	"squeak": {"db": -8.0, "unit": MOUSE_UNIT, "reach": MOUSE_REACH},
	"scurry": {"db": -15.0, "unit": 0.55, "reach": 5.0},
	"alarm": {"db": -6.0, "unit": 2.2, "reach": 16.0},
	"wingbeat": {"db": -12.0, "unit": 1.2, "reach": 8.0},
	"creak": {"db": -20.0, "unit": 3.5, "reach": 14.0},
	"fridge": {"db": -26.0, "unit": 4.0, "reach": 12.0},
	"wind": {"db": -24.0, "unit": 5.0, "reach": 18.0},
	"drip": {"db": -18.0, "unit": 2.2, "reach": 10.0},
}

const LOOPS := ["purr", "scrabble", "scurry", "wingbeat", "fridge", "wind"]


static func folder() -> String:
	return "web" if OS.has_feature("web") else "desktop"


static func uses_low_bitrate() -> bool:
	return OS.has_feature("web")


static func stream(kind: String) -> AudioStream:
	var path := "res://audio/%s/%s.ogg" % [folder(), kind]
	if not ResourceLoader.exists(path):
		path = "res://audio/web/%s.ogg" % kind
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


static func file_bytes(which: String, kind: String) -> int:
	var path := ProjectSettings.globalize_path("res://audio/%s/%s.ogg" % [which, kind])
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n


static func make_player(parent: Node, kind: String, looping: bool = false) -> AudioStreamPlayer3D:
	var mix: Dictionary = MIX.get(kind, {"db": -12.0, "unit": 1.5, "reach": 8.0})
	var player := AudioStreamPlayer3D.new()
	player.name = "Voice_%s" % kind
	var src := stream(kind)
	if src is AudioStreamOggVorbis:
		src = src.duplicate()
		(src as AudioStreamOggVorbis).loop = looping or kind in LOOPS
	player.stream = src
	player.volume_db = float(mix["db"])
	player.unit_size = float(mix["unit"])
	player.max_distance = float(mix["reach"])
	player.max_polyphony = 1
	parent.add_child(player)
	return player
