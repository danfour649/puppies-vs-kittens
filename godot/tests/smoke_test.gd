extends SceneTree

## Headless smoke test for Puppies vs Kittens (Godot edition).
##
## Run:  godot --headless --path godot -s res://tests/smoke_test.gd
##
## Drives the real game scene with the game's own API (start_round,
## debug_move, try_strike, toggle_bird_mode, quit_round) and asserts on
## game STATE — the data fed in — never on rendered pixels. Exits 0 on
## pass, 1 on failure, 2 on watchdog timeout.

var _game: Node = null
var _failures: int = 0
var _elapsed: float = 0.0
var _done: bool = false


func _check(ok: bool, what: String) -> void:
    if ok:
        print("SMOKE OK: ", what)
    else:
        _failures += 1
        print("SMOKE FAIL: ", what)


func _process(delta: float) -> bool:
    _elapsed += delta
    if _elapsed > 90.0 and not _done:
        print("SMOKE RESULT: FAIL (watchdog timeout)")
        quit(2)
        return true
    return false


func _initialize() -> void:
    var ps: PackedScene = load("res://main.tscn")
    _game = ps.instantiate()
    root.add_child(_game)
    await create_timer(0.2).timeout

    # --- round setup (hard: the full Java table) ---
    _game.start_round("hard")
    await physics_frame
    _check(_game.mice_remaining == 21, "hard spawns 21 mice (got %d)" % _game.mice_remaining)
    _check(_game.puppies.size() == 3, "hard spawns 3 puppies (got %d)" % _game.puppies.size())
    _check(is_instance_valid(_game.kitten) and int(_game.kitten.hp) == 100, "kitten starts at 100 hp")
    _check(is_instance_valid(_game.wild_bird), "wild bird NPC is on the field")
    _check(_game.state == "playing", "state is playing")

    # --- movement: debug input drives the kitten right ---
    var start_x: float = _game.kitten.position.x
    _game.debug_move = Vector2.RIGHT
    await create_timer(1.0).timeout
    _game.debug_move = Vector2.ZERO
    _check(_game.kitten.position.x > start_x + 120.0,
        "kitten moves under input (%.0f -> %.0f)" % [start_x, _game.kitten.position.x])

    # --- strike wounds a mouse at the paw; wound kills after 3 s (Java TTL) ---
    # Shield the kitten: on hard the (now correctly dangerous) puppies can
    # legitimately kill it during this 3.4 s window and end the round early.
    _game.kitten.hp = 100000.0
    var mouse: Animal = _game.mice[0]
    _game.kitten.facing = Vector2.RIGHT
    mouse.position = _game.kitten.paw_point()
    _game.kitten.try_strike()
    await physics_frame
    _check(mouse.is_wounded, "paw strike wounds the mouse at the paw point")
    await create_timer(3.4).timeout
    _check(_game.kills >= 1, "wounded mouse died after TTL, kills=%d" % _game.kills)
    _check(_game.mice_remaining == 21 - _game.kills,
        "mice_remaining consistent with kills (21 - %d = %d)" % [_game.kills, _game.mice_remaining])

    # --- puppy DPS: 20 hp per second per fighting puppy on hard ---
    _game.kitten.hp = 100000.0 # isolate the measurement from other puppies
    var hp_before: float = _game.kitten.hp
    _game.puppies[0].position = _game.kitten.position
    await create_timer(2.6).timeout
    var dropped: float = hp_before - _game.kitten.hp
    _check(dropped >= 20.0, "fighting puppy drains kitten hp (dropped %.0f in 2.6 s)" % dropped)
    _game.kitten.hp = 100.0

    # --- bird mode: possession swap, climb, dive, climb ---
    _game.toggle_bird_mode()
    await physics_frame
    _check(_game.player == _game.player_bird, "bird mode: player possesses the bird")
    _check(_game.kitten.brain == "wanderer", "bird mode: kitten stays in the world as an NPC")
    var frames := 0
    while is_instance_valid(_game.player_bird) and _game.player_bird.flight_phase != "cruise" and frames < 300:
        await physics_frame
        frames += 1
    _check(_game.player_bird.flight_phase == "cruise", "bird climbs to cruise (altitude %.2f)" % _game.player_bird.altitude)
    if is_instance_valid(_game.player_bird):
        _game.player_bird.try_strike() # SPACE = dive
        var saw_dive := false
        frames = 0
        while frames < 300 and is_instance_valid(_game.player_bird):
            await physics_frame
            frames += 1
            if _game.player_bird.flight_phase == "dive":
                saw_dive = true
            if saw_dive and _game.player_bird.altitude > 0.8:
                break
        _check(saw_dive, "bird dived on strike input")
        _check(is_instance_valid(_game.player_bird) and _game.player_bird.altitude > 0.8,
            "bird climbed back out of the dive")
    else:
        _check(false, "bird dived on strike input (no player bird)")
        _check(false, "bird climbed back out of the dive (no player bird)")

    # --- quit with mice left is a loss (Java rule) ---
    _game.quit_round()
    _check(_game.state == "over", "quit ends the round")
    _check(_game.was_lost, "quit with mice remaining counts as a loss")

    _done = true
    if _failures == 0:
        print("SMOKE RESULT: PASS")
        quit(0)
    else:
        print("SMOKE RESULT: FAIL (%d failures)" % _failures)
        quit(1)
