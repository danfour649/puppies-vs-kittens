extends Node
## Stills of the connected night, GL Compatibility, dressed lod0:
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --path godot3d \
##     --rendering-method gl_compatibility --resolution 1280x720 \
##     --audio-driver Dummy res://tools/tools_circuit_shots.tscn -- --quality high

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
		var feet: Vector3 = _game.cat.global_position
		var crown: Vector3 = feet + Vector3(0, 0.46, 0)
		var vp_h: float = get_viewport().get_visible_rect().size.y
		var frac: float = absf(cam.unproject_position(crown).y - cam.unproject_position(feet).y) / maxf(1.0, vp_h)
		var look: float = (-cam.global_basis.z).y
		extra = " dist=%.2f eye=%.2f look=%.2f fill=%.0f%% screen=%s" % [dist, eye, look, frac * 100.0, screen]
	print("SHOT ", name, " ", img.get_size(), extra)


func _look(yaw: float) -> void:
	_game.cam_yaw = yaw
	_game.snap_camera()


func _label_world(lab: Label) -> Vector3:
	var home: Vector3 = lab.get_meta("home")
	var host: Node = lab
	while host != null and not (host is HoarderDressing):
		host = host.get_parent()
	if host is Node3D:
		return (host as Node3D).to_global(home)
	return home


## Stand Willie in front of the long school-photograph name so the
## small label is in frame, then let it settle for a frame.
func _frame_keepsake() -> void:
	var labs: Array = _game.find_children("*", "Label", true, false)
	for n: Node in labs:
		var lab := n as Label
		if lab == null or not lab.has_meta("home"):
			continue
		if not lab.text.to_lower().contains("photograph"):
			continue
		var world := _label_world(lab)
		var offsets: Array[Vector3] = [
			Vector3(0.15, -0.1, 0.7),
			Vector3(0.65, -0.1, 0.25),
			Vector3(-0.65, -0.1, 0.25),
			Vector3(0.4, -0.1, 0.45),
			Vector3(-0.35, -0.1, 0.55),
			Vector3(0.2, -0.1, -0.55),
		]
		var best := offsets[0]
		var best_dist := -1.0
		for off: Vector3 in offsets:
			_game.cat.global_position = world + off
			_game.cat.velocity = Vector3.ZERO
			var to: Vector3 = world - _game.cat.global_position
			_look(atan2(-to.x, -to.z))
			await _wait(0.28)
			if not lab.visible:
				continue
			var cam_now := get_viewport().get_camera_3d()
			if cam_now == null:
				continue
			var away: float = cam_now.global_position.distance_to(_game.cat.global_position)
			if away > best_dist:
				best_dist = away
				best = off
		_game.cat.global_position = world + best
		_game.cat.velocity = Vector3.ZERO
		var aim: Vector3 = world - _game.cat.global_position
		_look(atan2(-aim.x, -aim.z))
		await _wait(0.35)
		var cam := get_viewport().get_camera_3d()
		var vp := get_viewport().get_visible_rect().size
		if cam != null:
			var screen: Vector2 = cam.unproject_position(world)
			var behind: bool = cam.is_position_behind(world)
			print("LABEL ", lab.text.replace("\n", " | "), " screen=", screen, " behind=", behind, " vp=", vp, " font=", lab.get_theme_font_size("font_size"), " box=", lab.position, lab.size, " vis=", lab.visible, " stand=", best)
		await _shot("keepsake")
		return
	print("SHOT keepsake missing")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/circuit"))
	_game = MainScene.instantiate()
	add_child(_game)
	await _wait(0.6)
	var comp_vis := false
	if _game.night != null and _game.night.compass() != null:
		comp_vis = _game.night.compass().visible
	var chip_vis := false
	if _game._hud_layer != null:
		chip_vis = _game._hud_layer.visible
	var paw_vis := false
	if _game._touch != null:
		paw_vis = _game._touch.visible
	print("PICKER paw=", paw_vis, " chip=", chip_vis, " compass=", comp_vis)
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
	_game.cat.global_position = HouseSpec.zone_origin(HouseSpec.GROUND_FLOOR) + Vector3(5.0, 0.2, -2.0)
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
