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


const LENGTH := 360.0
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


func _check_caught(delta: float) -> void:
	if seconds_left > FINAL_WINDOW or _glenys_state() != "grab":
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
		_banner.text = "You went all through the house, and you came back.\nGlenys is glad of the company.\n\nThe night is over. Press R to play again."
	elif reason == "caught":
		_banner.text = "Glenys gathered you up, and the night ended there.\nShe isn't cross.\n\nPress R to slip out and try again."
	else:
		_banner.text = "Dawn is in the windows. The night got away.\nThe house is awake.\n\nPress R to try the night again."
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
		if zone == HouseSpec.GROUND_FLOOR:
			return {"pos": _glenys_pos(), "hint": "Glenys — tell her you made the rounds"}
		return {"pos": _connector_world(zone, 0), "hint": "Back to Glenys"}
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
	if not show:
		return
	var secs := maxi(0, int(ceil(seconds_left)))
	_clock.text = "Night %d:%02d" % [secs / 60, secs % 60]
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
	_card_label.text = "The house is settling in for the night.\n\nCome in from the yard. See the basement. Look in on the attic. Then find Glenys and tell her you made the rounds.\n\nDawn ends it, and so does getting caught.\n\nPress Enter."
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
	compass.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	compass.offset_left = -250
	compass.offset_right = 250
	compass.offset_top = -118
	compass.offset_bottom = -16
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
	layer.add_child(compass)
	_clock.visible = false
	_floors.visible = false
	_hint.visible = false
	_arrow.visible = false


func _zones() -> ZoneManager:
	if _game == null:
		return null
	return _game.get("zones") as ZoneManager


func _obj() -> PvKObjectives:
	if _game == null:
		return null
	return _game.get("objectives") as PvKObjectives
