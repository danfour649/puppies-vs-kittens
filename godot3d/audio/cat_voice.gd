class_name CatVoice
extends Node
## Plays the manner voices on the cat. One-shots (meow, chirp,
## trill, hiss) retrigger. Loops follow the manner: chatter,
## purr while kneading or loafing, scrabble during zoomies.


var _loops: Dictionary = {}
var _shots: Dictionary = {}
var _greeted := false


func _ready() -> void:
	for kind in ["chatter", "purr", "scrabble"]:
		_loops[kind] = HouseAudio.make_player(self, kind, true)
	for kind in ["meow", "chirp", "trill", "hiss"]:
		_shots[kind] = HouseAudio.make_player(self, kind, false)


func speak(kind: String) -> void:
	var player := _shots.get(kind) as AudioStreamPlayer3D
	if player == null or player.stream == null:
		return
	player.play()


func _process(_delta: float) -> void:
	var cat := get_parent()
	if cat == null:
		return
	var manner := str(cat.get("manner"))
	_set_loop("chatter", manner == "chatter")
	_set_loop("purr", manner == "knead" or manner == "loaf")
	_set_loop("scrabble", manner == "zoomies")
	if manner == "greet":
		if not _greeted:
			speak("trill")
			_greeted = true
	else:
		_greeted = false


func _set_loop(kind: String, on: bool) -> void:
	var player := _loops.get(kind) as AudioStreamPlayer3D
	if player == null or player.stream == null:
		return
	if on and not player.playing:
		player.play()
	elif not on and player.playing:
		player.stop()
