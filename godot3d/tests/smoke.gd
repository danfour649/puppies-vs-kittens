extends Node
## Headless smoke test for Puppies vs Kittens 3D.
## Run: godot --headless --path godot3d res://tests/smoke.tscn
## Drives the real game through its input_override seam and asserts on
## STATE only — never on rendered pixels (headless readbacks lie).

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
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _run() -> void:
	print("SMOKE: loading main scene")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(10)
	var cat = _game.cat
	check(cat != null, "cat exists")
	check(_game.mice.size() == 7, "7 mice spawned (got %d)" % _game.mice.size())
	check(cat.anim_state == "idle", "cat starts idle (got %s)" % cat.anim_state)
	check(cat.is_on_floor(), "cat stands on the ground")
	check(cat.global_position.y > -0.1 and cat.global_position.y < 0.2, "cat at ground height (y=%.2f)" % cat.global_position.y)
	check(cat.species_name == "Willy", "cat is Willy (got %s)" % cat.species_name)
	# Scripted walk.
	var start_pos: Vector3 = cat.global_position
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": false}
	await frames(60)
	var moved := Vector2(cat.global_position.x - start_pos.x, cat.global_position.z - start_pos.z).length()
	check(moved > 0.8, "cat moved %.2f m under scripted input" % moved)
	check(cat.anim_state == "walk", "cat walks (got %s)" % cat.anim_state)
	# Sprint drains stamina.
	var st0: float = cat.stamina
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": true, "stalk": false}
	await frames(45)
	check(cat.anim_state == "sprint", "cat sprints (got %s)" % cat.anim_state)
	check(cat.stamina < st0 - 3.0, "stamina drains (%.1f -> %.1f)" % [st0, cat.stamina])
	# Stalk is slow and low.
	_game.input_override = {"active": true, "move": Vector2(0, 1), "sprint": false, "stalk": true}
	await frames(20)
	check(cat.anim_state == "stalk", "cat stalks (got %s)" % cat.anim_state)
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}
	await frames(10)
	# Lounge on command.
	cat.set_lounge(true)
	await frames(5)
	check(cat.anim_state == "lounge", "cat lounges (got %s)" % cat.anim_state)
	cat.set_lounge(false)
	await frames(5)
	# Freeze the mice (cut their cat reference) so the catch checks are
	# about the strike mechanic, not about flee timing.
	for m in _game.mice:
		m.cat = null
	await _catch_one(cat, _game.mice[0])
	check(_game.caught_count == 1, "strike caught a mouse (caught=%d)" % _game.caught_count)
	# Catch the rest -> win state.
	for i in range(1, _game.mice.size()):
		await _catch_one(cat, _game.mice[i])
	check(_game.won, "win state reached after all mice caught")
	check((_game.get("_banner") as Label).visible, "win banner visible")
	print("SMOKE DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _catch_one(cat, mouse) -> void:
	# Stand the cat half a metre behind the mouse, facing it (-Z fwd).
	cat.velocity = Vector3.ZERO
	cat.global_position = Vector3(mouse.global_position.x, 0.05, mouse.global_position.z + 0.5)
	cat.rotation.y = 0.0
	await frames(3)
	var ok: bool = cat.strike()
	check(ok, "strike started")
	await frames(4)
	check(cat.anim_state == "strike", "strike anim plays (got %s)" % cat.anim_state)
	# paw_swiped fires from the animation timeline (~0.10 s in); give it
	# real frames, then the cooldown, before the next catch.
	await frames(45)
