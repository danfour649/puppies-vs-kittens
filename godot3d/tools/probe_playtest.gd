extends Node
## PLAYTEST PROBE (scratch): boots the real integrated main scene and
## measures the four playtest reports with scripted play. Not a suite.

var _game = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ready() -> void:
	_run()


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(20)
	var cat = _game.cat
	var duo = _game.duo
	var aggie = duo.aggie_cat

	print("=== BOOT CENSUS ===")
	print("willie pos=%s walk=%.2f sprint=%.2f strike_range=%.2f scale=%.2f" % [cat.global_position, cat.walk_speed, cat.sprint_speed, cat.strike_range, cat.model_scale])
	cat.rotation.y = 0.0
	print("willie paw_point offset (facing -Z): %.3f" % _flat(cat.paw_point(), cat.global_position))
	print("aggie pos=%s walk=%.2f sprint=%.2f strike_range=%.2f scale=%.2f lounging=%s" % [aggie.global_position, aggie.walk_speed, aggie.sprint_speed, aggie.strike_range, aggie.model_scale, aggie.is_lounging])
	print("sibling mode=%s prov state=%s meter=%.1f" % [duo.sibling.mode, duo.prov.state, duo.prov.meter])
	print("game.catch_radius=%.2f" % _game.catch_radius)
	for id in _game._zone_roots:
		var r = _game._zone_roots[id]
		print("zone root %-12s global=%s" % [id, (r as Node3D).global_position if r is Node3D else Vector3.ZERO])

	print("=== BUG3: RACCOON PLACEMENT ===")
	var attic = _game._zone_roots[HouseSpec.ATTIC]
	print("attic root global=%s" % attic.global_position)
	if attic.mother != null:
		var m = attic.mother
		print("mother global=%s local=%s parent=%s" % [m.global_position, m.position, m.get_parent().name])
	for k in attic.kits:
		print("kit global=%s local=%s" % [(k as Node3D).global_position, (k as Node3D).position])
	print("attic-local mother (want ~(-4.5,0,-3.0)): %s" % attic.to_local(attic.mother.global_position))

	print("=== BUG4: PROVOCATION (no manual un-lounge) ===")
	duo.choose("willie")
	await frames(5)
	# Park Willie 2 m from Aggie, both still.
	var ap: Vector3 = aggie.global_position
	cat.global_position = ap + Vector3(2.0, 0.0, 0.0)
	cat.velocity = Vector3.ZERO
	aggie.velocity = Vector3.ZERO
	await frames(10)
	print("pre: aggie lounging=%s mode=%s flat dist=%.2f" % [aggie.is_lounging, duo.sibling.mode, _flat(cat.global_position, aggie.global_position)])
	var aggie_start: Vector3 = aggie.global_position
	var modes_seen := {}
	var max_hits := 0
	var willie_start: Vector3 = cat.global_position
	for i in 4:
		duo.player_meow()
		await frames(50)
		print("after meow %d: meter=%.1f state=%s mode=%s aggie_moved=%.2f" % [i + 1, duo.prov.meter, duo.prov.state, duo.sibling.mode, _flat(aggie.global_position, aggie_start)])
	for i in 60 * 10:
		await frames(1)
		modes_seen[duo.sibling.mode] = true
		max_hits = maxi(max_hits, int(duo.prov.get("_hits")))
		if duo.prov.state == "cooldown" and i > 120:
			break
	print("post: state=%s mode=%s modes_seen=%s prov_hits=%d aggie_displacement=%.2f willie_displacement=%.2f aggie_lounging=%s" % [duo.prov.state, duo.sibling.mode, modes_seen.keys(), max_hits, _flat(aggie.global_position, aggie_start), _flat(cat.global_position, willie_start), aggie.is_lounging])

	print("=== BUG1: SCRIPTED MOUSE CHASE ===")
	await _chase(true, 0.7, 60 * 45, "sprint, strike<0.70")
	await _chase(false, 0.7, 60 * 30, "walk-only, strike<0.70")

	print("=== BUG2: SHAFT ALIGNMENT (house-local) ===")
	for zid in [HouseSpec.GROUND_FLOOR, HouseSpec.BASEMENT, HouseSpec.ATTIC]:
		for c in HouseSpec.connectors(zid):
			print("%s connector at=%s -> %s/%s" % [zid, c["at"], c["target_zone"], c["target_entry"]])
	for zid in [HouseSpec.OUTSIDE, HouseSpec.GROUND_FLOOR, HouseSpec.BASEMENT, HouseSpec.ATTIC]:
		for ename in HouseSpec.entries(zid):
			var t: Transform3D = HouseSpec.entries(zid)[ename]
			var fwd := -t.basis.z
			print("%s entry %-16s local_pos=%s facing=(%.2f,%.2f)" % [zid, ename, t.origin, fwd.x, fwd.z])
	# Travel round trip: yard -> ground floor -> attic, check controls basis consistency.
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(10)
	print("in GF: cat world=%s" % cat.global_position)
	var before: Vector3 = cat.global_position
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": false}
	await frames(30)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	var delta: Vector3 = cat.global_position - before
	print("GF W-input (mv=(0,1)) moved cat by (%.2f, %.2f) xz" % [delta.x, delta.z])
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(10)
	print("in ATTIC: cat world=%s attic-local=%s facing_yaw=%.2f" % [cat.global_position, attic.to_local(cat.global_position), cat.rotation.y])
	_game.zones.travel(HouseSpec.OUTSIDE, "EntryFrontDoor", true)
	await frames(10)
	print("back OUTSIDE: cat world=%s" % cat.global_position)
	print("=== PROBE DONE ===")
	get_tree().quit()


func _chase(sprint: bool, strike_at: float, max_frames: int, label: String) -> void:
	var cat = _game.cat
	# Find nearest alive mouse and commit to it.
	var target: PvKMouse = null
	var bd := INF
	for m in _game.mice:
		if is_instance_valid(m) and m.state != "caught":
			var d := _flat(cat.global_position, m.global_position)
			if d < bd:
				bd = d
				target = m
	if target == null:
		print("chase[%s]: no alive mouse" % label)
		return
	var caught0: int = _game.caught_count
	var presses := 0
	var press_dists: Array = []
	var min_dist := INF
	var frames_used := 0
	for i in max_frames:
		frames_used = i
		if not is_instance_valid(target) or target.state == "caught":
			break
		var b: Basis = _game._rig.global_transform.basis
		var fwd := -b.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := b.x
		right.y = 0.0
		right = right.normalized()
		var dvec: Vector3 = target.global_position - cat.global_position
		dvec.y = 0.0
		var dist := dvec.length()
		min_dist = minf(min_dist, dist)
		var mv := Vector2.ZERO
		if dist > 0.05:
			var dn := dvec / dist
			mv = Vector2(dn.dot(right), dn.dot(fwd))
		_game.input_override = {"active": true, "move": mv, "sprint": sprint, "stalk": false}
		if dist < strike_at and cat.get("_strike_t") < 0.0 and cat.get("_strike_cd") <= 0.0:
			presses += 1
			press_dists.append(snappedf(dist, 0.01))
			_game.attempt_strike()
		await frames(1)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	print("chase[%s]: frames=%d presses=%d press_dists=%s caught_delta=%d min_dist=%.2f target_state=%s" % [label, frames_used, presses, press_dists, _game.caught_count - caught0, min_dist, target.state if is_instance_valid(target) else "freed"])
