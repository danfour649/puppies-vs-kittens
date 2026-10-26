extends Node
## Layout of the lived-in floors: the generated level stays playable,
## and the meshes we actually collide with stay off the doors, the
## stairs, the hatch, and the attic's walked floor.
## Run: godot --headless --path godot3d res://house/tests_dressing.tscn

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
	print("DRESSING TESTS")
	for floor_id: String in ["ground_floor", "attic"]:
		var seed_value := 25501 if floor_id == "ground_floor" else 25502
		var level: Dictionary = HoarderGenerator.generate_floor(floor_id, seed_value)
		var report: Dictionary = HoarderGenerator.playable(level, true)
		var why := ""
		if not bool(report["ok"]):
			why = ", ".join(report["reasons"])
		check(bool(report["ok"]), "%s seed %d is the one we build%s" % [floor_id, seed_value, ("" if why == "" else " — " + why)])
		var planned: Dictionary = HoarderDressing.plan(level)
		var rects := HoarderDressing.keep_rects(floor_id)
		var hit := false
		for s: Variant in planned["solids"]:
			var sd: Dictionary = s
			if HoarderDressing.overlaps_keep(sd["pos"], sd["size"], rects):
				hit = true
		for s: Variant in planned["steps"]:
			var sd: Dictionary = s
			if HoarderDressing.overlaps_keep(sd["pos"], sd["size"], rects):
				hit = true
		check(not hit, "%s solids stay out of the keep-rects" % floor_id)
		check(HoarderDressing.stack_count(planned) >= 3, "%s keeps tall stacks (%d)" % [floor_id, HoarderDressing.stack_count(planned)])
		check((planned["steps"] as Array).size() >= 3, "%s stacks have climb steps (%d)" % [floor_id, (planned["steps"] as Array).size()])
		check((planned["nests"] as Array).size() >= 1, "%s still shows a mouse nest" % floor_id)
		check((planned["lights"] as Array).size() <= 3, "%s light count stays web-small (%d)" % [floor_id, (planned["lights"] as Array).size()])
		check(String(planned["mood"]) == LightMood.for_zone(floor_id), "%s mood matches the hour (%s)" % [floor_id, planned["mood"]])
	# The real entrances, including where the sibling stands beside you.
	var landings: Array = [
		Vector2(2.5, 3.55), Vector2(3.35, 3.55),
		Vector2(-6.5, -1.55), Vector2(-7.35, -1.55),
		Vector2(6.5, -1.7), Vector2(5.65, -1.7),
	]
	var covered := true
	for p: Vector2 in landings:
		var inside := false
		for r: Rect2 in HoarderDressing.keep_rects("ground_floor"):
			if r.has_point(p):
				inside = true
		if not inside:
			covered = false
			print("  landing missed ", p)
	check(covered, "ground-floor landings sit in keep-rects")
	var attic_landings: Array = [Vector2(3.9, -3.9), Vector2(3.05, -3.9), Vector2(4.55, -3.55), Vector2(-1.0, 0.5), Vector2(0.8, 2.6)]
	var attic_ok := true
	for p: Vector2 in attic_landings:
		var inside := false
		for r: Rect2 in HoarderDressing.keep_rects("attic"):
			if r.has_point(p):
				inside = true
		if not inside:
			attic_ok = false
			print("  attic point missed ", p)
	check(attic_ok, "attic hatch, walks and pile sit in keep-rects")

	var host := Node3D.new()
	add_child(host)
	var dressed := HoarderDressing.build(host, HoarderGenerator.generate_floor("ground_floor", 25501))
	var shadowed := false
	var lights := 0
	for n: Node in dressed.find_children("*", "OmniLight3D", true, false):
		lights += 1
		if (n as OmniLight3D).shadow_enabled:
			shadowed = true
	check(lights >= 1 and not shadowed, "dressing lights are unshadowed (%d)" % lights)
	var wrapped := false
	var long_name := false
	var small := false
	for n: Node in dressed.find_children("*", "Label", true, false):
		var lab := n as Label
		if lab.text.find("photograph") >= 0 or lab.text.length() > 28:
			long_name = true
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF and lab.custom_minimum_size.x >= 160.0:
			wrapped = true
		var fs := lab.get_theme_font_size("font_size")
		if fs >= 14 and fs <= 16:
			small = true
	check(wrapped and long_name and small, "keepsake names are small wrapped labels")
	check(dressed.find_children("*", "DustShaft", true, false).size() >= 1 or dressed.get_node_or_null("DustShaft") != null, "a dust shaft comes in with the window")

	var dusk: Color = LightMood.fade_tint("ground_floor")
	var night: Color = LightMood.fade_tint("basement")
	var dawn: Color = LightMood.fade_tint("attic")
	var dusk_night := absf(dusk.r - night.r) + absf(dusk.b - night.b)
	var dawn_night := absf(dawn.r - night.r) + absf(dawn.b - night.b)
	check(dusk_night > 0.05 and dawn_night > 0.05, "door fades differ by the hour")
	check(LightMood.for_zone("outside") == "dusk", "the yard is dusk")

	print("DRESSING TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
