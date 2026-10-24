extends Node
# Headless checks for the Massey outside zone (zones/outside):
# trees + squirrels, the feeder bird stream + bush ambush, hostile
# Massey Street traffic, and pedestrians walking dogs.
# Run: godot --headless --path godot3d res://zones/outside/tests_outside.tscn
# Assertions read actor STATE only (same rule as the smoke suite).

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


func _wait_for(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func tp(c: Node3D, pos: Vector3) -> void:
	c.velocity = Vector3.ZERO
	c.global_position = pos


func face(c: Node3D, target: Vector3) -> void:
	var d := target - c.global_position
	c.rotation.y = atan2(-d.x, -d.z)


func _ready() -> void:
	print("OUTSIDE TESTS (Willie and Aggie — Massey outside zone)")
	var game: Node = load("res://main.tscn").instantiate()
	add_child(game)
	await frames(10)
	game.duo.choose("willie")
	await frames(5)
	var cat: PvKCat = game.cat
	var sys: OutsideSystem = game.outside
	check(sys != null, "outside system present")
	# Hold the ambient spawners; every phase stages its own actors.
	sys.debug_clear_cars()
	sys.debug_clear_birds()
	sys.debug_clear_walkers()
	sys._walker_t = 9999.0
	sys._bird_spawn_t = 9999.0
	check(sys.trees.size() == 3, "three yard trees")
	check(sys.squirrels.size() == 3, "three squirrels")
	check(sys.objectives.size() == 7, "seven objectives registered")

	# ---------------------------------------------------------------
	# 1. A squirrel flees to its branch and taunts, safe from paws.
	var sq: PvKSquirrel = sys.squirrels[0]
	var tree: YardTree = sq.home_tree
	await _wait_for(func() -> bool: return sq.state == "forage", 120)
	tp(cat, sq.global_position + Vector3(1.8, 0, 0))
	var fled := await _wait_for(func() -> bool: return sq.state == "taunt", 600)
	check(fled, "squirrel fled up the trunk and taunts")
	await _wait_for(func() -> bool: return sys.squirrels_treed >= 1, 60)
	check(sys.squirrels_treed >= 1, "treed event counted")
	check(sq.is_safe(), "taunting squirrel reads safe")
	tp(cat, tree.global_position + tree.branch_dir * 0.75)
	face(cat, tree.global_position)
	await frames(30) # let the strike cooldown from setup settle
	cat.strike()
	await frames(12)
	check(sq.state == "taunt" and sq.hp == 2, "ground paw cannot reach a taunting squirrel")

	# ---------------------------------------------------------------
	# 2. That same paw at the trunk starts the climb; the cat
	#    reaches the branch and swipes the squirrel down a hit.
	check(sys.climbing(), "paw at the trunk started the climb")
	sys.climb_axis_debug = 1.0
	var topped := await _wait_for(func() -> bool: return sys.climb_y() >= tree.branch_y - 0.01, 300)
	check(topped, "cat climbed to the first branch")
	check(cat.global_position.y > 1.2, "cat is up the trunk")
	sys.climb_swipe()
	check(sq.hp == 1, "branch swipe landed (squirrel hp 2 -> 1)")
	sys.climb_axis_debug = -1.0
	var down := await _wait_for(func() -> bool: return not sys.climbing(), 300)
	sys.climb_axis_debug = 0.0
	check(down, "cat climbed back down")
	await frames(20)
	check(cat.is_on_floor(), "cat back on the ground")

	# ---------------------------------------------------------------
	# 3. A pounce timed as a squirrel starts climbing catches it.
	var sq2: PvKSquirrel = sys.squirrels[1]
	var tree2: YardTree = sq2.home_tree
	tp(cat, tree2.global_position + tree2.branch_dir * 0.7)
	face(cat, tree2.global_position)
	await frames(30)
	sys.catch_roll_override = 0.0 # force the catch roll
	sq2.debug_force_climb()
	cat.strike()
	await frames(10)
	check(sq2.state == "caught", "trunk-base pounce caught the squirrel mid-climb")
	sys.catch_roll_override = -1.0
	await frames(40) # let the caught tween finish

	# ---------------------------------------------------------------
	# 4. The bird stream: spawns, lands, pecks; the cap holds.
	sys.debug_resume_birds()
	var landed := await _wait_for(func() -> bool: return sys.pecking_birds().size() >= 1, 900)
	check(landed, "stream bird landed and pecks")
	check(sys.birds.size() >= 1 and sys.birds.size() <= OutsideLayout.BIRD_MAX, "concurrent bird cap respected")
	sys.debug_clear_birds()

	# 5. Scare radii: a still cat at 2 m is ignored; a MOVING cat
	#    at the same distance bursts the bird off.
	var bpos := Vector3(3.0, 0, 0.5)
	var bird: PvKBird = sys.debug_spawn_bird_near(bpos)
	await _wait_for(func() -> bool: return bird.state == "peck", 240)
	tp(cat, bpos + Vector3(2.0, 0, 0))
	await frames(25)
	check(bird.state == "peck", "still cat nearby does not scare a pecking bird")
	game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": false}
	var burst := await _wait_for(func() -> bool: return bird.state == "flee", 120)
	game.input_override = {"active": false}
	check(burst, "moving cat bursts the bird off")

	# ---------------------------------------------------------------
	# 6. Ambush: hidden + still in a bush, a bird lands inside
	#    pounce range and a strike from hiding registers.
	sys.debug_clear_birds()
	var bush_a: Vector3 = OutsideLayout.BUSH_A
	tp(cat, bush_a)
	game.input_override = {"active": true, "move": Vector2.ZERO, "sprint": false, "stalk": true}
	var still := await _wait_for(func() -> bool: return sys.stillness > 0.6, 360)
	check(still, "stillness meter filled while hidden in the bush")
	check(sys.cat_hidden(cat), "cat reads hidden in the bush")
	var to_feeder := OutsideLayout.FEEDER_POS - bush_a
	to_feeder.y = 0.0
	var bird2: PvKBird = sys.debug_spawn_bird_near(bush_a + to_feeder.normalized() * 1.15)
	await _wait_for(func() -> bool: return bird2.state == "peck", 240)
	face(cat, bird2.global_position)
	var ambush_before: int = sys.ambush_catches
	cat.strike()
	await frames(12)
	game.input_override = {"active": false}
	check(bird2.state == "caught", "pounce from the bush caught the bird")
	check(sys.ambush_catches == ambush_before + 1, "ambush catch counted")
	check(bool(sys.objectives["first_bird"]["done"]), "objective: First bird")

	# ---------------------------------------------------------------
	# 7. Willie's meow while hiding scatters the flock + the meter.
	sys.debug_clear_birds()
	var bird3: PvKBird = sys.debug_spawn_bird_near(Vector3(7.0, 0, 2.6))
	var bird4: PvKBird = sys.debug_spawn_bird_near(Vector3(8.2, 0, 3.8))
	await _wait_for(func() -> bool: return bird3.state == "peck" and bird4.state == "peck", 300)
	tp(cat, OutsideLayout.BUSH_B)
	await frames(10)
	sys.stillness = 0.8
	var meows_before: int = game.duo.meow_count
	game.duo.player_meow()
	await frames(6)
	check(game.duo.meow_count > meows_before, "Willie meowed")
	check(bird3.state == "flee" and bird4.state == "flee", "meow in the bush scattered the flock")
	check(sys.stillness < 0.25, "meow emptied the stillness meter")
	tp(cat, Vector3(2.5, 0.05, -6.2)) # back to the yard for traffic staging

	# ---------------------------------------------------------------
	# 8. Traffic ignores a lawn cat; it hunts a road cat (honk!).
	var car1: PvKCar = sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, -8.0)
	await frames(50)
	check(not car1.hostile and not car1.honked, "car ignores a cat on the lawn")
	sys.debug_clear_cars()
	tp(cat, Vector3(2.5, 0.05, OutsideLayout.LANE_NEAR_Z + 0.7))
	var car2: PvKCar = sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, -4.0)
	var hunting := await _wait_for(func() -> bool: return car2.hostile, 120)
	check(hunting, "car targets the cat on the road")
	check(car2.honked, "car honked its telegraph")
	check(car2.target_z > car2.lane_z + 0.3, "car steers toward the cat")
	await frames(10)
	check(car2.global_position.z > car2.lane_z + 0.15, "car swerved toward the cat")
	tp(cat, Vector3(2.5, 0.05, -6.2))
	sys.debug_clear_cars()

	# 9. The Corolla island: a sheltered cat is not targeted.
	tp(cat, Vector3(OutsideLayout.COROLLA_POS.x, 0.05, OutsideLayout.LANE_NEAR_Z + 0.7))
	check(sys.cat_sheltered(cat.global_position), "cat behind the Corolla reads sheltered")
	var car3: PvKCar = sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, 0.0)
	await frames(55)
	check(not car3.hostile and not car3.honked, "sheltered cat is not targeted")
	sys.debug_clear_cars()

	# ---------------------------------------------------------------
	# 10. Crossing there-and-back flips the objective; the fish
	#     treat across the street fully heals.
	sys.debug_reset_road()
	tp(cat, Vector3(0.0, 0.05, -21.5))
	await frames(8)
	tp(cat, Vector3(0.0, 0.05, -17.0))
	await frames(8)
	tp(cat, Vector3(0.0, 0.05, -12.0))
	await frames(8)
	check(sys.crossings_total >= 1, "a crossing was counted")
	check(bool(sys.objectives["cross_massey_back"]["done"]), "objective: Cross Massey and back")
	sys.hp = 35.0
	tp(cat, OutsideLayout.FISH_TREAT_POS + Vector3(0, 0.05, 0))
	await frames(12)
	check(sys.hp == OutsideLayout.CAT_HP_MAX, "fish treat fully healed the cat")
	tp(cat, Vector3(2.5, 0.05, -6.2))
	await frames(5)

	# ---------------------------------------------------------------
	# 11. The HIT: heavy damage + a dramatic launch off the road.
	sys.debug_reset_road()
	tp(cat, Vector3(4.0, 0.05, OutsideLayout.LANE_NEAR_Z))
	sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, -3.0, 8.0)
	var hit := await _wait_for(func() -> bool: return sys.last_damage_kind == "vehicle", 300)
	check(hit, "vehicle hit registered")
	check(sys.last_damage == OutsideLayout.DMG_VEHICLE_HIT, "vehicle hit = 60 damage")
	check(sys.launch_active(), "hit launched the cat")
	var off_road := await _wait_for(func() -> bool: return not sys.cat_on_road(cat.global_position) and cat.is_on_floor() and not sys.launch_active(), 360)
	check(off_road, "cat landed off the road")
	check(sys.hp == OutsideLayout.CAT_HP_MAX - OutsideLayout.DMG_VEHICLE_HIT, "hp reflects the hit")

	# 12. A slow brush: small damage + shove, no launch.
	sys.debug_reset_road()
	tp(cat, Vector3(4.0, 0.05, OutsideLayout.LANE_NEAR_Z))
	sys.debug_spawn_car(OutsideLayout.LANE_NEAR_Z, 1.0, 1.5)
	var brushed := await _wait_for(func() -> bool: return sys.last_damage_kind == "vehicle_brush", 300)
	check(brushed, "slow brush registered")
	check(sys.last_damage == OutsideLayout.DMG_VEHICLE_BRUSH, "brush = 10 damage")
	check(not sys.launch_active(), "brush does not launch")
	sys.debug_clear_cars()
	tp(cat, Vector3(2.5, 0.05, -6.2))
	await frames(5)

	# ---------------------------------------------------------------
	# 13. Walkers + dogs.
	var w1: PvKWalker = sys.debug_spawn_walker(1.0, "small")
	var dog1: PvKDog = sys.dog
	check(dog1 != null and dog1.state == "heel", "walker pair spawned, dog at heel")
	var wx0: float = w1.global_position.x
	await frames(90)
	check(w1.global_position.x > wx0 + 1.5, "walker traverses the sidewalk")
	# The region gate: a backyard cat right across the fence line
	# must NOT alert the dog, even inside the alert radius.
	tp(cat, Vector3(-12.0, 0.05, -9.5))
	var any_alert := false
	for i in 12:
		await frames(30)
		if dog1.state != "heel":
			any_alert = true
	check(not any_alert, "dog ignores a backyard cat (front-zone gate)")
	# The same cat in the front yard: alert, then strain.
	tp(cat, Vector3(-12.0, 0.05, -12.2))
	var strained := await _wait_for(func() -> bool: return dog1.state == "strain", 420)
	check(strained, "dog alerts and strains at a front-yard cat")
	var dmax := 0.0
	var dmin := 99.0
	for i in 30:
		await get_tree().physics_frame
		var d := Vector2(dog1.global_position.x - dog1.human.hand_pos().x, dog1.global_position.z - dog1.human.hand_pos().z).length()
		dmax = maxf(dmax, d)
		dmin = minf(dmin, d)
	check(dmax <= OutsideLayout.LEASH_LEN + 0.15, "strain respects the leash limit")
	check(dmin >= 1.3, "dog is OUT at the leash end (the comedy)")
	check(dog1.human.skidding, "owner leans back and skids")
	# Close cat: the leash slips and the chase is on.
	tp(cat, dog1.global_position + Vector3(0.75, 0, 0.25))
	var chasing := await _wait_for(func() -> bool: return dog1.state == "chase", 120)
	check(chasing, "close cat slipped the leash -> chase")
	check(w1.state == "wait", "owner waits, leash-less")
	# Escape valve: up the west tree.
	var tree_w: YardTree = sys.trees[0]
	tp(cat, tree_w.global_position + Vector3(0.75, 0, 0))
	check(sys.try_start_climb(), "cat took to the tree mid-chase")
	sys.climb_axis_debug = 1.0
	var orbiting := await _wait_for(func() -> bool: return dog1.state == "orbit", 180)
	check(orbiting, "dog circles the trunk")
	await _wait_for(func() -> bool: return sys.climb_y() >= tree_w.branch_y - 0.02, 300)
	var gave_up := await _wait_for(func() -> bool: return dog1.state == "return" or dog1.state == "heel", 480)
	check(gave_up, "dog gave up on the treed cat")
	check(sys.dog_escapes >= 1, "escape counted (Dog dodger progress)")
	sys.climb_axis_debug = -1.0
	await _wait_for(func() -> bool: return not sys.climbing(), 300)
	sys.climb_axis_debug = 0.0
	await frames(20)

	# 14. Big dog: bite = 20, two quick bites -> grab = 30 + burst.
	sys.debug_clear_walkers()
	await frames(5)
	sys.debug_spawn_walker(1.0, "big")
	var dog2: PvKDog = sys.dog
	sys.walker.global_position.x = -10.0 # stage mid-street, on solid ground
	await _wait_for(func() -> bool: return absf(dog2.global_position.x - sys.walker.global_position.x) < 2.5, 420)
	tp(cat, Vector3(-6.5, 0.05, -12.0))
	var strained2 := await _wait_for(func() -> bool: return dog2.state == "strain", 420)
	check(strained2, "big dog strains at the cat")
	var hp0: float = sys.hp
	tp(cat, dog2.global_position + Vector3(0.7, 0, 0.2))
	await _wait_for(func() -> bool: return dog2.state == "chase", 120)
	var bit := await _wait_for(func() -> bool: return sys.last_damage_kind == "dog_bite", 240)
	check(bit and sys.last_damage == 20.0, "big-dog bite = 20 damage")
	check(sys.hp == hp0 - 20.0, "bite applied exactly once")
	var grabbed := await _wait_for(func() -> bool: return sys.last_damage_kind == "dog_grab", 300)
	check(grabbed and sys.last_damage == 30.0, "second quick bite -> grab = 30 damage")
	check(sys.hp == hp0 - 20.0 - 20.0 - 30.0, "grab sequence applied once per event")
	check(sys.launch_active(), "cat burst free of the grab")
	var bites := 0
	for e: Dictionary in sys.damage_log:
		if String(e["kind"]) == "dog_bite":
			bites += 1
	check(bites == 2, "exactly two bite events (no per-frame drain)")
	# The pair despawns at the street end once the dog is back.
	await _wait_for(func() -> bool: return dog2.state == "heel", 600)
	sys.walker.global_position.x = 17.9
	await frames(90)
	check(sys.walker == null, "walker pair despawned at the street end")

	# 15. The sibling never left the backyard through all of it.
	check(game.aggie.global_position.z > -9.9, "sibling stayed a backyard cat")

	print("OUTSIDE DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
