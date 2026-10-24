class_name PvKJoystick
extends Control

## Minimal virtual joystick: drag anywhere inside the control; `vector`
## is the knob offset normalised to the unit circle. Works with touch
## (InputEventScreenTouch/Drag) and with the mouse for desktop testing.

const RADIUS := 88.0

var vector: Vector2 = Vector2.ZERO

var _pointer_id: int = -999
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and _pointer_id == -999:
            _pointer_id = touch.index
            _update_knob(touch.position)
        elif not touch.pressed and touch.index == _pointer_id:
            _release()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == _pointer_id:
            _update_knob(drag.position)
    elif event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed and _pointer_id == -999:
                _pointer_id = -1
                _update_knob(mb.position)
            elif not mb.pressed and _pointer_id == -1:
                _release()
    elif event is InputEventMouseMotion and _pointer_id == -1:
        _update_knob((event as InputEventMouseMotion).position)


func _release() -> void:
    _pointer_id = -999
    _knob = Vector2.ZERO
    vector = Vector2.ZERO
    queue_redraw()


func _update_knob(p: Vector2) -> void:
    var off := p - size * 0.5
    if off.length() > RADIUS:
        off = off.normalized() * RADIUS
    _knob = off
    vector = off / RADIUS
    queue_redraw()


func _draw() -> void:
    var c := size * 0.5
    draw_circle(c, RADIUS, Color(1, 1, 1, 0.14))
    draw_arc(c, RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
    draw_circle(c + _knob, 32.0, Color(1, 1, 1, 0.35))
