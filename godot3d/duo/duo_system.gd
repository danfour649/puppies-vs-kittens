class_name DuoSystem
extends Node
## DUO — orchestrates the two-cat game on top of main.gd.
##
## main.gd stays the boss of the yard (environment, mice, camera,
## win state). This node adds: the sibling cat (built by the same
## cat_kit, from character data), the character-select screen,
## procedural meows, the provocation meter + its HUD, and the
## flurry / provoked-buff effects. The cats are always the same two
## instances; "choosing" just swaps which one the player drives and
## which one the sibling brain drives.

const CatScene := preload("res://cat_kit/cat.gd")
const SiblingAIScene := preload("res://duo/sibling_ai.gd")
const ProvocationScene := preload("res://duo/provocation.gd")
const CharacterSelectScene := preload("res://duo/character_select.gd")

const LOUNGE_SPOTS: Array = [
	Vector3(4.5, 0.46, 4.5), # the garden chair (resting height = seat top)
	Vector3(2.5, 0.24, -8.7), # the porch deck
	Vector3(-7.6, 0.0, -4.2), # tree shade
	Vector3(8.5, 0.0, 3.5), # sunny patch
	Vector3(-10.5, 0.0, 7.5), # fence corner
]
const CATCH_RADIUS_BASE := 0.62
const CATCH_RADIUS_PROVOKED := 0.80

var game: Node = null
var chars: Dictionary = {}
var willie_cat: PvKCat = null
var aggie_cat: PvKCat = null
var player_cat: PvKCat = null
var sibling: SiblingAI = null
var prov: Provocation = null
var select_ui: CharacterSelect = null
var aura: MeshInstance3D = null

var meow_count := 0 ## test seam: every meow, from any cat, lands here

var _voices: Dictionary = {}
var _bubbles: Dictionary = {}
var _bubble_t: Dictionary = {}
var _meow_cd: Dictionary = {}
var _base_speeds: Dictionary = {}
var _slow_t := 0.0
var _shake_t := 0.0
var _flash_t := 0.0
var _npc_meow_t := 5.0
var _rng := RandomNumberGenerator.new()

var _hud_layer: CanvasLayer
var _meter_bar: ProgressBar
var _meter_label: Label
var _flash_label: Label


func setup(game_node: Node) -> void:
	game = game_node
	_rng.randomize()
	chars = DuoCharacters.load_all()
	willie_cat = game.get("cat")
	# The sibling is built by the same kit: create the cat, apply her
	# character data, and only then add her to the tree (the kit
	# builds its model in _ready).
	aggie_cat = CatScene.new()
	aggie_cat.set_character("aggie") # kit loads her real record (tortie, wiry, 0.25)
	DuoCharacters.apply(aggie_cat, chars.get("aggie", {}))
	aggie_cat.name = String(chars.get("aggie", {}).get("name", "Aggie"))
	game.add_child(aggie_cat)
	aggie_cat.global_position = Vector3(4.5, 0.52, 4.5) # starts on the chair
	aggie_cat.rotation.y = 0.8
	player_cat = willie_cat
	for c: PvKCat in [willie_cat, aggie_cat]:
		_voices[c] = MeowAudio.make_voice(c)
		_bubbles[c] = _make_bubble(c)
		_base_speeds[c] = {
			"walk": float(c.get("walk_speed")),
			"stalk": float(c.get("stalk_speed")),
			"sprint": float(c.get("sprint_speed")),
		}
	aura = _make_aura(aggie_cat)
	sibling = SiblingAIScene.new()
	sibling.name = "SiblingAI"
	add_child(sibling)
	prov = ProvocationScene.new()
	prov.name = "Provocation"
	add_child(prov)
	prov.setup(aggie_cat, willie_cat, sibling, self)
	aggie_cat.paw_swiped.connect(_on_aggie_paw)
	_build_hud()
	select_ui = CharacterSelectScene.new()
	select_ui.name = "CharacterSelect"
	game.add_child(select_ui)
	select_ui.present(chars, ["willie", "aggie"])
	select_ui.chosen.connect(choose)
	if DuoCharacters.last_choice != "" and chars.has(DuoCharacters.last_choice):
		choose(DuoCharacters.last_choice) # restart keeps your cat
	else:
		sibling.bind(aggie_cat, willie_cat, LOUNGE_SPOTS)


# --- character select ----------------------------------------------------------

func select_visible() -> bool:
	return select_ui != null and select_ui.visible


## While the select is up, the player's cat waits (main.gd checks).
func input_locked() -> bool:
	return select_visible()


func player_id() -> String:
	return "aggie" if player_cat == aggie_cat else "willie"


func sibling_cat() -> PvKCat:
	return aggie_cat if player_cat == willie_cat else willie_cat


func choose(id: String) -> void:
	if not chars.has(id):
		return
	DuoCharacters.last_choice = id
	if select_ui != null:
		select_ui.visible = false
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	var want: PvKCat = willie_cat if id == "willie" else aggie_cat
	if want == player_cat:
		if sibling.cat != sibling_cat():
			sibling.bind(sibling_cat(), want, LOUNGE_SPOTS)
		_update_meter_label()
		return
	# Swap roles between the same two instances.
	sibling.unbind()
	prov.reset()
	var old := player_cat
	player_cat = want
	game.set("cat", player_cat)
	# MASSEY: enemies hunt the "player_cat" group — keep it current.
	for c: PvKCat in [willie_cat, aggie_cat]:
		c.remove_from_group("player_cat")
	player_cat.add_to_group("player_cat")
	# main's catch handler listens to one cat's paw: move the wire.
	var handler := Callable(game, "_on_paw_swiped")
	for c: PvKCat in [willie_cat, aggie_cat]:
		if c.paw_swiped.is_connected(handler):
			c.paw_swiped.disconnect(handler)
	player_cat.paw_swiped.connect(handler)
	# Mice flee the player, whoever that is now.
	var mice: Array = game.get("mice")
	for m: Variant in mice:
		if is_instance_valid(m):
			m.set("cat", player_cat)
	player_cat.set_lounge(false)
	sibling.bind(old, player_cat, LOUNGE_SPOTS)
	_apply_speed_scales()
	_update_meter_label()


# --- meows ---------------------------------------------------------------------

## The player's meow action (M key / MEOW button). Willie spams it;
## Aggie chirps rarely. Either way it goes through emit_meow.
func player_meow() -> void:
	if input_locked() or player_cat == null:
		return
	if float(_meow_cd.get(player_cat, 0.0)) > 0.0:
		return
	_meow_cd[player_cat] = 0.7 if player_cat == willie_cat else 1.5
	emit_meow(player_cat)


## One meow, from any cat: sound + bubble + Aggie hears it.
func emit_meow(cat: PvKCat) -> void:
	meow_count += 1
	var kind := "willie" if cat == willie_cat else "aggie"
	var voice := _voices.get(cat) as AudioStreamPlayer3D
	if voice != null:
		voice.stream = MeowAudio.stream_for(kind)
		voice.play()
	var bubble := _bubbles.get(cat) as Label3D
	if bubble != null:
		bubble.text = "MEOW!" if cat == willie_cat else "mew"
		bubble.visible = true
		_bubble_t[cat] = 0.9
	if prov != null:
		prov.hear_meow(cat)


# --- provocation effects (called by Provocation) --------------------------------

func show_flash() -> void:
	_flash_t = 1.4


func apply_provoked_buff(on: bool) -> void:
	if aura != null:
		aura.visible = on
	game.set("catch_radius", CATCH_RADIUS_PROVOKED if on else CATCH_RADIUS_BASE)
	_apply_speed_scales()


## One landed flurry paw. Knockback + brief slow + screen shake,
## and — once per flurry — Willie drops a catch (see main.gd).
func apply_flurry_hit(already_dropped: bool) -> void:
	var away := willie_cat.global_position - aggie_cat.global_position
	away.y = 0.0
	if away.length() > 0.01:
		willie_cat.global_position += away.normalized() * 0.38
	if willie_cat == player_cat:
		_slow_t = 1.6
		_shake_t = 0.3
		_apply_speed_scales()
		if not already_dropped and game.has_method("drop_caught_mouse"):
			game.drop_caught_mouse()


func _on_aggie_paw() -> void:
	if prov == null or prov.state != "active":
		return
	if sibling == null or sibling.mode != "flurry":
		return
	if _flat(aggie_cat.global_position, willie_cat.global_position) > 0.95:
		return
	prov.register_paw_hit()


# --- per-frame -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for c: Variant in _meow_cd.keys():
		_meow_cd[c] = maxf(float(_meow_cd[c]) - delta, 0.0)
	for c: Variant in _bubble_t.keys():
		var t := float(_bubble_t[c]) - delta
		_bubble_t[c] = t
		if t <= 0.0:
			(_bubbles[c] as Label3D).visible = false
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_apply_speed_scales()
	if _shake_t > 0.0 and game != null:
		_shake_t -= delta
		var k := clampf(_shake_t / 0.3, 0.0, 1.0)
		game.set("duo_shake", Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.4, 0.4),
			_rng.randf_range(-1.0, 1.0)) * 0.07 * k)
		if _shake_t <= 0.0:
			game.set("duo_shake", Vector3.ZERO)
	if _flash_t > 0.0:
		_flash_t -= delta
	# NPC Willie meows constantly, on his own schedule — including
	# from the lounge. It is only a problem if Aggie is listening.
	if player_cat == aggie_cat and not input_locked():
		_npc_meow_t -= delta
		if _npc_meow_t <= 0.0:
			_npc_meow_t = _rng.randf_range(6.0, 10.0)
			emit_meow(willie_cat)


func _process(_delta: float) -> void:
	if _meter_bar != null and prov != null:
		_meter_bar.value = prov.meter
	if _flash_label != null:
		_flash_label.visible = _flash_t > 0.0


func _apply_speed_scales() -> void:
	if player_cat == null:
		return
	var base: Dictionary = _base_speeds.get(player_cat, {})
	if base.is_empty():
		return
	var mult := 1.0
	if prov != null:
		mult *= prov.speed_multiplier()
	if _slow_t > 0.0:
		mult *= 0.45
	player_cat.set("walk_speed", float(base.get("walk", 2.4)) * mult)
	player_cat.set("stalk_speed", float(base.get("stalk", 1.2)) * mult)
	player_cat.set("sprint_speed", float(base.get("sprint", 5.0)) * mult)


# --- construction -----------------------------------------------------------------

func _make_bubble(cat: PvKCat) -> Label3D:
	var l := Label3D.new()
	l.name = "MeowBubble"
	l.text = "MEOW!"
	l.font_size = 96
	l.pixel_size = 0.0042
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1, 0.95, 0.8)
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.position = Vector3(0, 0.62, 0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.visible = false
	cat.add_child(l)
	return l


func _make_aura(cat: PvKCat) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "ProvokedAura"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.scale = Vector3(0.62, 0.52, 0.95)
	mi.position = Vector3(0, 0.17, 0.02)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.42, 0.15, 0.30)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	cat.add_child(mi)
	return mi


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 2
	add_child(_hud_layer)
	_meter_label = Label.new()
	_meter_label.position = Vector2(18, 122)
	_meter_label.add_theme_font_size_override("font_size", 18)
	_meter_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_meter_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_meter_label.add_theme_constant_override("shadow_offset_x", 2)
	_meter_label.add_theme_constant_override("shadow_offset_y", 2)
	_hud_layer.add_child(_meter_label)
	_meter_bar = ProgressBar.new()
	_meter_bar.position = Vector2(18, 148)
	_meter_bar.size = Vector2(190, 16)
	_meter_bar.min_value = 0.0
	_meter_bar.max_value = 100.0
	_meter_bar.value = 0.0
	_meter_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	_meter_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.45, 0.2)
	fill.set_corner_radius_all(4)
	_meter_bar.add_theme_stylebox_override("fill", fill)
	_hud_layer.add_child(_meter_bar)
	_flash_label = Label.new()
	_flash_label.text = "PROVOKED!"
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.add_theme_font_size_override("font_size", 34)
	_flash_label.add_theme_color_override("font_color", Color(1, 0.62, 0.3))
	_flash_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_flash_label.add_theme_constant_override("shadow_offset_x", 2)
	_flash_label.add_theme_constant_override("shadow_offset_y", 2)
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.offset_left = -300
	_flash_label.offset_right = 300
	_flash_label.offset_top = 170
	_flash_label.offset_bottom = 220
	_flash_label.visible = false
	_hud_layer.add_child(_flash_label)
	var meow_btn := Button.new()
	meow_btn.text = "MEOW"
	meow_btn.add_theme_font_size_override("font_size", 24)
	meow_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	meow_btn.offset_left = -160
	meow_btn.offset_right = -30
	meow_btn.offset_top = -300
	meow_btn.offset_bottom = -190
	meow_btn.pressed.connect(player_meow)
	_hud_layer.add_child(meow_btn)
	_update_meter_label()


func _update_meter_label() -> void:
	if _meter_label == null:
		return
	var aname := String(chars.get("aggie", {}).get("name", "Aggie"))
	if player_cat == aggie_cat:
		_meter_label.text = "Your provocation (%s)" % aname
	else:
		_meter_label.text = "%s provocation" % aname


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## MASSEY: after a zone travel, the sibling rebinds to the new
## zone's lounge spots and wander rect, then settles.
func relocate_sibling(zone_root: Node) -> void:
	if sibling == null or sibling.cat == null or zone_root == null:
		return
	if zone_root.has_method("get_lounge_spots"):
		sibling.lounge_spots = zone_root.call("get_lounge_spots")
	if zone_root.has_method("get_wander_rect"):
		sibling.wander_rect = zone_root.call("get_wander_rect")
	sibling.cat.set_lounge(false)
	sibling.go_lounge_nearest()
