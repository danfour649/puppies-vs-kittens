extends Node
# Outside-zone visual pass: stage each signature beat and save a
# PNG to res://screenshots/. Mirrors tools/shots.gd (real timers,
# game.cam_anchor aiming, viewport capture).
# Run under a display: xvfb-run godot --path godot3d res://zones/outside/tools_outside_shots.tscn

var game: Node


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % name)
	print("shot: ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


var _anchor: Node3D = null


func _aim(target: Vector3, dist: float, yaw: float, pitch := -0.5) -> void:
	if _anchor == null:
		_anchor = Node3D.new()
		game.add_child(_anchor)
		game.cam_anchor = _anchor
	_anchor.global_position = target
	game.cam_dist = dist
	game.cam_yaw = yaw
	game.cam_pitch = pitch


func _ready() -> void:
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

	# feeder_stream — birds working the feeder, cat watching.
	for i in 3:
		var spot: Vector3 = [Vector3(7.6, 0, 3.2), Vector3(6.8, 0, 2.4), Vector3(8.4, 0, 4.1)][i]
		sys.debug_spawn_bird_near(spot)
	cat.global_position = Vector3(4.6, 0.05, 1.2)
	cat.rotation.y = -2.2
	_aim(Vector3(7.4, 0.6, 3.2), 5.5, 0.6)
	await _wait(1.6)
	await _snap("feeder_stream")

	# ambush_bush — Willie hidden in bush A, meter up, bird close.
	var to_feeder := OutsideLayout.FEEDER_POS - OutsideLayout.BUSH_A
	cat.global_position = OutsideLayout.BUSH_A + to_feeder.normalized() * 0.55 # rim of the bush: hidden, but visible to the camera
	game.input_override = {"active": true, "move": Vector2.ZERO, "sprint": false, "stalk": true}
	to_feeder.y = 0.0
	sys.debug_spawn_bird_near(OutsideLayout.BUSH_A + to_feeder.normalized() * 1.3)
	var t := 0.0
	while sys.stillness < 0.85 and t < 6.0:
		await _wait(0.25)
		t += 0.25
	cat.rotation.y = atan2(-to_feeder.x, -to_feeder.z)
	_aim(OutsideLayout.BUSH_A + Vector3(0, 0.3, 0), 3.4, -0.7)
	await _wait(0.4)
	await _snap("ambush_bush")
	game.input_override = {"active": false}
	sys.debug_clear_birds()

	# squirrel_taunt — a squirrel up the west tree, flicking its tail.
	var sq: PvKSquirrel = sys.squirrels[0]
	sq.debug_force_climb()
	var t2 := 0.0
	while sq.state != "taunt" and t2 < 4.0:
		await _wait(0.2)
		t2 += 0.2
	cat.global_position = sq.home_tree.global_position + Vector3(2.6, 0.05, 1.6)
	cat.rotation.y = 2.4
	_aim(sq.home_tree.global_position + Vector3(0, 1.3, 0), 3.6, 2.6)
	await _wait(0.5)
	await _snap("squirrel_taunt")

	# trunk_climb — Willie halfway up the west trunk.
	cat.global_position = sq.home_tree.global_position + sq.home_tree.branch_dir * 0.75
	var d := sq.home_tree.global_position - cat.global_position
	cat.rotation.y = atan2(-d.x, -d.z)
	sys.try_start_climb()
	sys.climb_axis_debug = 1.0
	await _wait(0.9)
	sys.climb_axis_debug = 0.0
	_aim(cat.global_position, 3.2, 2.9)
	await _wait(0.3)
	await _snap("trunk_climb")
	sys.end_climb()
	await _wait(0.3)

	# road_crossing — Willie mid-road, a car swerving + honking.
	cat.global_position = Vector3(3.0, 0.05, OutsideLayout.LANE_NEAR_Z + 0.6)
	cat.rotation.y = PI
	var car: PvKCar = sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, -5.0, 8.0)
	_aim(cat.global_position + Vector3(0, 0.25, 0), 5.4, -0.7, -0.42)
	await _wait(0.32)
	await _snap("road_crossing")
	sys.debug_reset_road()
	sys.debug_clear_cars()
	if is_instance_valid(car):
		pass
	cat.global_position = Vector3(-6.0, 0.05, -12.0)

	# dog_strain — the owner skidding, dog at the end of the leash.
	var w: PvKWalker = sys.debug_spawn_walker(1.0, "big")
	var dog: PvKDog = sys.dog
	cat.global_position = w.global_position + Vector3(6.0, 0, -1.4)
	var t3 := 0.0
	while dog.state != "strain" and t3 < 6.0:
		await _wait(0.2)
		t3 += 0.2
	_aim((dog.global_position + w.global_position) * 0.5 + Vector3(0, 0.5, 0), 4.6, 0.4)
	await _wait(0.4)
	await _snap("dog_strain")

	# dog_chase — the leash slips; the dog is loose.
	cat.global_position = dog.global_position + Vector3(0.8, 0, 0.3)
	var t4 := 0.0
	while dog.state != "chase" and t4 < 3.0:
		await _wait(0.15)
		t4 += 0.15
	cat.global_position = dog.global_position + Vector3(2.6, 0, -0.6)
	_aim(dog.global_position + Vector3(0.8, 0.3, 0), 4.8, 0.9)
	await _wait(0.35)
	await _snap("dog_chase")

	print("OUTSIDE SHOTS DONE")
	get_tree().quit(0)
