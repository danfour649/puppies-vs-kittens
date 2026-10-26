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
	_gesture_math()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NightHunt.HINT_FILE))
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
	check(hunt.gesture_hint_visible(), "the first night says tap to pounce, swipe to paw")
	check(_no_begin_button(hunt), "the title starts from a tap, not a Begin button")
	check(hunt._hint.text == NightHunt.HINT_TEXT, "the hint is the one we promised")
	_framing(hunt)
	await _labels(hunt)
	_moths(hunt)
	await _gestures()

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


func _gesture_math() -> void:
	check(TouchControls3D.classify(4.0, 0.05) == "tap", "a short press is a tap")
	check(TouchControls3D.classify(40.0, 0.1) == "swipe", "a drag is a swipe")
	check(TouchControls3D.classify(4.0, 0.5) == "hold", "a still hold is a stalk")
	check(absf(TouchControls3D.yaw_to_face(Vector3(0, 0, -1))) < 0.001, "facing -Z keeps yaw at 0")
	check(absf(TouchControls3D.yaw_to_face(Vector3(1, 0, 0)) + PI * 0.5) < 0.001, "facing +X is a quarter turn")
	var phone := Vector2(390, 844)
	var paw := TouchControls3D.stick_size(phone)
	check(12.0 + paw.x < phone.x * 0.5, "the paw stays left of centre on a phone (right edge %.0f)" % (12.0 + paw.x))
	var tall := Vector2(1152, 2493)
	var tall_paw := TouchControls3D.stick_size(tall)
	check(12.0 + tall_paw.x < tall.x * 0.5, "the paw stays left of centre on a tall viewport")


func _gestures() -> void:
	var touch := TouchControls3D.new()
	add_child(touch)
	await frames(2)
	check(_no_paw_buttons(touch), "PAW and POUNCE buttons are gone")
	check(touch.joystick != null and touch.joystick.TOE_BEANS == 4, "the stick is a paw print, four toes")
	check(PvKJoystick3D.IDLE_ALPHA < PvKJoystick3D.TOUCH_ALPHA - 0.2, "an idle paw is quieter than a touched one")
	var vp := get_viewport().get_visible_rect().size
	var origin := Vector2(vp.x * 0.72, vp.y * 0.45)
	var strikes := [0]
	var pounces := [0]
	var meows := [0]
	var restarts := [0]
	touch.strike_pressed.connect(func() -> void: strikes[0] += 1)
	touch.pounce_pressed.connect(func() -> void: pounces[0] += 1)
	touch.meow_pressed.connect(func() -> void: meows[0] += 1)
	touch.restart_pressed.connect(func() -> void: restarts[0] += 1)
	_screen_touch(touch, origin, true, 0)
	_screen_touch(touch, origin, false, 0)
	check(meows[0] == 1 and pounces[0] == 0 and strikes[0] == 0, "a tap on the right half meows")
	_screen_touch(touch, origin, true, 1)
	_screen_drag(touch, origin + Vector2(90, -12), 1)
	_screen_touch(touch, origin + Vector2(90, -12), false, 1)
	check(strikes[0] == 1, "a swipe on the right half is a paw")
	check(touch.swipe_dir.length() > 40.0, "the paw swipe keeps its direction (%.0f)" % touch.swipe_dir.length())
	_screen_touch(touch, origin, true, 2)
	touch._fingers[2]["msec"] = Time.get_ticks_msec() - 500
	touch._process(0.1)
	check(touch.stalk_held, "holding still on the right half stalks")
	_screen_touch(touch, origin + Vector2(4, 2), false, 2)
	check(not touch.stalk_held, "letting go ends the stalk")
	check(meows[0] == 1, "a stalk hold does not also meow")
	_screen_touch(touch, origin, true, 4)
	_screen_touch(touch, origin + Vector2(36, 4), true, 5)
	touch._fingers[4]["msec"] = Time.get_ticks_msec() - 900
	touch._fingers[5]["msec"] = Time.get_ticks_msec() - 900
	touch._process(0.1)
	check(restarts[0] == 1, "two fingers held still ask to restart")
	var meows_before := int(meows[0])
	_screen_touch(touch, origin, false, 4)
	_screen_touch(touch, origin + Vector2(36, 4), false, 5)
	check(meows[0] == meows_before, "the restart does not also meow")
	var p0 := int(pounces[0])
	var s0 := int(strikes[0])
	_mouse(touch, origin, MOUSE_BUTTON_LEFT, true)
	_mouse(touch, origin, MOUSE_BUTTON_LEFT, false)
	_mouse(touch, origin, MOUSE_BUTTON_RIGHT, true)
	_mouse(touch, origin, MOUSE_BUTTON_RIGHT, false)
	check(pounces[0] == p0 + 1, "left click pounces")
	check(strikes[0] == s0 + 1, "right click paws")
	var left := Vector2(vp.x * 0.18, vp.y * 0.55)
	var p1 := int(pounces[0])
	_screen_touch(touch, left, true, 3)
	_screen_touch(touch, left, false, 3)
	check(pounces[0] == p1, "the left half stays the stick, not a pounce")
	var pauses := [0]
	touch.pause_pressed.connect(func() -> void: pauses[0] += 1)
	var meows_pause := int(meows[0])
	var restarts_before := int(restarts[0])
	_screen_touch(touch, origin, true, 7)
	_screen_touch(touch, origin + Vector2(30, 8), true, 8)
	_screen_touch(touch, origin + Vector2(-24, 18), true, 9)
	check(pauses[0] == 1, "three fingers together pause")
	check(restarts[0] == restarts_before, "three fingers do not also restart")
	_screen_touch(touch, origin, false, 7)
	_screen_touch(touch, origin + Vector2(30, 8), false, 8)
	_screen_touch(touch, origin + Vector2(-24, 18), false, 9)
	check(meows[0] == meows_pause, "the pause tap does not also meow")
	touch.queue_free()


func _no_begin_button(node: Node) -> bool:
	if node is Button and String((node as Button).text).begins_with("Begin"):
		return false
	for c: Node in node.get_children():
		if not _no_begin_button(c):
			return false
	return true


func _no_paw_buttons(node: Node) -> bool:
	if node is Button:
		var t := String((node as Button).text)
		if t == "PAW" or t == "POUNCE":
			return false
	for c: Node in node.get_children():
		if not _no_paw_buttons(c):
			return false
	return true


func _screen_touch(touch: TouchControls3D, pos: Vector2, pressed: bool, index: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = pressed
	ev.index = index
	touch._unhandled_input(ev)


func _screen_drag(touch: TouchControls3D, pos: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = pos
	ev.relative = Vector2(40, 0)
	ev.index = index
	touch._unhandled_input(ev)


func _mouse(touch: TouchControls3D, pos: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.button_index = button
	ev.pressed = pressed
	touch._unhandled_input(ev)


func _framing(hunt: NightHunt) -> void:
	var cam := hunt.get_viewport().get_camera_3d()
	check(cam != null, "the night has a camera on Willie")
	if cam == null or hunt.cat == null:
		return
	var willie := hunt.cat.global_position + Vector3(0, 0.22, 0)
	check(not cam.is_position_behind(willie), "Willie is in front of the camera")
	var vp := hunt.get_viewport().get_visible_rect().size
	var screen := cam.unproject_position(willie)
	var in_x := screen.x > vp.x * 0.18 and screen.x < vp.x * 0.82
	var in_y := screen.y > vp.y * 0.16 and screen.y < vp.y * 0.84
	check(in_x and in_y, "the default camera frames Willie (screen %s of %s)" % [screen, vp])
	var dist := cam.global_position.distance_to(hunt.cat.global_position)
	check(dist > 0.9 and dist < 2.15, "Willie is close enough to read (camera %.2f m)" % dist)


func _name_fully_on_screen(hunt: NightHunt, what: String) -> void:
	var cam := hunt.get_viewport().get_camera_3d()
	if cam == null:
		check(false, what)
		return
	var vp := hunt.get_viewport().get_visible_rect().size
	var found := false
	for lab: Variant in hunt.keepsake_labels:
		var l := lab as Label3D
		if l == null or not l.visible:
			continue
		found = true
		var ahead := not cam.is_position_behind(l.global_position)
		var at := cam.unproject_position(l.global_position)
		var half: Vector2 = hunt.label_screen_half(l, cam)
		var inside := NightHunt.block_inside(at, half, vp, NightHunt.LABEL_MARGIN)
		check(ahead and inside, "%s — \"%s\" at %s half %s view %s" % [what, l.text, at, half, vp])
	if not found:
		check(false, "%s — a name is showing" % what)


func _labels(hunt: NightHunt) -> void:
	check(NightHunt.keepsake_alpha(0.4) == 1.0, "a name beside Willie is solid")
	check(NightHunt.keepsake_alpha(2.2) < NightHunt.keepsake_alpha(1.2), "a name fades as he walks off")
	check(NightHunt.keepsake_alpha(8.0) == 0.0, "a name across the room is hidden")
	var pinned := NightHunt.clamp_screen(Vector2(576, -70), Vector2(170, 80), Vector2(1152, 648), NightHunt.LABEL_MARGIN)
	check(is_equal_approx(pinned.x, 576.0) and is_equal_approx(pinned.y, 96.0), "a name above the frame drops until the whole line fits")
	check(NightHunt.block_inside(pinned, Vector2(170, 80), Vector2(1152, 648), NightHunt.LABEL_MARGIN), "that dropped name stays inside the frame")
	var mid := NightHunt.clamp_screen(Vector2(-40, 900), Vector2(900, 900), Vector2(1152, 648), NightHunt.LABEL_MARGIN)
	check(is_equal_approx(mid.x, 576.0) and is_equal_approx(mid.y, 324.0), "a name bigger than the screen is pinned to the middle")
	check(hunt.keepsake_labels.size() >= 4, "the marked decades still have names (%d)" % hunt.keepsake_labels.size())
	_name_fully_on_screen(hunt, "the keepsake beside Willie at the start stays on screen")
	var home := hunt.cat.global_position
	var spot: Vector3 = hunt.keepsake_points[0]
	hunt.cat.global_position = spot + Vector3(0, 0.1, 0)
	hunt.cat.velocity = Vector3.ZERO
	await frames(2)
	var shown := 0
	var shown_i := -1
	for i in hunt.keepsake_labels.size():
		var lab: Label3D = hunt.keepsake_labels[i]
		if lab.visible:
			shown += 1
			shown_i = i
	check(shown == 1 and shown_i == 0, "only the nearest keepsake is named (shown %d, idx %d)" % [shown, shown_i])
	_name_fully_on_screen(hunt, "the name stays on screen when Willie stands over the keepsake")
	var named: Label3D = hunt.keepsake_labels[0]
	check(named.autowrap_mode != TextServer.AUTOWRAP_OFF and named.width > 0.0, "a long name wraps instead of running off")
	check(named.text.length() > 12, "the name is the keepsake's own (%s)" % named.text)
	hunt.cat.global_position = spot + Vector3(0, 0.1, 9.0)
	await frames(2)
	var any := false
	for lab: Variant in hunt.keepsake_labels:
		if (lab as Label3D).visible:
			any = true
	check(not any, "with Willie far from every keepsake, no names are up")
	hunt.cat.global_position = home
	hunt.cat.velocity = Vector3.ZERO


func _moths(hunt: NightHunt) -> void:
	var moth: CellarMoth = hunt.moths[0]
	check(moth.wing_span >= 0.45, "a moth's wings are big enough to read (span %.2f)" % moth.wing_span)
	check(moth.wings_emissive, "moth wings are emissive")
	check(moth.wing_material != null and moth.wing_material.emission_enabled, "the wing material actually emits")
	check(moth.wing_material.emission_energy_multiplier >= 2.5, "the wing glow is bright enough to see (%.1f)" % moth.wing_material.emission_energy_multiplier)


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
