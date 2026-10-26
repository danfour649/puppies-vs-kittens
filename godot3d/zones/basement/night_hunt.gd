class_name NightHunt
extends Node3D
## One night in the basement. A seeded hoarder maze, the shared
## creature brain, and a gift for Glenys at the stairs.
##
## Clear start (the title card), a clear goal (three mice), a clear
## end (she is pleased). The full house — yard, ground floor, attic —
## is a different scene and is not touched by this one.


const CatScript := preload("res://cat_kit/cat.gd")
const MouseScript := preload("res://zones/basement/basement_mouse.gd")
const BirdScript := preload("res://zones/basement/songbird.gd")
const OtherScript := preload("res://zones/basement/other_cat.gd")
const MothScript := preload("res://zones/basement/moth.gd")
const SpiderScript := preload("res://zones/basement/cellar_spider.gd")
const TouchScript := preload("res://touch_controls_3d.gd")

const GOAL := 3
const CATCH_RADIUS := 0.72

@export var seed_value := 0 ## 0 = pick one at random
@export var autostart := false
@export var shot_path := ""
@export var shot_frames := 40

var phase := "title" ## title, play, gift, end
var level: Dictionary = {}
var level_seed := 0
var cat: PvKCat
var glenys_pos := Vector3.ZERO
var caught := 0
var carrying_gift := false
var mice: Array = []
var birds: Array = []
var moths: Array = []
var cellar_spider: CellarSpider
var other: OtherCat
var ledger := NightLoop.new()
var scent := CatScentMap.new()
var elapsed := 0.0

var _static: StaticBody3D
var _mats := {}
var _pending_sounds: Array = []
var _live_sounds: Array = []
var _window := Vector3.ZERO
var _rig: Node3D
var _arm: SpringArm3D
var cam_yaw := PI
var cam_pitch := -0.62
var cam_dist := 5.4
var _dragging := false
var _touch: TouchControls3D
var _ui: CanvasLayer
var _title: Control
var _end: Control
var _end_body: Label
var _hud: Label
var _banner: Label
var _goal: Label
var _shot_wait := 0
var _meow := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			shot_path = args[i + 1]
			shot_frames = 150
		elif args[i] == "--seed" and i + 1 < args.size():
			seed_value = int(args[i + 1])
	_build_ui()
	if shot_path != "" or autostart:
		_begin()
	else:
		_show_title()


var _built := false


func _begin() -> void:
	if _built:
		return
	_built = true
	phase = "play"
	ledger.setup()
	if _title != null:
		_title.visible = false
	_generate()
	_build_world()
	_spawn_cast()
	_build_camera()
	if _touch == null:
		_touch = TouchScript.new()
		add_child(_touch)
		_touch.strike_pressed.connect(func() -> void: if cat != null: cat.strike())
		_touch.pounce_pressed.connect(_jump_or_pounce)


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	level_seed = seed_value if seed_value != 0 else rng.randi_range(1, 999983)
	level = HoarderGenerator.generate(level_seed)
	var guard := 0
	while not bool(HoarderGenerator.playable(level, true)["ok"]) and guard < 6:
		guard += 1
		level_seed += 1
		level = HoarderGenerator.generate(level_seed)


func _build_world() -> void:
	_static = StaticBody3D.new()
	_static.name = "Solids"
	add_child(_static)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.18, 0.16, 0.2)
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.1, 0.09)
	e.fog_density = 0.04
	VisualQuality.apply_environment(e, "basement")
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 20, 0)
	moon.light_color = Color(0.55, 0.62, 0.8)
	moon.light_energy = 0.15
	moon.shadow_enabled = false
	add_child(moon)
	VisualQuality.add_dust_shaft(self, Vector3(0.2, 2.4, 4.6), -62.0, 8.0)
	# The whole floor, then the things Glenys kept, stacked into walls.
	_solid(Vector3(18, 0.4, 14), Vector3(0, -0.2, 0), Color(0.28, 0.26, 0.24))
	_border()
	var map: Array = level["map"]
	var gap: Vector2i = level["gap_cell"]
	var gap_dir: Vector2i = level["gap_dir"]
	var stack_h := {}
	for s: Variant in level["stacks"]:
		var sd: Dictionary = s
		var cell: Vector2i = sd["cell"]
		stack_h[cell] = float(sd["height"])
	for r in map.size():
		var row := String(map[r])
		for c in row.length():
			var ch := row.substr(c, 1)
			var center := HoarderGenerator.cell_center(c, r)
			if ch == "T":
				_mesh(Vector3(0.92, 0.04, 0.92), center + Vector3(0, 0.02, 0), Color(0.16, 0.14, 0.13))
				_mesh(Vector3(0.18, 0.08, 0.9), center + Vector3(0, 1.05, 0), Color(0.35, 0.32, 0.28))
			elif ch == "H":
				_mesh(Vector3(0.96, 0.03, 0.96), center + Vector3(0, 0.02, 0), Color(0.34, 0.22, 0.16))
			if ch == "#":
				var h := float(stack_h.get(Vector2i(c, r), 1.05))
				var tint := Color(0.62, 0.48, 0.32).lerp(Color(0.45, 0.32, 0.22), randf_from_seed(c * 17 + r))
				_solid(Vector3(0.98, h, 0.98), center + Vector3(0, h * 0.5, 0), tint)
			elif ch == "G":
				_gap_blocks(center, gap_dir)
	# A step up the side of each tall stack — the vertical route.
	for route: Variant in level["vertical_routes"]:
		var rd: Dictionary = route
		var floor_cell: Vector2i = rd["floor_cell"]
		var base := HoarderGenerator.cell_center(floor_cell.x, floor_cell.y)
		_solid(Vector3(0.42, 0.42, 0.42), base + Vector3(0, 0.21, 0), Color(0.5, 0.38, 0.26))
	for item: Variant in level["items"]:
		var it: Dictionary = item
		var decade := int(it["decade"])
		var k := clampf(float(decade - 1960) / 50.0, 0.0, 1.0)
		var col := Color(0.40, 0.28, 0.18).lerp(Color(0.72, 0.58, 0.40), k)
		var pos: Vector3 = it["pos"]
		_mesh(Vector3(0.28, 0.16, 0.22), pos, col)
		if decade == 1960 or decade == 1980 or decade == 2010:
			var lab := Label3D.new()
			lab.text = String(it["name"])
			lab.font_size = 28
			lab.pixel_size = 0.0035
			lab.position = pos + Vector3(0, 0.22, 0)
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.modulate = Color(0.96, 0.93, 0.86)
			lab.outline_size = 6
			add_child(lab)
	var entry: Vector2i = level["entry_cell"]
	var entry_pos := HoarderGenerator.cell_center(entry.x, entry.y)
	_window = entry_pos + Vector3(0, 1.55, 0.4)
	_omni(_window, Color(0.85, 0.9, 1.0), 2.4, 7.0)
	var heart: Vector2i = level["heart_cell"]
	_omni(HoarderGenerator.cell_center(heart.x, heart.y) + Vector3(0, 1.7, 0), Color(1.0, 0.78, 0.5), 1.3, 6.0)
	_omni(entry_pos + Vector3(-2.0, 1.6, -2.0), Color(1.0, 0.72, 0.45), 0.9, 5.0)
	# Stairs, and Glenys at the bottom of them. She is waiting, not chasing.
	glenys_pos = entry_pos + Vector3(0.0, 0.0, 0.35)
	_stairs(entry_pos)
	_glenys(glenys_pos)
	scent.setup(Vector2(-8, -6), Vector2(16, 12), 0.5)


func _spawn_cast() -> void:
	var entry: Vector2i = level["entry_cell"]
	var heart: Vector2i = level["heart_cell"]
	var path: Array = HoarderGenerator.bfs(level, entry, heart, true)
	var spawn_cell: Vector2i = path[mini(4, path.size() - 1)] if not path.is_empty() else entry
	cat = CatScript.new()
	cat.set_character("willie")
	cat.name = "Willie"
	add_child(cat)
	cat.global_position = HoarderGenerator.cell_center(spawn_cell.x, spawn_cell.y) + Vector3(0, 0.08, 0)
	cat.rotation.y = PI
	cat.paw_swiped.connect(_on_paw)
	var anchors: Array = []
	var shut := HoarderGenerator.reachable_from(level, entry, true)
	for item: Variant in level["items"]:
		var it: Dictionary = item
		var cell: Vector2i = it["cell"]
		if shut.has(cell):
			anchors.append(HoarderGenerator.cell_center(cell.x, cell.y))
	var spots: Array[Vector2i] = []
	for n: Variant in level["nests"]:
		spots.append(n)
	var open_main: Array[Vector2i] = []
	for key: Variant in shut.keys():
		open_main.append(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	while spots.size() < 5 and not open_main.is_empty():
		spots.append(open_main[rng.randi() % open_main.size()])
	for i in mini(5, spots.size()):
		var cell: Vector2i = spots[i]
		var m := MouseScript.new()
		m.name = "Mouse%d" % i
		add_child(m)
		var pos := HoarderGenerator.cell_center(cell.x, cell.y) + Vector3(0, 0.02, 0)
		m.global_position = pos
		m.home = pos
		m.cat = cat
		m.scent_map = scent
		m.configure_maze(level, anchors)
		m.was_caught.connect(_on_mouse_caught)
		mice.append(m)
	for i in 3:
		var b := BirdScript.new()
		b.name = "Songbird%d" % i
		add_child(b)
		b.global_position = _window + Vector3(rng.randf_range(-0.8, 0.8), -0.9, rng.randf_range(-0.4, 0.5))
		b.cat = cat
		b.indoor = true
		b.windows = [_window]
		b.lights = [_window]
		b.flock = birds
		birds.append(b)
	for b: Variant in birds:
		(b as Songbird).flock = birds
	var heart_lamp := HoarderGenerator.cell_center(heart.x, heart.y) + Vector3(0, 1.6, 0)
	var lamps: Array[Vector3] = [_window, heart_lamp]
	for i in 4:
		var moth := MothScript.new()
		moth.name = "Moth%d" % i
		add_child(moth)
		moth.lamp = lamps[i % lamps.size()]
		moth.cat = cat
		moth.global_position = moth.lamp + Vector3(0.15 * float(i - 1), -0.25, 0.1 * float(i))
		moths.append(moth)
	cellar_spider = SpiderScript.new()
	cellar_spider.name = "CellarSpider"
	cellar_spider.anchor = heart_lamp + Vector3(0.85, 0.15, 0.2)
	cellar_spider.cat = cat
	add_child(cellar_spider)
	var perches: Array = []
	for route: Variant in level["vertical_routes"]:
		perches.append((route as Dictionary)["perch"])
	other = OtherScript.new()
	other.name = "OtherCat"
	add_child(other)
	var perch: Vector3 = perches[0] if not perches.is_empty() else cat.global_position + Vector3(0, 1.2, 0)
	for p: Variant in perches:
		var pp: Vector3 = p
		if pp.y > perch.y:
			perch = pp
	other.perches = perches
	other.hour = 19.0
	other.rival = cat
	other.quarry = mice
	other.territory = HoarderGenerator.cell_center(heart.x, heart.y)
	other.territory_radius = 5.5
	other._pos = Vector3(perch.x, perch.y, perch.z)
	if other.body != null:
		other.body.global_position = other._pos


func _process(delta: float) -> void:
	if phase == "play" or phase == "gift":
		elapsed += delta
		scent.decay(delta)
		scent.age_novels(delta)
		if cat != null:
			var gait := _willie_gait()
			var foot := CatNoise.footstep(cat.global_position, gait)
			if not foot.is_empty():
				_pending_sounds.append(foot)
			scent.deposit(cat.global_position, CatNoise.scent_rate(gait) * delta)
			ledger.note_noise(gait, delta)
			ledger.settle(delta, gait)
		if _meow and cat != null:
			_pending_sounds.append(CatNoise.meow(cat.global_position))
			cat.set_meta("meow_until_msec", Time.get_ticks_msec() + 650)
			if cat.has_method("play_meow"):
				cat.play_meow()
			ledger.note_noise("meow", 1.0)
			_meow = false
		_live_sounds = _pending_sounds.duplicate()
		_pending_sounds.clear()
		for m: Variant in mice:
			if is_instance_valid(m):
				(m as BasementMouse).heard_sounds = _live_sounds
		for b: Variant in birds:
			if is_instance_valid(b):
				(b as Songbird).sounds = _live_sounds
				(b as Songbird).sound_sink = _pending_sounds
		for moth: Variant in moths:
			if is_instance_valid(moth):
				(moth as CellarMoth).sounds = _live_sounds
		if phase == "play" and caught >= GOAL:
			phase = "gift"
			carrying_gift = true
		if phase == "gift" and cat != null and Vector2(cat.global_position.x - glenys_pos.x, cat.global_position.z - glenys_pos.z).length() < 1.15:
			_finish()
	_update_hud()
	_update_camera(delta)
	if shot_path != "" and phase == "play":
		_shot_wait += 1
		if _shot_wait == shot_frames:
			call_deferred("_save_shot")


func _physics_process(_delta: float) -> void:
	if cat == null or phase == "title" or phase == "end":
		if cat != null:
			cat.set_move_input(Vector3.ZERO, false, false)
		return
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
	if _touch != null:
		var stick := _touch.move_vector()
		if stick.length() > 0.12:
			ix = stick.x
			iz = -stick.y
	var dir := _cam_relative(Vector2(ix, iz))
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var stalk := Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C)
	cat.set_move_input(dir, sprint, stalk)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_ENTER, KEY_SPACE:
				if phase == "title":
					_begin()
				elif k.keycode == KEY_SPACE and phase != "end":
					_jump_or_pounce()
			KEY_F:
				if cat != null and phase != "title" and phase != "end":
					cat.strike()
			KEY_M:
				_meow = true
			KEY_R:
				get_tree().reload_current_scene()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if phase == "title":
			return
		if b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.4, 2.4, 9.0)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.4, 2.4, 9.0)
	elif event is InputEventMouseMotion and _dragging and _rig != null:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.005
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.004, -1.2, -0.15)


func debug_force_gift() -> void:
	caught = GOAL
	carrying_gift = true
	phase = "gift"


func _on_paw() -> void:
	if cat == null or (phase != "play" and phase != "gift"):
		return
	var pp := cat.paw_point()
	for m: Variant in mice:
		if not is_instance_valid(m):
			continue
		var mouse := m as BasementMouse
		if mouse.state == "caught":
			continue
		var d := Vector2(mouse.global_position.x - pp.x, mouse.global_position.z - pp.z).length()
		if d <= CATCH_RADIUS:
			mouse.get_caught()


func _on_mouse_caught(_m: PvKMouse) -> void:
	caught += 1
	ledger.note_catch(elapsed, _willie_gait() == "stalk")
	if caught >= GOAL and phase == "play":
		phase = "gift"
		carrying_gift = true


func _finish() -> void:
	phase = "end"
	carrying_gift = false
	var gift := ledger.deliver_gift()
	if _end_body != null:
		_end_body.text = (
			String(gift["line"])
			+ "\n\nScore %d. The house was %s.\n\nThe night is over. Press R to hunt again."
			% [int(gift["score"]), String(gift["mess_word"])]
		)
	if cat != null:
		cat.set_move_input(Vector3.ZERO, false, false)
		cat.set_lounge(true)
	if _end != null:
		_end.visible = true


func _jump_or_pounce() -> void:
	if cat == null or phase == "title" or phase == "end":
		return
	if cat.is_on_floor():
		cat.jump()
	else:
		cat.pounce()


func _willie_gait() -> String:
	if cat == null:
		return "idle"
	if cat.is_pouncing():
		return "pounce"
	var moving := cat.anim_state in ["walk", "stalk", "sprint"]
	return CatNoise.gait_of(moving, cat.anim_state == "sprint", cat.anim_state == "stalk", false)


# --- presentation -----------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_title = _panel()
	var title := _label(_title, "Willie and Aggie", 42)
	title.position = Vector2(0, 36)
	title.size = Vector2(760, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(_title, "One night in the basement", 26)
	sub.position = Vector2(0, 96)
	sub.size = Vector2(760, 36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := _label(_title,
		"The house is asleep. Downstairs, Glenys kept the years:\n" +
		"notes tied with string, the yellow teapot, a school jumper folded.\n" +
		"The mice know every narrow path through it.\n\n" +
		"Catch three. Bring one to Glenys, at the stairs.\n" +
		"She would like the thought.", 20)
	body.position = Vector2(48, 150)
	body.size = Vector2(664, 180)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var how := _label(_title, "WASD move    Shift sprint (loud)    Ctrl stalk (quiet)    F paw\nSpace jump    M meow    Right-drag looks    R starts the night over", 16)
	how.position = Vector2(48, 340)
	how.size = Vector2(664, 56)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var begin := Button.new()
	begin.text = "Begin the night"
	begin.position = Vector2(270, 420)
	begin.size = Vector2(220, 48)
	begin.pressed.connect(_begin)
	_title.add_child(begin)
	_hud = _label(_ui, "", 20)
	_hud.position = Vector2(16, 12)
	_goal = _label(_ui, "", 18)
	_goal.position = Vector2(16, 40)
	_banner = _label(_ui, "", 22)
	_banner.position = Vector2(200, 78)
	_banner.size = Vector2(720, 64)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end = _panel()
	_end.visible = false
	var end_title := _label(_end, "For me?", 40)
	end_title.position = Vector2(0, 48)
	end_title.size = Vector2(760, 52)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body = _label(_end,
		"Glenys takes it the way you take a gift from someone you love.\n" +
		"A little laugh, a hand on the stair rail.\n" +
		"\"You dreadful, perfect boy.\"\n\n" +
		"The night is over. Press R to hunt again.", 20)
	_end_body.position = Vector2(40, 140)
	_end_body.size = Vector2(680, 220)
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _show_title() -> void:
	phase = "title"
	if _title != null:
		_title.visible = true
	if _goal != null:
		_goal.text = ""
	if _hud != null:
		_hud.text = ""


func _update_hud() -> void:
	if _hud == null or phase == "title":
		return
	var combo_bit := ""
	if ledger.combo > 1:
		combo_bit = "    combo x%d" % ledger.combo
	_hud.text = "Night seed %d    %s    score %d    house: %s%s" % [level_seed, _clock(), ledger.score, ledger.mess_word(), combo_bit]
	if phase == "end":
		_goal.text = ""
		_banner.text = ""
		return
	if phase == "gift":
		_goal.text = "The gift is yours. Take it to Glenys, at the light on the stairs.  " + _goal_ticks()
		_banner.text = "She is waiting."
	else:
		_goal.text = "Mice for Glenys: %d / %d    %s" % [mini(caught, GOAL), GOAL, _goal_ticks()]
		if other != null and other.boast != "":
			_banner.text = other.boast
		elif cellar_spider != null and cellar_spider.line != "":
			_banner.text = cellar_spider.line
		else:
			_banner.text = "Stalk, and they only mind you if they see you. A sprint or a meow carries."


func _goal_ticks() -> String:
	if ledger.objectives.is_empty():
		return ""
	var bits: PackedStringArray = PackedStringArray()
	for o: Variant in ledger.objectives:
		var d: Dictionary = o
		var mark := "x" if bool(d.get("done", false)) else " "
		bits.append("[%s] %s" % [mark, String(d.get("title", ""))])
	return "  ".join(bits)


func _clock() -> String:
	var mins := int(elapsed / 60.0)
	var secs := int(elapsed) % 60
	return "%d:%02d" % [mins, secs]


func _update_camera(delta: float) -> void:
	if _rig == null or cat == null:
		return
	var target := cat.global_position + Vector3(0, 0.35, 0)
	_rig.global_position = _rig.global_position.lerp(target, 1.0 - exp(-8.0 * delta))
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch
	_arm.spring_length = cam_dist


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.name = "CamRig"
	add_child(_rig)
	_arm = SpringArm3D.new()
	_arm.spring_length = cam_dist
	_arm.margin = 0.2
	_rig.add_child(_arm)
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 58.0
	_arm.add_child(cam)
	if cat != null:
		_rig.global_position = cat.global_position + Vector3(0, 0.4, 0)
	_rig.rotation.y = cam_yaw
	_arm.rotation.x = cam_pitch


func _save_shot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(shot_path)
	get_tree().quit()


func _cam_relative(mv: Vector2) -> Vector3:
	if _rig == null or mv.length() < 0.05:
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


func _panel() -> Control:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -260)
	panel.size = Vector2(760, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.09, 0.92)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	return panel


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	parent.add_child(l)
	return l


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.92
		_mats[key] = m
	return _mats[key]


func _mesh(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)


func _solid(size: Vector3, pos: Vector3, color: Color) -> void:
	_mesh(size, pos, color)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	_static.add_child(shape)


func _border() -> void:
	var h := 1.3
	var col := Color(0.33, 0.3, 0.28)
	_solid(Vector3(18, h, 0.3), Vector3(0, h * 0.5, -7.1), col)
	_solid(Vector3(18, h, 0.3), Vector3(0, h * 0.5, 7.1), col)
	_solid(Vector3(0.3, h, 14), Vector3(-8.1, h * 0.5, 0), col)
	_solid(Vector3(0.3, h, 14), Vector3(8.1, h * 0.5, 0), col)


func _gap_blocks(center: Vector3, dir: Vector2i) -> void:
	var along_x := absi(dir.x) == 1
	var gap_w := 0.13
	var side := (1.0 - gap_w) * 0.5
	var offset := gap_w * 0.5 + side * 0.5
	for sign: float in [-1.0, 1.0]:
		if along_x:
			_solid(Vector3(1.0, 1.15, side), center + Vector3(0, 0.575, sign * offset), Color(0.55, 0.4, 0.28))
		else:
			_solid(Vector3(side, 1.15, 1.0), center + Vector3(sign * offset, 0.575, 0), Color(0.55, 0.4, 0.28))


func _omni(pos: Vector3, color: Color, energy: float, omni_range: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = omni_range
	light.shadow_enabled = false
	add_child(light)
	_mesh(Vector3(0.12, 0.16, 0.12), pos, Color(1.0, 0.92, 0.7))


func _stairs(entry_pos: Vector3) -> void:
	for i in 3:
		var h := 0.16 + float(i) * 0.16
		_solid(Vector3(1.1, h, 0.38), entry_pos + Vector3(0, h * 0.5, 0.7 + float(i) * 0.36), Color(0.4, 0.38, 0.36))


func _glenys(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Glenys"
	root.position = pos
	add_child(root)
	_person_box(root, Vector3(0.38, 0.7, 0.28), Vector3(0, 0.72, 0), Color(0.45, 0.2, 0.28))
	_person_box(root, Vector3(0.22, 0.22, 0.22), Vector3(0, 1.18, 0), Color(0.9, 0.82, 0.74))
	_person_box(root, Vector3(0.24, 0.08, 0.24), Vector3(0, 1.32, 0), Color(0.75, 0.75, 0.78))
	_person_box(root, Vector3(0.06, 0.7, 0.06), Vector3(0.22, 0.4, 0.1), Color(0.35, 0.24, 0.14))
	var name := Label3D.new()
	name.text = "Glenys"
	name.font_size = 48
	name.pixel_size = 0.004
	name.position = Vector3(0, 1.6, 0)
	name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name.modulate = Color(1, 0.95, 0.85)
	root.add_child(name)


func _person_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)


func randf_from_seed(n: int) -> float:
	var x := int(n * 1103515245 + 12345) & 0x7fffffff
	return float(x % 1000) / 1000.0
