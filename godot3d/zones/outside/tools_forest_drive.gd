extends Node
## Massey forest + rose-hedge DRIVE verification (TODO #121 lane):
## walks the player cat with the game's real input_override seam
## and asserts, in a live boot:
##   A the south thorn hedge stops the cat where the fence did
##     (and the centre glade lane stays traversable end to end),
##   B the east hedge stops the cat, C the west hedge stops it,
##   E a forest trunk is solid (cat bumps, never clips through),
##   F the front-garden roses are ornamental (cat walks through
##     the bed to the house wall).
## Camera yaw is pinned to 0, so input_override move vectors map
## to world axes: (0,-1) south, (0,1) north, (1,0) east, (-1,0) west.
## Run under a display (weston/wayland on fola4.0):
##   godot --display-driver wayland --path godot3d \
##     res://zones/outside/tools_forest_drive.tscn

var game: Node
var _fails := 0


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _check(ok: bool, label: String) -> void:
	print("FOREST DRIVE: ", "PASS" if ok else "FAIL", " - ", label)
	if not ok:
		_fails += 1


func _walk(cat: PvKCat, from: Vector3, mv: Vector2, secs: float) -> Vector3:
	game.input_override = {"active": false}
	cat.velocity = Vector3.ZERO
	cat.global_position = from
	await _wait(0.35)
	game.input_override = {"active": true, "move": mv, "sprint": true, "stalk": false}
	await _wait(secs)
	game.input_override = {"active": false}
	cat.velocity = Vector3.ZERO
	await _wait(0.2)
	return cat.global_position


func _ready() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await _wait(0.6)
	game.duo.choose("willie")
	await _wait(0.4)
	var sys: OutsideSystem = game.outside
	var cat: PvKCat = game.cat
	sys.debug_clear_cars()
	sys.debug_clear_birds()
	sys.debug_clear_walkers()
	sys._walker_t = 9999.0
	sys._bird_spawn_t = 9999.0
	# Pin the camera so input maps to world axes.
	var anchor := Node3D.new()
	game.add_child(anchor)
	anchor.global_position = Vector3(0, 1.0, 0)
	game.cam_anchor = anchor
	game.cam_yaw = 0.0
	game.cam_pitch = -0.5
	game.cam_dist = 5.0
	await _wait(0.3)

	# A — glade lane south, stopped by the hedge (fence line z 9.9).
	var pa := await _walk(cat, Vector3(-2.0, 0.05, -2.0), Vector2(0, -1), 8.0)
	_check(pa.z > 8.8 and pa.z < 9.8, "A south hedge holds (z=%.2f), glade lane open" % pa.z)

	# B — east hedge.
	var pb := await _walk(cat, Vector3(6.0, 0.05, 0.0), Vector2(1, 0), 6.0)
	_check(pb.x > 11.3 and pb.x < 12.8, "B east hedge holds (x=%.2f)" % pb.x)

	# C — west hedge.
	var pc := await _walk(cat, Vector3(-6.0, 0.05, -0.5), Vector2(-1, 0), 6.0)
	_check(pc.x < -11.3 and pc.x > -12.8, "C west hedge holds (x=%.2f)" % pc.x)

	# E — forest trunk at (3.3, 8.55) is solid.
	var pe := await _walk(cat, Vector3(3.3, 0.05, 6.2), Vector2(0, -1), 5.0)
	_check(pe.z > 7.4 and pe.z < 8.35, "E forest trunk solid (z=%.2f)" % pe.z)

	# F — front roses ornamental: through the bed to the house wall.
	var pf := await _walk(cat, Vector3(-3.2, 0.05, -13.6), Vector2(0, -1), 4.0)
	_check(pf.z > -11.25 and pf.z < -10.6, "F front roses passable, wall stops cat (z=%.2f)" % pf.z)

	print("FOREST DRIVE DONE: %d failures" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
