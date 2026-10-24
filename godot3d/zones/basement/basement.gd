extends ZoneRoot
## BASEMENT — foundation STUB: the shell + stair flight + an entry
## room of storage boxes. The basement lane replaces this dressing
## with the labyrinth (box maze, shelves, rats, spiders, ghosts,
## the litter box) — the shell, entries and connectors stay
## HouseSpec's, per docs/massey-zones.md.


func _init() -> void:
	zone_id = HouseSpec.BASEMENT


func _build() -> void:
	var k := HouseBuilder.kit(self)
	HouseBuilder.build_stub(k, zone_id)
