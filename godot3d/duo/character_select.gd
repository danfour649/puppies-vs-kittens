class_name CharacterSelect
extends CanvasLayer
## SELECT — Mortal Kombat-pattern character select (Daniel, locked
## 2026-10-25): one screen, one decision — move, pick, done.
##
## The highlighted cat stands RENDERED on a spotlight stage (the real
## cat_kit model, idle-animated in a SubViewport), its NAME and ONE
## trait line beside it, and its start marked on a house-and-yard
## minimap with the start's name. Nothing else lives here: no stats,
## no lore, no menus, no settings. The polish is in the type, the
## spacing, the backdrop and the light.
##
## Picking rides the existing flow unchanged: chosen(id) -> DuoSystem
## .choose(), which persists the choice (DuoCharacters.last_choice)
## and swaps the same two cat instances. Arrows / A,D / hover move
## the highlight; Enter / Space / click picks; 1 / 2 pick directly,
## as they always have.

signal chosen(id: String)

const StageScene := preload("res://duo/select_stage.gd")
const MinimapScene := preload("res://duo/select_minimap.gd")

const GOLD := Color(1.0, 0.80, 0.38)
const CREAM := Color(1.0, 0.97, 0.88)
const FAINT := Color(0.60, 0.63, 0.70)

var _ids: Array = []
var _chars: Dictionary = {}
var _highlight := 0
var _built := false

var _content: Control
var _viewport: SubViewport
var _stage_box: SubViewportContainer
var _stage: SelectStage
var _name_l: Label
var _line_l: Label
var _start_l: Label
var _minimap: SelectMinimap
var _strip: HBoxContainer
var _cells: Array = [] # PanelContainer per roster id
var _cell_names: Array = [] # Label inside each cell
var _ptr := -2
var _ptr_from := Vector2.ZERO
var _ptr_slide := 0.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func option_count() -> int:
	return _ids.size()


func highlighted_id() -> String:
	return String(_ids[_highlight]) if not _ids.is_empty() else ""


## Verification seam: move the highlight without picking.
func highlight(id: String) -> void:
	var i := _ids.find(id)
	if i >= 0:
		_set_highlight(i)


## Verification seam: pick whatever is highlighted.
func confirm() -> void:
	if not _ids.is_empty():
		chosen.emit(highlighted_id())


func present(chars: Dictionary, order: Array) -> void:
	_chars = chars
	_ids = order.duplicate()
	if not _built:
		_build()
		_built = true
	# A returning player (R / RESTART) sees their cat highlighted.
	_highlight = 0
	if DuoCharacters.last_choice != "" and _ids.has(DuoCharacters.last_choice):
		_highlight = _ids.find(DuoCharacters.last_choice)
	_apply_highlight()


# --- build ---------------------------------------------------------------------

func _build() -> void:
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	# Backdrop: near-black radial falloff, lit a breath behind the stage.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.115, 0.12, 0.15), Color(0.012, 0.012, 0.02)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.32, 0.42)
	gtex.fill_to = Vector2(0.32, 1.15)
	var backdrop := TextureRect.new()
	backdrop.texture = gtex
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(backdrop)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var spaced := FontVariation.new()
	spaced.base_font = _content.get_theme_default_font()
	spaced.spacing_glyph = 5

	# The stage: the highlighted cat, rendered, in a spotlight.
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(880, 620)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_stage_box = SubViewportContainer.new()
	_stage_box.stretch = true
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stage_box)
	_stage_box.add_child(_viewport)
	_stage = StageScene.new()
	_viewport.add_child(_stage)
	_stage.setup(_chars, _ids)

	# Name + the one line.
	_name_l = _label(58, CREAM, spaced)
	_place(_name_l, 0.655, 0.085, 0.975, 0.20)
	_content.add_child(_name_l)
	_line_l = _label(20, FAINT, null)
	_place(_line_l, 0.657, 0.205, 0.975, 0.265)
	_content.add_child(_line_l)

	# Minimap with the highlighted cat's start, and the start's name.
	_minimap = MinimapScene.new()
	_place(_minimap, 0.655, 0.325, 0.975, 0.685)
	for id: Variant in _ids:
		var ch: Dictionary = _chars.get(id, {})
		if ch.has("start_pos"):
			var p: Vector3 = ch["start_pos"]
			_minimap.starts[String(id)] = Vector2(p.x, p.z)
	_minimap.order = _ids.duplicate()
	_content.add_child(_minimap)
	_start_l = _label(24, CREAM, spaced)
	_place(_start_l, 0.657, 0.715, 0.975, 0.80)
	_content.add_child(_start_l)

	# Roster strip: move the highlight by hovering, click to pick.
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", 18)
	_content.add_child(_strip)
	for i: int in _ids.size():
		var id := String(_ids[i])
		var ch: Dictionary = _chars.get(id, {})
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(300, 66)
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var nm := _label(24, CREAM, spaced)
		nm.text = String(ch.get("name", id)).to_upper()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(nm)
		_strip.add_child(cell)
		_cells.append(cell)
		_cell_names.append(nm)
		cell.mouse_entered.connect(func() -> void: _set_highlight(i))
		var cell_i := i
		cell.gui_input.connect(func(event: InputEvent) -> void: _cell_input(cell_i, cell, event))
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)
	_fit()


func _label(size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _place(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


func _fit() -> void:
	if _content == null:
		return
	apply_layout(get_viewport().get_visible_rect().size)


## Wide windows keep the stage beside the name. A portrait window,
## and any window under 720px wide, stacks the stage, the name and
## a roster whose cells fit.
func apply_layout(vp: Vector2) -> void:
	if vp.x < 2.0 or vp.y < 2.0 or _stage_box == null:
		return
	if vp.y > vp.x * 1.05 or vp.x < 720.0:
		_layout_phone(vp)
	else:
		_layout_desk()


func _layout_desk() -> void:
	_place(_stage_box, 0.015, 0.03, 0.615, 0.845)
	_place(_name_l, 0.655, 0.085, 0.975, 0.20)
	_place(_line_l, 0.657, 0.205, 0.975, 0.265)
	_place(_minimap, 0.655, 0.325, 0.975, 0.685)
	_place(_start_l, 0.657, 0.715, 0.975, 0.80)
	_font(_name_l, 58)
	_font(_line_l, 20)
	_font(_start_l, 24)
	_align_copy(HORIZONTAL_ALIGNMENT_LEFT, TextServer.AUTOWRAP_OFF)
	_strip.add_theme_constant_override("separation", 18)
	_place(_strip, 0.5, 0.885, 0.5, 0.965)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for i: int in _cells.size():
		(_cells[i] as Control).custom_minimum_size = Vector2(300, 66)
		_font(_cell_names[i] as Label, 24)


func _layout_phone(vp: Vector2) -> void:
	var margin := vp.x * 0.05
	var stage_w := vp.x - margin * 2.0
	var stage_h := minf(stage_w * (620.0 / 880.0), vp.y * 0.38)
	var top := vp.y * 0.02
	_box(_stage_box, margin, top, margin + stage_w, top + stage_h)
	var name_h := clampf(vp.y * 0.065, 40.0, 78.0)
	var line_h := clampf(vp.y * 0.07, 52.0, 84.0)
	var y := top + stage_h + vp.y * 0.012
	_box(_name_l, margin, y, vp.x - margin, y + name_h)
	y += name_h
	_box(_line_l, margin, y, vp.x - margin, y + line_h)
	y += line_h + 6.0
	var roster_h := clampf(vp.y * 0.1, 68.0, 96.0)
	var roster_top := vp.y - margin * 0.4 - roster_h
	var start_h := clampf(vp.y * 0.045, 32.0, 52.0)
	var start_top := roster_top - start_h - 6.0
	_box(_minimap, margin + vp.x * 0.08, y, vp.x - margin - vp.x * 0.08, maxf(start_top - 8.0, y + 48.0))
	_box(_start_l, margin, start_top, vp.x - margin, start_top + start_h)
	_box(_strip, margin, roster_top, vp.x - margin, roster_top + roster_h)
	_font(_name_l, int(clampf(vp.x * 0.065, 22, 48)))
	_font(_line_l, int(clampf(vp.x * 0.04, 14, 22)))
	_font(_start_l, int(clampf(vp.x * 0.048, 16, 26)))
	_align_copy(HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	var count := maxi(_cells.size(), 1)
	var sep := 12
	_strip.add_theme_constant_override("separation", sep)
	var avail := (vp.x - margin * 2.0) - float(sep * (count - 1))
	var cell_w := minf(280.0, avail / float(count))
	for i: int in _cells.size():
		(_cells[i] as Control).custom_minimum_size = Vector2(cell_w, minf(64.0, roster_h - 4.0))
		var nm := _cell_names[i] as Label
		_font(nm, int(clampf(vp.x * 0.045, 14, 22)))
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF


func _align_copy(align: HorizontalAlignment, wrap: TextServer.AutowrapMode) -> void:
	for l: Label in [_name_l, _line_l, _start_l]:
		l.horizontal_alignment = align
		l.autowrap_mode = wrap
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _font(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)


func _box(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
	c.grow_horizontal = Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_END


# --- highlight / pick ------------------------------------------------------------

func _set_highlight(i: int) -> void:
	if _ids.is_empty():
		return
	_highlight = wrapi(i, 0, _ids.size())
	_apply_highlight()


func _apply_highlight() -> void:
	var id := highlighted_id()
	if id == "":
		return
	var ch: Dictionary = _chars.get(id, {})
	_name_l.text = String(ch.get("name", id)).to_upper()
	_line_l.text = String(ch.get("line", ""))
	_start_l.text = String(ch.get("start_name", "")).to_upper()
	_minimap.set_highlight(id)
	_stage.show_character(id)
	for i: int in _cells.size():
		var on := i == _highlight
		(_cells[i] as PanelContainer).add_theme_stylebox_override(
			"panel", _cell_style(on)
		)
		(_cell_names[i] as Label).add_theme_color_override(
			"font_color", GOLD if on else CREAM
		)


func _cell_style(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.06, 0.96) if on else Color(0.05, 0.05, 0.07, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(2 if on else 1)
	sb.border_color = GOLD if on else Color(0.30, 0.31, 0.37)
	return sb


## A short press on a card chooses it. A sideways stroke moves
## the highlight, on the card or across the stage.
func _cell_input(i: int, cell: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pointer_down(mb.position, -1)
		else:
			_pointer_up(i)
		cell.accept_event()
	elif event is InputEventMouseMotion and _ptr == -1:
		_pointer_move((event as InputEventMouseMotion).position)
		cell.accept_event()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_pointer_down(t.position, t.index)
		elif _ptr == t.index:
			_pointer_up(i)
		cell.accept_event()
	elif event is InputEventScreenDrag and _ptr == (event as InputEventScreenDrag).index:
		_pointer_move((event as InputEventScreenDrag).position)
		cell.accept_event()


func _pointer_down(pos: Vector2, id: int) -> void:
	_ptr = id
	_ptr_from = pos
	_ptr_slide = 0.0


func _pointer_move(pos: Vector2) -> void:
	var dx := pos.x - _ptr_from.x
	_ptr_slide = maxf(_ptr_slide, absf(dx))
	if absf(dx) >= 72.0:
		_set_highlight(_highlight + (1 if dx < 0.0 else -1))
		_ptr_from = pos
		_ptr_slide = 0.0


func _pointer_up(cell_i: int) -> void:
	if _ptr == -2:
		return
	var tap := _ptr_slide < 36.0
	_ptr = -2
	if tap and cell_i >= 0:
		_set_highlight(cell_i)
		confirm()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _ids.is_empty():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pointer_down(mb.position, -1)
			else:
				_pointer_up(-1)
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion and _ptr == -1:
		_pointer_move((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_pointer_down(t.position, t.index)
		elif _ptr == t.index:
			_pointer_up(-1)
		get_viewport().set_input_as_handled()
		return
	elif event is InputEventScreenDrag and _ptr == (event as InputEventScreenDrag).index:
		_pointer_move((event as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_LEFT, KEY_A:
				_set_highlight(_highlight - 1)
			KEY_RIGHT, KEY_D:
				_set_highlight(_highlight + 1)
			KEY_1:
				_set_highlight(0)
				confirm()
			KEY_2:
				if _ids.size() > 1:
					_set_highlight(1)
					confirm()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirm()


func _on_visibility_changed() -> void:
	# Parked when hidden: the stage world, the turntable and the
	# minimap pulse all stop costing cycles during play.
	if _content != null:
		_content.process_mode = (
			Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
		)
	if _viewport != null:
		_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
		)
