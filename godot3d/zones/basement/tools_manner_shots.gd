extends Node
## Frames of the cat manners: chatter at the window, zoomies off
## the litter tray, Aggie waiting under the furniture.
##   xvfb-run godot --path godot3d res://zones/basement/tools_manner_shots.tscn


const HuntScene := preload("res://zones/basement/night_hunt.tscn")


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(hunt: NightHunt, name: String) -> void:
	for _i in 2:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/hunt/%s.png" % name)
	print("SHOT ", name, " ", img.get_size(), " manner ", hunt.cat.manner if hunt.cat != null else "", " aggie ", hunt.other.state if hunt.other != null else "")


func _frame(hunt: NightHunt, at: Vector3) -> void:
	hunt.cam_lock = true
	hunt.cam_lock_pos = at + Vector3(0, 0.4, 0)
	hunt.cam_dist = 2.2
	hunt.cam_pitch = -0.32
	hunt._arm.collision_mask = 0


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	var hint := FileAccess.open(ProjectSettings.globalize_path(NightHunt.HINT_FILE), FileAccess.WRITE)
	if hint != null:
		hint.store_string("seen")
		hint.close()
	var hunt: NightHunt = HuntScene.instantiate()
	hunt.autostart = true
	hunt.seed_value = 42
	add_child(hunt)
	await _frames(24)
	var stand := hunt._window + Vector3(0, 0.08, 1.15)
	hunt.cat.global_position = stand
	hunt.cat.velocity = Vector3.ZERO
	var to := hunt._window - stand
	hunt.cat.rotation.y = TouchControls3D.yaw_to_face(Vector3(to.x, 0.0, to.z))
	_frame(hunt, hunt._window)
	await _frames(4)
	await _shot(hunt, "chatter")
	if hunt.litter_pos != Vector3.ZERO:
		hunt.cat.global_position = hunt.litter_pos
		hunt.cat.velocity = Vector3.ZERO
		if hunt.other != null:
			hunt.other._pos = hunt.litter_pos + Vector3(14.0, 0.0, 14.0)
			if hunt.other.body != null:
				hunt.other.body.global_position = hunt.other._pos
		_frame(hunt, hunt.litter_pos)
		await _frames(3)
		for _i in 6:
			hunt.cam_lock_pos = hunt.cat.global_position + Vector3(0, 0.4, 0)
			await get_tree().process_frame
		await _shot(hunt, "zoomies")
		hunt._zoom_t = 0.0
	if hunt.other != null and hunt.other.body != null and not hunt.covers.is_empty():
		var cover: Vector3 = hunt.covers[0]
		hunt.cat.global_position = cover + Vector3(6.0, 0.1, 6.0)
		hunt.cat.velocity = Vector3.ZERO
		hunt.other._pos = cover + Vector3(0, 0.05, 0)
		hunt.other.body.global_position = hunt.other._pos
		hunt.other._watch_t = 9.0
		if not hunt.mice.is_empty():
			var mouse: Node3D = hunt.mice[0]
			mouse.global_position = cover + Vector3(0, 0.02, -2.2)
		_frame(hunt, cover)
		await _frames(8)
		await _shot(hunt, "ambush")
	get_tree().quit()
