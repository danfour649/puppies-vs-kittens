extends Node
## REALISM pass shots: before/after evidence for the animation +
## detail iteration. Staged against main.tscn under Xvfb (real
## rendering):
##   xvfb-run godot --path godot3d res://tools/realism_shots.tscn
## Saves res://screenshots/realism_*.png. Run it BEFORE the pass and
## again AFTER; the staging is identical so frames compare 1:1.
## NOTE: input is camera-relative — set the camera yaw BEFORE
## driving, and keep the follow anchor tracking during waits or the
## smoothing rig lags a beat behind the cat.

var _game = null
var _anchor: Node3D = null
var _track: Node3D = null # node the anchor follows while waiting


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		var step: float = minf(0.05, sec - t)
		await get_tree().create_timer(step).timeout
		t += step
		if _track != null and _anchor != null:
			_anchor.global_position = _track.global_position + Vector3(0, 0.15, 0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % shot_name)
	print("SHOT saved ", shot_name, " ", img.get_size())


func _follow(node: Node3D, dist: float, pitch: float, yaw: float) -> void:
	if _anchor == null:
		_anchor = Node3D.new()
		_game.add_child(_anchor)
		_game.cam_anchor = _anchor
	_track = node
	_anchor.global_position = node.global_position + Vector3(0, 0.15, 0)
	_game.cam_dist = dist
	_game.cam_pitch = pitch
	_game.cam_yaw = yaw


func _drive(move: Vector2, sprint: bool, stalk: bool) -> void:
	_game.input_override = {"active": true, "move": move, "sprint": sprint, "stalk": stalk}


func _stop() -> void:
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.0)
	if _game.duo != null and _game.duo.select_visible():
		_game.duo.choose("willie")
		await _wait(0.4)
	var cat = _game.cat
	var suns: Array = _game.find_children("*", "DirectionalLight3D")
	if suns.size() > 0:
		(suns[0] as DirectionalLight3D).light_energy = 0.95

	# -- 1) Stride strip: fixed camera, Willie crosses in profile.
	# (Input is camera-relative, so a follow cam can never see his
	# flank — park the anchor on his path and strafe him across it.)
	_track = null
	_anchor = Node3D.new()
	_game.add_child(_anchor)
	_game.cam_anchor = _anchor
	_anchor.global_position = Vector3(-4.2, 0.28, 3.0)
	_game.cam_dist = 2.4
	_game.cam_pitch = -0.18
	_game.cam_yaw = PI
	cat.global_position = Vector3(-1.2, 0.1, 3.0)
	cat.velocity = Vector3.ZERO
	await _wait(0.5)
	_drive(Vector2(1, 0), false, false) # rig-right at yaw PI = world -X
	for i in 4:
		await _wait(0.55 if i == 0 else 0.17)
		await _shot("realism_stride_%d" % (i + 1))
	# -- 2) The turn: sprint across, then cut away north; catch the lean.
	_drive(Vector2(1, 0), true, false)
	await _wait(0.45)
	_drive(Vector2(0, 1), true, false)
	await _wait(0.16)
	await _shot("realism_turn")
	_stop()
	cat.velocity = Vector3.ZERO
	_follow(cat, 1.15, -0.28, PI * 0.75)
	# -- 3) Idle repertoire: leave him standing; ~13 s in.
	await _wait(12.5)
	await _shot("realism_idle")
	# -- 4) Aggie close-up (the tortie read, wherever she is posted).
	var aggie = _game.aggie
	_follow(aggie, 0.65, -0.3, -2.0)
	await _wait(0.8)
	await _shot("realism_aggie")
	# -- 5) Squirrel mid-bound: stage a flee run at its tree.
	var squirrels: Array = _game.find_children("Squirrel*", "", true, false)
	if squirrels.size() > 0:
		var sq = squirrels[0]
		cat.global_position = Vector3(8.0, 0.1, 6.0) # Willie out of frame
		cat.velocity = Vector3.ZERO
		var tree_pos: Vector3 = sq.get("home_tree").global_position
		var out_dir: Vector3 = (sq.global_position - tree_pos)
		out_dir.y = 0.0
		out_dir = out_dir.normalized() if out_dir.length() > 0.1 else Vector3.RIGHT
		sq.global_position = tree_pos + out_dir * 4.6 # a real run home
		sq.global_position.y = 0.0
		_follow(sq, 1.5, -0.3, PI * 0.5)
		sq.set("state", "flee")
		await _wait(0.2)
		await _shot("realism_squirrel")
	else:
		print("SHOT skipped squirrel (none found)")
	# -- 6) Yard wide: house front, fence, dressing.
	cat.global_position = Vector3(1.5, 0.1, 4.0)
	cat.velocity = Vector3.ZERO
	_track = null
	_anchor.global_position = Vector3(0, 0.6, 3.0)
	_game.cam_dist = 9.0
	_game.cam_pitch = -0.5
	_game.cam_yaw = PI
	await _wait(0.8)
	await _shot("realism_yard")
	# -- 7) Hub interior: through the front door, living-room side.
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await _wait(0.9)
	cat.global_position = Vector3(4.15, 0.05, -201.95)
	cat.velocity = Vector3.ZERO
	cat.rotation.y = -0.4
	_track = null
	_anchor.global_position = Vector3(4.6, 0.65, -199.4)
	_game.cam_dist = 3.9
	_game.cam_pitch = -0.30
	_game.cam_yaw = 0.35
	await _wait(0.8)
	await _shot("realism_hub")
	print("REALISM SHOTS DONE")
	get_tree().quit(0)
