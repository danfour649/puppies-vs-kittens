class_name FloorAmbience
extends Node3D
## A quiet bed for one floor. The basement drips, the kitchen
## hums, the attic wind moves. Creaks visit all three. None of
## them are loud enough to hide a mouse.


var floor_name := "basement"
var _drip: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _bed: AudioStreamPlayer3D
var _wait := 1.4
var _creak_wait := 6.0
var _rng := RandomNumberGenerator.new()


static func attach(parent: Node, which: String) -> FloorAmbience:
	var node := FloorAmbience.new()
	node.floor_name = which
	node.name = "FloorAmbience"
	parent.add_child(node)
	return node


func _ready() -> void:
	_rng.seed = hash(floor_name) + 17
	_drip = HouseAudio.make_player(self, "drip", false)
	_creak = HouseAudio.make_player(self, "creak", false)
	var bed := ""
	if floor_name == "ground":
		bed = "fridge"
	elif floor_name == "attic":
		bed = "wind"
	if bed != "":
		_bed = HouseAudio.make_player(self, bed, true)
		if _bed.stream != null:
			_bed.play()
	_place(_drip if floor_name == "basement" else _creak)


func _process(delta: float) -> void:
	_wait -= delta
	_creak_wait -= delta
	if floor_name == "basement" and _wait <= 0.0:
		_wait = _rng.randf_range(1.8, 4.4)
		_place(_drip)
		if _drip.stream != null:
			_drip.play()
	if _creak_wait <= 0.0:
		_creak_wait = _rng.randf_range(7.0, 16.0)
		_place(_creak)
		if _creak.stream != null:
			_creak.play()


func _place(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	player.position = Vector3(_rng.randf_range(-3.0, 3.0), 0.4, _rng.randf_range(-3.0, 3.0))
