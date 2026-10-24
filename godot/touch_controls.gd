class_name TouchControls
extends CanvasLayer

## Touch UI: virtual joystick (bottom-left) + PAW and BIRD buttons
## (bottom-right). Shown only on touch devices; the game also feeds the
## joystick with the mouse on desktop when emulate-touch is enabled.

signal strike_pressed
signal bird_pressed

var joystick: PvKJoystick


func _ready() -> void:
    joystick = PvKJoystick.new()
    joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    joystick.offset_left = 30
    joystick.offset_top = -250
    joystick.offset_right = 250
    joystick.offset_bottom = -30
    add_child(joystick)

    var bird := Button.new()
    bird.text = "BIRD"
    bird.add_theme_font_size_override("font_size", 24)
    bird.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    bird.offset_left = -160
    bird.offset_top = -310
    bird.offset_right = -30
    bird.offset_bottom = -190
    bird.pressed.connect(_on_bird)
    add_child(bird)

    var strike := Button.new()
    strike.text = "PAW"
    strike.add_theme_font_size_override("font_size", 26)
    strike.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    strike.offset_left = -160
    strike.offset_top = -170
    strike.offset_right = -30
    strike.offset_bottom = -50
    strike.pressed.connect(_on_strike)
    add_child(strike)


func _on_strike() -> void:
    strike_pressed.emit()


func _on_bird() -> void:
    bird_pressed.emit()
