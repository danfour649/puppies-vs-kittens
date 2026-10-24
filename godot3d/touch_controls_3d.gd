class_name TouchControls3D
extends CanvasLayer
## Touch UI for the 3D edition: virtual joystick bottom-left, PAW
## button bottom-right. Same pattern as the 2D edition's
## TouchControls, minus the bird button (there are no birds here).

signal strike_pressed
signal pounce_pressed

var joystick: PvKJoystick3D


func _ready() -> void:
	joystick = PvKJoystick3D.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 30
	joystick.offset_top = -250
	joystick.offset_right = 250
	joystick.offset_bottom = -30
	add_child(joystick)
	var paw := Button.new()
	paw.text = "PAW"
	paw.add_theme_font_size_override("font_size", 26)
	paw.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	paw.offset_left = -160
	paw.offset_top = -170
	paw.offset_right = -30
	paw.offset_bottom = -50
	paw.pressed.connect(func() -> void: strike_pressed.emit())
	add_child(paw)
	var pounce := Button.new()
	pounce.text = "POUNCE"
	pounce.add_theme_font_size_override("font_size", 22)
	pounce.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pounce.offset_left = -330
	pounce.offset_right = -175
	pounce.offset_top = -300
	pounce.offset_bottom = -190
	pounce.pressed.connect(func() -> void: pounce_pressed.emit())
	add_child(pounce)


func move_vector() -> Vector2:
	return joystick.value if joystick != null else Vector2.ZERO
