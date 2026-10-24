extends ZoneRoot
## ATTIC — foundation STUB: the shell + roof + perch block +
## blanket pile. The attic lane replaces this dressing with the
## raccoon family's home (Mother boss, kits, window perch) — the
## shell, entries and connectors stay HouseSpec's, per
## docs/massey-zones.md.


func _init() -> void:
	zone_id = HouseSpec.ATTIC


func _build() -> void:
	var k := HouseBuilder.kit(self)
	HouseBuilder.build_stub(k, zone_id)
