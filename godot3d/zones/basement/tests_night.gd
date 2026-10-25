extends Node
## The one-night basement: it builds, the cast is there, a paw
## catches, and the gift reaches Glenys.
## Run: godot --headless --path godot3d res://zones/basement/tests_night.tscn

const HuntScene := preload("res://zones/basement/night_hunt.tscn")

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
	for _i in n:
		await get_tree().process_frame
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _run() -> void:
	print("NIGHT TESTS")
	var hunt: NightHunt = HuntScene.instantiate()
	hunt.autostart = true
	hunt.seed_value = 42
	add_child(hunt)
	await frames(20)
	check(hunt.phase == "play", "the night starts without the title card when asked (phase %s)" % hunt.phase)
	check(hunt.cat != null and hunt.cat.species_name == "Willie", "Willie is the cat you play")
	check(hunt.mice.size() == 5, "five mice in the stacks (got %d)" % hunt.mice.size())
	check(hunt.birds.size() == 3, "a small flock by the window (got %d)" % hunt.birds.size())
	check(hunt.other != null and hunt.other.body != null and hunt.other.body.species_name == "Aggie", "Aggie is the other cat, on her own brain")
	check(hunt.get_node_or_null("Glenys") != null, "Glenys is at the stairs")
	var report: Dictionary = HoarderGenerator.playable(hunt.level, true)
	var why := ""
	if not bool(report["ok"]):
		why = ", ".join(report["reasons"])
	check(bool(report["ok"]), "the night's basement is a playable level%s" % ("" if why == "" else " — " + why))
	check(hunt.cat.is_on_floor(), "Willie is standing on the floor")

	var mouse: BasementMouse = hunt.mice[0]
	mouse.set_process(false)
	mouse.global_position = hunt.cat.paw_point()
	hunt.cat.strike()
	await frames(15)
	check(hunt.caught == 1, "a paw in range catches a mouse (caught %d)" % hunt.caught)

	hunt.debug_force_gift()
	check(hunt.phase == "gift" and hunt.carrying_gift, "three mice and the gift is for Glenys")
	for _i in 8:
		hunt.cat.global_position = hunt.glenys_pos + Vector3(0, 0.12, -0.45)
		hunt.cat.velocity = Vector3.ZERO
		await frames(1)
	check(hunt.phase == "end", "bringing it to her ends the night (phase %s)" % hunt.phase)
	check(hunt.cat.is_lounging, "Willie does the lounge flop")

	print("NIGHT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
