extends Node
## One connected night of the house, walked, not teleported.
## Yard spawn → front door → ground floor → basement → ground →
## attic → ground → back out the front door. Each leg is a
## scripted walk into that zone's connector.
## Run: godot --headless --path godot3d res://tests/test_circuit.tscn

var _pass := 0
var _fail := 0
var _game = null


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _run() -> void:
	print("CIRCUIT TESTS: loading main scene")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(12)
	_game.duo.choose("willie")
	if _game.glenys != null:
		_game.glenys.set_active(false)
	await frames(6)
	var cat: PvKCat = _game.cat
	var zones: ZoneManager = _game.zones
	check(zones.current_zone == HouseSpec.OUTSIDE, "the night starts in the yard")

	# Camera yaw PI: stick (0, -1) is north, toward the house.
	_game.cam_yaw = PI
	_game.input_override = {"active": true, "move": Vector2(0, -1), "sprint": true, "stalk": false}
	var walked := 0
	while zones.current_zone == HouseSpec.OUTSIDE and walked < 500:
		await frames(1)
		walked += 1
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	check(zones.current_zone == HouseSpec.GROUND_FLOOR,
		"walking up the porch enters the front door (at %s after %d frames)" % [cat.global_position, walked])
	await frames(12)
	var cam: Camera3D = _game.get_viewport().get_camera_3d()
	var local: Vector3 = cam.global_position - HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
	check(not CameraFeel.outside_footprint(local, HouseSpec.ceil_h(HouseSpec.GROUND_FLOOR)),
		"the ground-floor camera stays inside the room (%s)" % local)
	check(is_equal_approx(_game.cam_dist, 4.6), "the yard's camera distance is kept for the door back out")
	check(_game._arm.collision_mask == 1, "the spring arm collides with the house")
	_check_dressed(zones)
	cat.velocity = Vector3.ZERO
	cat.global_position = HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR) + Vector3(5.0, 0.2, -2.0)
	_game.cam_yaw = 0.0
	_game.snap_camera()
	await frames(30)
	cam = _game.get_viewport().get_camera_3d()
	var shoulder: float = cam.global_position.distance_to(cat.global_position)
	var eye: float = cam.global_position.y - cat.global_position.y
	var feet: Vector3 = cat.global_position
	var crown: Vector3 = feet + Vector3(0, 0.46, 0)
	var vp_h: float = cam.get_viewport().get_visible_rect().size.y
	var frac: float = absf(cam.unproject_position(crown).y - cam.unproject_position(feet).y) / maxf(1.0, vp_h)
	check(shoulder > 0.7 and shoulder < 2.35, "indoors the camera sits at Willie's shoulder (%.2f m)" % shoulder)
	check(eye > 0.34 and eye < 0.46, "the indoor lens is at cat-eye height (%.2f m)" % eye)
	check(frac > 0.22 and frac < 0.36, "Willie fills about a quarter of the frame (%.0f%%)" % (frac * 100.0))
	var look_up: float = (-cam.global_basis.z).y
	check(look_up > 0.02, "the indoor lens looks slightly up (%.2f)" % look_up)
	await _settle(zones)

	await _walk_into(cat, zones, Vector3(-6.5, 0.35, -201.05), Vector3(-6.5, 0.2, -203.2),
		HouseSpec.BASEMENT, "walking into the stairwell drops to the basement")
	await _walk_into(cat, zones, Vector3(3.4, -2.35, -195.85), Vector3(6.5, -2.4, -195.78),
		HouseSpec.GROUND_FLOOR, "walking to the cellar stairs returns upstairs")
	await _walk_into(cat, zones, Vector3(6.5, 0.35, -201.4), Vector3(6.5, 0.2, -203.2),
		HouseSpec.ATTIC, "walking into the hatch climbs to the attic")
	await _walk_into(cat, zones, Vector3(3.7, 3.15, -203.9), Vector3(5.3, 3.1, -203.55),
		HouseSpec.GROUND_FLOOR, "walking back to the attic hatch returns downstairs")
	await _walk_into(cat, zones, Vector3(2.5, 0.35, -196.9), Vector3(2.5, 0.2, -195.4),
		HouseSpec.OUTSIDE, "walking out the front door returns to the yard")

	print("CIRCUIT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _check_dressed(zones: ZoneManager) -> void:
	for id: String in [HouseSpec.GROUND_FLOOR, HouseSpec.BASEMENT, HouseSpec.ATTIC]:
		var root: Node = zones.zones.get(id)
		check(root != null, "%s is part of the night run" % id)
		if root == null:
			continue
		var floor_tex := false
		var wall_tex := false
		var hunyuan := false
		var recliner := false
		for n: Node in root.find_children("*", "Node", true, false):
			if n.has_meta("hunyuan"):
				hunyuan = true
				if String(n.get_meta("hunyuan")) == "recliner":
					recliner = true
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var mat := mi.material_override as StandardMaterial3D
				if mat == null or mat.albedo_texture == null or not (mi.mesh is BoxMesh):
					continue
				var path := mat.albedo_texture.resource_path
				var size := (mi.mesh as BoxMesh).size
				var thin := minf(size.x, size.z)
				var wide := maxf(size.x, size.z)
				var is_floor := size.y >= 0.12 and size.y <= 0.45 and size.x >= 3.0 and size.z >= 2.0
				var is_wall := thin <= 0.45 and size.y >= 0.8 and wide >= 3.0
				if is_floor and (path.contains("hardwood") or path.contains("linoleum") or path.contains("concrete") or path.contains("attic")):
					floor_tex = true
				if is_wall and (path.contains("wallpaper") or path.contains("concrete")):
					wall_tex = true
		check(floor_tex, "%s floor wears a house texture" % id)
		check(wall_tex, "%s walls wear a house texture" % id)
		check(hunyuan, "%s places a Hunyuan prop" % id)
		if id == HouseSpec.GROUND_FLOOR:
			check(recliner, "the ground floor keeps the recliner")


func _settle(zones: ZoneManager) -> void:
	var n := 0
	while (zones.travelling or not zones.can_travel()) and n < 180:
		await frames(1)
		n += 1


func _walk_into(cat: PvKCat, zones: ZoneManager, stand: Vector3, dest: Vector3, want: String, label: String) -> void:
	await _settle(zones)
	cat.velocity = Vector3.ZERO
	cat.global_position = stand
	await frames(10)
	var walked := 0
	while zones.current_zone != want and walked < 280:
		var d := dest - cat.global_position
		d.y = 0.0
		if d.length() < 0.08:
			d = Vector3(0, 0, -1)
		else:
			d = d.normalized()
		_game.cam_yaw = PI
		if _game._rig != null:
			_game._rig.rotation.y = PI
		# Yaw PI: stick x = -world x, stick y = world z.
		_game.input_override = {"active": true, "move": Vector2(-d.x, d.z), "sprint": true, "stalk": false}
		await frames(1)
		walked += 1
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	var settle := 0
	while zones.travelling and settle < 40:
		await frames(1)
		settle += 1
	check(zones.current_zone == want, "%s (at %s after %d frames)" % [label, cat.global_position, walked])
