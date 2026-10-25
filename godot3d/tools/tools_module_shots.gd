extends Node
## MODULE shots: the cat start played in the REAL game — boot
## main.tscn, the character select over the yard, then the
## module's choose_cat("aggie") lands both cats inside the
## ground-floor hub. Staged under Xvfb:
##   xvfb-run godot --path godot3d res://tools/tools_module_shots.tscn
## Saves into res://screenshots/. Prints its outcome asserts.

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


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.2)
	print("MODULE SHOTS: select visible at boot: ", _game.duo.select_visible())
	await _shot("module_select")
	# The module cat start, in the real game: pick Aggie, wake up
	# in the house (module/massey_module.gd choose_cat).
	_game.module.choose_cat("aggie")
	await _wait(1.4)
	var cat = _game.cat
	print("MODULE SHOTS: player is Aggie: ", _game.duo.player_id() == "aggie")
	print("MODULE SHOTS: zone after start: ", _game.zones.current_zone)
	print("MODULE SHOTS: player cat at ", cat.global_position, " (hub entry is (2.5, 0, -196.45))")
	print("MODULE SHOTS: sibling at ", _game.duo.sibling_cat().global_position)
	var anchor := Node3D.new()
	anchor.position = Vector3(2.5, 0.25, -195.9)
	_game.add_child(anchor)
	_game.cam_anchor = anchor
	_game.cam_dist = 2.4
	_game.cam_pitch = -0.58
	_game.cam_yaw = PI
	await _wait(0.9)
	await _shot("module_cat_start_hub")
	print("MODULE SHOTS DONE")
	get_tree().quit(0)
