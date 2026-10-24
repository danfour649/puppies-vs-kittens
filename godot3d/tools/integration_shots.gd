extends Node
## INTEGRATION shots: the ground-floor hub with its occupants and
## both cats, and lap-petting on the real hub sofa — staged
## against main.tscn under Xvfb:
##   xvfb-run godot --path godot3d res://tools/integration_shots.tscn
## Saves into res://screenshots/.

var _game = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait_until(fn: Callable, max_sec: float) -> bool:
	var t := 0.0
	while t < max_sec:
		if bool(fn.call()):
			return true
		await _wait(0.25)
		t += 0.25
	return bool(fn.call())


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/%s.png" % shot_name)
	print("SHOT saved ", shot_name, " ", img.get_size())


func _anchor_at(pos: Vector3, dist: float, pitch: float, yaw: float) -> void:
	var n := Node3D.new()
	n.position = pos
	_game.add_child(n)
	_game.cam_anchor = n
	_game.cam_dist = dist
	_game.cam_pitch = pitch
	_game.cam_yaw = yaw


func _run() -> void:
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _wait(1.0)
	if _game.duo != null and _game.duo.select_visible():
		_game.duo.choose("willie")
		await _wait(0.4)
	var suns: Array = _game.find_children("*", "DirectionalLight3D")
	if suns.size() > 0:
		(suns[0] as DirectionalLight3D).light_energy = 0.9
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor", true)
	await _wait(0.8)
	var occ = _game.occupants
	var daniel = _game.find_child("Daniel", true, false)
	var folasade = _game.find_child("Folasade", true, false)
	# Compose the household: Daniel takes the sofa's west seat,
	# Folasade works the kitchen counter; both cats on the rug.
	daniel.dwell_scale = 0.02 # routines effectively hold their stations
	folasade.dwell_scale = 0.02
	daniel.go_station(2)
	folasade.go_station(4)
	var sib = _game.duo.sibling_cat()
	if sib != null:
		sib.global_position = Vector3(5.55, 0.05, -201.15)
		sib.velocity = Vector3.ZERO
		sib.rotation.y = 0.5
		sib.set_lounge(true)
	_game.cat.global_position = Vector3(4.15, 0.05, -201.95)
	_game.cat.velocity = Vector3.ZERO
	_game.cat.rotation.y = -0.4
	var seated := await _wait_until(func() -> bool: return daniel.is_seated(), 25.0)
	var at_counter := await _wait_until(func() -> bool: return folasade.global_position.distance_to(Vector3(-4.3, 0, -203.85)) < 0.6, 25.0)
	print("hub stage: daniel seated = ", seated, ", folasade at counter = ", at_counter)
	_anchor_at(Vector3(4.6, 0.6, -199.6), 3.6, -0.30, 0.35)
	await _wait(0.9)
	await _shot("integration_hub")
	# The lap: Folasade's routine starts with her sit station.
	folasade.dwell_scale = 1.0
	folasade.go_station(0)
	var sat := await _wait_until(func() -> bool: return folasade.is_seated(), 25.0)
	print("lap stage: folasade seated = ", sat)
	var spot: Vector3 = folasade.lap_spot()
	_game.cat.global_position = spot + Vector3(0.0, 0.0, 0.55)
	_game.cat.velocity = Vector3.ZERO
	_game.cat.rotation.y = PI
	await _wait(0.4)
	var mounted: bool = occ.try_mount_lap(_game.cat)
	print("lap stage: mounted = ", mounted)
	await _wait(1.6)
	_anchor_at(spot + Vector3(0.35, 0.30, 0.55), 1.35, -0.30, 0.0)
	await _wait(0.9)
	await _shot("integration_lap")
	get_tree().quit(0)
