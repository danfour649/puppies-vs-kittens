extends Node
## PLAYTEST PROBE 4 (scratch): bisect the sibling travel corruption.

var _game = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(20)
	_game.duo.choose("willie")
	await frames(5)
	var aggie = _game.duo.aggie_cat
	var attic = _game._zone_roots[HouseSpec.ATTIC]
	var entry = attic.get_entry("EntryHatch")
	print("entry global_transform origin=%s basis_x=%s basis_z=%s" % [entry.global_transform.origin, entry.global_transform.basis.x, entry.global_transform.basis.z])
	print("aggie parent=%s pos=%s" % [aggie.get_parent().name, aggie.global_position])
	# Freeze every per-frame writer we can: sibling AI off, duo off, attic off, outside off, occupants off.
	_game.duo.sibling.process_mode = Node.PROCESS_MODE_DISABLED
	_game.duo.process_mode = Node.PROCESS_MODE_DISABLED
	attic.process_mode = Node.PROCESS_MODE_DISABLED
	_game.outside.process_mode = Node.PROCESS_MODE_DISABLED
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	print("same-frame after travel: aggie=%s willie=%s" % [aggie.global_position, _game.cat.global_position])
	await frames(5)
	print("after 5 frames (AI frozen): aggie=%s" % aggie.global_position)
	await frames(55)
	print("after 60 frames (AI frozen): aggie=%s" % aggie.global_position)
	# Re-enable ONLY the sibling AI.
	_game.duo.sibling.process_mode = Node.PROCESS_MODE_INHERIT
	await frames(5)
	print("after sibling AI on +5: aggie=%s sib_mode=%s sib_target=%s" % [aggie.global_position, _game.duo.sibling.mode, _game.duo.sibling.get("_target")])
	await frames(55)
	print("after sibling AI on +60: aggie=%s sib_mode=%s" % [aggie.global_position, _game.duo.sibling.mode])
	print("=== PROBE4 DONE ===")
	get_tree().quit()
