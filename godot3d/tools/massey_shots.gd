extends Node
## MASSEY standing shots: the ground-floor hub and the front-door
## connector, under Xvfb (real rendering):
##   xvfb-run godot --path godot3d res://tools/massey_shots.tscn
## Saves massey_ground_floor.png + massey_front_door.png into
## res://screenshots/.
##
## Framing notes: the game camera is a SpringArm — indoors it
## shortens on wall contact, so anchors sit in open floor and the
## distances stay short. The door shot anchors OUT in the yard:
## anchoring at the door itself parks the arm inside the porch.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % shot_name)
	print("SHOT saved ", shot_name, " ", img.get_size())


func _anchor_at(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	_game.add_child(n)
	_game.cam_anchor = n


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.0)
	if _game.duo != null and _game.duo.select_visible():
		_game.duo.choose("willie")
		await _wait(0.4)
	var suns: Array = _game.find_children("*", "DirectionalLight3D")
	if suns.size() > 0:
		(suns[0] as DirectionalLight3D).light_energy = 0.9
	# (a) The hub: anchor over the living-room rug, camera short-
	# armed to the south-east, looking north-west — sofa, TV wall,
	# rug and coffee table, kitchen through the divider gap.
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await _wait(0.8)
	_anchor_at(Vector3(3.2, 0.6, -201.5))
	_game.cam_dist = 2.6
	_game.cam_pitch = -0.22
	_game.cam_yaw = 0.85
	await _wait(0.9)
	await _shot("massey_ground_floor")
	# (b) The front door from the yard: anchor in open lawn south
	# of the porch, camera behind it — porch, door, the player cat
	# on the entry, and the connector disc in one frame.
	_game.zones.travel(HouseSpec.OUTSIDE, "EntryFrontDoor", true)
	await _wait(0.8)
	_anchor_at(Vector3(2.5, 0.55, -7.1))
	_game.cam_dist = 2.4
	_game.cam_pitch = -0.22
	_game.cam_yaw = 0.12
	await _wait(0.9)
	await _shot("massey_front_door")
	get_tree().quit(0)
