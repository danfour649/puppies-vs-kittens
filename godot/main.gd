extends Node2D

## Puppies vs Kittens — Godot edition (v0.3), main controller.
##
## A faithful port of the JavaFX original's rules (KvPModel.java / Main.java):
##   * field 500x500 in the original; here the same proportions at 1000x1000
##   * mice 7 / 14 / 21 and puppies 1 / 2 / 3 on easy / medium / hard
##   * mice random-jitter movement, faster per difficulty
##   * puppies chase with step = distance / divisor (150 / 100 / 50) and a
##     per-puppy index multiplier; a fighting puppy drains kitten HP once
##     per second: 5 / 7 / 20 by difficulty; kitten HP 100, lose at 0
##   * a paw strike wounds a mouse; the wound kills after 3 s
##     (Java timeToLiveAfterHurt); win when no mice remain
##   * quitting with mice left is a loss; the kills counter is cumulative
##     across rounds in a session, exactly like the original
## Extensions on top: continuous movement + WASD, touch controls, and bird
## mode (possession swap adapted from GTA Fredericton's bird mode, TODO #87).

const FIELD_RECT := Rect2(0, 0, 1000, 1000)
const VERSION := "v0.3"

const DIFFICULTY: Dictionary = {
    "easy": {"mice": 7, "puppies": 1, "mouse_jitter": 130.0, "puppy_rate_mult": 1.0, "puppy_damage": 5.0, "puppy_speed_cap": 300.0},
    "medium": {"mice": 14, "puppies": 2, "mouse_jitter": 260.0, "puppy_rate_mult": 1.5, "puppy_damage": 7.0, "puppy_speed_cap": 340.0},
    "hard": {"mice": 21, "puppies": 3, "mouse_jitter": 390.0, "puppy_rate_mult": 3.0, "puppy_damage": 20.0, "puppy_speed_cap": 400.0},
}
# Java spawn corners (500,500) / (0,0) / (500,0), rescaled and inset.
const PUPPY_CORNERS: Array = [Vector2(950, 950), Vector2(50, 50), Vector2(950, 50)]

var state: String = "splash" # splash | playing | over
var difficulty: String = "easy"
var was_lost: bool = false

var kitten: Animal = null
var player: Animal = null
var player_bird: Animal = null
var wild_bird: Animal = null
var mice: Array = []
var puppies: Array = []

var kills: int = 0 # cumulative across rounds (faithful to the original)
var round_kills: int = 0
var kills_by_mode: Dictionary = {"easy": 0, "medium": 0, "hard": 0}
var mice_remaining: int = 0
var clock_time: int = 0
var total_play_time: int = 0

# Test hooks (used by tests/smoke_test.gd; harmless in normal play).
var debug_move: Vector2 = Vector2.ZERO

var _second_acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _corpses: Array = []

var _hud: CanvasLayer
var _lbl_mice: Label
var _lbl_kills: Label
var _lbl_time: Label
var _lbl_hp: Label
var _lbl_mode: Label
var _splash: CanvasLayer
var _credits: CanvasLayer
var _credits_title: Label
var _credits_body: Label
var _touch: TouchControls


func _ready() -> void:
    _rng.randomize()
    _setup_input()
    _build_hud()
    _build_splash()
    _build_credits()
    _touch = TouchControls.new()
    add_child(_touch)
    _touch.strike_pressed.connect(_on_touch_strike)
    _touch.bird_pressed.connect(_on_touch_bird)
    _touch.visible = false
    queue_redraw()
    show_splash()


func _draw() -> void:
    draw_rect(FIELD_RECT, Color(1, 0.937, 0.835)) # papawhip, like the original
    var deco := RandomNumberGenerator.new()
    deco.seed = 4242
    for i in 240:
        var p := Vector2(deco.randf_range(8, 992), deco.randf_range(8, 992))
        draw_circle(p, 2.4, Color(0.93, 0.85, 0.66))
    for i in 60:
        var p := Vector2(deco.randf_range(8, 992), deco.randf_range(8, 992))
        var c := Color(0.72, 0.78, 0.5, 0.8)
        draw_line(p + Vector2(-4, 3), p + Vector2(0, -4), c, 1.6)
        draw_line(p + Vector2(4, 3), p + Vector2(1, -5), c, 1.6)
    draw_rect(FIELD_RECT, Color(0, 0.36, 0.36), false, 6.0) # dark cyan frame


# ------------------------------------------------------------------ setup

func _setup_input() -> void:
    _add_key_action("move_left", [KEY_LEFT, KEY_A])
    _add_key_action("move_right", [KEY_RIGHT, KEY_D])
    _add_key_action("move_up", [KEY_UP, KEY_W])
    _add_key_action("move_down", [KEY_DOWN, KEY_S])
    _add_key_action("strike", [KEY_SPACE])
    _add_key_action("bird_toggle", [KEY_B])
    _add_key_action("restart_round", [KEY_R])
    _add_key_action("quit_round", [KEY_ESCAPE])


func _add_key_action(action: StringName, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for k in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = k
        InputMap.action_add_event(action, ev)


func _mk_label(text: String, size: int, color: Color = Color(0.08, 0.08, 0.08)) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


func _mk_button(text: String, min_h: float = 52.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, min_h)
    b.add_theme_font_size_override("font_size", 22)
    b.focus_mode = Control.FOCUS_NONE
    return b


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
    _hud = CanvasLayer.new()
    add_child(_hud)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1, 1, 1, 0.78)
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    panel.add_theme_stylebox_override("panel", sb)
    _hud.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    panel.add_child(row)
    _lbl_mice = _mk_label("Mice Left: 0", 24)
    _lbl_kills = _mk_label("Kills: 0", 24)
    _lbl_time = _mk_label("Time: 0", 24, Color(0, 0.45, 0.45))
    _lbl_hp = _mk_label("HP: 100", 24, Color(0.5, 0.05, 0.05))
    _lbl_mode = _mk_label("", 20, Color(0.3, 0.3, 0.3))
    row.add_child(_lbl_mice)
    row.add_child(_lbl_kills)
    row.add_child(_lbl_time)
    row.add_child(_lbl_hp)
    row.add_child(_lbl_mode)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    var b_easy := _mk_button("EASY", 46)
    b_easy.pressed.connect(func() -> void: start_round("easy"))
    row.add_child(b_easy)
    var b_med := _mk_button("MED", 46)
    b_med.pressed.connect(func() -> void: start_round("medium"))
    row.add_child(b_med)
    var b_hard := _mk_button("HARD", 46)
    b_hard.pressed.connect(func() -> void: start_round("hard"))
    row.add_child(b_hard)
    var b_bird := _mk_button("BIRD", 46)
    b_bird.pressed.connect(toggle_bird_mode)
    row.add_child(b_bird)
    var b_restart := _mk_button("RESTART", 46)
    b_restart.pressed.connect(func() -> void: start_round(difficulty))
    row.add_child(b_restart)
    var b_quit := _mk_button("QUIT", 46)
    b_quit.pressed.connect(quit_round)
    row.add_child(b_quit)
    _hud.visible = false


func _update_hud() -> void:
    _lbl_mice.text = "Mice Left: %d" % mice_remaining
    _lbl_kills.text = "Kills: %d" % kills
    _lbl_time.text = "Time: %d" % clock_time
    if kitten != null and is_instance_valid(kitten):
        _lbl_hp.text = "HP: %d" % int(kitten.hp)
    var mode_name := difficulty.capitalize()
    if player != null and player == player_bird:
        mode_name += " · BIRD"
    _lbl_mode.text = mode_name


# ------------------------------------------------------------------ splash / credits

func _overlay(bg: Color) -> CanvasLayer:
    var layer := CanvasLayer.new()
    add_child(layer)
    var rect := ColorRect.new()
    rect.color = bg
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(rect)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(center)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    center.add_child(vbox)
    layer.set_meta("vbox", vbox)
    return layer


func _build_splash() -> void:
    _splash = _overlay(Color(0.62, 0.16, 0.11, 1.0)) # firebrick, like the FXML splash
    var vbox: VBoxContainer = _splash.get_meta("vbox")
    var logo := TextureRect.new()
    logo.texture = load("res://assets/KvPlogo.png")
    logo.custom_minimum_size = Vector2(430, 354)
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    vbox.add_child(logo)
    var title := _mk_label("Puppies vs Kittens", 52, Color.WHITE)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    var sub := _mk_label("Godot edition " + VERSION + " — you are the kitten. Hunt every mouse. Dodge the puppies.", 20, Color(1, 0.9, 0.8))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(sub)
    var pick := _mk_label("Choose a difficulty to play:", 22, Color.WHITE)
    pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(pick)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    vbox.add_child(row)
    for diff_id in ["easy", "medium", "hard"]:
        var b := _mk_button(str(diff_id).to_upper(), 60)
        b.custom_minimum_size = Vector2(180, 60)
        var d: String = str(diff_id)
        b.pressed.connect(func() -> void: start_round(d))
        row.add_child(b)
    var help := _mk_label("Move: Arrow keys / WASD / joystick    Strike: SPACE / PAW\nBird mode: B / BIRD button (SPACE dives to snatch a mouse)\nRestart: R    Quit: ESC", 18, Color(1, 0.85, 0.75))
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(help)


func _build_credits() -> void:
    _credits = _overlay(Color(0.1, 0.08, 0.08, 0.88))
    var vbox: VBoxContainer = _credits.get_meta("vbox")
    _credits_title = _mk_label("", 44, Color.WHITE)
    _credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_credits_title)
    _credits_body = _mk_label("", 24, Color(0.95, 0.92, 0.85))
    _credits_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_credits_body)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    vbox.add_child(row)
    var again := _mk_button("PLAY AGAIN", 60)
    again.custom_minimum_size = Vector2(220, 60)
    again.pressed.connect(func() -> void: start_round(difficulty))
    row.add_child(again)
    var menu := _mk_button("MENU", 60)
    menu.custom_minimum_size = Vector2(160, 60)
    menu.pressed.connect(show_splash)
    row.add_child(menu)
    _credits.visible = false


func show_splash() -> void:
    state = "splash"
    _clear_animals()
    _splash.visible = true
    _credits.visible = false
    _hud.visible = false
    _touch.visible = false


# ------------------------------------------------------------------ rounds

func start_round(diff_id: String) -> void:
    difficulty = diff_id
    _clear_animals()
    var d: Dictionary = DIFFICULTY[diff_id]
    round_kills = 0
    clock_time = 0
    _second_acc = 0.0
    was_lost = false

    kitten = _spawn("kitten", Vector2(500, 500))
    kitten.brain = "player"
    kitten.player_controlled = true
    player = kitten

    for i in int(d["mice"]):
        var pos := Vector2(_rng.randf_range(45, 955), _rng.randf_range(45, 955))
        var m := _spawn("mouse", pos)
        mice.append(m)
    mice_remaining = mice.size()
    for m in mice:
        m.flock = mice
        m.threat = kitten

    for i in int(d["puppies"]):
        var p := _spawn("puppy", PUPPY_CORNERS[i])
        p.pack_index = i
        p.threat = kitten
        puppies.append(p)

    # A wild bird works the field from the start: it circles and now and
    # then dives at a mouse (bird-mode design reused from GTA Fredericton).
    wild_bird = _spawn("bird", Vector2(500, 180))
    wild_bird.brain = "aerial_predator"
    wild_bird.altitude = 1.0
    wild_bird.flight_phase = "cruise"

    state = "playing"
    _splash.visible = false
    _credits.visible = false
    _hud.visible = true
    _touch.visible = DisplayServer.is_touchscreen_available()
    _update_hud()


func quit_round() -> void:
    if state != "playing":
        return
    if mice_remaining > 0:
        _end_round(false, "You quit — the mice remain!")
    else:
        _end_round(true, "All mice caught!")


func _end_round(won: bool, headline: String) -> void:
    state = "over"
    was_lost = not won
    if player != null and is_instance_valid(player):
        player.input_move = Vector2.ZERO
    _credits_title.text = headline
    _credits_body.text = "Time taken that round: %d s\nTotal time played: %d s\n\nEasy Mode Kills: %d    Medium Mode Kills: %d    Hard Mode Kills: %d\nTotal Kills: %d" % [
        clock_time, total_play_time,
        int(kills_by_mode["easy"]), int(kills_by_mode["medium"]), int(kills_by_mode["hard"]),
        kills]
    _credits.visible = true
    _hud.visible = false
    _touch.visible = false


func _spawn(species_id: String, pos: Vector2) -> Animal:
    var a := AnimalKit.make_animal(species_id)
    a.tuning = DIFFICULTY[difficulty]
    a.field_rect = FIELD_RECT
    add_child(a)
    a.position = pos
    a.died.connect(_on_animal_died)
    return a


func _clear_animals() -> void:
    for child in get_children():
        if child is Animal:
            child.queue_free()
    for c in _corpses:
        if is_instance_valid(c["node"]):
            (c["node"] as Node).queue_free()
    _corpses.clear()
    mice.clear()
    puppies.clear()
    kitten = null
    player = null
    player_bird = null
    wild_bird = null


# ------------------------------------------------------------------ bird mode

func toggle_bird_mode() -> void:
    if state != "playing" or kitten == null:
        return
    if player == kitten:
        if player_bird == null or not is_instance_valid(player_bird):
            player_bird = _spawn("bird", kitten.position)
        else:
            player_bird.position = kitten.position
        player_bird.brain = "player_bird"
        player_bird.player_controlled = true
        player_bird.altitude = 0.0
        player_bird.flight_phase = "ground"
        kitten.player_controlled = false
        kitten.brain = "wanderer" # possession swap: the cat stays in the world
        kitten.input_move = Vector2.ZERO
        player = player_bird
    else:
        player_bird.player_controlled = false
        player_bird.brain = "aerial_predator"
        player_bird.input_move = Vector2.ZERO
        kitten.brain = "player"
        kitten.player_controlled = true
        player = kitten
    _update_hud()


# ------------------------------------------------------------------ events

func _on_animal_died(a: Animal) -> void:
    if a.species_id == "mouse":
        _corpses.append({"node": a, "t": 0.9})
        if state == "playing":
            kills += 1
            round_kills += 1
            kills_by_mode[difficulty] = int(kills_by_mode[difficulty]) + 1
            mice_remaining -= 1
            mice.erase(a)
            _update_hud()
            if mice_remaining <= 0:
                total_play_time += clock_time
                _end_round(true, "All mice caught!")
    elif a == kitten and state == "playing":
        _end_round(false, "Caught! The puppies got the kitten.")


func _on_touch_strike() -> void:
    if state == "playing" and player != null:
        player.input_strike = true


func _on_touch_bird() -> void:
    toggle_bird_mode()


func _input(event: InputEvent) -> void:
    if state != "playing":
        return
    if event.is_action_pressed("strike") and player != null:
        player.input_strike = true
    elif event.is_action_pressed("bird_toggle"):
        toggle_bird_mode()
    elif event.is_action_pressed("restart_round"):
        start_round(difficulty)
    elif event.is_action_pressed("quit_round"):
        quit_round()


func _physics_process(delta: float) -> void:
    if state != "playing":
        return
    if player != null and is_instance_valid(player):
        var kv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
        var tv := Vector2.ZERO
        if _touch != null and _touch.visible and _touch.joystick != null:
            tv = _touch.joystick.vector
        player.input_move = (kv + tv + debug_move).limit_length(1.0)

    # Mice fear whichever predator is dangerous right now: a diving bird,
    # otherwise the kitten.
    var bird_threat: Animal = null
    if player_bird != null and is_instance_valid(player_bird) and player_bird.flight_phase == "dive":
        bird_threat = player_bird
    elif wild_bird != null and is_instance_valid(wild_bird) and wild_bird.flight_phase == "dive":
        bird_threat = wild_bird
    for m in mice:
        if is_instance_valid(m):
            m.threat = bird_threat if bird_threat != null else kitten

    _second_acc += delta
    while _second_acc >= 1.0:
        _second_acc -= 1.0
        _on_second_tick()


func _on_second_tick() -> void:
    clock_time += 1
    if kitten != null and is_instance_valid(kitten) and not kitten.is_dead:
        var dmg := float(DIFFICULTY[difficulty]["puppy_damage"])
        for p in puppies:
            if is_instance_valid(p) and p.in_attack_range:
                kitten.take_damage(dmg) # Java checkFightPuppies: per second, per fighting puppy
    _update_hud()


func _process(delta: float) -> void:
    for i in range(_corpses.size() - 1, -1, -1):
        var c: Dictionary = _corpses[i]
        var node: Node = c["node"]
        if not is_instance_valid(node):
            _corpses.remove_at(i)
            continue
        c["t"] = float(c["t"]) - delta
        (node as Node2D).modulate.a = clampf(float(c["t"]) / 0.9, 0.0, 1.0)
        if float(c["t"]) <= 0.0:
            node.queue_free()
            _corpses.remove_at(i)
