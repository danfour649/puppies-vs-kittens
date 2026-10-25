extends Node3D
## MODULE HOST STUB — the minimal §9.3 host for the standalone
## module proof (tests/test_module.gd). This is NOT the game: no
## yard, no mice, no camera, no HUD. It implements exactly the
## host surface MasseyModule codes against (module/DROP-IN.md),
## so the module assembling and playing here proves it is a
## drop-in package, not a slice of main.tscn.
##
## Host surface (PvK realization of §9.3):
##   cat / duo / mice / catch_radius — vars the module + duo read/write
##   _on_paw_swiped() — the paw sink (a real host runs catch/combat)
##   on_zone_changed(id) — the zone hook (a real host moves its
##     camera; every host rebinds the sibling to the new zone)
##   get_entry / get_lounge_spots / get_wander_rect — the host IS
##     the outside zone root; the module mounts the entry node.

var cat: PvKCat = null
var duo = null
var mice: Array = []
var catch_radius := 0.42
var module: MasseyModule = null
var zone_changes: Array = []


func _on_paw_swiped() -> void:
	pass # sink: this host has no yard game for a paw to catch in


func on_zone_changed(zone_id: String) -> void:
	zone_changes.append(zone_id)
	if duo != null and module != null and module.zone_root(zone_id) != null:
		duo.relocate_sibling(module.zone_root(zone_id))


func get_entry(entry_name: String) -> Node3D:
	return get_node_or_null(entry_name) as Node3D


func get_lounge_spots() -> Array:
	return DuoSystem.LOUNGE_SPOTS.duplicate()


func get_wander_rect() -> Rect2:
	return HouseSpec.wander_rect(HouseSpec.OUTSIDE)
