extends Node
## Glenys shot pass. Run under Xvfb (real rendering):
##   xvfb-run godot --path godot3d res://glenys/tools_glenys_shots.tscn
## Saves PNGs into res://screenshots/glenys/:
##   pursuit — Glenys mid-stride after the cat, cane planted;
##   grab    — the caught moment, cat held up, squirm prompt up.
## Drives the real game (main.tscn) with its own camera; timing is
## polled in physics frames so slow software rendering cannot
## desync a capture from the pose it is meant to show.

var _cam: Camera3D = null


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/glenys/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _camera(pos: Vector3, target: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		add_child(_cam)
		_cam.current = true
	_cam.global_position = pos
	_cam.look_at(target, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/glenys")
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await _frames(14)
	game.duo.choose("willie")
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await _frames(6)
	var sys: GlenysSystem = game.get("glenys")
	var actor: Glenys = sys.actor
	sys.force_wake()
	sys.set("_forget_t", 9999.0)
	sys.set("_offer_t", 9999.0)
	var origin := HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
	var cat: PvKCat = game.cat
	cat.set_lounge(false)

	# (1) PURSUIT — she is mid-room, mid-stride, cane down, the cat
	# a couple of metres ahead of her in the living room.
	cat.global_position = origin + Vector3(3.4, 0.1, 1.4)
	cat.velocity = Vector3.ZERO
	actor.global_position = origin + Vector3(-0.7, 0.1, 0.5)
	await _frames(46) # let the gait and the cane cycle get going
	_camera(origin + Vector3(4.9, 1.5, 4.6), origin + Vector3(1.2, 0.75, 1.0))
	await _shot("pursuit")

	# (2) GRAB — caught: held up at her chest, prompt on screen.
	sys.debug_grab()
	await _frames(8)
	var a := actor.global_position
	_camera(a + Vector3(1.35, 0.75, 1.55), a + Vector3(0, 0.95, 0))
	await _shot("grab")

	print("GLENYS SHOTS DONE")
	get_tree().quit(0)
