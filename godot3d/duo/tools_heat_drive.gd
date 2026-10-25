extends Node
## HEAT in-game drive pass. Run under Xvfb (real rendering, real
## input path):  xvfb-run godot --path godot3d res://duo/tools_heat_drive.tscn
##
## Boots the actual game and PLAYS it: the player cat is moved with
## injected physical-key events (main.gd reads Input.is_physical_
## key_pressed), characters are picked through the select's own
## choose() path, and heat/response beats are staged with the
## systems' debug seams (force_heat / force_response) — stated
## plainly in the transcript. Screenshots land in
## res://screenshots/heat/; the printed transcript records what was
## driven and what the game state did in response.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/heat/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/heat")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.2)
	var duo = _game.duo
	var heat = duo.heat
	for m in _game.mice:
		m.cat = null # freeze the mice; this is a heat pass, not a hunt

	# ---- Beat 1: play as Willie. Aggie hunts him down and solicits.
	duo.choose("willie")
	var willie = duo.willie_cat
	var aggie = duo.aggie_cat
	willie.velocity = Vector3.ZERO
	willie.global_position = Vector3(0.5, 0.05, 1.5)
	aggie.velocity = Vector3.ZERO
	aggie.global_position = Vector3(-4.5, 0.05, -3.5)
	aggie.set_lounge(false)
	_game.cam_dist = 3.4
	_game.cam_pitch = -0.45
	_game.cam_yaw = PI + 0.6
	heat.force_heat()
	print("DRIVE beat1: heat forced on; Aggie mode=", duo.sibling.mode)
	var t := 0.0
	while t < 12.0 and duo.sibling.mode != "heat_solicit":
		await _wait(0.15)
		t += 0.15
	print("DRIVE beat1: after ", t, " s Aggie mode=", duo.sibling.mode,
		" dist=", snappedf(_flat(aggie.global_position, willie.global_position), 0.01),
		" courtship_k=", snappedf(aggie.courtship_k, 0.01), " yowls=", heat.yowl_count)
	# Catch a frame with the YOOOWL bubble up if one comes round.
	t = 0.0
	while t < 5.0:
		await _wait(0.25)
		t += 0.25
		for c in [willie, aggie]:
			pass
		var bub = aggie.get_node_or_null("MeowBubble")
		if bub != null and bub.visible and bub.text == "YOOOWL!":
			break
	await _shot("heat_solicit")

	# ---- Beat 2: the dodge, on the REAL input path (physical keys).
	var start_pos: Vector3 = willie.global_position
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	print("DRIVE beat2: W+SHIFT held; Input.is_physical_key_pressed(W)=",
		Input.is_physical_key_pressed(KEY_W))
	await _wait(1.3)
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	var ran := _flat(willie.global_position, start_pos)
	print("DRIVE beat2: Willie ran ", snappedf(ran, 0.01), " m on key input alone; Aggie mode=",
		duo.sibling.mode, " dist now=", snappedf(_flat(aggie.global_position, willie.global_position), 0.01))
	t = 0.0
	while t < 3.0 and duo.sibling.mode != "heat_seek":
		await _wait(0.1)
		t += 0.1
	await _shot("heat_dodge")

	# ---- Beat 3: swap to Aggie. The urge meter + objective in-game.
	duo.choose("aggie")
	heat = duo.heat
	willie = duo.willie_cat
	aggie = duo.aggie_cat
	aggie.velocity = Vector3.ZERO
	aggie.global_position = Vector3(-8.5, 0.05, -6.5)
	willie.velocity = Vector3.ZERO
	willie.global_position = Vector3(8.5, 0.05, 6.5)
	_game.cam_dist = 6.0
	_game.cam_pitch = -0.55
	heat.force_heat()
	heat.heat_time_left = 999.0
	t = 0.0
	while t < 8.0 and heat.urge < 22.0:
		await _wait(0.25)
		t += 0.25
	print("DRIVE beat3: player Aggie urge=", snappedf(heat.urge, 0.1),
		" urge_bar visible=", heat._urge_bar.visible,
		" objective visible=", heat._objective_label.visible)
	await _shot("heat_urge")

	# ---- Beat 4: Willie's pointed self-grooming, up close.
	willie.velocity = Vector3.ZERO
	willie.global_position = aggie.global_position + Vector3(1.3, 0.05, 0.3)
	_game.cam_dist = 3.0
	heat.force_response("groom")
	await _wait(0.9)
	print("DRIVE beat4: Willie mode=", duo.sibling.mode, " act_pose=", willie.act_pose,
		" act_pose_k=", snappedf(willie.act_pose_k, 0.01))
	await _shot("heat_groom")

	# ---- Beat 5: he wanders off and knocks his bowl over.
	t = 0.0
	while t < 4.0 and duo.sibling.mode != "idle":
		await _wait(0.15)
		t += 0.15
	heat.force_response("knock")
	t = 0.0
	while t < 15.0 and not heat.bowl_tipped:
		await _wait(0.2)
		t += 0.2
	print("DRIVE beat5: bowl_tipped=", heat.bowl_tipped, " after ", t, " s; Willie mode=", duo.sibling.mode)
	aggie.velocity = Vector3.ZERO
	aggie.global_position = Vector3(4.6, 0.05, -5.6) # stand by the porch for the photo
	_game.cam_dist = 3.2
	_game.cam_yaw = PI * 0.85
	await _wait(0.5)
	await _shot("heat_bowl")

	# ---- Beat 6: the mount attempt + the punchline popup.
	willie.velocity = Vector3.ZERO
	willie.global_position = aggie.global_position + Vector3(1.4, 0.05, 0)
	_game.cam_dist = 3.4
	_game.cam_yaw = PI + 0.4
	heat.force_response("mount")
	t = 0.0
	while t < 8.0 and duo.sibling.mode != "heat_mount_hold":
		await _wait(0.12)
		t += 0.12
	print("DRIVE beat6: Willie mode=", duo.sibling.mode, " attempts=", heat.mount_attempts,
		" punchline_shown=", heat.punchline_shown, " popup='", heat._popup_label.text, "'")
	await _shot("heat_mount_popup")
	print("HEAT DRIVE DONE")
	get_tree().quit(0)
