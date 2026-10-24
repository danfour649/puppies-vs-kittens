extends Node
## Standing-shot pass for Puppies vs Kittens 3D. Run under Xvfb (real
## rendering, unlike the headless smoke test):
##   xvfb-run godot --path godot3d res://tools/shots.tscn
## Saves three PNGs into res://screenshots/.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.0)
	# (a) Cat close-up: 3/4 front view, cat idle (breathing). Genuinely
	# close, and the sun eased for this shot only so Willy's white coat
	# and ginger don't blow out under the game's midday lighting.
	var suns: Array = _game.find_children("*", "DirectionalLight3D")
	var sun: DirectionalLight3D = null
	if suns.size() > 0:
		sun = suns[0] as DirectionalLight3D
	if sun != null:
		sun.light_energy = 0.85
	_game.cam_dist = 0.8
	_game.cam_pitch = -0.18
	_game.cam_yaw = -0.6
	await _wait(0.7)
	await _shot("cat_closeup")
	if sun != null:
		sun.light_energy = 1.05
	# (b) Wide gameplay: cat walks into the yard among the mice.
	_game.cam_dist = 8.5
	_game.cam_pitch = -0.72
	_game.cam_yaw = PI
	_game.input_override = {"active": true, "move": Vector2(0.3, 1), "sprint": false, "stalk": false}
	await _wait(1.5)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	await _wait(0.4)
	await _shot("gameplay_wide")
	# (c) The lounge: cat teleported onto the garden chair, Willy flop.
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(4.5, 0.55, 4.5)
	_game.cat.rotation.y = 0.8
	await _wait(0.5)
	_game.cat.set_lounge(true)
	_game.cam_yaw = -2.36
	_game.cam_dist = 1.5
	_game.cam_pitch = -0.35
	await _wait(1.0)
	await _shot("lounge")
	print("SHOTS DONE")
	get_tree().quit(0)
