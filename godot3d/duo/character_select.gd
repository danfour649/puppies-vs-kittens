class_name CharacterSelect
extends CanvasLayer
## SELECT — Mortal Kombat-pattern character select (Daniel, locked
## 2026-10-25): one screen, one decision — move, pick, done.
##
## The highlighted cat stands RENDERED on a spotlight stage (the real
## cat_kit model, idle-animated in a SubViewport), its NAME and ONE
## trait line beside it, and its start marked on a house-and-yard
## minimap with the start's name. The roster cells carry tight
## rendered portraits of each cat's own model (duo/portraits/, from
## duo/tools_portrait_shots.gd) — in MK the cells are the fighters'
## faces. Nothing else lives here: no stats,
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

## Roster-cell portraits: tight head-and-shoulders renders of the REAL
## cat_kit models, captured by duo/tools_portrait_shots.gd — in MK the
## cells are the fighters' faces, so here they are the cats' faces.
const PORTRAITS := {
	"willie": preload("res://duo/portraits/willie.png"),
	"aggie": preload("res://duo/portraits/aggie.png"),
}

const GOLD := Color(1.0, 0.80, 0.38)
const CREAM := Color(1.0, 0.97, 0.88)
const FAINT := Color(0.68, 0.70, 0.77)

var _ids: Array = []
var _chars: Dictionary = {}
var _highlight := 0
var _built := false

var _content: Control
var _viewport: SubViewport
var _stage: SelectStage
var _name_l: Label
var _line_l: Label
var _start_l: Label
var _minimap: SelectMinimap
var _cells: Array = [] # PanelContainer per roster id
var _cell_names: Array = [] # Label inside each cell
var _cell_portraits: Array = [] # TextureRect inside each cell


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
	grad.colors = PackedColorArray([Color(0.135, 0.108, 0.082), Color(0.010, 0.010, 0.016)])
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

	# A soft warm glow pooled behind the stage side of the screen, so
	# the spotlight panel sits in light instead of on a black field.
	var glow_grad := Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 1.0])
	glow_grad.colors = PackedColorArray(
		[Color(1.0, 0.80, 0.42, 0.22), Color(1.0, 0.80, 0.42, 0.0)]
	)
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = glow_tex
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(glow, -0.06, -0.12, 0.74, 0.80)
	_content.add_child(glow)

	var spaced := FontVariation.new()
	spaced.base_font = _content.get_theme_default_font()
	spaced.spacing_glyph = 5

	# The stage: the highlighted cat, rendered, in a spotlight.
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(1024, 600)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style())
	_place(frame, 0.010, 0.022, 0.620, 0.664)
	_content.add_child(frame)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(svc)
	svc.add_child(_viewport)
	_stage = StageScene.new()
	_viewport.add_child(_stage)
	_stage.setup(_chars, _ids)

	# Name + the one line.
	_name_l = _label(58, CREAM, spaced)
	_name_l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_name_l.add_theme_constant_override("shadow_offset_x", 3)
	_name_l.add_theme_constant_override("shadow_offset_y", 3)
	_name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_name_l.add_theme_constant_override("outline_size", 6)
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
	var kick := _label(12, FAINT, spaced)
	kick.text = "START"
	_place(kick, 0.657, 0.715, 0.975, 0.745)
	_content.add_child(kick)
	_start_l = _label(24, CREAM, spaced)
	_place(_start_l, 0.657, 0.745, 0.975, 0.815)
	_content.add_child(_start_l)

	# Roster strip: move the highlight by hovering, click to pick.
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 20)
	strip.anchor_left = 0.435
	strip.anchor_top = 0.688
	strip.anchor_right = 0.435
	strip.anchor_bottom = 0.968
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_content.add_child(strip)
	for i: int in _ids.size():
		var id := String(_ids[i])
		var ch: Dictionary = _chars.get(id, {})
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(238, 248)
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 6)
		cell.add_child(vb)
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if PORTRAITS.has(id):
			pic.texture = PORTRAITS[id]
		pic.custom_minimum_size = Vector2(218, 192)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vb.add_child(pic)
		var nm := _label(22, CREAM, spaced)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.text = String(ch.get("name", id)).to_upper()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vb.add_child(nm)
		strip.add_child(cell)
		_cells.append(cell)
		_cell_names.append(nm)
		_cell_portraits.append(pic)
		cell.mouse_entered.connect(func() -> void: _set_highlight(i))
		cell.gui_input.connect(
			func(event: InputEvent) -> void:
				if event is InputEventMouseButton:
					var mb := event as InputEventMouseButton
					if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
						_set_highlight(i)
						confirm()
		)


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
		(_cell_portraits[i] as TextureRect).modulate = (
			Color(1, 1, 1, 1) if on else Color(0.60, 0.60, 0.67, 1)
		)


func _frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.028, 0.040, 0.92)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.44, 0.35, 0.16)
	return sb


func _cell_style(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.105, 0.05, 0.97) if on else Color(0.038, 0.038, 0.052, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	sb.set_border_width_all(3 if on else 1)
	sb.border_color = GOLD if on else Color(0.30, 0.31, 0.37)
	return sb


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _ids.is_empty():
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
