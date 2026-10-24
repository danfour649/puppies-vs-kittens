extends Node3D
## Puppies vs Kittens 3D — cat-first edition (v0.4).
## You are the cat: Wolastoq Willow, built by cat_kit from GTA
## Fredericton's stray_cat. Catch every mouse in the backyard.
## No birds. Puppies are Phase 2 (see README.md).

const CatScene := preload("res://cat_kit/cat.gd")
const MouseScene := preload("res://mouse.gd")
const TouchScene := preload("res://touch_controls_3d.gd")

const MOUSE_COUNT := 7
const YARD := Rect2(-12.4, -9.4, 24.8, 18.8) # inside the fence
const CHAIR_SEAT := Vector3(4.5, 0.46, 4.5) # top of the garden chair

var cat: PvKCat
var mice: Array = []
var caught_count := 0
var elapsed := 0.0
var won := false

var cam_yaw := PI
var cam_pitch := -0.48
var cam_dist := 4.6

## Smoke-test seam: when active, physics input comes from here.
var input_override := {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}

var _rig: Node3D
var _arm: SpringArm3D
var _lbl_left: Label
var _lbl_caught: Label
var _lbl_time: Label
var _banner: Label
var _touch: TouchControls3D
var _dragging := false
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _meshes := {}


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_lights()
	cat = CatScene.new()
	cat.name = "Willow"
	add_child(cat)
	cat.global_position = Vector3(2.5, 0.1, -6.2)
	cat.rotation.y = PI # face into the yard (+Z); model forward is -Z
	cat.paw_swiped.connect(_on_paw_swiped)
	_build_camera()
	_build_hud()
	_touch = TouchScene.new()
	add_child(_touch)
	_touch.strike_pressed.connect(attempt_strike)
	_spawn_mice()


# --- materials / boxes (wildlife.gd idiom, shadows on for a diorama) --------

func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _static_box(parent: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


# --- world -------------------------------------------------------------------

func _build_environment() -> void:
	var env := Node3D.new()
	env.name = "Yard"
	add_child(env)
	var grass := Color(0.32, 0.5, 0.22)
	var grass2 := Color(0.28, 0.45, 0.19)
	var grass3 := Color(0.37, 0.55, 0.25)
	var wood := Color(0.55, 0.42, 0.3)
	var wood_dark := Color(0.42, 0.31, 0.21)
	_box(env, Vector3(26.4, 0.2, 20.4), Vector3(0, -0.1, 0), grass)
	# Mown patches, a whisper above the lawn to avoid z-fighting.
	var patches := [grass2, grass3, grass2, grass3, grass2, grass3]
	var spots := [Vector2(-8, -3), Vector2(6, 1), Vector2(-2, 6), Vector2(9, -6), Vector2(-10, 5), Vector2(1, -1)]
	for i in spots.size():
		_box(env, Vector3(4.5, 0.012, 3.6), Vector3(spots[i].x, 0.006 + i * 0.0012, spots[i].y), patches[i])
	# Fence: posts + two rails on the south, east and west edges.
	for side: int in [-1, 1]:
		var x := 13.0 * side
		for zi in range(-10, 11, 2):
			_box(env, Vector3(0.14, 1.15, 0.14), Vector3(x, 0.57, float(zi)), wood_dark)
		_box(env, Vector3(0.06, 0.12, 20.4), Vector3(x, 0.85, 0), wood)
		_box(env, Vector3(0.06, 0.12, 20.4), Vector3(x, 0.4, 0), wood)
	for zi in range(-12, 13, 2):
		_box(env, Vector3(0.14, 1.15, 0.14), Vector3(float(zi), 0.57, 10.0), wood_dark)
	_box(env, Vector3(26.4, 0.12, 0.06), Vector3(0, 0.85, 10.0), wood)
	_box(env, Vector3(26.4, 0.12, 0.06), Vector3(0, 0.4, 10.0), wood)
	# House along the north edge: wall, roof lip, door, windows, porch.
	var siding := Color(0.74, 0.71, 0.65)
	var trim := Color(0.92, 0.9, 0.85)
	_box(env, Vector3(17.0, 3.4, 0.4), Vector3(0, 1.7, -10.2), siding)
	_box(env, Vector3(17.6, 0.22, 2.4), Vector3(0, 3.55, -10.5), Color(0.3, 0.26, 0.24), Vector3(0.16, 0, 0))
	_box(env, Vector3(6.4, 0.24, 2.6), Vector3(2.5, 0.12, -8.7), wood) # porch deck
	_box(env, Vector3(1.05, 2.1, 0.12), Vector3(2.5, 1.29, -9.96), Color(0.36, 0.2, 0.12)) # door
	_box(env, Vector3(0.09, 0.09, 0.09), Vector3(2.05, 1.29, -9.88), Color(0.8, 0.7, 0.3)) # knob
	for wx: float in [-4.5, 6.5]:
		_box(env, Vector3(1.5, 1.1, 0.1), Vector3(wx, 1.9, -9.97), trim)
		_box(env, Vector3(1.3, 0.9, 0.12), Vector3(wx, 1.9, -9.97), Color(0.62, 0.74, 0.82))
	# Tree, crates, and the garden chair (the lounge throne).
	_box(env, Vector3(0.4, 2.6, 0.4), Vector3(-8.5, 1.3, -5.0), Color(0.4, 0.3, 0.2))
	_box(env, Vector3(2.6, 1.8, 2.6), Vector3(-8.5, 3.3, -5.0), Color(0.25, 0.45, 0.18), Vector3(0.1, 0.4, 0.05))
	_box(env, Vector3(1.9, 1.4, 1.9), Vector3(-8.2, 4.3, -4.6), Color(0.3, 0.52, 0.2), Vector3(-0.06, 0.9, 0.12))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(9.5, 0.36, -6.0), Color(0.6, 0.48, 0.32))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(10.3, 0.36, -6.1), Color(0.57, 0.45, 0.3))
	_box(env, Vector3(0.72, 0.72, 0.72), Vector3(9.9, 1.08, -6.05), Color(0.63, 0.5, 0.34))
	var chair := Color(0.7, 0.68, 0.62)
	_box(env, Vector3(0.66, 0.06, 0.58), CHAIR_SEAT + Vector3(0, -0.03, 0), chair, Vector3(-0.08, 0.5, 0))
	_box(env, Vector3(0.66, 0.8, 0.06), CHAIR_SEAT + Vector3(-0.19, 0.36, -0.24), chair, Vector3(-0.3, 0.5, 0))
	for sx: float in [-0.26, 0.26]:
		for sz: float in [-0.22, 0.22]:
			_box(env, Vector3(0.07, 0.46, 0.07), CHAIR_SEAT + Vector3(sx * 0.9, -0.26, sz), chair, Vector3(0, 0.5, 0))
	# Collision: perimeter, house, porch, tree, crates, chair.
	var statics := StaticBody3D.new()
	statics.name = "Statics"
	add_child(statics)
	_static_box(statics, Vector3(17.0, 3.4, 1.0), Vector3(0, 1.7, -10.2))
	_static_box(statics, Vector3(26.4, 1.3, 0.6), Vector3(0, 0.65, 10.2))
	_static_box(statics, Vector3(0.6, 1.3, 20.4), Vector3(13.2, 0.65, 0))
	_static_box(statics, Vector3(0.6, 1.3, 20.4), Vector3(-13.2, 0.65, 0))
	_static_box(statics, Vector3(6.4, 0.24, 2.6), Vector3(2.5, 0.12, -8.7))
	_static_box(statics, Vector3(0.5, 2.6, 0.5), Vector3(-8.5, 1.3, -5.0))
	_static_box(statics, Vector3(2.4, 1.5, 1.2), Vector3(9.9, 0.75, -6.05))
	_static_box(statics, Vector3(0.7, 0.46, 0.7), CHAIR_SEAT + Vector3(0, -0.23, 0))


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.25, 0.46, 0.75)
	psm.sky_horizon_color = Color(0.72, 0.8, 0.88)
	psm.ground_bottom_color = Color(0.2, 0.24, 0.18)
	psm.ground_horizon_color = Color(0.72, 0.8, 0.88)
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.fog_enabled = true
	e.fog_light_color = Color(0.78, 0.84, 0.9)
	e.fog_density = 0.012
	we.environment = e
	add_child(we)


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CamRig"
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = cam_dist
	_arm.margin = 0.25
	_rig.add_child(_arm)
	var cam := Camera3D.new()
	cam.fov = 55.0
	_arm.add_child(cam)
	_rig.global_position = cat.global_position + Vector3(0, 0.3, 0)
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_lbl_left = _hud_label(layer, "Mice Left: %d" % MOUSE_COUNT, Vector2(18, 12))
	_lbl_caught = _hud_label(layer, "Caught: 0", Vector2(18, 48))
	_lbl_time = _hud_label(layer, "Time: 0.0", Vector2(18, 84))
	var restart := Button.new()
	restart.text = "RESTART"
	restart.add_theme_font_size_override("font_size", 22)
	restart.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	restart.offset_left = -150
	restart.offset_right = -18
	restart.offset_top = 12
	restart.offset_bottom = 58
	restart.pressed.connect(restart_game)
	layer.add_child(restart)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	_banner.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 120
	_banner.offset_bottom = 220
	_banner.visible = false
	layer.add_child(_banner)


func _hud_label(parent: Node, text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


# --- game --------------------------------------------------------------------

func _spawn_mice() -> void:
	for i in MOUSE_COUNT:
		var m: PvKMouse = MouseScene.new()
		m.name = "Mouse%d" % (i + 1)
		add_child(m)
		var pos := Vector3(_rng.randf_range(-10.0, 11.0), 0, _rng.randf_range(-6.0, 8.5))
		m.global_position = pos
		m.home = pos
		m.bounds = YARD
		m.cat = cat
		m.rotation.y = _rng.randf() * TAU
		m.was_caught.connect(_on_mouse_caught)
		mice.append(m)


func attempt_strike() -> void:
	if not won:
		cat.strike()


func _on_paw_swiped() -> void:
	var pp := cat.paw_point()
	for m: Variant in mice:
		var mouse := m as PvKMouse
		if mouse.state == "caught":
			continue
		var d := Vector2(mouse.global_position.x - pp.x, mouse.global_position.z - pp.z).length()
		if d <= 0.42:
			mouse.get_caught()


func _on_mouse_caught(_m: PvKMouse) -> void:
	caught_count += 1
	if caught_count >= MOUSE_COUNT and not won:
		won = true
		_banner.text = "All mice caught in %.1f s!\nWillow approves. Press R to play again." % elapsed
		_banner.visible = true
		cat.set_lounge(true) # victory flop, Willow style


func restart_game() -> void:
	get_tree().reload_current_scene()


func mice_left() -> int:
	return MOUSE_COUNT - caught_count


# --- input + loop ------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var dir := Vector3.ZERO
	var sprint := false
	var stalk := false
	if bool(input_override["active"]):
		var mv: Vector2 = input_override["move"]
		dir = _cam_relative(mv)
		sprint = bool(input_override["sprint"])
		stalk = bool(input_override["stalk"])
	else:
		var ix := 0.0
		var iz := 0.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			ix -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			ix += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			iz += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			iz -= 1.0
		var stick := _touch.move_vector()
		if stick.length() > 0.12:
			ix = stick.x
			iz = -stick.y
		dir = _cam_relative(Vector2(ix, iz))
		sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		stalk = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	cat.set_move_input(dir, sprint, stalk)


func _cam_relative(mv: Vector2) -> Vector3:
	if mv.length() < 0.05:
		return Vector3.ZERO
	var b := _rig.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	var d := right * mv.x + fwd * mv.y
	if d.length() > 1.0:
		d = d.normalized()
	return d


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_SPACE:
					attempt_strike()
				KEY_L:
					cat.toggle_lounge()
				KEY_R:
					restart_game()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.5, 2.2, 9.0)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.5, 2.2, 9.0)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.005
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.004, -1.15, -0.08)


func _process(delta: float) -> void:
	if not won:
		elapsed += delta
	var target := cat.global_position + Vector3(0, 0.3, 0)
	_rig.global_position = _rig.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch
	_arm.spring_length = cam_dist
	_lbl_left.text = "Mice Left: %d" % mice_left()
	_lbl_caught.text = "Caught: %d" % caught_count
	_lbl_time.text = "Time: %.1f" % elapsed
