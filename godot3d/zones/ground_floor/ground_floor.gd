extends ZoneRoot
## GROUND FLOOR — the hub of 255 Massey: kitchen + living room at
## cat scale, built entirely from HouseSpec by HouseBuilder (the
## drawer, the water bowl, the sofa/lap seat, stairs + hatch
## dressing). Foundation-owned; zone lanes don't build here.


func _init() -> void:
	zone_id = HouseSpec.GROUND_FLOOR


func _build() -> void:
	var k := HouseBuilder.kit(self)
	HouseBuilder.build_ground_floor(k)
