extends Node
## DUO shot pass. Run under Xvfb (real rendering):
##   xvfb-run godot --path godot3d res://duo/tools_duo_shots.tscn
## Saves PNGs into res://screenshots/gameplay/.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/gameplay/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/gameplay")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.0)
	var duo = _game.duo
	# (a) Character select over the yard: both cats in frame behind
	# the cards (Willie at his spawn, Aggie on the chair).
	_game.cam_dist = 9.0
	_game.cam_pitch = -0.62
	_game.cam_yaw = PI
	await _wait(0.6)
	await _shot("character_select")
	# (b) The flurry: play as Willie, park Aggie next to him, meow.
	duo.choose("willie")
	for m in _game.mice:
		m.cat = null # freeze the mice for the photo
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(0.5, 0.05, 2.0)
	_game.cat.rotation.y = 0.4
	duo.sibling.autonomous = false
	duo.aggie_cat.velocity = Vector3.ZERO
	duo.aggie_cat.global_position = Vector3(-1.6, 0.05, 2.2)
	duo.aggie_cat.set_lounge(false)
	_game.cam_dist = 3.4
	_game.cam_pitch = -0.42
	_game.cam_yaw = PI + 0.5
	await _wait(0.4)
	for i in 3:
		duo.emit_meow(_game.cat)
		await _wait(0.15)
	# Wait for the dash/flurry, then catch her mid-strike.
	var t := 0.0
	while t < 3.0 and duo.sibling.mode != "flurry":
		await _wait(0.1)
		t += 0.1
	await _wait(0.55) # let a strike pose develop
	await _shot("aggie_dash")
	# (c) Both cats in the yard, roles swapped: you are Aggie now,
	# Willie lounges it off in the sunny patch.
	duo.choose("aggie")
	duo.sibling.go_lounge(Vector3(8.5, 0.0, 3.5))
	_game.cam_dist = 8.5
	_game.cam_pitch = -0.72
	_game.cam_yaw = PI
	await _wait(2.2)
	await _shot("both_cats_yard")
	print("DUO SHOTS DONE")
	get_tree().quit(0)
