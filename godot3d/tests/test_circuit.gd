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
	await _settle(zones)

	await _walk_into(cat, zones, Vector3(-6.5, 0.35, -201.05), Vector3(-6.5, 0.2, -203.2),
		HouseSpec.BASEMENT, "walking into the stairwell drops to the basement")
	await _walk_into(cat, zones, Vector3(2.9, -2.35, -196.2), Vector3(4.6, -2.4, -195.2),
		HouseSpec.GROUND_FLOOR, "walking to the cellar stairs returns upstairs")
	await _walk_into(cat, zones, Vector3(6.5, 0.35, -201.4), Vector3(6.5, 0.2, -203.2),
		HouseSpec.ATTIC, "walking into the hatch climbs to the attic")
	await _walk_into(cat, zones, Vector3(3.7, 3.15, -203.9), Vector3(5.3, 3.1, -203.55),
		HouseSpec.GROUND_FLOOR, "walking back to the attic hatch returns downstairs")
	await _walk_into(cat, zones, Vector3(2.5, 0.35, -196.9), Vector3(2.5, 0.2, -195.4),
		HouseSpec.OUTSIDE, "walking out the front door returns to the yard")

	print("CIRCUIT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


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
