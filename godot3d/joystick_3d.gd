class_name PvKJoystick3D
extends Control
## Virtual joystick, drawn as a paw so it reads on a dark floor.
## The big pad is the base ring, four toe beans sit above it, and
## the knob is a smaller pad that follows the touch.
## Handles touch and mouse. Same pattern as the 2D edition's joystick.

const RADIUS := 78.0
const TOE_BEANS := 4
## Idle stays translucent. A touch brings the print up.
const IDLE_ALPHA := 0.46
const TOUCH_ALPHA := 0.94

var value := Vector2.ZERO
var _pointer := -2 # -2 none, -1 mouse, >= 0 touch index


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(230, 250)


func is_touched() -> bool:
	return _pointer != -2


func _centre() -> Vector2:
	# Sit the print a little low so the toes have room.
	return Vector2(size.x * 0.5, size.y * 0.58)


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
	var a := TOUCH_ALPHA if is_touched() else IDLE_ALPHA
	var shadow := Color(0.02, 0.01, 0.02, 0.55)
	_print(c + Vector2(7, 9), shadow, 0.0, false)
	_print(c, Color(0.96, 0.42, 0.36, a), a, true)
	var knob := c + value * RADIUS * 0.72
	draw_circle(knob + Vector2(3, 4), 20.0, Color(0.02, 0.01, 0.02, 0.4))
	var knob_a := minf(a + 0.28, 1.0)
	_ellipse(knob, 22.0, 18.0, Color(1.0, 0.78, 0.64, knob_a))
	draw_polyline(_closed(_ellipse_points(knob, 22.0, 18.0)), Color(1.0, 0.97, 0.9, maxf(a, 0.8)), 3.0, true)


## Big pad, then the four toes. `outline` keeps a cream edge so the
## print still shows when the fill is faint.
func _print(c: Vector2, fill: Color, alpha: float, outline: bool) -> void:
	_ellipse(c, 74.0, 56.0, fill)
	if outline:
		var edge := Color(1.0, 0.96, 0.88, maxf(alpha, 0.82))
		draw_polyline(_closed(_ellipse_points(c, 74.0, 56.0)), edge, 5.0, true)
		draw_arc(c, 86.0, 0, TAU, 48, Color(1.0, 0.95, 0.86, 0.28 + alpha * 0.25), 8.0, true)
	var toes: Array[Vector2] = [
		Vector2(-50, -58), Vector2(-18, -78), Vector2(18, -78), Vector2(50, -58),
	]
	var toe_r := [Vector2(18, 24), Vector2(15, 22), Vector2(15, 22), Vector2(18, 24)]
	for i in TOE_BEANS:
		var at := c + toes[i]
		var rr: Vector2 = toe_r[i]
		_ellipse(at, rr.x, rr.y, fill)
		if outline:
			draw_polyline(_closed(_ellipse_points(at, rr.x, rr.y)), Color(1.0, 0.96, 0.88, maxf(alpha, 0.82)), 3.0, true)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(c, rx, ry), color)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.is_empty():
		return pts
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _ellipse_points(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var t := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts
