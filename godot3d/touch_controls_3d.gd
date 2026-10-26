class_name TouchControls3D
extends CanvasLayer
## Touch UI for the 3D edition. The left side is a paw-print
## joystick. The right half is gestures: a tap pounces, a swipe
## paws in that direction, a still hold stalks.
## Desktop: left click pounces, right click paws, right-drag or
## middle-drag looks. Keyboard bindings stay where they are.

signal strike_pressed
signal pounce_pressed
signal look_dragged(relative: Vector2)

const TAP_PX := 26.0
const HOLD_SEC := 0.32

var joystick: PvKJoystick3D
## Screen-space swipe, y down. Zero means "use the way he is facing".
var swipe_dir := Vector2.ZERO
var stalk_held := false

var _touch_id := -2
var _touch_from := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_msec := 0
var _touch_moved := 0.0

var _mouse_btn := 0
var _mouse_from := Vector2.ZERO
var _mouse_moved := 0.0
var _mouse_look := false


func _ready() -> void:
	layer = 12
	joystick = PvKJoystick3D.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 24
	joystick.offset_top = -286
	joystick.offset_right = 254
	joystick.offset_bottom = -18
	add_child(joystick)


func move_vector() -> Vector2:
	return joystick.value if joystick != null else Vector2.ZERO


## "swipe" wins over a hold, and a short still press is a tap.
static func classify(moved: float, held: float) -> String:
	if moved >= TAP_PX:
		return "swipe"
	if held >= HOLD_SEC:
		return "hold"
	return "tap"


## Model forward is -Z, so this yaw turns that axis onto `dir`.
static func yaw_to_face(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _process(_delta: float) -> void:
	if _touch_id < 0:
		stalk_held = false
		return
	var held := float(Time.get_ticks_msec() - _touch_msec) / 1000.0
	stalk_held = _touch_moved < TAP_PX and held >= HOLD_SEC


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _mouse_btn != 0:
		_on_mouse_motion(event as InputEventMouseMotion)


func _right_half(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	return pos.x >= vp.x * 0.5


func _over_stick(pos: Vector2) -> bool:
	return joystick != null and joystick.get_global_rect().has_point(pos)


func _on_screen_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		if _touch_id != -2 or _over_stick(t.position) or not _right_half(t.position):
			return
		_touch_id = t.index
		_touch_from = t.position
		_touch_last = t.position
		_touch_msec = Time.get_ticks_msec()
		_touch_moved = 0.0
		get_viewport().set_input_as_handled()
	elif t.index == _touch_id:
		_finish_touch(t.position)
		get_viewport().set_input_as_handled()


func _on_screen_drag(d: InputEventScreenDrag) -> void:
	if d.index != _touch_id:
		return
	_touch_last = d.position
	_touch_moved = maxf(_touch_moved, _touch_from.distance_to(d.position))
	get_viewport().set_input_as_handled()


func _finish_touch(pos: Vector2) -> void:
	_touch_last = pos
	_touch_moved = maxf(_touch_moved, _touch_from.distance_to(pos))
	var held := float(Time.get_ticks_msec() - _touch_msec) / 1000.0
	var kind := classify(_touch_moved, held)
	swipe_dir = _touch_last - _touch_from
	_touch_id = -2
	stalk_held = false
	if kind == "swipe":
		strike_pressed.emit()
	elif kind == "tap":
		swipe_dir = Vector2.ZERO
		pounce_pressed.emit()


func _on_mouse_button(b: InputEventMouseButton) -> void:
	if b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT and b.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if _over_stick(b.position) and b.button_index == MOUSE_BUTTON_LEFT:
		return
	if b.pressed:
		_mouse_btn = b.button_index
		_mouse_from = b.position
		_mouse_moved = 0.0
		_mouse_look = false
		get_viewport().set_input_as_handled()
		return
	if b.button_index != _mouse_btn:
		return
	_mouse_moved = maxf(_mouse_moved, _mouse_from.distance_to(b.position))
	var look := _mouse_look or _mouse_moved >= TAP_PX
	var btn := _mouse_btn
	_mouse_btn = 0
	_mouse_look = false
	if btn == MOUSE_BUTTON_LEFT and not look:
		swipe_dir = Vector2.ZERO
		pounce_pressed.emit()
	elif btn == MOUSE_BUTTON_RIGHT and not look:
		swipe_dir = Vector2.ZERO
		strike_pressed.emit()
	get_viewport().set_input_as_handled()


func _on_mouse_motion(m: InputEventMouseMotion) -> void:
	_mouse_moved = maxf(_mouse_moved, _mouse_from.distance_to(m.position))
	var looking := _mouse_btn == MOUSE_BUTTON_RIGHT or _mouse_btn == MOUSE_BUTTON_MIDDLE
	if looking and _mouse_moved >= TAP_PX:
		_mouse_look = true
		look_dragged.emit(m.relative)
		get_viewport().set_input_as_handled()
