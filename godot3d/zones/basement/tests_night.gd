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
	_ledger()
	var hunt: NightHunt = HuntScene.instantiate()
	hunt.autostart = true
	hunt.seed_value = 42
	add_child(hunt)
	await frames(20)
	check(hunt.phase == "play", "the night starts without the title card when asked (phase %s)" % hunt.phase)
	check(hunt.cat != null and hunt.cat.species_name == "Willie", "Willie is the cat you play")
	check(hunt.mice.size() == 5, "five mice in the stacks (got %d)" % hunt.mice.size())
	check(hunt.birds.size() == 3, "a small flock by the window (got %d)" % hunt.birds.size())
	check(hunt.moths.size() == 4, "moths on the lamps (got %d)" % hunt.moths.size())
	check(hunt.cellar_spider != null, "a spider keeps a thread by the heart lamp")
	check(hunt.ledger.objectives.size() == 4, "the night has four goals")
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
	check(hunt.ledger.gifts == 1, "the gift was scored")
	check(hunt.ledger.objective_done("gift"), "bringing it to her completes the gift goal")
	var line := ""
	if hunt.get("_end_body") != null:
		line = String(hunt._end_body.text)
	check(line.contains("Score"), "Glenys's answer names the score")
	for banned: String in ["stupid", "idiot", "crazy", "demented", "useless", "hate"]:
		check(not line.to_lower().contains(banned), "her line stays kind (no '%s')" % banned)

	print("NIGHT TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _ledger() -> void:
	var loop := NightLoop.new()
	loop.setup()
	var first: Dictionary = loop.note_catch(1.0, true)
	var second: Dictionary = loop.note_catch(2.2, false)
	check(int(first["points"]) == 115, "a quiet catch is the base plus a little extra (%d)" % int(first["points"]))
	check(int(second["combo"]) == 2, "a second catch inside the window is a combo")
	check(loop.objective_done("combo"), "two in a breath completes that goal")
	check(not loop.objective_done("mice"), "one short of three mice, that goal stays open")
	loop.note_catch(3.0, false)
	check(loop.objective_done("mice"), "the third mouse closes the night's hunt")
	var proud: Dictionary = loop.deliver_gift()
	check(String(proud["tone"]) == "delighted", "three in a row, and a tidy floor, delights her")
	check(String(proud["line"]).contains("thorough"), "the delighted line is proud of him")
	var noisy := NightLoop.new()
	noisy.setup()
	noisy.note_catch(0.0, false)
	noisy.note_noise("sprint", 12.0)
	noisy.note_noise("meow", 1.0)
	check(noisy.mess_word() == "the house noticed", "a long sprint and a meow stir the house (%.1f)" % noisy.mess)
	var fond: Dictionary = noisy.deliver_gift()
	check(String(fond["tone"]) == "fond_exasperation", "a stirred house, and she is still glad of the gift")
	check(String(fond["line"]).contains("lovely"), "she says the gift is lovely")
	var broken := NightLoop.glenys_line("fond_exasperation", 1, 80.0) + NightLoop.glenys_line("quiet_pride", 1, 0.0) + NightLoop.glenys_line("delighted", 3, 90.0) + NightLoop.glenys_line("pleased", 1, 30.0)
	for banned: String in ["stupid", "idiot", "crazy", "demented", "useless", "hate"]:
		check(not broken.to_lower().contains(banned), "ledger lines stay kind (no '%s')" % banned)
