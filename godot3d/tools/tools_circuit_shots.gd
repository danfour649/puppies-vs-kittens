extends Node
## Stills of the connected house, GL Compatibility:
##   xvfb-run godot --path godot3d --rendering-method gl_compatibility res://tools/tools_circuit_shots.tscn

const MainScene := preload("res://main.tscn")

var _game


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/circuit/%s.png" % name)
	print("SHOT ", name, " ", img.get_size())


func _look(yaw: float) -> void:
	_game.cam_yaw = yaw
	_game.snap_camera()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/circuit"))
	_game = MainScene.instantiate()
	add_child(_game)
	await _wait(0.4)
	_game.duo.choose("willie")
	await _wait(0.3)
	_look(0.0)
	await _shot("night_start")
	_game.night.start_playing()
	_game.cat.global_position = Vector3(2.5, 0.32, -8.7)
	_game.cat.velocity = Vector3.ZERO
	_look(0.0)
	await _wait(0.35)
	await _shot("yard")
	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryFrontDoor")
	await _wait(0.1)
	await _shot("transition")
	var guard := 0
	while _game.zones.travelling and guard < 40:
		await _wait(0.05)
		guard += 1
	_look(0.0)
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR) + Vector3(2.4, 0.2, 0.6)
	_game.snap_camera()
	await _wait(0.7)
	await _shot("ground")
	_game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	_look(PI)
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.BASEMENT) + Vector3(1.2, 0.2, 1.4)
	_game.snap_camera()
	await _wait(0.7)
	await _shot("basement")
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	_look(PI)
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.ATTIC) + Vector3(1.0, 0.2, -1.2)
	_game.snap_camera()
	await _wait(0.7)
	await _shot("attic")
	print("CIRCUIT SHOTS DONE")
	get_tree().quit(0)
