extends Node
## Massey forest + rose-hedge visual pass (TODO #121 lane): fixed
## viewpoints over the back yard, the south boundary and the front
## garden, staged identically every run so BEFORE (fence, open lawn)
## and AFTER (forest, thorn hedge, front roses) captures compare
## directly. Saves PNGs to res://screenshots/ with a prefix taken
## from the user arg --forest-prefix=before_ (default "after_").
## Run under a display (weston/wayland on fola4.0):
##   godot --display-driver wayland --path godot3d \
##     res://zones/outside/tools_forest_shots.tscn -- --forest-prefix=before_

var game: Node
var _anchor: Node3D = null
var _prefix := "after_"


func _snap(sname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s%s.png" % [_prefix, sname])
	print("shot: ", _prefix, sname)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _aim(target: Vector3, dist: float, yaw: float, pitch := -0.5) -> void:
	if _anchor == null:
		_anchor = Node3D.new()
		game.add_child(_anchor)
		game.cam_anchor = _anchor
	_anchor.global_position = target
	game.cam_dist = dist
	game.cam_yaw = yaw
	game.cam_pitch = pitch


func _face(cat: Node3D, toward: Vector3) -> void:
	var d := toward - cat.global_position
	cat.rotation.y = atan2(-d.x, -d.z)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--forest-prefix="):
			_prefix = a.trim_prefix("--forest-prefix=")
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	game = load("res://main.tscn").instantiate()
	add_child(game)
	await _wait(0.6)
	game.duo.choose("willie")
	await _wait(0.4)
	var sys: OutsideSystem = game.outside
	var cat: PvKCat = game.cat
	# Freeze the ambient spawners; every shot stages its own cast.
	sys.debug_clear_cars()
	sys.debug_clear_birds()
	sys.debug_clear_walkers()
	sys._walker_t = 9999.0
	sys._bird_spawn_t = 9999.0
	await _wait(0.3)

	# yard_from_porch — from the back door axis, looking south across
	# the whole lawn to the boundary.
	cat.global_position = Vector3(2.5, 0.05, -6.2)
	_face(cat, Vector3(2.5, 0, 6.0))
	_aim(Vector3(2.5, 0.6, 4.5), 7.0, PI, -0.42)
	await _wait(1.2)
	await _snap("yard_from_porch")

	# yard_centre — Willie mid-lawn, the south woods behind him.
	cat.global_position = Vector3(0.0, 0.05, 0.5)
	_face(cat, Vector3(-4.5, 0, -3.0))
	_aim(Vector3(0.0, 0.5, 0.5), 5.5, -2.2, -0.5)
	await _wait(1.0)
	await _snap("yard_centre")

	# boundary_south — tight on the south boundary line (fence BEFORE,
	# thorn hedge AFTER).
	cat.global_position = Vector3(-1.5, 0.05, 6.6)
	_face(cat, Vector3(-1.5, 0, 12.0))
	_aim(Vector3(0.0, 0.7, 9.3), 6.5, PI, -0.4)
	await _wait(1.0)
	await _snap("boundary_south")

	# grove_west — looking west into the west edge from inside.
	cat.global_position = Vector3(-7.6, 0.05, 2.0)
	_face(cat, Vector3(-13.0, 0, 2.0))
	_aim(Vector3(-10.8, 0.9, 2.0), 5.0, PI / 2.0, -0.45)
	await _wait(1.0)
	await _snap("grove_west")

	# canopy_south — along the south tree line, canopy read.
	cat.global_position = Vector3(1.0, 0.05, 6.2)
	_face(cat, Vector3(-8.0, 0, 8.0))
	_aim(Vector3(-2.0, 1.7, 8.4), 7.5, PI / 2.0, -0.3)
	await _wait(1.0)
	await _snap("canopy_south")

	# front_garden — from the street, looking north at the house
	# front (roses AFTER; bare siding/lawn BEFORE).
	cat.global_position = Vector3(-2.0, 0.05, -12.3)
	_face(cat, Vector3(-2.0, 0, -20.0))
	_aim(Vector3(0.0, 0.7, -14.8), 5.5, PI, -0.3)
	await _wait(1.0)
	await _snap("front_garden")

	print("FOREST SHOTS DONE")
	get_tree().quit(0)
