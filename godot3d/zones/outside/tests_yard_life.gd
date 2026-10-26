extends Node
## Garden, shed, feeder and fence-top routes stay off the yard's
## existing gameplay points.
## Run: godot --headless --path godot3d res://zones/outside/tests_yard_life.tscn

var _pass := 0
var _fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func _ready() -> void:
	_run()


func _run() -> void:
	print("YARD LIFE TESTS")
	var problems := YardLife.clearance_problems()
	var why := ", ".join(problems)
	check(problems.is_empty(), "garden, shed and rails clear the yard's routes%s" % ("" if why == "" else " — " + why))
	check(YardLife.route_is_walkable(), "the shed-side fence is one walkable route")
	var rails := 0
	var climbs := 0
	for spec: Variant in YardLife.collision_plan():
		var kind := String((spec as Dictionary)["kind"])
		if kind == "rail":
			rails += 1
		if kind == "climb":
			climbs += 1
			var pos: Vector3 = (spec as Dictionary)["pos"]
			var size: Vector3 = (spec as Dictionary)["size"]
			var top := pos.y + size.y * 0.5
			check(top <= 1.85, "shed tread tops at %.2f, under the roof" % top)
	check(rails >= 3, "fence-top rails (%d)" % rails)
	check(climbs >= 3, "shed has a stair of crates (%d)" % climbs)
	check(YardLife.GARDEN.size.x > 2.0 and YardLife.GARDEN.size.y > 1.5, "the garden is a bed, not a tuft")
	var feeder_d := Vector2(YardLife.GARDEN_FEEDER.x - OutsideLayout.FEEDER_POS.x, YardLife.GARDEN_FEEDER.z - OutsideLayout.FEEDER_POS.z).length()
	check(feeder_d > 4.0, "the garden feeder is not the gameplay feeder (%.1f m)" % feeder_d)

	var host := Node3D.new()
	add_child(host)
	var yard := YardLife.new()
	host.add_child(yard)
	yard.build()
	var lamp := yard.find_children("*", "OmniLight3D", true, false)
	check(lamp.size() == 1 and not (lamp[0] as OmniLight3D).shadow_enabled, "shed lamp is one unshadowed light")
	check(yard.get_node_or_null("YardLifeSolids") != null, "yard life has collision")

	print("YARD LIFE TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
