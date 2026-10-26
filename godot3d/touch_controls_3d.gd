class_name TouchControls3D
extends CanvasLayer
## Touch UI for the 3D edition. The left side is a paw-print
## joystick. The right half is gestures: a tap meows, a swipe
## paws in that direction, a still hold stalks. Two fingers held
## still restart. Desktop: left click pounces, right click paws,
## right-drag or middle-drag looks. Keyboard bindings stay.

signal strike_pressed
signal pounce_pressed
signal meow_pressed
signal restart_pressed
signal look_dragged(relative: Vector2)

const TAP_PX := 26.0
const HOLD_SEC := 0.32
const RESTART_HOLD := 0.7

var joystick: PvKJoystick3D
## Screen-space swipe, y down. Zero means "use the way he is facing".
var swipe_dir := Vector2.ZERO
var stalk_held := false

## Controls (the compass) that a touch should not also meow on.
var pass_controls: Array = []

var _fingers := {}
var _restart_sent := false

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
	stalk_held = false
	if _fingers.size() == 1:
		var only: Dictionary = _fingers[_fingers.keys()[0]]
		var held := float(Time.get_ticks_msec() - int(only["msec"])) / 1000.0
		stalk_held = float(only["moved"]) < TAP_PX and held >= HOLD_SEC
	if _fingers.size() >= 2 and not _restart_sent:
		var ready := true
		for index: Variant in _fingers.keys():
			var f: Dictionary = _fingers[index]
			var held := float(Time.get_ticks_msec() - int(f["msec"])) / 1000.0
			if float(f["moved"]) >= TAP_PX or held < RESTART_HOLD:
				ready = false
		if ready:
			_restart_sent = true
			restart_pressed.emit()


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


func _blocked(pos: Vector2) -> bool:
	for c: Variant in pass_controls:
		if c is Control and is_instance_valid(c):
			var ctrl := c as Control
			if ctrl.visible and ctrl.get_global_rect().has_point(pos):
				return true
	return false


func _on_screen_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		if _blocked(t.position) or _over_stick(t.position):
			return
		if _fingers.is_empty() and not _right_half(t.position):
			return
		if _fingers.size() >= 2:
			return
		_fingers[t.index] = {
			"from": t.position,
			"msec": Time.get_ticks_msec(),
			"moved": 0.0,
		}
		get_viewport().set_input_as_handled()
	elif _fingers.has(t.index):
		_release_finger(t.index, t.position)
		get_viewport().set_input_as_handled()


func _on_screen_drag(d: InputEventScreenDrag) -> void:
	if not _fingers.has(d.index):
		return
	var f: Dictionary = _fingers[d.index]
	var from: Vector2 = f["from"]
	f["moved"] = maxf(float(f["moved"]), from.distance_to(d.position))
	get_viewport().set_input_as_handled()


func _release_finger(index: int, pos: Vector2) -> void:
	var f: Dictionary = _fingers[index]
	var from: Vector2 = f["from"]
	var moved := maxf(float(f["moved"]), from.distance_to(pos))
	var held := float(Time.get_ticks_msec() - int(f["msec"])) / 1000.0
	var others := _fingers.size() - 1
	_fingers.erase(index)
	stalk_held = false
	if _restart_sent:
		if _fingers.is_empty():
			_restart_sent = false
		return
	if others > 0:
		return
	var kind := classify(moved, held)
	swipe_dir = pos - from
	if kind == "swipe":
		strike_pressed.emit()
	elif kind == "tap":
		swipe_dir = Vector2.ZERO
		meow_pressed.emit()


func _on_mouse_button(b: InputEventMouseButton) -> void:
	if b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT and b.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if _blocked(b.position):
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
