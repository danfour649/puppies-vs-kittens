class_name ZoneManager
extends Node
## ZONE MANAGER — owns travel between the Massey zones: the fade,
## the two-cat move, the arrival grace, and the zone bookkeeping
## (objectives HUD reads current_zone; enemies never need to know).
##
## Only the player cat trips connectors (zone_connector.gd); travel
## always moves BOTH cats — the sibling materialises beside the
## player at the entry point and rebinds to the new zone's lounge
## spots (duo.relocate_sibling).

signal zone_changed(zone_id: String)

var game: Node = null # main.gd (untyped: it owns everything)
var zones: Dictionary = {} # id -> root node (main itself for outside)
var current_zone := HouseSpec.OUTSIDE
var travelling := false

var _cooldown := 0.0
var _fade_rect: ColorRect
var _fade_layer: CanvasLayer


func _ready() -> void:
	add_to_group("zone_manager")
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 20
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func setup(game_node: Node) -> void:
	game = game_node


func register_zone(id: String, root: Node) -> void:
	zones[id] = root


func player_cat() -> PvKCat:
	if game == null:
		return null
	return game.get("cat") as PvKCat


func can_travel() -> bool:
	if travelling or _cooldown > 0.0 or game == null:
		return false
	var duo: Node = game.get("duo")
	if duo != null and bool(duo.call("input_locked")):
		return false # the character select is still up
	return true


func travel(zone_id: String, entry_name: String, instant := false) -> void:
	if travelling or not zones.has(zone_id):
		return
	var root: Node = zones[zone_id]
	if root == null or not root.has_method("get_entry"):
		return
	var entry := root.call("get_entry", entry_name) as Node3D
	if entry == null:
		return
	if instant:
		_do_move(zone_id, entry)
		return
	travelling = true
	# A short dip through the destination's own light — dusk, night
	# or dawn — rather than a hard black cut. The move happens while
	# the rect is opaque, so the camera never shows the teleport.
	var tint := LightMood.fade_tint(zone_id)
	_fade_rect.color = Color(tint.r, tint.g, tint.b, _fade_rect.color.a)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.12)
	tw.tween_callback(_do_move.bind(zone_id, entry))
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.18)
	tw.tween_callback(func() -> void: travelling = false)


func _do_move(zone_id: String, entry: Node3D) -> void:
	var dest := entry.global_transform
	var player := player_cat()
	if player != null:
		player.velocity = Vector3.ZERO
		player.global_transform = dest
		player.global_position += Vector3(0, 0.05, 0)
	var duo: Node = game.get("duo") if game != null else null
	if duo != null:
		var sib := duo.call("sibling_cat") as PvKCat
		if sib != null and sib != player:
			sib.velocity = Vector3.ZERO
			sib.global_transform = dest
			var right := dest.basis.x
			right.y = 0.0
			sib.global_position += right.normalized() * 0.85 + Vector3(0, 0.05, 0)
	current_zone = zone_id
	_cooldown = 1.2
	if game != null and game.has_method("on_zone_changed"):
		game.on_zone_changed(zone_id)
	zone_changed.emit(zone_id)


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
