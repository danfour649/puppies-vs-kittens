class_name PvKJoystick3D
extends Control
## Virtual joystick: drag anywhere inside the control; value is the
## offset from centre clamped to the rim (y down = screen down).
## Handles touch and mouse. Same pattern as the 2D edition's joystick.

const RADIUS := 95.0

var value := Vector2.ZERO
var _pointer := -2 # -2 none, -1 mouse, >= 0 touch index


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(220, 220)


func _centre() -> Vector2:
	return size * 0.5


func _update(local_pos: Vector2) -> void:
	var off := local_pos - _centre()
	if off.length() > RADIUS:
		off = off.normalized() * RADIUS
	value = off / RADIUS
	queue_redraw()


func _release() -> void:
	_pointer = -2
	value = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _pointer == -2:
			_pointer = t.index
			_update(t.position)
			accept_event()
		elif not t.pressed and t.index == _pointer:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _pointer:
			_update(d.position)
			accept_event()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed and _pointer == -2:
				_pointer = -1
				_update(b.position)
				accept_event()
			elif not b.pressed and _pointer == -1:
				_release()
				accept_event()
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if _pointer == -1:
			_update(m.position)
			accept_event()


func _draw() -> void:
	var c := _centre()
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(c + value * RADIUS * 0.65, 34.0, Color(1, 1, 1, 0.25))
