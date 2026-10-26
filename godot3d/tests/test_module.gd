extends Node
## MODULE STANDALONE PROOF — the 255 Massey drop-in module
## (docs/massey-zones.md §9) played in an EMPTY host.
## Run: godot --headless --path godot3d res://tests/test_module.tscn
##
## The host is tests/module_host.gd: no main.tscn preload, no
## yard, no mice, no camera, no HUD — only the §9.3 host surface.
## Everything the house does here comes from godot3d/module/ and
## the module content it assembles (zones, duo, occupants,
## objectives). If this passes, the module is a drop-in package.
##
## Also locks the §9.2 mapping table against the built geometry
## (re-verified 2026-10-25): every row is recomputed from its
## authoritative source constant. ONE row is the AMENDED value —
## the basement Aggie gap: the printed table said PvK x 4.35,
## but the built gap is basement cell (11, 2), centre x 4.5
## (see the §9 amendments in docs/massey-zones.md).

const ModuleHost := preload("res://tests/module_host.gd")
const CatScene := preload("res://cat_kit/cat.gd")

var _pass := 0
var _fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok - ", label)
	else:
		_fail += 1
		print("  FAIL - ", label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _collect(node: Node, out: Array) -> void:
	if node is ZoneConnector:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _ready() -> void:
	_run()


func _audit_row(label: String, local_xz: Vector2, doc_uv: Vector2, doc_gta: Vector2) -> void:
	var uv := HouseSpec.anchor_uv(local_xz)
	check(uv.distance_to(doc_uv) <= 0.002, "§9.2 %s: (u,v) recomputes to the table (got %s, doc %s)" % [label, uv, doc_uv])
	var g := HouseSpec.uv_to_gta(uv)
	check(g.distance_to(doc_gta) <= 0.02, "§9.2 %s: GTA cell-local recomputes to the table (got %s, doc %s)" % [label, g, doc_gta])


func _entry_xz(zone: String, entry_name: String) -> Vector2:
	var t: Transform3D = HouseSpec.entries(zone)[entry_name]
	return Vector2(t.origin.x, t.origin.z)


func _audit_mapping() -> void:
	print("MODULE TESTS: §9.2 mapping table vs built geometry")
	_audit_row("front door", Vector2(HouseSpec.FRONT_DOOR_X, HouseSpec.FOOTPRINT_D / 2.0), Vector2(0.647, 1.000), Vector2(1.59, 7.30))
	_audit_row("stairwell", HouseSpec.STAIRWELL.get_center(), Vector2(0.118, 0.188), Vector2(-4.13, -4.56))
	_audit_row("hatch", HouseSpec.HATCH.get_center(), Vector2(0.882, 0.188), Vector2(4.13, -4.56))
	_audit_row("kitchen centre", HouseSpec.KITCHEN.get_center(), Vector2(0.197, 0.500), Vector2(-3.27, 0.00))
	_audit_row("living centre", HouseSpec.LIVING.get_center(), Vector2(0.697, 0.500), Vector2(2.13, 0.00))
	_audit_row("drawer", Vector2(HouseSpec.DRAWER_POS.x, HouseSpec.DRAWER_POS.z), Vector2(0.194, 0.068), Vector2(-3.30, -6.31))
	_audit_row("water bowl", Vector2(HouseSpec.WATER_BOWL_POS.x, HouseSpec.WATER_BOWL_POS.z), Vector2(0.362, 0.781), Vector2(-1.49, 4.10))
	_audit_row("sofa", Vector2(HouseSpec.SOFA_POS.x, HouseSpec.SOFA_POS.z), Vector2(0.782, 0.099), Vector2(3.05, -5.85))
	_audit_row("scratch post", Vector2(HouseSpec.SCRATCH_POST_POS.x, HouseSpec.SCRATCH_POST_POS.z), Vector2(0.965, 0.594), Vector2(5.02, 1.37))
	_audit_row("attic perch", Vector2(PvKAttic.PERCH_POS.x, PvKAttic.PERCH_POS.z), Vector2(0.812, 0.500), Vector2(3.37, 0.00))
	_audit_row("attic hatch", Vector2(PvKAttic.HATCH_POS.x, PvKAttic.HATCH_POS.z), Vector2(0.797, 0.130), Vector2(3.21, -5.40))
	_audit_row("attic entry landing", _entry_xz(HouseSpec.ATTIC, "EntryHatch"), Vector2(0.729, 0.094), Vector2(2.48, -5.93))
	_audit_row("basement entry landing", _entry_xz(HouseSpec.BASEMENT, "EntryStairs"), Vector2(0.668, 0.922), Vector2(1.81, 6.16))
	_audit_row("basement stair foot", Vector2(PvKBasement.ENTRY_POS.x, PvKBasement.ENTRY_POS.z), Vector2(0.756, 0.932), Vector2(2.76, 6.31))
	_audit_row("basement heart", Vector2(PvKBasement.HEART_POS.x, PvKBasement.HEART_POS.z), Vector2(0.559, 0.292), Vector2(0.64, -3.04))
	_audit_row("basement litter box", Vector2(PvKBasement.LITTER_POS.x, PvKBasement.LITTER_POS.z), Vector2(0.068, 0.094), Vector2(-4.67, -5.93))
	# AMENDED row (2026-10-25): built gap centre is cell (11, 2).
	var gap := PvKBasement.cell_center(PvKBasement.GAP_CELL.x, PvKBasement.GAP_CELL.y)
	_audit_row("basement Aggie gap (amended)", Vector2(gap.x, gap.z), Vector2(0.765, 0.240), Vector2(2.86, -3.80))
	var feather := Vector3.ZERO
	for spec: Variant in PvKBasement.TOY_SPAWNS:
		if String((spec as Array)[0]) == "feather":
			feather = (spec as Array)[1]
	_audit_row("basement feather toy", Vector2(feather.x, feather.z), Vector2(0.871, 0.229), Vector2(4.00, -3.96))
	# The named ANCHORS resolve inside the GTA cell on the right floors.
	var anchors_ok := true
	for name_: String in HouseSpec.ANCHORS:
		var a := HouseSpec.anchor(name_, "gta")
		var fl := String((HouseSpec.ANCHORS[name_] as Dictionary)["floor"])
		if not is_equal_approx(a.y, float(HouseSpec.GTA_FLOOR_Y[fl])) or absf(a.x) > 5.41 or absf(a.z) > 7.31:
			anchors_ok = false
	check(anchors_ok, "§9.2 every named anchor resolves inside the GTA cell at its GTA_FLOOR_Y")
	# The manifest enumerates the same module (derived, not forked).
	check(MasseyModuleManifest.floors().size() == 4, "manifest lists all 4 floors")
	var frame := MasseyModuleManifest.canonical_frame()
	check(frame["footprint"] == Vector2(11.79, 15.64) and is_equal_approx(float(frame["cell_y"]), 300.0) and is_equal_approx(float(frame["linked_dy"]), 40.0), "manifest canonical frame is GTA's (11.79 x 15.64, CELL_Y 300, LINKED +40)")
	var pair_ok := true
	for p: Variant in MasseyModuleManifest.pairings():
		var d := p as Dictionary
		if not HouseSpec.entries(String(d["target_zone"])).has(String(d["target_entry"])):
			pair_ok = false
	check(pair_ok and MasseyModuleManifest.pairings().size() == 6, "manifest pairing table: 6 pairings, every target entry exists")
	var states := {}
	for row: Variant in MasseyModuleManifest.contents_inventory():
		states[String((row as Dictionary)["contents"]).left(6)] = String((row as Dictionary)["state"])
	check(states.get("Glenys", "") == "pending", "manifest inventory marks Glenys pending (PR #14, not in tree)")


func _make_host() -> Array:
	var host = ModuleHost.new()
	host.name = "ModuleHost"
	add_child(host)
	var cat: PvKCat = CatScene.new()
	cat.name = "Willie"
	host.add_child(cat)
	cat.global_position = Vector3(2.5, 0.1, -6.2)
	cat.rotation.y = PI
	host.cat = cat
	cat.paw_swiped.connect(host._on_paw_swiped)
	var module := MasseyModule.new()
	module.name = "MasseyModule"
	host.module = module
	host.add_child(module)
	module.setup(host)
	module.build_occupants()
	return [host, module]


func _run() -> void:
	_audit_mapping()

	# --- run 1: play as Willie -------------------------------------------------
	print("MODULE TESTS: empty host, cat start as Willie")
	var pair1 := _make_host()
	var host1 = pair1[0]
	var mod1: MasseyModule = pair1[1]
	await frames(3)
	check(mod1.zones != null and mod1.zones.zones.size() == 4, "module registers all 4 zones in an empty host")
	check(mod1.objectives != null and mod1.objectives.is_in_group("objectives"), "module's objectives registry is live (group 'objectives')")
	check(host1.get_entry("EntryFrontDoor") != null, "module mounts the outside EntryFrontDoor on the host")
	var conns: Array = []
	_collect(host1, conns)
	check(conns.size() >= 6, "6+ connector volumes assembled (got %d)" % conns.size())
	var gf1: Node = mod1.zone_root(HouseSpec.GROUND_FLOOR)
	check(gf1.find_child("Daniel", true, false) != null and gf1.find_child("Folasade", true, false) != null, "occupants moved into the hub")
	check(mod1.objectives.get_item("occupants:ankle_assassin") != null, "occupants declared their objectives")
	var bs1: Node = mod1.zone_root(HouseSpec.BASEMENT)
	check((bs1.call("get_objectives") as Array).size() >= 3, "basement's zone-local objectives loaded (JSON data)")
	check(mod1.start_pending(), "character select is up before the start (start pending)")
	mod1.choose_cat("willie")
	await frames(10)
	var zones1: ZoneManager = mod1.zones
	var entry_gf := gf1.call("get_entry", "EntryFrontDoor") as Node3D
	check(zones1.current_zone == HouseSpec.GROUND_FLOOR, "cat start spawns in the ground floor (zone = %s)" % zones1.current_zone)
	check(not mod1.start_pending(), "character select resolved by the start")
	var pcat1: PvKCat = host1.cat
	check(pcat1.max_hp == 120.0, "Willie is the player (120 HP)")
	check(pcat1.global_position.distance_to(entry_gf.global_position) < 1.2, "player cat stands at the ground-floor front-door entry")
	var sib1: PvKCat = mod1.duo.sibling_cat()
	check(sib1.global_position.distance_to(entry_gf.global_position) < 2.5, "sibling materialised beside the player in the hub")
	var gf_spots: Array = gf1.call("get_lounge_spots")
	check(mod1.duo.sibling.lounge_spots == gf_spots, "sibling rebound to the hub's lounge spots")
	# Systems respond: an occupant score event lands in the registry.
	mod1.occupants.score_event.emit("ankle_attack", 25, Vector3.ZERO)
	check(mod1.objectives.score == 25, "occupant score event lands (score 25)")
	check(int((mod1.objectives.get_item("occupants:ankle_assassin") as Dictionary)["count"]) == 1, "ankle_assassin progress advanced")
	# Travel the house on the module's own manager.
	zones1.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	await frames(4)
	check(zones1.current_zone == HouseSpec.BASEMENT and pcat1.global_position.y < -2.0, "travel down: cat in the basement (y %.2f)" % pcat1.global_position.y)
	zones1.travel(HouseSpec.GROUND_FLOOR, "EntryStairsTop", true)
	await frames(4)
	zones1.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(4)
	check(zones1.current_zone == HouseSpec.ATTIC and pcat1.global_position.y > 2.4, "travel up: cat in the attic (y %.2f)" % pcat1.global_position.y)
	zones1.travel(HouseSpec.GROUND_FLOOR, "EntryHatchBottom", true)
	await frames(80) # let the 1.2 s arrival grace lapse
	pcat1.global_position = Vector3(2.5, 0.9, -200.0 + 4.35) # inside the GF door volume
	pcat1.velocity = Vector3.ZERO
	var t := 0
	while zones1.current_zone != HouseSpec.OUTSIDE and t < 150:
		await frames(1)
		t += 1
	check(zones1.current_zone == HouseSpec.OUTSIDE, "walking into the front-door volume travels outside (real connector)")
	host1.queue_free()
	await frames(4)

	# --- run 2: play as Aggie ----------------------------------------------------
	print("MODULE TESTS: empty host, cat start as Aggie")
	var pair2 := _make_host()
	var host2 = pair2[0]
	var mod2: MasseyModule = pair2[1]
	mod2.choose_cat("aggie")
	await frames(10)
	check(mod2.duo.player_id() == "aggie" and host2.cat == mod2.duo.aggie_cat, "Aggie is the player after the swap")
	check((host2.cat as PvKCat).max_hp == 80.0, "Aggie's 80 HP from the species data (read live, not copied)")
	check(mod2.zones.current_zone == HouseSpec.GROUND_FLOOR, "Aggie start also spawns in the ground floor")
	var gf2: Node = mod2.zone_root(HouseSpec.GROUND_FLOOR)
	var entry2 := gf2.call("get_entry", "EntryFrontDoor") as Node3D
	check((host2.cat as PvKCat).global_position.distance_to(entry2.global_position) < 1.2, "Aggie stands at the front-door entry")
	host2.queue_free()
	await frames(2)

	print("MODULE TESTS DONE: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
