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
	var cam := get_viewport().get_camera_3d()
	var extra := ""
	if cam != null and _game != null and _game.cat != null:
		var chest: Vector3 = _game.cat.global_position + Vector3(0, 0.22, 0)
		var dist: float = cam.global_position.distance_to(chest)
		var eye: float = cam.global_position.y - _game.cat.global_position.y
		var screen: Vector2 = cam.unproject_position(chest)
		extra = " dist=%.2f eye=%.2f screen=%s" % [dist, eye, screen]
	print("SHOT ", name, " ", img.get_size(), extra)


func _look(yaw: float) -> void:
	_game.cam_yaw = yaw
	_game.snap_camera()


## Stand Willie in front of the long school-photograph name so the
## wrapped label is in frame, then let the clamp settle for a frame.
func _frame_keepsake() -> void:
	var labs: Array = _game.find_children("*", "Label3D", true, false)
	for n: Node in labs:
		var lab := n as Label3D
		if lab == null or not lab.text.to_lower().contains("photograph"):
			continue
		var world := lab.global_position
		_game.cat.global_position = world + Vector3(0.15, -0.15, 0.85)
		_game.cat.velocity = Vector3.ZERO
		_look(0.0)
		await _wait(0.45)
		var cam := get_viewport().get_camera_3d()
		var vp := get_viewport().get_visible_rect().size
		if cam != null:
			var screen: Vector2 = cam.unproject_position(lab.global_position)
			var behind: bool = cam.is_position_behind(lab.global_position)
			print("LABEL ", lab.text.replace("\n", " | "), " screen=", screen, " behind=", behind, " vp=", vp, " px=", lab.pixel_size, " width=", lab.width)
		await _shot("keepsake")
		return
	print("SHOT keepsake missing")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/circuit"))
	_game = MainScene.instantiate()
	add_child(_game)
	await _wait(0.6)
	await _shot("picker")
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
	await _frame_keepsake()
	_game.zones.travel(HouseSpec.BASEMENT, "EntryStairs", true)
	_look(PI)
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.BASEMENT) + Vector3(1.2, 0.2, 1.4)
	_game.snap_camera()
	await _wait(0.7)
	await _shot("basement")
	_game.zones.travel(HouseSpec.ATTIC, "EntryHatch", true)
	_look(0.0)
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.ATTIC) + Vector3(3.2, 0.2, -2.4)
	_game.snap_camera()
	await _wait(0.7)
	await _shot("attic")
	if _game.pause_menu != null:
		_game.pause_menu.show_menu()
		await _wait(0.25)
		await _shot("pause")
		_game.pause_menu.close()
	print("CIRCUIT SHOTS DONE")
	get_tree().quit(0)
