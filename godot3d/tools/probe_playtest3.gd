extends Node
## PLAYTEST PROBE 3 (scratch): sibling travel tracking.

var _game = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run()


func _snap(label: String) -> void:
	var cat = _game.cat
	var aggie = _game.duo.aggie_cat
	print("%s: zone=%s travelling=%s willie=%s aggie=%s sib_mode=%s aggie_lounging=%s" % [
		label, _game.zones.current_zone, _game.zones.travelling,
		cat.global_position, aggie.global_position, _game.duo.sibling.mode, aggie.is_lounging])


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await frames(20)
	_game.duo.choose("willie")
	await frames(5)
	_snap("boot")
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(5)
	_snap("after yard->attic instant")
	for i in 4:
		await frames(60)
		_snap("attic +%ds" % (i + 1))
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryHatchBottom", true)
	await frames(5)
	_snap("after attic->gf instant")
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	await frames(5)
	_snap("after gf->attic instant")
	_game.zones.travel(HouseSpec.OUTSIDE, "EntryFrontDoor", true)
	await frames(5)
	_snap("after attic->outside instant")
	for i in 3:
		await frames(60)
		_snap("outside +%ds" % (i + 1))
	print("=== PROBE3 DONE ===")
	get_tree().quit()
