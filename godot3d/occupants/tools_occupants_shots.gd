extends Node
## Occupants shot pass. Run under Xvfb (real rendering):
##   xvfb-run godot --path godot3d res://occupants/tools_occupants_shots.tscn
## Saves PNGs into res://screenshots/occupants/:
## ankle_attack, lap_petting (+ _b/_c variants to pick from), path_cross.
## Timing is polled in physics frames so slow software rendering
## cannot desync a capture from the animation it is meant to show.

const RoomScene := preload("res://occupants/occupants_room.tscn")

var _cam: Camera3D = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String, draws := 2) -> void:
	for i in draws:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/occupants/%s.png" % name)
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
	DirAccess.make_dir_recursive_absolute("res://screenshots/occupants")
	var room = RoomScene.instantiate()
	add_child(room)
	await _wait(0.6)
	var sys = room.system
	var daniel = room.daniel
	var fola = room.folasade
	var cat = room.cat

	# (a) ANKLE ATTACK — Daniel at the counter, Willie at his ankle.
	# Poll for the hop reaction, then capture near its peak (k~0.4).
	daniel.set_routine([{"pos": Vector3(-3.05, 0, -1.2), "yaw": PI / 2.0, "action": "stand", "dwell": 999.0}])
	daniel.place_at(Vector3(-3.05, 0, -1.2), PI / 2.0)
	cat.global_position = Vector3(-2.45, 0.05, -1.2)
	cat.rotation.y = PI / 2.0
	cat.set_move_input(Vector3.ZERO, false, false)
	await _frames(30)
	# From his front-right, far enough south-east that the whole
	# score popup floats over open floor (closer angles let the
	# counter occlude one end of it), head + "!" in frame.
	_camera(Vector3(-0.55, 1.1, 0.95), Vector3(-2.8, 0.55, -1.2))
	cat.strike()
	var guard := 0
	while daniel.last_reaction() != "hop" and guard < 120:
		await get_tree().physics_frame
		guard += 1
	# The hop lasts 0.45 s and a frame_post_draw wait costs real time
	# at software-render framerates, so fixed delays keep missing the
	# peak. Poll the model's actual lift in render time instead and
	# grab a burst of candidates while he is airborne; the best one
	# is kept as ankle_attack.png.
	var tries := 0
	guard = 0
	while daniel._react_t > 0.05 and tries < 4 and guard < 200:
		await get_tree().process_frame
		guard += 1
		if daniel._model.position.y > 0.045:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://screenshots/occupants/ankle_try%d.png" % (tries + 1))
			print("SHOT saved ankle_try", tries + 1, " lift=", daniel._model.position.y)
			tries += 1

	# (b) LAP PETTING — Folasade seated, Willie settled and healing.
	# Three framings; the best-reading one is kept as lap_petting.png.
	fola.dwell_scale = 0.05
	guard = 0
	while not fola.is_seated() and guard < 600:
		await get_tree().physics_frame
		guard += 1
	cat.global_position = Vector3(3.27, 0.05, -1.15)
	cat.rotation.y = 0.0
	cat.set_move_input(Vector3.ZERO, false, false)
	await _frames(10)
	sys.try_mount_lap(cat)
	await _frames(80) # glided up, settled, petting eased in
	var spot: Vector3 = fola.lap_spot()
	_camera(Vector3(2.45, 0.88, -0.62), spot + Vector3(0, 0.02, 0))
	await _shot("lap_petting_a")
	_camera(Vector3(4.35, 0.82, -1.05), spot + Vector3(0, 0.02, 0))
	await _shot("lap_petting_b")
	await _frames(45) # a different point in the stroke cycle
	_camera(Vector3(2.45, 0.88, -0.62), spot + Vector3(0, 0.02, 0))
	await _shot("lap_petting_c")
	sys.release_cat(cat)

	# (c) PATH CROSS — Willie cuts Daniel off dead-centre; windmill.
	sys.force_stumble = true
	daniel.set_routine([
		{"pos": Vector3(4.5, 0, 0.6), "yaw": -PI / 2.0, "action": "stand", "dwell": 0.1},
		{"pos": Vector3(-4.5, 0, 0.6), "yaw": PI / 2.0, "action": "stand", "dwell": 0.1},
	])
	daniel.place_at(Vector3(-3.4, 0, 0.6), -PI / 2.0)
	guard = 0
	while not (daniel.is_walking() and daniel.velocity.x > 0.3) and guard < 300:
		await get_tree().physics_frame
		guard += 1
	cat.global_position = Vector3(daniel.global_position.x + 0.45, 0.05, -0.35)
	cat.rotation.y = PI
	cat.set_move_input(Vector3(0, 0, 1), true, false)
	_camera(Vector3(1.4, 1.45, 3.4), daniel.global_position + Vector3(0.4, 0.8, 0))
	guard = 0
	while daniel.last_reaction() != "stumble" and guard < 300:
		await get_tree().physics_frame
		guard += 1
	cat.set_move_input(Vector3.ZERO, false, false)
	await _wait(0.28) # mid-windmill
	_camera(Vector3(daniel.global_position.x + 1.3, 1.35, daniel.global_position.z + 2.6), daniel.global_position + Vector3(0, 0.85, 0))
	await _shot("path_cross")

	print("OCCUPANTS SHOTS DONE")
	get_tree().quit(0)
