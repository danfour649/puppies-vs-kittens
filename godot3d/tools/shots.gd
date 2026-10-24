extends Node
## Standing-shot pass for Puppies vs Kittens 3D. Run under Xvfb (real
## rendering, unlike the headless smoke test):
##   xvfb-run godot --path godot3d res://tools/shots.tscn
## Saves four PNGs into res://screenshots/: willie_closeup,
## aggie_closeup, both_cats, lounge.

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
	var sun: DirectionalLight3D = null
	if suns.size() > 0:
		sun = suns[0] as DirectionalLight3D
	# (a) Willie close-up: 3/4 front view, cat idle (breathing).
	# Genuinely close, and the sun eased for this shot only so the
	# white coat and rich ginger don't blow out under midday light.
	if sun != null:
		sun.light_energy = 0.85
	_game.cam_dist = 0.8
	_game.cam_pitch = -0.18
	_game.cam_yaw = -0.6
	await _wait(0.7)
	await _shot("willie_closeup")
	if sun != null:
		sun.light_energy = 1.05
	# (b) Aggie close-up: she lounges on the garden chair; anchor the
	# camera on her and come in close from her front-left.
	_anchor_at(_game.aggie.global_position + Vector3(0, 0.13, 0))
	_game.cam_dist = 0.45
	_game.cam_pitch = -0.25
	_game.cam_yaw = -2.0
	await _wait(0.7)
	await _shot("aggie_closeup")
	# (c) Both cats: Willie staged on the lawn in front of Aggie's
	# chair, looking up at her; wide enough to read both at once.
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(3.45, 0.08, 3.30)
	_game.cat.rotation.y = 2.45
	_anchor_at(Vector3(4.05, 0.30, 3.95))
	_game.cam_dist = 2.0
	_game.cam_pitch = -0.38
	_game.cam_yaw = -2.35
	await _wait(0.8)
	await _shot("both_cats")
	# (d) The lounge: Willie flopped on the porch deck.
	_game.cam_anchor = null
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(2.5, 0.34, -8.7)
	_game.cat.rotation.y = PI # face into the yard
	await _wait(0.5)
	_game.cat.set_lounge(true)
	_game.cam_yaw = 0.5
	_game.cam_dist = 1.2
	_game.cam_pitch = -0.35
	await _wait(1.0)
	await _shot("lounge")
	print("SHOTS DONE")
	get_tree().quit(0)
