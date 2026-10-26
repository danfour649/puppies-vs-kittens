extends Node
## The night round on the full house: start, the floors, Glenys,
## dawn, and getting caught.
## Run: godot --headless --path godot3d res://tests/test_night_run.tscn

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
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _run() -> void:
	print("NIGHT RUN TESTS")
	await _briefing_tap()
	await _round()
	await _dawn()
	await _caught()
	await _gathered()
	print("NIGHT RUN TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _briefing_tap() -> void:
	DuoCharacters.last_choice = ""
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await frames(8)
	game.duo.select_ui.confirm()
	await frames(2)
	check(game.night.phase == "briefing", "picking a cat opens the briefing")
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = Vector2(200, 200)
	Input.parse_input_event(mb)
	await frames(2)
	check(game.night.phase == "briefing", "the click that picked the cat does not skip the card")
	game.night._brief_arm = 0.0
	Input.parse_input_event(mb)
	await frames(2)
	check(game.night.phase == "playing", "a later tap begins the night")
	game.queue_free()
	await frames(2)


func _boot():
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await frames(12)
	game.duo.choose("willie")
	await frames(4)
	check(not game.night._compass.visible, "the compass stays off the roster until the night starts")
	check(game.night._compass.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the compass does not take taps")
	game.night.start_playing()
	await frames(2)
	check(game.night._compass.visible, "the compass shows once the night is underway")
	return game


func _round() -> void:
	var game = await _boot()
	var night: NightRun = game.night
	var obj: PvKObjectives = game.objectives
	await frames(2)
	check(night.phase == "playing", "the night is underway")
	check(_named_buttons(game).is_empty(), "no RESTART, OBJECTIVES, or MEOW buttons (%s)" % " ".join(_named_buttons(game)))
	check(night.where_text().contains("Glenys"), "the compass says where Glenys is (%s)" % night.where_text())
	var hud := game.get_node("ObjectivesHUD") as ObjectivesHUD
	check(hud != null and not hud.panel_visible(), "the objective list starts folded")
	hud.toggle()
	check(hud.panel_visible() and night.objectives_open(), "tapping the compass opens the list")
	hud.toggle()
	check(obj.get_item("night:threshold") != null, "coming inside is an objective")
	check(obj.get_item("night:cellar") != null, "the basement is an objective")
	check(obj.get_item("night:attic") != null, "the attic is an objective")
	check(obj.get_item("night:glenys") != null, "Glenys is the ending")
	var door: Vector3 = HouseSpec.connectors(HouseSpec.OUTSIDE)[0]["at"]
	var aim: Vector3 = night.aim_point()
	check(Vector2(aim.x - door.x, aim.z - door.z).length() < 0.3, "the compass points at the front door")
	check(night.hint_text() == "The front door", "the compass names the front door")
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(2)
	check(obj.is_done("night:threshold"), "coming in from the yard counts")
	game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(2)
	check(obj.is_done("night:cellar"), "reaching the basement counts")
	check(night.hint_text().contains("attic") or night.hint_text().contains("Upstairs"), "the compass turns toward the attic (%s)" % night.hint_text())
	game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(2)
	check(obj.is_done("night:attic"), "reaching the attic counts")
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(2)
	var actor: Node3D = game.glenys.actor
	game.cat.global_position = actor.global_position + Vector3(0.7, 0.1, 0.2)
	await frames(8)
	check(obj.is_done("night:glenys"), "standing with Glenys ends the round")
	check(night.phase == "won", "the night is won")
	check(night._banner.text.contains("Press R"), "the ending offers a restart")
	game.queue_free()
	await frames(2)


func _dawn() -> void:
	var game = await _boot()
	var night: NightRun = game.night
	night.seconds_left = 0.2
	await frames(30)
	check(night.phase == "failed", "dawn ends the night")
	check(night.fail_reason == "dawn", "the fail is dawn")
	check(night._banner.text.contains("Press R"), "dawn offers a restart")
	check(night.blocks_move(), "dawn holds the cat")
	game.queue_free()
	await frames(2)


func _caught() -> void:
	var game = await _boot()
	var night: NightRun = game.night
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(4)
	night.seconds_left = 12.0
	check(game.glenys.debug_grab(), "she has him")
	await frames(120)
	check(night.phase == "failed", "staying caught ends the night")
	check(night.fail_reason == "caught", "the fail is caught")
	check(night._banner.text.contains("Glenys"), "the caught line is about Glenys")
	check(not night._banner.text.contains("crazy"), "the caught line stays kind")
	game.queue_free()
	await frames(2)


func _gathered() -> void:
	var game = await _boot()
	var night: NightRun = game.night
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(2)
	game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(2)
	game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(2)
	game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await frames(4)
	check(game.glenys.debug_grab(), "she gathers him after the rounds")
	await frames(8)
	check(night.phase == "won", "being gathered in after the rounds is the ending")
	check(night._banner.text.contains("glad"), "that ending is glad, not a scolding")
	game.queue_free()
	await frames(2)


func _named_buttons(node: Node) -> PackedStringArray:
	var bad: PackedStringArray = []
	if node is Button:
		var t := String((node as Button).text)
		if t == "RESTART" or t == "OBJECTIVES" or t == "MEOW":
			bad.append(t)
	for c: Node in node.get_children():
		for bit: String in _named_buttons(c):
			bad.append(bit)
	return bad
