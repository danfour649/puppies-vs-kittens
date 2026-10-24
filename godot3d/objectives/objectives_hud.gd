class_name ObjectivesHUD
extends CanvasLayer
## OBJECTIVES HUD — the checklist panel for Willie and Aggie.
## Toggle with Tab or the OBJECTIVES button (touch). Lists the
## registry's items grouped by zone with done states, plus the
## current zone and the running score. Data comes from
## PvKObjectives; zone context from ZoneManager. Polls their
## version/zone on a slow timer — rendering only, no game logic.

var objectives: PvKObjectives = null
var manager: ZoneManager = null

var _panel: PanelContainer
var _body: Label
var _score_label: Label
var _seen_version := -1
var _seen_zone := ""
var _poll := 0.0


func setup(obj: PvKObjectives, mgr: ZoneManager) -> void:
	objectives = obj
	manager = mgr
	layer = 3
	var btn := Button.new()
	btn.text = "OBJECTIVES"
	btn.add_theme_font_size_override("font_size", 18)
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -180
	btn.offset_right = -18
	btn.offset_top = 66
	btn.offset_bottom = 106
	btn.pressed.connect(toggle)
	add_child(btn)
	_score_label = Label.new()
	_score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_left = -120
	_score_label.offset_right = 120
	_score_label.offset_top = 10
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_score_label)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.offset_left = -348
	_panel.offset_right = -18
	_panel.offset_top = -190
	_panel.offset_bottom = 190
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 19)
	_body.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	_panel.add_child(_body)
	_panel.visible = false
	add_child(_panel)
	_refresh()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()


func panel_visible() -> bool:
	return _panel != null and _panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.25
	if objectives == null:
		return
	var zone := manager.current_zone if manager != null else ""
	if objectives.version != _seen_version or zone != _seen_zone:
		_refresh()


func _refresh() -> void:
	if objectives == null or _body == null:
		return
	_seen_version = objectives.version
	_seen_zone = manager.current_zone if manager != null else ""
	_score_label.text = "Score: %d" % objectives.score if objectives.score > 0 else ""
	var lines: Array = ["WILLIE AND AGGIE — OBJECTIVES", "Now: %s" % String(HouseSpec.ZONE_NAMES.get(_seen_zone, _seen_zone)), ""]
	for zone_id: String in HouseSpec.ZONE_ORDER:
		var zone_items: Array = []
		for it: Variant in objectives.items:
			if String((it as Dictionary).get("zone", "")) == zone_id:
				zone_items.append(it)
		if zone_items.is_empty():
			continue
		lines.append("— %s —" % String(HouseSpec.ZONE_NAMES.get(zone_id, zone_id)))
		for it: Variant in zone_items:
			var d := it as Dictionary
			var mark := "☑" if bool(d["done"]) else "☐"
			var tail := ""
			if int(d["target"]) > 1 or int(d["count"]) > 0:
				tail = " (%d/%d)" % [int(d["count"]), int(d["target"])]
			lines.append("%s %s%s" % [mark, String(d["title"]), tail])
		lines.append("")
	_body.text = "\n".join(lines)
