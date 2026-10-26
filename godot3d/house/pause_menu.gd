class_name PauseMenu
extends CanvasLayer
## The night's pause. Esc, or three fingers together.
## Volume, picture, the look of the camera, and a saved night
## to come back to. The yard and the rooms keep running when
## this is closed.


const SETTINGS_PATH := "user://house_settings.cfg"
const NIGHT_PATH := "user://night_progress.json"

var game: Node = null
var open := false

var _root: Control
var _note: Label
var _volume: HSlider
var _sens: HSlider
var _invert: CheckButton
var _quality: Label
var _volume_value := 1.0
var _sens_value := 1.0
var _invert_value := false
var _tier := "high"


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_settings()
	_root.visible = false


func bind(host: Node) -> void:
	game = host
	_apply_to_game()
	_refresh_quality_label()


func toggle() -> void:
	if open:
		close()
	else:
		show_menu()


func show_menu() -> void:
	open = true
	_root.visible = true
	_note.text = ""
	get_tree().paused = true


func close() -> void:
	open = false
	_root.visible = false
	_save_settings()
	if get_tree() != null:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230
	panel.offset_top = -250
	panel.offset_right = 230
	panel.offset_bottom = 250
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.08, 0.07, 0.96)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", box)
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var title := _text("The night, paused", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(_text("Volume", 16))
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.02
	_volume.value = 1.0
	_volume.custom_minimum_size = Vector2(0, 28)
	_volume.value_changed.connect(_on_volume)
	col.add_child(_volume)
	_quality = _text("Picture: high", 16)
	col.add_child(_quality)
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 8)
	col.add_child(tiers)
	var high := _button("High")
	high.pressed.connect(func() -> void: _set_tier("high"))
	var low := _button("Low")
	low.pressed.connect(func() -> void: _set_tier("low"))
	tiers.add_child(high)
	tiers.add_child(low)
	_invert = CheckButton.new()
	_invert.text = "Invert the look"
	_invert.toggled.connect(_on_invert)
	col.add_child(_invert)
	col.add_child(_text("Look sensitivity", 16))
	_sens = HSlider.new()
	_sens.min_value = 0.4
	_sens.max_value = 2.2
	_sens.step = 0.05
	_sens.value = 1.0
	_sens.custom_minimum_size = Vector2(0, 28)
	_sens.value_changed.connect(_on_sens)
	col.add_child(_sens)
	var save_b := _button("Save this night")
	save_b.pressed.connect(_save_night)
	col.add_child(save_b)
	var resume_b := _button("Resume the saved night")
	resume_b.pressed.connect(_resume_night)
	col.add_child(resume_b)
	var back := _button("Back to the night")
	back.pressed.connect(close)
	col.add_child(back)
	_note = _text("", 14)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(380, 36)
	col.add_child(_note)


func _text(msg: String, size: int) -> Label:
	var l := Label.new()
	l.text = msg
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	return l


func _button(msg: String) -> Button:
	var b := Button.new()
	b.text = msg
	b.custom_minimum_size = Vector2(0, 36)
	return b


func _on_volume(v: float) -> void:
	_volume_value = v
	_apply_volume()
	_save_settings()


func _on_sens(v: float) -> void:
	_sens_value = v
	_apply_to_game()
	_save_settings()


func _on_invert(on: bool) -> void:
	_invert_value = on
	_apply_to_game()
	_save_settings()


func _set_tier(tier: String) -> void:
	_tier = tier
	if is_instance_valid(VisualQuality):
		VisualQuality.tier_name = tier
		_repaint()
	_refresh_quality_label()
	_save_settings()


func _refresh_quality_label() -> void:
	if _quality != null:
		_quality.text = "Picture: %s" % _tier


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if _volume_value <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(_volume_value))


func _apply_to_game() -> void:
	_apply_volume()
	if game == null:
		return
	game.set("look_sens", _sens_value)
	game.set("look_invert", _invert_value)
	if is_instance_valid(VisualQuality) and (_tier == "high" or _tier == "low"):
		VisualQuality.tier_name = _tier


func _repaint() -> void:
	if get_tree() == null:
		return
	var nodes := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	for n: Node in nodes:
		var we := n as WorldEnvironment
		if we.environment == null:
			continue
		var place := "yard"
		var parent_name := String(we.get_parent().name if we.get_parent() != null else "").to_lower()
		if parent_name.contains("basement"):
			place = "basement"
		VisualQuality.apply_environment(we.environment, place)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_tier = VisualQuality.tier_name if is_instance_valid(VisualQuality) else "high"
		return
	_volume_value = float(cfg.get_value("look", "volume", 1.0))
	_sens_value = float(cfg.get_value("look", "sensitivity", 1.0))
	_invert_value = bool(cfg.get_value("look", "invert", false))
	_tier = String(cfg.get_value("look", "quality", "high"))
	if _volume != null:
		_volume.set_value_no_signal(_volume_value)
	if _sens != null:
		_sens.set_value_no_signal(_sens_value)
	if _invert != null:
		_invert.set_pressed_no_signal(_invert_value)
	_refresh_quality_label()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "volume", _volume_value)
	cfg.set_value("look", "sensitivity", _sens_value)
	cfg.set_value("look", "invert", _invert_value)
	cfg.set_value("look", "quality", _tier)
	cfg.save(SETTINGS_PATH)


func _save_night() -> void:
	if game == null:
		return
	var night: Node = game.get("night")
	if night == null or not night.has_method("snapshot"):
		_note.text = "The night is not ready to keep."
		return
	var data: Dictionary = night.call("snapshot") as Dictionary
	var f := FileAccess.open(NIGHT_PATH, FileAccess.WRITE)
	if f == null:
		_note.text = "The night could not be written down."
		return
	f.store_string(JSON.stringify(data))
	f.close()
	_note.text = "Saved. The night will be here when you resume."


func _resume_night() -> void:
	if game == null:
		return
	if not FileAccess.file_exists(NIGHT_PATH):
		_note.text = "No night saved yet."
		return
	var f := FileAccess.open(NIGHT_PATH, FileAccess.READ)
	if f == null:
		_note.text = "The saved night could not be read."
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_note.text = "The saved night could not be read."
		return
	var night: Node = game.get("night")
	if night == null or not night.has_method("restore"):
		_note.text = "The night is not ready to resume."
		return
	night.call("restore", parsed)
	_note.text = ""
	close()
