extends Node
## PLAYTEST PROBE 2 (scratch): map the mouse-catch success window and
## check the attic perch lounge spot.

var _game = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ready() -> void:
	_run()


func _fresh_mouse() -> PvKMouse:
	for m in _game.mice:
		if is_instance_valid(m) and m.state != "caught":
			return m
	return null


func _trial(press_at: float, lateral: float, sprint: bool) -> bool:
	# Reset: one mouse 6 m north of the cat, cat facing it, both calm.
	var cat = _game.cat
	var mouse := _fresh_mouse()
	if mouse == null:
		return false
	mouse.state = "idle"
	mouse.set("_flee_t", 0.0)
	cat.global_position = Vector3(0.0, 0.05, 0.0)
	cat.velocity = Vector3.ZERO
	cat.rotation.y = PI # face +Z (toward the mouse)
	mouse.global_position = Vector3(lateral, 0.0, 6.0)
	mouse.home = mouse.global_position
	var caught0: int = _game.caught_count
	var pressed := false
	for i in 60 * 12:
		var b: Basis = _game._rig.global_transform.basis
		var fwd := -b.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := b.x
		right.y = 0.0
		right = right.normalized()
		var dvec: Vector3 = mouse.global_position - cat.global_position
		dvec.y = 0.0
		var dist := dvec.length()
		var mv := Vector2.ZERO
		if dist > 0.05:
			var dn := dvec / dist
			mv = Vector2(dn.dot(right), dn.dot(fwd))
		_game.input_override = {"active": true, "move": mv, "sprint": sprint, "stalk": false}
		if not pressed and dist < press_at and cat.get("_strike_t") < 0.0:
			_game.attempt_strike()
			pressed = true
		await frames(1)
		if _game.caught_count > caught0:
			_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
			return true
		if pressed and cat.get("_strike_t") < 0.0 and cat.get("_strike_cd") > 0.0:
			# strike resolved without a catch — but the chase may still land later; keep going briefly
			pass
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	return _game.caught_count > caught0


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(20)
	_game.duo.choose("willie")
	await frames(5)
	print("=== MICE CENSUS ===")
	for m in _game.mice:
		print("mouse pos=%s state=%s" % [(m as Node3D).global_position, m.state])
	print("=== CATCH WINDOW SWEEP (sprint) ===")
	for press_at in [1.1, 0.9, 0.7, 0.5]:
		for lateral in [0.0, 0.3]:
			var hits := 0
			for t in 3:
				if await _trial(press_at, lateral, true):
					hits += 1
			print("press_at=%.2f lateral=%.1f sprint: %d/3 caught" % [press_at, lateral, hits])
	print("=== CATCH WINDOW SWEEP (walk) ===")
	for press_at in [0.9, 0.7]:
		var hits := 0
		for t in 3:
			if await _trial(press_at, 0.0, false):
				hits += 1
		print("press_at=%.2f lateral=0.0 walk: %d/3 caught" % [press_at, hits])
	print("=== ATTIC PERCH LOUNGE SPOT ===")
	var attic = _game._zone_roots[HouseSpec.ATTIC]
	var spots: Array = attic.get_lounge_spots()
	for s in spots:
		print("attic lounge spot world=%s attic-local=%s" % [s, attic.to_local(s)])
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(10)
	var aggie = _game.duo.aggie_cat
	_game.duo.sibling.go_lounge(spots[0])
	for i in 8:
		await frames(60)
		print("aggie t=%ds pos=%s mode=%s lounging=%s" % [i + 1, aggie.global_position, _game.duo.sibling.mode, aggie.is_lounging])
	print("=== PROBE2 DONE ===")
	get_tree().quit()
