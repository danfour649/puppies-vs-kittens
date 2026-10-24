class_name CharacterSelect
extends CanvasLayer
## DUO — character select. Two cards over the live yard: pick your
## cat with touch, mouse, or keys 1 / 2. The cat you don't pick
## becomes the sibling NPC. Trait text comes from the character
## data, never from constants in this file.

signal chosen(id: String)

var _ids: Array = []


func _init() -> void:
	layer = 10


func option_count() -> int:
	return _ids.size()


func present(chars: Dictionary, order: Array) -> void:
	_ids = order.duplicate()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "WHO ARE YOU TODAY?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 42
	title.offset_bottom = 92
	add_child(title)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	center.add_child(row)
	for id: Variant in order:
		var ch: Dictionary = chars.get(id, {})
		row.add_child(_card(ch, String(id)))


func _card(ch: Dictionary, id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 330)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.12, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var name_l := Label.new()
	name_l.text = String(ch.get("name", id)).to_upper()
	name_l.add_theme_font_size_override("font_size", 34)
	name_l.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	vb.add_child(name_l)
	var traits: Array = ch.get("traits", [])
	for t: Variant in traits:
		var l := Label.new()
		l.text = "•  " + String(t)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 17)
		vb.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var blurb := Label.new()
	blurb.text = String(ch.get("blurb", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 16)
	blurb.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	vb.add_child(blurb)
	var btn := Button.new()
	btn.text = "PLAY AS " + String(ch.get("name", id)).to_upper()
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void: chosen.emit(id))
	vb.add_child(btn)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				chosen.emit(id)
	)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_1 and _ids.size() > 0:
				chosen.emit(String(_ids[0]))
			elif k.keycode == KEY_2 and _ids.size() > 1:
				chosen.emit(String(_ids[1]))
