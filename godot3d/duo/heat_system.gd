class_name HeatSystem
extends Node
## DUO — Aggie's heat cycle (Daniel's spec, 2026-10-24 22:43).
##
## Aggie goes into heat FREQUENTLY: ~30–60 s stretches in which she
## hunts Willie down wherever he is and solicits — rolling,
## presenting, tail aside, and a loud synth YOWL. Willie is
## NEUTERED. His responses are pure comedy: a blank stare, pointed
## self-grooming, wandering off to knock a drink over, and the
## occasional half-hearted mount attempt that goes nowhere.
## NO KITTENS, EVER — the game states that punchline in a popup.
##
## - Aggie is the NPC: SiblingAI heat modes (seek / solicit) run her.
## - Aggie is the player: an urge meter + "Find Willie" objective,
##   plus occasional involuntary roll-and-yowl interrupts.
## - Willie is the player: her pursuit is a hazard to dodge.
##
## Dignity rules: heat never starts, and its behaviours pause,
## while the provocation system is mid-flurry/buff, while a cat is
## fainted, while the player cat is on an occupant's lap (or held —
## the "caught" meta is the forward-compatible seam for a certain
## cane-wielding grabber), or while the character select is up.
## Cartoonish throughout — comedy in behaviour, never anatomy.

const OFF_MIN := 16.0
const OFF_MAX := 30.0
const HEAT_MIN := 30.0
const HEAT_MAX := 60.0
const POST_TIME := 5.0
const YOWL_MIN := 3.5
const YOWL_MAX := 6.5
const RESPONSE_GAP_MIN := 2.0
const RESPONSE_GAP_MAX := 4.5
const RESPONSE_NEAR := 3.2 # Willie performs only when she's close
const RESPONSE_WATCHDOG := 10.0
const INTERRUPT_MIN := 8.0
const INTERRUPT_MAX := 14.0
const INTERRUPT_TIME := 0.9
const URGE_FULL_DIST := 10.0
const PUNCHLINE := "He's neutered. There will be NO kittens."
## Willie's water bowl, on the ground by the porch — his to knock.
const BOWL_POS := Vector3(3.4, 0.0, -7.6)
const BOWL_STAND := Vector3(3.4, 0.0, -6.95)

## state: off | heat | post
var state := "off"
var heat_time_left := 0.0
var cycle_time_left := 20.0
## Player-Aggie: 0..100, climbs during heat (faster far from Willie).
var urge := 0.0
## Test seam: every yowl Aggie makes lands here.
var yowl_count := 0
## How many times Willie has tried the half-hearted mount.
var mount_attempts := 0
## The punchline popup has been shown (once per session is enough —
## the joke lands, then it's just his life).
var punchline_shown := false
## Test seam: Willie's performed responses, in order.
var response_log: Array = []
## The drink Willie's knock response tips over.
var bowl_tipped := false

var duo: Node = null # DuoSystem (untyped: no cyclic class refs)
var aggie: PvKCat = null
var willie: PvKCat = null

var _rng := RandomNumberGenerator.new()
var _response_t := 0.0
var _watch_t := 0.0
var _yowl_t := 0.0
var _interrupt_t := 0.0
var _interrupt_left := 0.0
var _suspended := false
var _bowl: Node3D = null
var _bowl_pivot: Node3D = null
var _splash: MeshInstance3D = null

var _hud_layer: CanvasLayer
var _heat_label: Label
var _heat_flash_t := 0.0
var _urge_bar: ProgressBar
var _urge_label: Label
var _objective_label: Label
var _popup_label: Label
var _popup_t := 0.0


func setup(d: Node, a: PvKCat, w: PvKCat) -> void:
	duo = d
	aggie = a
	willie = w
	_rng.randomize()
	cycle_time_left = _rng.randf_range(OFF_MIN, OFF_MAX)
	_build_bowl()
	_build_hud()


func heat_active() -> bool:
	return state == "heat"


func aggie_is_npc() -> bool:
	return duo != null and duo.player_cat == willie


func willie_is_npc() -> bool:
	return duo != null and duo.player_cat == aggie


## Character-select role swap: drop back to a clean off state.
func reset() -> void:
	if _interrupt_left > 0.0:
		_end_interrupt()
	_release_sibling_heat()
	state = "off"
	heat_time_left = 0.0
	urge = 0.0
	cycle_time_left = _rng.randf_range(OFF_MIN, OFF_MAX)


## Test seam / debug: start a heat stretch right now.
func force_heat() -> void:
	if state != "heat":
		_begin_heat()


## Test seam / debug: end the current heat stretch.
func end_heat() -> void:
	if state == "heat":
		_finish_heat()


## Test seam: run one named Willie response right now
## ("stare" | "groom" | "knock" | "mount").
func force_response(kind: String) -> void:
	if state == "heat" and willie_is_npc():
		_perform_response(kind)


## Test seam: fire the player-Aggie roll-and-yowl interrupt now.
func force_interrupt() -> void:
	if state == "heat" and duo != null and duo.player_cat == aggie:
		_begin_interrupt()


# --- the cycle -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if duo == null or aggie == null or willie == null:
		return
	_heat_flash_t = maxf(_heat_flash_t - delta, 0.0)
	_popup_t = maxf(_popup_t - delta, 0.0)
	match state:
		"off":
			if _start_blocked():
				return
			cycle_time_left -= delta
			if cycle_time_left <= 0.0:
				_begin_heat()
		"heat":
			heat_time_left -= delta
			if heat_time_left <= 0.0:
				_finish_heat()
				return
			# The interrupt always counts down, blocked or not, so
			# the player's controls can never wedge.
			if _interrupt_left > 0.0:
				_interrupt_left -= delta
				if _interrupt_left <= 0.0:
					_end_interrupt()
			if _behaviours_blocked():
				if not _suspended:
					_suspended = true
					_release_sibling_heat()
				return
			if _suspended:
				_suspended = false
				_resume_heat()
			_run_heat(delta)
		"post":
			cycle_time_left -= delta
			if cycle_time_left <= 0.0:
				state = "off"
				cycle_time_left = _rng.randf_range(OFF_MIN, OFF_MAX)


func _begin_heat() -> void:
	state = "heat"
	heat_time_left = _rng.randf_range(HEAT_MIN, HEAT_MAX)
	urge = 0.0
	_response_t = 1.2
	_watch_t = 0.0
	_yowl_t = 0.6
	_interrupt_t = _rng.randf_range(INTERRUPT_MIN, INTERRUPT_MAX)
	_interrupt_left = 0.0
	_suspended = false
	_heat_flash_t = 2.2
	if aggie_is_npc():
		duo.sibling.begin_heat_seek()


func _finish_heat() -> void:
	state = "post"
	cycle_time_left = POST_TIME
	urge = 0.0
	if _interrupt_left > 0.0:
		_end_interrupt()
	_release_sibling_heat()
	_untip_bowl()


func _resume_heat() -> void:
	if aggie_is_npc():
		duo.sibling.begin_heat_seek()


func _release_sibling_heat() -> void:
	if duo != null and duo.sibling != null and duo.sibling.mode.begins_with("heat"):
		duo.sibling.end_heat()


# --- dignity gates ---------------------------------------------------------------

func _held(cat: PvKCat) -> bool:
	# "on_lap" is set by the occupants' lap sessions; "caught" is
	# the forward-compatible seam for a grabber's caught state.
	return bool(cat.get_meta("on_lap", false)) or bool(cat.get_meta("caught", false))


func _start_blocked() -> bool:
	if duo.input_locked():
		return true
	if duo.prov != null and duo.prov.state == "active":
		return true
	if aggie.is_fainted or willie.is_fainted:
		return true
	var pc: PvKCat = duo.player_cat
	if pc != null and _held(pc):
		return true
	return false


func _behaviours_blocked() -> bool:
	if _start_blocked():
		return true
	# The sibling being held mid-heat suspends her act too.
	var sib: PvKCat = duo.sibling_cat()
	if sib != null and _held(sib):
		return true
	return false


# --- heat behaviours ---------------------------------------------------------------

func _run_heat(delta: float) -> void:
	if aggie_is_npc():
		# She hunts the player (Willie) and solicits at him, yowling
		# as she goes. He dodges. That is the entire game for him.
		var sib: SiblingAI = duo.sibling
		if sib.mode == "heat_seek" or sib.mode == "heat_solicit":
			_yowl_t -= delta
			if _yowl_t <= 0.0:
				_yowl_t = _rng.randf_range(YOWL_MIN, YOWL_MAX)
				_yowl()
		elif not sib.mode.begins_with("heat"):
			sib.begin_heat_seek() # diverted (zone travel, a rebind) — back on him
	else:
		# Player is Aggie: the urge climbs (faster the farther she
		# is from Willie) and now and then her body just does the
		# roll-and-yowl thing. Brief. Mortifying. Never a lockout.
		var d := _flat(aggie.global_position, willie.global_position)
		urge = minf(urge + delta * lerpf(4.0, 11.0, clampf(d / URGE_FULL_DIST, 0.0, 1.0)), 100.0)
		if _interrupt_left <= 0.0:
			_interrupt_t -= delta
			if _interrupt_t <= 0.0:
				_begin_interrupt()
	if willie_is_npc():
		_run_willie_responses(delta)


func _run_willie_responses(delta: float) -> void:
	var sib: SiblingAI = duo.sibling
	if sib.heat_event == "knock":
		sib.heat_event = ""
		_tip_bowl()
	if sib.mode.begins_with("heat"):
		# A response is playing out; just watch the clock on it.
		_watch_t += delta
		if _watch_t > RESPONSE_WATCHDOG:
			_watch_t = 0.0
			_response_t = 1.0
			sib.cancel_heat_mode()
		return
	_watch_t = 0.0
	_response_t -= delta
	if _response_t > 0.0:
		return
	if _flat(aggie.global_position, willie.global_position) > RESPONSE_NEAR:
		_response_t = 0.5 # he performs for an audience of one; check again soon
		return
	_response_t = _rng.randf_range(RESPONSE_GAP_MIN, RESPONSE_GAP_MAX)
	_perform_response(_pick_response())


func _pick_response() -> String:
	var r := _rng.randf()
	if r < 0.30:
		return "stare"
	if r < 0.58:
		return "groom"
	if r < 0.84:
		return "knock"
	# The mount attempt stays occasional — and the first one ever
	# always makes the cut, because the popup has to land.
	if mount_attempts == 0 or _rng.randf() < 0.35:
		return "mount"
	return "stare"


func _perform_response(kind: String) -> void:
	var sib: SiblingAI = duo.sibling
	response_log.append(kind)
	match kind:
		"stare":
			sib.begin_heat_stare()
		"groom":
			sib.begin_heat_groom()
		"knock":
			sib.begin_heat_knock(BOWL_STAND)
		"mount":
			mount_attempts += 1
			sib.begin_heat_mount()
			if not punchline_shown:
				punchline_shown = true
				_show_popup(PUNCHLINE)


# --- the interrupt (player Aggie) ---------------------------------------------------

func _begin_interrupt() -> void:
	_interrupt_left = INTERRUPT_TIME
	_interrupt_t = _rng.randf_range(INTERRUPT_MIN, INTERRUPT_MAX)
	aggie.set_courtship(true)
	_yowl()
	var game: Node = duo.game
	if game != null:
		# A slow mortifying drift through main's input_override
		# seam while the pose does the rest.
		game.set("input_override", {"active": true, "move": Vector2(0.35, 0.0), "sprint": false, "stalk": false})


func _end_interrupt() -> void:
	_interrupt_left = 0.0
	aggie.set_courtship(false)
	var game: Node = duo.game
	if game != null:
		game.set("input_override", {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false})


# --- voice ---------------------------------------------------------------------------

func _yowl() -> void:
	yowl_count += 1
	duo.emit_yowl(aggie)


# --- the drink bowl --------------------------------------------------------------------

func _build_bowl() -> void:
	var game: Node = duo.get("game")
	if game == null:
		return
	_bowl = Node3D.new()
	_bowl.name = "DrinkBowl"
	_bowl.position = BOWL_POS
	game.add_child(_bowl)
	_bowl_pivot = Node3D.new()
	_bowl_pivot.name = "Pivot"
	_bowl_pivot.position = Vector3(0, 0.045, 0)
	_bowl.add_child(_bowl_pivot)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.55, 0.65)
	steel.metallic = 0.6
	steel.roughness = 0.35
	var bm := CylinderMesh.new()
	bm.top_radius = 0.17
	bm.bottom_radius = 0.12
	bm.height = 0.09
	bm.radial_segments = 20
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = bm
	bowl_mi.material_override = steel
	_bowl_pivot.add_child(bowl_mi)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.35, 0.62, 0.95, 0.85)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wm := CylinderMesh.new()
	wm.top_radius = 0.145
	wm.bottom_radius = 0.145
	wm.height = 0.012
	wm.radial_segments = 20
	var water := MeshInstance3D.new()
	water.mesh = wm
	water.material_override = wmat
	water.position = Vector3(0, 0.032, 0)
	_bowl_pivot.add_child(water)
	var sm := CylinderMesh.new()
	sm.top_radius = 0.34
	sm.bottom_radius = 0.34
	sm.height = 0.006
	sm.radial_segments = 20
	_splash = MeshInstance3D.new()
	_splash.mesh = sm
	_splash.material_override = wmat
	_splash.position = Vector3(0.18, 0.004, 0.12)
	_splash.visible = false
	_bowl.add_child(_splash)


func _tip_bowl() -> void:
	if bowl_tipped or _bowl_pivot == null:
		return
	bowl_tipped = true
	_bowl_pivot.rotation.z = 1.8
	_bowl_pivot.position.y = 0.10 # resting on its rim, water gone
	if _splash != null:
		_splash.visible = true


func _untip_bowl() -> void:
	bowl_tipped = false
	if _bowl_pivot != null:
		_bowl_pivot.rotation.z = 0.0
		_bowl_pivot.position.y = 0.045
	if _splash != null:
		_splash.visible = false


# --- HUD ---------------------------------------------------------------------------------

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 3
	add_child(_hud_layer)
	_heat_label = _hud_banner("AGGIE IS IN HEAT", 40, Color(1, 0.55, 0.75), 108)
	_popup_label = _hud_banner("", 26, Color(1, 0.95, 0.85), 222)
	_urge_label = Label.new()
	_urge_label.text = "Aggie's urge"
	_urge_label.position = Vector2(18, 210)
	_urge_label.add_theme_font_size_override("font_size", 18)
	_urge_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_urge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_urge_label.add_theme_constant_override("shadow_offset_x", 2)
	_urge_label.add_theme_constant_override("shadow_offset_y", 2)
	_urge_label.visible = false
	_hud_layer.add_child(_urge_label)
	_urge_bar = ProgressBar.new()
	_urge_bar.position = Vector2(18, 236)
	_urge_bar.size = Vector2(190, 16)
	_urge_bar.min_value = 0.0
	_urge_bar.max_value = 100.0
	_urge_bar.value = 0.0
	_urge_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	_urge_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.45, 0.75)
	fill.set_corner_radius_all(4)
	_urge_bar.add_theme_stylebox_override("fill", fill)
	_urge_bar.visible = false
	_hud_layer.add_child(_urge_bar)
	_objective_label = Label.new()
	_objective_label.text = "Objective: Find Willie"
	_objective_label.position = Vector2(18, 260)
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color(1, 0.85, 0.9))
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_objective_label.add_theme_constant_override("shadow_offset_x", 2)
	_objective_label.add_theme_constant_override("shadow_offset_y", 2)
	_objective_label.visible = false
	_hud_layer.add_child(_objective_label)


func _hud_banner(text: String, size: int, color: Color, top: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = top
	l.offset_bottom = top + 50
	l.visible = false
	_hud_layer.add_child(l)
	return l


func _show_popup(text: String) -> void:
	if _popup_label != null:
		_popup_label.text = text
	_popup_t = 4.5


func _process(_delta: float) -> void:
	if _urge_bar != null:
		_urge_bar.value = urge
		var show_urge: bool = state == "heat" and duo != null and duo.player_cat == aggie
		_urge_bar.visible = show_urge
		_urge_label.visible = show_urge
		_objective_label.visible = show_urge
	if _heat_label != null:
		_heat_label.visible = _heat_flash_t > 0.0
	if _popup_label != null:
		_popup_label.visible = _popup_t > 0.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
