extends Node
## The seeded basement, in the same map format the basement suite walks.
## Run: godot --headless --path godot3d res://zones/basement/tests_hoarder.tscn

const ZoneScript := preload("res://zones/basement/basement.gd")

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
	print("HOARDER TESTS")
	var seeds: Array[int] = [1, 2, 7, 19, 42, 100, 256, 2026, 8675309]
	for seed_value: int in seeds:
		var level: Dictionary = HoarderGenerator.generate(seed_value)
		var report: Dictionary = HoarderGenerator.playable(level, true)
		var why := ""
		if not bool(report["ok"]):
			var reasons: Array = report["reasons"]
			why = ", ".join(reasons)
		check(bool(report["ok"]), "seed %d is playable%s" % [seed_value, ("" if why == "" else " — " + why)])
	var again: Dictionary = HoarderGenerator.generate(7)
	var once: Dictionary = HoarderGenerator.generate(7)
	check(HoarderGenerator.maps_equal(again, once), "the same seed builds the same basement")
	check(not HoarderGenerator.maps_equal(HoarderGenerator.generate(1), HoarderGenerator.generate(2)), "two seeds are not the same house")

	var grid_ok := true
	for r in ZoneScript.GRID_ROWS:
		for c in ZoneScript.GRID_COLS:
			var ch := ZoneScript.cell_char(c, r)
			if HoarderGenerator.walkable(ch, true) != ZoneScript.cell_walkable(c, r, true):
				grid_ok = false
			if HoarderGenerator.walkable(ch, false) != ZoneScript.cell_walkable(c, r, false):
				grid_ok = false
	check(grid_ok, "walkability matches the basement legend on the hand-authored map")
	check(HoarderGenerator.cell_center(3, 4).distance_to(ZoneScript.cell_center(3, 4)) < 0.001, "cells sit on the basement grid")

	var canon := {
		"map": ZoneScript.MAP,
		"entry_cell": Vector2i(11, 9),
		"heart_cell": Vector2i(8, 3),
		"gap_cell": Vector2i(11, 2),
		"alcove_cells": [Vector2i(12, 2), Vector2i(13, 2), Vector2i(12, 3), Vector2i(13, 3)],
		"nests": [],
	}
	var canon_report: Dictionary = HoarderGenerator.playable(canon, false)
	var canon_why := ""
	if not bool(canon_report["ok"]):
		canon_why = ", ".join(canon_report["reasons"])
	check(bool(canon_report["ok"]), "the hand-authored basement passes the same connectivity check%s" % ("" if canon_why == "" else " — " + canon_why))

	var sample: Dictionary = HoarderGenerator.generate(42)
	check(int(sample["items"].size()) >= 12, "every decade leaves keepsakes (%d)" % sample["items"].size())
	var routes: Array = sample["vertical_routes"]
	check(routes.size() >= 3, "tall stacks carry vertical routes (%d)" % routes.size())
	var tall := true
	for route: Variant in routes:
		if float((route as Dictionary).get("height", 0.0)) < 1.2:
			tall = false
	check(tall, "stacks stand taller than a step")

	for floor_id: String in ["ground_floor", "attic"]:
		for seed_value: int in seeds:
			var level: Dictionary = HoarderGenerator.generate_floor(floor_id, seed_value)
			var report: Dictionary = HoarderGenerator.playable(level, true)
			var why := ""
			if not bool(report["ok"]):
				why = ", ".join(report["reasons"])
			check(bool(report["ok"]), "%s seed %d is playable%s" % [floor_id, seed_value, ("" if why == "" else " — " + why)])
		var again_f: Dictionary = HoarderGenerator.generate_floor(floor_id, 42)
		var once_f: Dictionary = HoarderGenerator.generate_floor(floor_id, 42)
		check(HoarderGenerator.maps_equal(again_f, once_f), "%s seed builds the same rooms" % floor_id)
		check(not HoarderGenerator.maps_equal(HoarderGenerator.generate_floor(floor_id, 1), HoarderGenerator.generate_floor(floor_id, 2)), "%s two seeds differ" % floor_id)
		var sample_f: Dictionary = HoarderGenerator.generate_floor(floor_id, 42)
		check(int(sample_f["items"].size()) >= 12, "%s keeps a keepsake from every decade (%d)" % [floor_id, sample_f["items"].size()])
		check(int(sample_f["nests"].size()) >= 2, "%s hides mouse nests (%d)" % [floor_id, sample_f["nests"].size()])
		var named := false
		for item: Variant in sample_f["items"]:
			var nm := String((item as Dictionary).get("name", ""))
			if nm.contains("Glenys") or nm.contains("Daniel") or nm.contains("cats"):
				named = true
		check(named, "%s keepsakes name the household" % floor_id)
		check(String(sample_f["mood"]) != "", "%s carries a light mood (%s)" % [floor_id, sample_f["mood"]])
	var basement_again: Dictionary = HoarderGenerator.generate_floor("basement", 7)
	check(HoarderGenerator.maps_equal(basement_again, once), "basement generate_floor matches generate")
	check(not HoarderGenerator.maps_equal(HoarderGenerator.generate_floor("ground_floor", 7), once), "the ground floor is not a copy of the basement")

	print("HOARDER TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
