class_name GlenysSystem
extends Node
## GLENYS — the brain: pursuit, the grab, the chocolate, the
## forgetting. The body is glenys.gd; the spec is godot3d/TODO.md
## (Daniel, 2026-10-24, locked). Design choices where the spec was
## silent are marked CHOICE and documented in glenys/README.md.
##
## The shape of her, in one paragraph: she lives in the ground
## floor and notices the cats the first time they come into HER
## house (CHOICE: activation gate — it also keeps yard-only play
## and the yard test suites exactly as they were). From then on she
## pursues the PLAYABLE cat — cane-paced (0.8 m/s), predictive
## (she steers at where the cat is heading and cuts the corners),
## and relentless: when the cat changes zone she follows through
## the same connector after FOLLOW_DELAY, forever. Mid-pursuit she
## sometimes FORGETS — stops, looks around, gives the cat a few
## seconds of peace — because she is Glenys, and that is both the
## mercy mechanic and the character. A grab is a caught state:
## controls locked, wiggle to struggle free, NO damage, ever. And
## now and then she offers the cat CHOCOLATE — labelled, in-world
## and on the HUD, as the poison it is: eating it is a deliberate
## hold-to-eat act and the game's one run-ending death.

const FOLLOW_DELAY := 6.0 ## seconds behind the cat's zone travel
const GRAB_RANGE := 0.62
const RESET_TIME := 3.0 ## her breather after an escape (no re-grab)
const FORGET_EVERY: Array = [9.0, 16.0] ## pursuit seconds between lapses
const FORGET_TIME: Array = [2.5, 4.0]
const STRUGGLE_NEED := 1.8 ## wiggle flips * STRUGGLE_PER_FLIP to escape
const STRUGGLE_PER_FLIP := 0.30
const GRAB_MAX := 6.0 ## mercy: she lets go on her own after this
const OFFER_FIRST := 22.0 ## seconds after waking to the first offer
const OFFER_EVERY: Array = [38.0, 55.0]
const OFFER_TIME := 8.0
const OFFER_MIN_DIST := 1.0
const OFFER_MAX_DIST := 4.2
const EAT_RADIUS := 1.15 ## around the chocolate itself
const EAT_TIME := 1.0 ## seconds of deliberate holding to eat
const LEAD_TIME := 0.55 ## prediction horizon for corner-cutting
const ENTRY_FOR_ZONE := {
	HouseSpec.OUTSIDE: "EntryFrontDoor",
	HouseSpec.GROUND_FLOOR: "EntryFrontDoor",
	HouseSpec.BASEMENT: "EntryStairs",
	HouseSpec.ATTIC: "EntryHatch",
}
const FORGET_LINES: Array = [
	"…Where was I?",
	"Now… where did that cat go?",
	"Hmm. I was doing something…",
]
const WAKE_LINES: Array = ["Oh! A cat!", "There's my kitty!"]

var game: Node = null ## main.gd (untyped, like the other systems)
var actor: Glenys = null
var state := "dormant" ## dormant|pursue|forget|grab|reset|offer|follow_wait|distraught|disabled
var her_zone := HouseSpec.GROUND_FLOOR
var escapes := 0
var grabs := 0
var eat_progress := 0.0
var struggle := 0.0

var _forget_t := 12.0
var _forget_left := 0.0
var _follow_left := 0.0
var _follow_zone := ""
var _reset_left := 0.0
var _offer_t := OFFER_FIRST
var _offer_left := 0.0
var _grab_t := 0.0
var _grab_cool := 0.0
var _eat_held := false ## test/touch seam: hold-to-eat without a keyboard
var _last_sign := Vector2i.ZERO
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _detour_t := 0.0
var _detour_side := 1.0
var _rng := RandomNumberGenerator.new()

var _bubble: Label3D
var _bubble_t := 0.0
var _hud_layer: CanvasLayer
var _prompt: Label
var _bar: ProgressBar


func setup(game_node: Node, actor_node: Glenys) -> void:
	game = game_node
	actor = actor_node
	_rng.randomize()
	_forget_t = _rng.randf_range(FORGET_EVERY[0], FORGET_EVERY[1])
	# Her speech bubble (the duo idiom: a Label3D over the head).
	_bubble = Label3D.new()
	_bubble.name = "GlenysBubble"
	_bubble.font_size = 72
	_bubble.pixel_size = 0.004
	_bubble.modulate = Color(1.0, 0.97, 0.88)
	_bubble.outline_size = 10
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 1.86, 0)
	_bubble.visible = false
	actor.add_child(_bubble)
	_build_hud()
	# Paw taps during an offer are part of the deliberate eat act.
	# NOTE: game.cat and game.aggie can be the SAME cat here (the
	# duo auto-re-picks last session's cat during setup) — dedupe.
	var seen := {}
	for c: PvKCat in [game.get("aggie") as PvKCat, game.get("cat") as PvKCat]:
		if c != null and not seen.has(c):
			seen[c] = true
			c.paw_swiped.connect(_on_any_paw)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 14
	add_child(_hud_layer)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-420, -120)
	_prompt.size = Vector2(840, 34)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.text = ""
	_hud_layer.add_child(_prompt)
	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.position = Vector2(-140, -84)
	_bar.size = Vector2(280, 16)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false
	_hud_layer.add_child(_bar)


# --- public seams (tests, touch, the coordinator's probes) ---------------------

## The cat she hunts: always the playable one (main's cat handle,
## which the duo system swaps on character select).
func player_target() -> PvKCat:
	if game == null:
		return null
	return game.get("cat") as PvKCat


func set_active(on: bool) -> void:
	if on and state == "disabled":
		state = "dormant"
		actor.visible = true
		actor.set_physics_process(true)
	elif not on:
		state = "disabled"
		_release_cat(false)
		actor.set_move_dir(Vector3.ZERO)
		actor.visible = false
		actor.set_physics_process(false)


## Skip the activation gate (tests, shots).
func force_wake() -> void:
	if state == "dormant":
		_wake()


func force_forget() -> void:
	if state == "pursue":
		_enter_forget()


func force_offer() -> void:
	if state == "pursue" or state == "reset":
		_enter_offer()


## Teleport her within grab range and grab (tests, shots).
func debug_grab() -> bool:
	var cat := player_target()
	if cat == null or actor == null:
		return false
	actor.global_position = cat.global_position + Vector3(0.4, 0.0, 0.4)
	_begin_grab()
	return state == "grab"


## One wiggle input direction (tests + touch feed this; the
## keyboard path polls real keys in _step_grab).
func struggle_wiggle(v: Vector2) -> void:
	if state != "grab":
		return
	_count_wiggle(v)


## Hold-to-eat without a keyboard (tests + touch).
func set_eat_held(on: bool) -> void:
	_eat_held = on


## Where she is steering right now: the cat's PREDICTED position
## (velocity-led — the corner-cutting), routed through the divider
## gap when the ground floor's partition is in the way.
func steering_target() -> Vector3:
	var cat := player_target()
	if cat == null or actor == null:
		return Vector3.ZERO
	var predicted := cat.global_position + cat.velocity * LEAD_TIME
	predicted.y = cat.global_position.y
	var zones: ZoneManager = game.get("zones") as ZoneManager
	if zones != null and zones.current_zone == HouseSpec.GROUND_FLOOR and her_zone == HouseSpec.GROUND_FLOOR:
		var o := HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR)
		var hx := actor.global_position.x - o.x
		var tx := predicted.x - o.x
		if (hx - HouseSpec.DIVIDER_X) * (tx - HouseSpec.DIVIDER_X) < 0.0:
			var hz := actor.global_position.z - o.z
			if absf(hz) > 0.9: # not already in the doorway band
				return Vector3(o.x + HouseSpec.DIVIDER_X, actor.global_position.y, o.z)
	if _detour_t > 0.0:
		var to := predicted - actor.global_position
		to.y = 0.0
		if to.length() > 0.05:
			var side := Vector3(-to.normalized().z, 0, to.normalized().x) * _detour_side
			return predicted + side * 1.1
	return predicted


# --- per-frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or actor == null:
		return
	if state == "disabled" or state == "distraught":
		actor.set_move_dir(Vector3.ZERO)
		_update_hud()
		return
	var cat := player_target()
	var zones: ZoneManager = game.get("zones") as ZoneManager
	if cat == null or zones == null:
		return
	if _grab_cool > 0.0:
		_grab_cool -= delta

	if state == "dormant":
		actor.set_move_dir(Vector3.ZERO)
		actor.set_pose("idle")
		if zones.current_zone == HouseSpec.GROUND_FLOOR:
			_wake()
		_update_hud()
		return

	# Zone following: she is where she is; the cat may not be.
	if state != "grab":
		var cat_zone := zones.current_zone
		if cat_zone == her_zone:
			if state == "follow_wait":
				state = "pursue" # he came back — no trip needed
				actor.set_pose("walk")
		else:
			if state != "follow_wait" or _follow_zone != cat_zone:
				if state == "offer":
					actor.set_chocolate_visible(false)
					eat_progress = 0.0
					_offer_t = _rng.randf_range(OFFER_EVERY[0], OFFER_EVERY[1])
				state = "follow_wait"
				_follow_zone = cat_zone
				_follow_left = FOLLOW_DELAY
				actor.set_pose("idle")
				_say("Now where…?")
			actor.set_move_dir(Vector3.ZERO)
			_follow_left -= delta
			if _follow_left <= 0.0:
				_arrive(_follow_zone)
			_update_hud()
			return

	match state:
		"pursue":
			_step_pursue(delta, cat)
		"forget":
			actor.set_move_dir(Vector3.ZERO)
			actor.set_pose("forget")
			_forget_left -= delta
			if _forget_left <= 0.0:
				state = "pursue"
				actor.set_pose("walk")
				_forget_t = _rng.randf_range(FORGET_EVERY[0], FORGET_EVERY[1])
				_say("There you are!")
		"grab":
			_step_grab(delta, cat)
		"reset":
			actor.set_move_dir(Vector3.ZERO)
			actor.set_pose("reset")
			_reset_left -= delta
			if _reset_left <= 0.0:
				state = "pursue"
				actor.set_pose("walk")
		"offer":
			_step_offer(delta, cat)
	_update_hud()


func _process(delta: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0 and _bubble != null:
			_bubble.visible = false


# --- pursuit -----------------------------------------------------------------------

func _step_pursue(delta: float, cat: PvKCat) -> void:
	actor.set_pose("walk")
	# The forgetting: her one mercy, on her own schedule.
	_forget_t -= delta
	if _forget_t <= 0.0:
		_enter_forget()
		return
	# The chocolate: offered on a slow cycle, only at conversation
	# distance — she has to be able to hold it out to him.
	_offer_t -= delta
	var flat := _flat(actor.global_position, cat.global_position)
	if _offer_t <= 0.0 and flat >= OFFER_MIN_DIST and flat <= OFFER_MAX_DIST:
		_enter_offer()
		return
	# Steer at the predicted point; if the world won't let her
	# through, bias sideways for a moment (the corner-slide).
	var point := steering_target()
	var to := point - actor.global_position
	to.y = 0.0
	if to.length() > 0.05:
		actor.set_move_dir(to.normalized())
		_face(point, delta)
	else:
		actor.set_move_dir(Vector3.ZERO)
	if _detour_t > 0.0:
		_detour_t -= delta
	if actor.speed_now < 0.15 and to.length() > 1.0:
		_stuck_t += delta
		if _stuck_t > 0.8:
			_stuck_t = 0.0
			_detour_t = 1.1
			_detour_side = -_detour_side
	else:
		_stuck_t = 0.0
	_last_pos = actor.global_position
	# The grab itself.
	if _grab_cool <= 0.0 and flat <= GRAB_RANGE and _can_grab(cat):
		_begin_grab()


func _can_grab(cat: PvKCat) -> bool:
	if cat.is_fainted or cat.is_poisoned or cat.is_held:
		return false
	if cat.has_meta("on_lap") and bool(cat.get_meta("on_lap")):
		return false # CHOICE (spec-recommended): not even Glenys takes a cat off a lap
	if bool(game.get("won")) or bool(game.get("run_over")):
		return false
	var zones: ZoneManager = game.get("zones") as ZoneManager
	if zones != null and zones.travelling:
		return false
	var duo: Node = game.get("duo")
	if duo != null and bool(duo.call("input_locked")):
		return false
	return true


# --- the grab: a caught state, a struggle, never an injury -------------------------

func _begin_grab() -> void:
	var cat := player_target()
	if cat == null:
		return
	state = "grab"
	grabs += 1
	struggle = 0.0
	_grab_t = 0.0
	_last_sign = Vector2i.ZERO
	cat.set_held(true)
	actor.set_pose("grab")
	actor.set_move_dir(Vector3.ZERO)
	_say("Got you!")
	# A carried catch is dropped (the duo rule: it respawns and the
	# win stays reachable) — being grabbed is annoying, not fatal.
	if game.has_method("drop_caught_mouse"):
		game.drop_caught_mouse()


func _step_grab(delta: float, cat: PvKCat) -> void:
	_grab_t += delta
	# She holds him up at her chest; his physics is pinned (the lap
	# idiom: kinematic pin per step, velocity zeroed).
	cat.velocity = Vector3.ZERO
	cat.global_position = actor.hold_point_global()
	cat.rotation.y = actor.rotation.y + PI
	# Struggle input: rapid direction changes (keys or stick).
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y -= 1.0
	var touch: Node = game.get("_touch")
	if touch != null and touch.has_method("move_vector"):
		var stick: Vector2 = touch.call("move_vector")
		if stick.length() > 0.35:
			v = stick
	if v.length() > 0.1:
		_count_wiggle(v)
	if struggle >= STRUGGLE_NEED:
		_escape(true)
	elif _grab_t >= GRAB_MAX:
		_escape(false) # she lets go on her own — no soft-locks, ever


func _count_wiggle(v: Vector2) -> void:
	var s := Vector2i.ZERO
	if absf(v.x) >= absf(v.y):
		s = Vector2i(1 if v.x > 0.0 else -1, 0)
	else:
		s = Vector2i(0, 1 if v.y > 0.0 else -1)
	if s == Vector2i.ZERO:
		return
	if _last_sign != Vector2i.ZERO and s != _last_sign:
		struggle += STRUGGLE_PER_FLIP
	_last_sign = s


func _escape(scored: bool) -> void:
	var cat := player_target()
	if cat != null:
		cat.set_held(false)
		# The break-free pop: positional, because the cat's
		# controller eats external velocity by design (the duo
		# flurry does the same). Her reset is the real head start.
		var away := cat.global_position - actor.global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = -actor.global_transform.basis.z
			away.y = 0.0
		cat.global_position += away.normalized() * 0.55 + Vector3(0, 0.06, 0)
	actor.set_pose("reset")
	state = "reset"
	_reset_left = RESET_TIME
	_grab_cool = RESET_TIME + 1.0
	_say("Oh! Come back here!")
	if scored:
		escapes += 1
		var obj: PvKObjectives = game.get("objectives") as PvKObjectives
		if obj != null:
			obj.add_score("glenys_escape")
			obj.add_progress("glenys:escape_artist", 1)


func _release_cat(scored: bool) -> void:
	if state == "grab":
		_escape(scored)


# --- the chocolate: a treat to her, a poison to cats ------------------------------

func _enter_offer() -> void:
	state = "offer"
	_offer_left = OFFER_TIME
	eat_progress = 0.0
	actor.set_move_dir(Vector3.ZERO)
	actor.set_pose("offer")
	actor.set_chocolate_visible(true)
	_say("Here, kitty — chocolate!")


func _end_offer(resume_line: String) -> void:
	actor.set_chocolate_visible(false)
	actor.set_pose("walk")
	eat_progress = 0.0
	_offer_t = _rng.randf_range(OFFER_EVERY[0], OFFER_EVERY[1])
	state = "pursue"
	if resume_line != "":
		_say(resume_line)


func _step_offer(delta: float, cat: PvKCat) -> void:
	actor.set_move_dir(Vector3.ZERO)
	_face(cat.global_position, delta)
	_offer_left -= delta
	var d := actor.chocolate_point().distance_to(cat.global_position)
	if d > 6.0:
		_end_offer("") # he left — she'll catch up and try again later
		return
	if d <= EAT_RADIUS:
		# The deliberate act: hold PAW (or the seam), in range, for
		# a full second, under a warning that never leaves the HUD.
		var held := _eat_held or Input.is_physical_key_pressed(KEY_F)
		if held:
			eat_progress += delta
		else:
			eat_progress = maxf(0.0, eat_progress - delta * 2.0)
		if eat_progress >= EAT_TIME:
			_eat_chocolate(cat)
			return
	else:
		eat_progress = maxf(0.0, eat_progress - delta * 2.0)
	if _offer_left <= 0.0:
		_end_offer("More for me, then.")


func _on_any_paw() -> void:
	# A paw tap near the chocolate is a nibble's worth of eating —
	# it only matters mid-offer, in range, and it is the cat's own
	# paw every time.
	if state != "offer":
		return
	var cat := player_target()
	if cat == null:
		return
	if actor.chocolate_point().distance_to(cat.global_position) <= EAT_RADIUS:
		eat_progress += 0.35


func _eat_chocolate(cat: PvKCat) -> void:
	actor.set_chocolate_visible(false)
	actor.set_pose("distraught")
	state = "distraught"
	actor.set_move_dir(Vector3.ZERO)
	_say("Oh no… oh no no no.")
	cat.eat_poison("chocolate") # the run-ender lives in main + the cat


# --- forgetting, waking, arriving -----------------------------------------------------

func _enter_forget() -> void:
	state = "forget"
	_forget_left = _rng.randf_range(FORGET_TIME[0], FORGET_TIME[1])
	actor.set_move_dir(Vector3.ZERO)
	actor.set_pose("forget")
	_say(FORGET_LINES[_rng.randi() % FORGET_LINES.size()])


func _wake() -> void:
	state = "pursue"
	actor.set_pose("walk")
	_offer_t = OFFER_FIRST
	_forget_t = _rng.randf_range(FORGET_EVERY[0], FORGET_EVERY[1])
	_say(WAKE_LINES[_rng.randi() % WAKE_LINES.size()])


func _arrive(zone_id: String) -> void:
	var zones: ZoneManager = game.get("zones") as ZoneManager
	if zones == null:
		return
	var root: Node = zones.zones.get(zone_id)
	if root == null or not root.has_method("get_entry"):
		state = "pursue"
		return
	var entry := root.call("get_entry", String(ENTRY_FOR_ZONE.get(zone_id, "EntryFrontDoor"))) as Node3D
	if entry == null:
		state = "pursue"
		return
	actor.global_transform = entry.global_transform
	var right := entry.global_transform.basis.x
	right.y = 0.0
	actor.global_position += right.normalized() * 0.45 + Vector3(0, 0.05, 0)
	actor.velocity = Vector3.ZERO
	her_zone = zone_id
	state = "pursue"
	actor.set_pose("walk")
	_say("There you are!")


# --- small things -----------------------------------------------------------------------

func _say(text: String) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = 2.4


func _face(point: Vector3, delta: float) -> void:
	var to := point - actor.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var target_yaw := atan2(-to.normalized().x, -to.normalized().z)
	actor.rotation.y = lerp_angle(actor.rotation.y, target_yaw, 1.0 - exp(-6.0 * delta))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _update_hud() -> void:
	if _prompt == null:
		return
	var cat := player_target()
	match state:
		"grab":
			_prompt.text = "CAUGHT! Wiggle (A/D/W/S or the stick) to struggle free!"
			_bar.visible = true
			_bar.value = clampf(struggle / STRUGGLE_NEED, 0.0, 1.0)
		"offer":
			if cat != null and actor.chocolate_point().distance_to(cat.global_position) <= EAT_RADIUS:
				_prompt.text = "⚠ CHOCOLATE IS POISON FOR CATS — hold PAW (F) to eat it and END THE RUN · walk away to refuse"
				_bar.visible = true
				_bar.value = clampf(eat_progress / EAT_TIME, 0.0, 1.0)
			else:
				_prompt.text = "Glenys is offering chocolate. It would kill a cat. She doesn't know that."
				_bar.visible = false
		_:
			_prompt.text = ""
			_bar.visible = false
