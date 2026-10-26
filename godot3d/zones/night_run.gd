class_name NightRun
extends Node
## One night at 255 Massey, played across the whole house.
##
## Start in the yard. Come inside, see the basement, look in on
## the attic, then find Glenys and tell her the round is done.
## Dawn ends it. So does staying in her arms once the night is
## nearly over. R starts the night again.
##
## The compass is the "where next" for that round: the floor you
## are on, and an arrow toward the next door.


const LENGTH := 420.0
const FINAL_WINDOW := 30.0
const CAUGHT_HOLD := 1.6
const GLENYS_REACH := 1.55
const BRIEFING := 5.0

var phase := "wait" # wait, briefing, playing, won, failed
var fail_reason := ""
var seconds_left := LENGTH

var _game: Node = null
var _brief_t := 0.0
var _held_t := 0.0
var _visited_outside := false
var _card: PanelContainer
var _card_label: Label
var _banner: Label
var _clock: Label
var _floors: Label
var _hint: Label
var _arrow: Label
var _where: Label
var _list: Label
var _compass: PanelContainer
var _objectives_open := false
var _seen_glenys_zone := ""


func setup(game: Node) -> void:
	_game = game
	var obj: PvKObjectives = game.get("objectives")
	if obj != null:
		obj.declare("night:threshold", HouseSpec.GROUND_FLOOR, "Come in out of the yard")
		obj.declare("night:cellar", HouseSpec.BASEMENT, "Visit the basement she kept")
		obj.declare("night:attic", HouseSpec.ATTIC, "Look in on the attic")
		obj.declare("night:glenys", HouseSpec.GROUND_FLOOR, "Tell Glenys the house is settled")
	var zones: ZoneManager = game.get("zones")
	if zones != null and not zones.zone_changed.is_connected(_on_zone):
		zones.zone_changed.connect(_on_zone)
		_visited_outside = zones.current_zone == HouseSpec.OUTSIDE
	_build_ui()
	var duo: Node = game.get("duo")
	if duo != null and not bool(duo.call("input_locked")):
		_open_briefing()
	elif duo != null:
		var select: Node = duo.get("select_ui")
		if select != null and select.has_signal("chosen"):
			select.chosen.connect(func(_id: String) -> void: _open_briefing())


func blocks_move() -> bool:
	return phase == "briefing" or phase == "won" or phase == "failed"


func start_playing() -> void:
	if phase == "won" or phase == "failed":
		return
	phase = "playing"
	if _card != null:
		_card.visible = false
	var zones: ZoneManager = _zones()
	if zones != null:
		_note_zone(zones.current_zone)


func aim_point() -> Vector3:
	return _next().pos


func hint_text() -> String:
	return _next().hint


func _open_briefing() -> void:
	if phase != "wait":
		return
	phase = "briefing"
	_brief_t = 0.0
	if _card != null:
		_card.visible = true


func _process(delta: float) -> void:
	if _game == null:
		return
	if phase == "briefing":
		_brief_t += delta
		if _brief_t >= BRIEFING or _enter_pressed():
			seconds_left = LENGTH
			start_playing()
	elif phase == "playing":
		seconds_left = maxf(0.0, seconds_left - delta)
		_watch_glenys()
		_check_glenys()
		_check_caught(delta)
		if phase == "playing" and seconds_left <= 0.0:
			var held := _glenys_state() == "grab"
			_end(false, "caught" if held else "dawn")
	_refresh_compass()


func _enter_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_E)


func _on_zone(id: String) -> void:
	if phase == "won" or phase == "failed" or phase == "wait":
		return
	_note_zone(id)


func _note_zone(id: String) -> void:
	var obj := _obj()
	if obj == null:
		return
	if id == HouseSpec.OUTSIDE:
		_visited_outside = true
	if id == HouseSpec.GROUND_FLOOR and _visited_outside:
		obj.set_progress("night:threshold", 1)
	if id == HouseSpec.BASEMENT:
		obj.set_progress("night:cellar", 1)
	if id == HouseSpec.ATTIC:
		obj.set_progress("night:attic", 1)
	_check_glenys()


func _check_glenys() -> void:
	if phase != "playing":
		return
	var obj := _obj()
	if obj == null or not obj.is_done("night:threshold") or not obj.is_done("night:cellar") or not obj.is_done("night:attic"):
		return
	if obj.is_done("night:glenys"):
		return
	var glenys: Node = _game.get("glenys")
	var cat: Node3D = _game.get("cat")
	if glenys == null or cat == null:
		return
	var actor: Node3D = glenys.get("actor")
	if actor == null:
		return
	if cat.global_position.distance_to(actor.global_position) > GLENYS_REACH:
		return
	obj.set_progress("night:glenys", 1)
	_end(true, "")


func _floors_done() -> bool:
	var obj := _obj()
	if obj == null:
		return false
	return obj.is_done("night:threshold") and obj.is_done("night:cellar") and obj.is_done("night:attic")


func _check_caught(delta: float) -> void:
	var held := _glenys_state() == "grab"
	if not held:
		_held_t = 0.0
		return
	# She already has you, and the rounds are done: that is the ending.
	if _floors_done():
		_end(true, "")
		return
	if seconds_left > FINAL_WINDOW:
		_held_t = 0.0
		return
	_held_t += delta
	if _held_t >= CAUGHT_HOLD:
		_end(false, "caught")


func _end(won: bool, reason: String) -> void:
	if phase == "won" or phase == "failed":
		return
	phase = "won" if won else "failed"
	fail_reason = reason
	if _banner == null:
		return
	if won:
		_banner.text = "You went all through the house, and you came back.\nGlenys is glad of the company.\n\nThe night is over. Press R twice to play again."
		_tell("You made the rounds. I'm glad of the company.")
	elif reason == "caught":
		_banner.text = "Glenys gathered you up before the rounds were done.\nShe isn't cross.\n\nPress R twice to slip out and try again."
		_tell("I've got you. The night can wait.")
	else:
		_banner.text = "Dawn is in the windows. The night got away.\nThe house is awake.\n\nPress R twice to try the night again."
		_tell("Morning already. Come along, the house is awake.")
	_banner.visible = true


func _glenys_state() -> String:
	var glenys: Node = _game.get("glenys") if _game != null else null
	if glenys == null:
		return ""
	return String(glenys.get("state"))


func _next() -> Dictionary:
	var zone := ""
	var zones := _zones()
	if zones != null:
		zone = zones.current_zone
	var obj := _obj()
	var threshold := obj != null and obj.is_done("night:threshold")
	var cellar := obj != null and obj.is_done("night:cellar")
	var attic := obj != null and obj.is_done("night:attic")
	var told := obj != null and obj.is_done("night:glenys")
	if not threshold:
		if zone == HouseSpec.OUTSIDE:
			return {"pos": _connector_world(HouseSpec.OUTSIDE, 0), "hint": "The front door"}
		return {"pos": _connector_world(zone, 0), "hint": "Back toward the yard door"}
	if not cellar:
		if zone == HouseSpec.GROUND_FLOOR:
			return {"pos": _connector_world(HouseSpec.GROUND_FLOOR, 1), "hint": "Stairs down to the basement"}
		if zone == HouseSpec.ATTIC:
			return {"pos": _connector_world(HouseSpec.ATTIC, 0), "hint": "Downstairs, then the cellar stairs"}
		if zone == HouseSpec.BASEMENT:
			return {"pos": _connector_world(HouseSpec.BASEMENT, 0), "hint": "The basement — have a look, then back up"}
		return {"pos": _connector_world(HouseSpec.OUTSIDE, 0), "hint": "Inside, then the cellar stairs"}
	if not attic:
		if zone == HouseSpec.GROUND_FLOOR:
			return {"pos": _connector_world(HouseSpec.GROUND_FLOOR, 2), "hint": "The hatch up to the attic"}
		if zone == HouseSpec.BASEMENT:
			return {"pos": _connector_world(HouseSpec.BASEMENT, 0), "hint": "Upstairs, then the attic hatch"}
		if zone == HouseSpec.ATTIC:
			return {"pos": _connector_world(HouseSpec.ATTIC, 0), "hint": "The attic — have a look, then back down"}
		return {"pos": _connector_world(HouseSpec.OUTSIDE, 0), "hint": "Inside, then the attic hatch"}
	if not told:
		return _toward_glenys(zone)
	return {"pos": _glenys_pos(), "hint": "The round is done"}


func _glenys_pos() -> Vector3:
	var glenys: Node = _game.get("glenys") if _game != null else null
	if glenys != null:
		var actor: Node3D = glenys.get("actor")
		if actor != null:
			return actor.global_position
	return HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR) + Vector3(-6.8, 0.0, 3.1)


func _connector_world(zone_id: String, index: int) -> Vector3:
	var list: Array = HouseSpec.connectors(zone_id)
	if list.is_empty():
		return _glenys_pos()
	var cfg: Dictionary = list[clampi(index, 0, list.size() - 1)]
	var at: Vector3 = cfg["at"]
	if zone_id == HouseSpec.OUTSIDE:
		return at
	return HouseSpec.zone_origin(zone_id) + at


func _refresh_compass() -> void:
	if _clock == null or _game == null:
		return
	var show := phase != "wait"
	_clock.visible = show
	_floors.visible = show
	_hint.visible = show
	_arrow.visible = show
	if _where != null:
		_where.visible = show
	if _list != null and not show:
		_list.visible = false
	if not show:
		return
	var secs := maxi(0, int(ceil(seconds_left)))
	_clock.text = "Night %d:%02d" % [secs / 60, secs % 60]
	if phase == "playing" and seconds_left <= 60.0:
		_clock.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	else:
		_clock.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	if _where != null:
		_where.text = _where_sentence(_glenys_zone())
	if _list != null:
		_list.visible = _objectives_open
	if _objectives_open:
		_refresh_list()
	if _compass != null:
		_compass.offset_top = -300.0 if _objectives_open else -132.0
	var zone := ""
	var zones := _zones()
	if zones != null:
		zone = zones.current_zone
	var names := {"outside": "Yard", "ground_floor": "House", "basement": "Cellar", "attic": "Attic"}
	var bits: PackedStringArray = []
	for id: String in ["outside", "ground_floor", "basement", "attic"]:
		var mark := String(names[id])
		if id == zone:
			mark = "● " + mark
		bits.append(mark)
	_floors.text = "   ".join(bits)
	var nxt := _next()
	_hint.text = String(nxt["hint"])
	var cat: Node3D = _game.get("cat")
	var rig: Node3D = _game.get("_rig")
	if cat == null or rig == null:
		return
	var to: Vector3 = nxt["pos"] - cat.global_position
	to.y = 0.0
	if to.length() < 0.15:
		_arrow.rotation = 0.0
		return
	var fwd := -rig.global_basis.z
	fwd.y = 0.0
	var right := rig.global_basis.x
	right.y = 0.0
	if fwd.length() < 0.01:
		return
	_arrow.rotation = atan2(right.dot(to), fwd.dot(to))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -280
	_card.offset_right = 280
	_card.offset_top = -150
	_card.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.07, 0.9)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_card.add_theme_stylebox_override("panel", sb)
	_card_label = Label.new()
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.add_theme_font_size_override("font_size", 20)
	_card_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	_card_label.text = "The house is settling in for the night.\n\nCome in from the yard. See the basement. Look in on the attic. Then find Glenys. She will say where she is.\n\nYou have until dawn. Tap the compass for the list.\n\nPress Enter."
	_card.add_child(_card_label)
	_card.visible = false
	layer.add_child(_card)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -340
	_banner.offset_right = 340
	_banner.offset_top = -80
	_banner.offset_bottom = 80
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.visible = false
	layer.add_child(_banner)
	var compass := PanelContainer.new()
	_compass = compass
	compass.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	compass.offset_left = -250
	compass.offset_right = 250
	compass.offset_top = -132
	compass.offset_bottom = -16
	compass.mouse_filter = Control.MOUSE_FILTER_STOP
	compass.gui_input.connect(_on_compass_input)
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(0.06, 0.05, 0.06, 0.72)
	cb.set_corner_radius_all(10)
	cb.content_margin_left = 14
	cb.content_margin_right = 14
	cb.content_margin_top = 8
	cb.content_margin_bottom = 8
	compass.add_theme_stylebox_override("panel", cb)
	var box := VBoxContainer.new()
	compass.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	_arrow = Label.new()
	_arrow.text = "▲"
	_arrow.custom_minimum_size = Vector2(28, 28)
	_arrow.pivot_offset = Vector2(14, 14)
	_arrow.add_theme_font_size_override("font_size", 22)
	_arrow.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	row.add_child(_arrow)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 16)
	_clock.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	words.add_child(_clock)
	_floors = Label.new()
	_floors.add_theme_font_size_override("font_size", 15)
	_floors.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	words.add_child(_floors)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	words.add_child(_hint)
	_where = Label.new()
	_where.add_theme_font_size_override("font_size", 14)
	_where.add_theme_color_override("font_color", Color(0.86, 0.8, 0.7))
	words.add_child(_where)
	_list = Label.new()
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_theme_font_size_override("font_size", 15)
	_list.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	_list.visible = false
	box.add_child(_list)
	for child: Node in compass.find_children("*", "Control", true, false):
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(compass)
	_clock.visible = false
	_floors.visible = false
	_hint.visible = false
	_arrow.visible = false


func compass() -> Control:
	return _compass


func objectives_open() -> bool:
	return _objectives_open


func where_text() -> String:
	return _where.text if _where != null else ""


func toggle_objectives() -> void:
	_objectives_open = not _objectives_open
	_refresh_list()
	if _list != null:
		_list.visible = _objectives_open
	if _compass != null:
		_compass.offset_top = -300.0 if _objectives_open else -132.0


func _on_compass_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
			toggle_objectives()
			_compass.accept_event()


func _refresh_list() -> void:
	if _list == null:
		return
	var obj := _obj()
	if obj == null:
		_list.text = ""
		return
	var lines: PackedStringArray = []
	for it: Variant in obj.items:
		var d := it as Dictionary
		var mark := "☑" if bool(d.get("done", false)) else "☐"
		lines.append("%s %s" % [mark, String(d.get("title", ""))])
		if lines.size() >= 8:
			break
	_list.text = "\n".join(lines)


func _watch_glenys() -> void:
	var gz := _glenys_zone()
	if gz == "":
		return
	if _seen_glenys_zone == "":
		_seen_glenys_zone = gz
		return
	if gz == _seen_glenys_zone:
		return
	_seen_glenys_zone = gz
	_tell(_spoken_where(gz))


func _toward_glenys(zone: String) -> Dictionary:
	var gz := _glenys_zone()
	var hint := _where_sentence(gz)
	if zone == gz:
		return {"pos": _glenys_pos(), "hint": hint}
	if zone == "":
		return {"pos": _glenys_pos(), "hint": hint}
	return {"pos": _connector_world(zone, 0), "hint": hint}


func _glenys_zone() -> String:
	var glenys: Node = _game.get("glenys") if _game != null else null
	if glenys == null:
		return ""
	return String(glenys.get("her_zone"))


func _where_sentence(zone_id: String) -> String:
	match zone_id:
		"outside":
			return "Glenys is out in the yard"
		"basement":
			return "Glenys is down in the basement"
		"attic":
			return "Glenys is up in the attic"
		_:
			return "Glenys is in the house"


func _spoken_where(zone_id: String) -> String:
	match zone_id:
		"outside":
			return "I'm out in the yard, love."
		"basement":
			return "Down in the basement, if you're looking."
		"attic":
			return "Up in the attic — mind your head."
		_:
			return "I'm in the house, dear."


func _tell(line: String) -> void:
	if _game == null:
		return
	var glenys: Node = _game.get("glenys")
	if glenys != null and glenys.has_method("tell"):
		glenys.tell(line)


func _zones() -> ZoneManager:
	if _game == null:
		return null
	return _game.get("zones") as ZoneManager


func _obj() -> PvKObjectives:
	if _game == null:
		return null
	return _game.get("objectives") as PvKObjectives
