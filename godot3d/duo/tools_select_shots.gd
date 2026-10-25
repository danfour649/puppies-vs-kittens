extends Node
## SELECT verification pass (Daniel's rule: validated = in-game).
## Run with real rendering:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot3d \
##     res://duo/tools_select_shots.tscn --resolution 1600x900
##
## Drives the REAL input path both times:
##  - Aggie: a synthetic mouse motion + click pushed through the
##    viewport onto her roster cell (hover highlight, then pick).
##  - Willie: a synthetic Enter keypress through _unhandled_input.
## Screenshots land in res://screenshots/select/.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/select/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


## Cell centre in WINDOW pixels — the space synthetic input events
## live in. get_global_rect() is canvas space (1152x648 logical);
## the engine maps OS input by the stretch ratio, so the tool does
## the same. (Proven by gui_get_hovered_control(): at unscaled
## coords the GUI reported the backdrop under the shrunken point.)
func _cell_centre(cell: Control) -> Vector2:
	var logical := get_viewport().get_visible_rect().size
	var win := Vector2(get_window().size)
	return cell.get_global_rect().get_center() * (win / logical)


## Input goes through Input.parse_input_event — the same queue OS
## input takes — so the viewport's mouse state and GUI picking see
## exactly what a real player's mouse would do.
func _push_hover(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)


func _push_click(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	Input.parse_input_event(release)


func _push_enter() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	var up := InputEventKey.new()
	up.keycode = KEY_ENTER
	up.physical_keycode = KEY_ENTER
	up.pressed = false
	Input.parse_input_event(up)


func _spawn_game() -> Node:
	DuoCharacters.last_choice = "" # fresh boots show the select
	var g = load("res://main.tscn").instantiate()
	add_child(g)
	return g


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/select")

	# ---------- Willie highlighted, idle life, then Aggie by mouse ----------
	_game = _spawn_game()
	await _wait(1.6)
	var duo = _game.duo
	print("SELECT visible=", duo.select_visible(), " highlighted=", duo.select_ui.highlighted_id())
	await _shot("select_willie_stand")
	await _wait(6.5) # idle repertoire advances: stand -> sit/groom
	await _shot("select_willie_idle2")
	# Aggie: hover her roster cell (highlight moves), capture the
	# screen with her lit, THEN click the cell to pick her.
	var cell: Control = duo.select_ui._cells[1]
	print("CELL aggie rect=", cell.get_global_rect(), " centre_vp=", _cell_centre(cell))
	_push_hover(_cell_centre(cell))
	await _wait(0.5)
	var hov = get_viewport().gui_get_hovered_control()
	print(
		"HOVER aggie: highlighted=", duo.select_ui.highlighted_id(),
		" gui_hovered=", hov.name if hov != null else "<none>"
	)
	await _shot("select_aggie")
	await _push_click(_cell_centre(cell))
	# Wait for the game camera to settle on the player cat (Aggie,
	# on the garden chair).
	await _wait(1.4)
	print("SPAWN aggie: select_visible=", duo.select_visible(), " player=", duo.player_id())
	await _shot("spawn_aggie")
	_game.queue_free()
	await _wait(0.6)

	# ---------- Willie by Enter key ----------
	_game = _spawn_game()
	await _wait(1.6)
	duo = _game.duo
	print("SELECT2 visible=", duo.select_visible(), " highlighted=", duo.select_ui.highlighted_id())
	await _push_enter()
	await _wait(1.4)
	print("SPAWN willie: select_visible=", duo.select_visible(), " player=", duo.player_id())
	await _shot("spawn_willie")
	print("SELECT SHOTS DONE")
	get_tree().quit()
