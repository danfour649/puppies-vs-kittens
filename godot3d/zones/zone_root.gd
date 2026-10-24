class_name ZoneRoot
extends Node3D
## ZONE ROOT — base class for every interior zone scene
## (zones/<id>/<id>.tscn). Owns the contract plumbing so a zone
## lane only writes its interior: entry nodes and connector
## volumes come from HouseSpec; the sibling's lounge spots and
## wander rect come from HouseSpec too (override the two getters
## if your zone reshapes the walkable area).
##
## A zone script sets zone_id in _init() and builds in _build().

var zone_id := ""


func _ready() -> void:
	_build()
	HouseBuilder.add_entries(self, zone_id)
	HouseBuilder.add_connectors(self, zone_id)


## Override: construct the zone's content (HouseBuilder kit).
func _build() -> void:
	pass


func get_entry(entry_name: String) -> Node3D:
	return get_node_or_null(entry_name) as Node3D


func get_lounge_spots() -> Array:
	var out: Array = []
	for p: Variant in HouseSpec.lounge_spots(zone_id):
		out.append(to_global(p))
	return out


func get_wander_rect() -> Rect2:
	var r := HouseSpec.wander_rect(zone_id)
	return Rect2(r.position + Vector2(global_position.x, global_position.z), r.size)
