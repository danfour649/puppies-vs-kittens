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
	# Seeded keepsakes. The spine stays open between the door, the
	# stairs and the hatch; see HoarderDressing keep-rects.
	HoarderDressing.build(self, HoarderGenerator.generate_floor(HouseSpec.GROUND_FLOOR, 25501))
