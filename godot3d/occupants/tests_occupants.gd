extends Node
## Headless tests for the Occupants system.
## Run: godot --headless --path godot3d res://occupants/tests_occupants.tscn
## Asserts on STATE only (headless rendered readbacks lie).

const RoomScene := preload("res://occupants/occupants_room.tscn")
const CatHealthScript := preload("res://occupants/cat_health.gd")

var _pass := 0
var _fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Poll a callable each physics frame until it returns true or the
## budget runs out. Returns the final value.
func until(callable: Callable, budget: int) -> bool:
	var left := budget
	while left > 0:
		if bool(callable.call()):
			return true
		await get_tree().physics_frame
		left -= 1
	return bool(callable.call())


func new_room() -> Node:
	var room = RoomScene.instantiate()
	add_child(room)
	return room


func _ready() -> void:
	_run()


func _run() -> void:
	await _test_build_and_routine()
	await _test_ankle_and_shoo()
	await _test_underfoot()
	await _test_lap()
	print("OCCUPANTS TESTS: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


# --- build + routine -----------------------------------------------------------

func _test_build_and_routine() -> void:
	print("OCC: build + routine")
	var room = await new_room()
	await frames(10)
	var daniel = room.daniel
	var fola = room.folasade
	check(daniel != null and fola != null, "both occupants exist")
	check(room.system != null and room.cat != null, "system + player cat wired")
	var dh: float = daniel.head_top_y()
	var fh: float = fola.head_top_y()
	check(dh > 1.60 and dh < 1.84, "Daniel stands ~1.7 m (head top %.2f)" % dh)
	check(fh > 1.58 and fh < 1.82, "Folasade stands ~1.7 m (head top %.2f)" % fh)
	check(room.cat.model_scale < 0.4 and dh > room.cat.model_scale * 4.0, "cat is cat-sized next to the humans")
	# Daniel walks his routine.
	var p0: Vector3 = daniel.global_position
	var walked := await until(func() -> bool: return daniel.global_position.distance_to(p0) > 0.8, 400)
	check(walked, "Daniel walks his routine")
	var reached_dwell := await until(func() -> bool: return daniel.state_name() == "dwell", 700)
	check(reached_dwell, "Daniel reaches a stand station and dwells")
	# Folasade's loop: she sits at the couch, then (with dwell sped
	# up) stands and walks again — the routine loops.
	fola.dwell_scale = 6.0
	var sat := await until(func() -> bool: return fola.is_seated(), 700)
	check(sat, "Folasade sits at the couch (lap state)")
	check(room.system.is_lap_available(fola), "lap is available while she is seated")
	var looped := await until(func() -> bool: return fola.state_name() == "walk", 1400)
	check(looped, "routine loops: she stands and walks again")
	room.queue_free()
	await frames(5)


# --- ankle attacks + shooing ------------------------------------------------------

func _test_ankle_and_shoo() -> void:
	print("OCC: ankle attack + shoo")
	var room = await new_room()
	await frames(5)
	var sys = room.system
	var daniel = room.daniel
	var fola = room.folasade
	var cat = room.cat
	# Park Daniel standing at the counter, facing it (-X).
	daniel.set_routine([{"pos": Vector3(-3.05, 0, -1.2), "yaw": PI / 2.0, "action": "stand", "dwell": 999.0}])
	daniel.place_at(Vector3(-3.05, 0, -1.2), PI / 2.0)
	await frames(10)
	check(not daniel.is_seated(), "Daniel standing for the ankle test")
	# Stage the cat so its paw lands on his ankle.
	cat.global_position = Vector3(-2.45, 0.05, -1.2)
	cat.rotation.y = PI / 2.0 # face -X, toward Daniel
	cat.set_move_input(Vector3.ZERO, false, false)
	await frames(5)
	var score0: int = sys.total_score
	check(cat.strike(), "cat strikes at the ankle")
	var fired := await until(func() -> bool: return sys.event_count("ankle_attack") >= 1, 40)
	check(fired, "ankle_attack event fired")
	check(sys.event_count("ankle_attack") == 1, "ankle_attack fired exactly once")
	check(sys.total_score - score0 >= 25, "ankle attack scored +25 (total %d)" % sys.total_score)
	check(daniel.last_reaction() == "hop", "Daniel hops (got '%s')" % daniel.last_reaction())
	# Cooldown: a second strike inside 10 s scores nothing.
	await frames(50)
	cat.strike()
	await frames(25)
	check(sys.event_count("ankle_attack") == 1, "ankle cooldown respected (still 1 in window)")
	# Shoo: strike at seated Folasade's ankle from the floor.
	fola.dwell_scale = 0.05
	var sat := await until(func() -> bool: return fola.is_seated(), 900)
	check(sat, "Folasade seated for the shoo test")
	if sat:
		cat.global_position = Vector3(3.27, 0.05, -1.50)
		cat.rotation.y = 0.0 # face -Z, toward her ankles
		cat.set_move_input(Vector3.ZERO, false, false)
		await frames(5)
		var z0: float = cat.global_position.z
		cat.strike()
		var shooed := await until(func() -> bool: return sys.event_count("ankle_shoo") >= 1, 40)
		check(shooed, "seated ankle strike gets the cat shooed")
		check(cat.global_position.z > z0 + 0.15, "shoo pushes the cat back (z %.2f -> %.2f)" % [z0, cat.global_position.z])
		check(sys.lap_lockout_left(fola) > 0.0, "shoo locks the lap out briefly")
		check(not sys.is_lap_available(fola), "lap unavailable during lockout")
	room.queue_free()
	await frames(5)


# --- underfoot crossings -------------------------------------------------------------

func _patrol_room() -> Node:
	var room = await new_room()
	await frames(5)
	room.daniel.set_routine([
		{"pos": Vector3(4.5, 0, 0), "yaw": -PI / 2.0, "action": "stand", "dwell": 0.1},
		{"pos": Vector3(-4.5, 0, 0), "yaw": PI / 2.0, "action": "stand", "dwell": 0.1},
	])
	room.daniel.place_at(Vector3(-4.5, 0, 0), -PI / 2.0)
	room.folasade.place_at(Vector3(-4.0, 0, 3.8), 0.0)
	room.folasade.set_routine([{"pos": Vector3(-4.0, 0, 3.8), "yaw": 0.0, "action": "stand", "dwell": 999.0}])
	return room


func _wait_daniel_eastbound(room: Node) -> bool:
	return await until(func() -> bool:
		return room.daniel.is_walking() and room.daniel.velocity.x > 0.3 and room.daniel.global_position.x > -3.6, 500)


func _test_underfoot() -> void:
	print("OCC: underfoot crossings")
	# (a) A genuine front crossing scores.
	var room = await _patrol_room()
	var sys = room.system
	var daniel = room.daniel
	var cat = room.cat
	check(await _wait_daniel_eastbound(room), "Daniel patrols eastbound")
	cat.global_position = Vector3(daniel.global_position.x + 0.85, 0.05, -1.05)
	cat.rotation.y = PI # face +Z
	cat.set_move_input(Vector3(0, 0, 1), true, false)
	var crossed := await until(func() -> bool: return sys.event_count("underfoot") >= 1, 300)
	cat.set_move_input(Vector3.ZERO, false, false)
	check(crossed, "front crossing fires underfoot")
	check(sys.event_count("trip_hazard") == 0, "no trip on a wide crossing (ahead ~0.66)")
	room.queue_free()
	await frames(5)
	# (b) Running beside him scores nothing.
	room = await _patrol_room()
	sys = room.system
	daniel = room.daniel
	cat = room.cat
	check(await _wait_daniel_eastbound(room), "Daniel patrols eastbound (beside case)")
	cat.global_position = Vector3(daniel.global_position.x + 0.5, 0.05, daniel.global_position.z + 0.95)
	cat.rotation.y = -PI / 2.0 # face +X, parallel
	cat.set_move_input(Vector3(1, 0, 0), true, false)
	await frames(80)
	cat.set_move_input(Vector3.ZERO, false, false)
	check(sys.event_count("underfoot") == 0, "running beside him scores nothing")
	room.queue_free()
	await frames(5)
	# (c) Crossing behind him scores nothing.
	room = await _patrol_room()
	sys = room.system
	daniel = room.daniel
	cat = room.cat
	check(await _wait_daniel_eastbound(room), "Daniel patrols eastbound (behind case)")
	cat.global_position = Vector3(daniel.global_position.x - 0.85, 0.05, -1.05)
	cat.rotation.y = PI
	cat.set_move_input(Vector3(0, 0, 1), true, false)
	await frames(120)
	cat.set_move_input(Vector3.ZERO, false, false)
	check(sys.event_count("underfoot") == 0, "crossing behind him scores nothing")
	room.queue_free()
	await frames(5)
	# (d) A dead-centre cut-off trips him (forced roll).
	room = await _patrol_room()
	sys = room.system
	daniel = room.daniel
	cat = room.cat
	sys.force_stumble = true
	check(await _wait_daniel_eastbound(room), "Daniel patrols eastbound (trip case)")
	cat.global_position = Vector3(daniel.global_position.x + 0.45, 0.05, -0.80)
	cat.rotation.y = PI
	cat.set_move_input(Vector3(0, 0, 1), true, false)
	var tripped := await until(func() -> bool: return sys.event_count("trip_hazard") >= 1, 300)
	cat.set_move_input(Vector3.ZERO, false, false)
	check(tripped, "dead-centre cut-off fires trip_hazard")
	check(daniel.last_reaction() == "stumble", "Daniel stumbles (windmill)")
	room.queue_free()
	await frames(5)


# --- the lap: healing, standing, attacking --------------------------------------------

func _test_lap() -> void:
	print("OCC: lap + petting heals")
	var room = await new_room()
	await frames(5)
	var sys = room.system
	var fola = room.folasade
	var cat = room.cat
	fola.dwell_scale = 0.05 # she stays seated for the whole test
	room.daniel.dwell_scale = 0.05
	var health = CatHealthScript.new()
	health.name = "CatHealth"
	cat.add_child(health)
	await frames(3)
	health.hp = 40.0
	var sat := await until(func() -> bool: return fola.is_seated(), 900)
	check(sat, "Folasade seated for the lap test")
	if not sat:
		room.queue_free()
		return
	cat.global_position = Vector3(3.27, 0.05, -1.15)
	cat.rotation.y = 0.0
	cat.set_move_input(Vector3.ZERO, false, false)
	await frames(5)
	check(sys.try_mount_lap(cat), "cat mounts the lap")
	check(sys.lap_session_active(fola), "lap session active")
	check(bool(cat.get_meta("on_lap", false)), "cat flagged safe on the lap")
	await frames(180) # 3 s at +10%/s from 40 -> ~70
	check(health.hp >= 62.0, "petting heals: hp %.1f after 3 s (from 40)" % health.hp)
	await frames(420) # -> full
	check(health.hp >= 99.9, "healed to full on the lap (hp %.1f)" % health.hp)
	check(sys.event_count("lap_full_heal") >= 1, "lap_full_heal objective event fired")
	await frames(300)
	check(sys.event_count("lap_purr") >= 2, "purr score ticks while being petted (%d)" % sys.event_count("lap_purr"))
	check(cat.global_position.distance_to(fola.lap_spot()) < 0.3 and cat.global_position.y > 0.4,
		"cat actually rests ON the lap (pinned at the spot, y %.2f)" % cat.global_position.y)
	# Standing up puts the cat down safely first.
	fola.end_dwell_now()
	var ended := await until(func() -> bool: return not sys.lap_session_active(fola), 200)
	check(ended, "session ends when she stands")
	await frames(30)
	check(cat.global_position.y < 0.35, "cat is on the floor, not dropped (y %.2f)" % cat.global_position.y)
	check(not cat.is_lounging, "cat no longer lounging after being put down")
	check(not bool(cat.get_meta("on_lap", true)), "on_lap flag cleared")
	# Attack from the lap: session over, lockout, no heal-scam.
	fola.set_routine([{"pos": Vector3(3.27, 0, -2.18), "yaw": PI, "action": "sit", "dwell": 999.0}])
	fola.go_station(0)
	var sat2 := await until(func() -> bool: return fola.is_seated(), 900)
	check(sat2, "Folasade sits again for the attack test")
	if sat2:
		health.hp = 50.0
		cat.global_position = Vector3(3.27, 0.05, -1.15)
		cat.rotation.y = 0.0
		await frames(5)
		check(sys.try_mount_lap(cat), "cat mounts again")
		await frames(30)
		sys.attack_from_lap(cat)
		await frames(10)
		check(not sys.lap_session_active(fola), "attack from the lap ends the session")
		check(sys.lap_lockout_left(fola) > 0.0, "attack locks the lap out")
		check(not sys.try_mount_lap(cat), "no re-mount during lockout")
		check(cat.global_position.y < 0.35, "cat put down on the floor after the attack")
	room.queue_free()
	await frames(5)
