class_name ObjectivesHUD
extends CanvasLayer
## The objective list lives on the night compass. Tab, or a tap
## on that card, opens it. This node stays so the massey harness
## can still call toggle() / panel_visible().

var objectives: PvKObjectives = null
var manager: ZoneManager = null

var _open := false


func setup(obj: PvKObjectives, mgr: ZoneManager) -> void:
	objectives = obj
	manager = mgr
	layer = 3


func toggle() -> void:
	var night := _night()
	if night != null:
		night.toggle_objectives()
		_open = night.objectives_open()
	else:
		_open = not _open


func panel_visible() -> bool:
	var night := _night()
	if night != null:
		return night.objectives_open()
	return _open


func _night() -> NightRun:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("NightRun") as NightRun


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
