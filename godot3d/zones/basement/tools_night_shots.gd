extends Node
## Night-ledger shots. Run under Xvfb:
##   xvfb-run godot --path godot3d res://zones/basement/tools_night_shots.tscn
## Saves screenshots/hunt/night_floor.png, night_label.png, moths.png, gift.png.


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
	var cam := hunt.get_viewport().get_camera_3d()
	var note := ""
	if cam != null and hunt.cat != null:
		var dist := cam.global_position.distance_to(hunt.cat.global_position)
		var screen := cam.unproject_position(hunt.cat.global_position + Vector3(0, 0.2, 0))
		note = " dist %.2f screen %s" % [dist, screen]
	var named := ""
	if cam != null:
		for lab: Variant in hunt.keepsake_labels:
			var l := lab as Label3D
			if l.visible:
				var at := cam.unproject_position(l.global_position)
				named = "%s a=%.2f at %s" % [l.text, l.modulate.a, at]
	print("SHOT ", name, " ", img.get_size(), note, " label: ", named)


func _cell_open(hunt: NightHunt, pos: Vector3) -> bool:
	var map: Array = hunt.level["map"]
	var c := int(floor(pos.x - HoarderGenerator.GRID_MIN.x))
	var r := int(floor(pos.z - HoarderGenerator.GRID_MIN.y))
	if r < 0 or r >= map.size():
		return false
	var row := String(map[r])
	if c < 0 or c >= row.length():
		return false
	var ch := row.substr(c, 1)
	return ch != "#" and ch != "G"


func _frame_label(hunt: NightHunt) -> bool:
	hunt._arm.collision_mask = 0
	hunt.cam_lock = false
	hunt.cam_yaw = PI
	hunt.cam_pitch = -0.36
	hunt.cam_dist = 1.85
	var offsets: Array[Vector3] = [Vector3(0, 0.08, -1.05), Vector3(0, 0.08, -1.4)]
	for i in hunt.keepsake_points.size():
		var p: Vector3 = hunt.keepsake_points[i]
		for off: Vector3 in offsets:
			var stand := p + off
			if not _cell_open(hunt, stand) or not _cell_open(hunt, stand + Vector3(0, 0, -0.9)):
				continue
			hunt.cat.global_position = stand
			hunt.cat.velocity = Vector3.ZERO
			await _frames(8)
			var cam := hunt.get_viewport().get_camera_3d()
			var lab: Label3D = hunt.keepsake_labels[i]
			if cam == null or not lab.visible or cam.is_position_behind(lab.global_position):
				continue
			var at := cam.unproject_position(lab.global_position)
			var willie := cam.unproject_position(hunt.cat.global_position + Vector3(0, 0.18, 0))
			var vp := hunt.get_viewport().get_visible_rect().size
			var label_ok := at.x > 80 and at.x < vp.x - 80 and at.y > 24 and at.y < vp.y * 0.58
			var willie_ok := willie.y > vp.y * 0.3 and willie.y < vp.y * 0.86
			print("LABEL TRY ", lab.text, " at ", at, " willie ", willie)
			if label_ok and willie_ok:
				return true
	return false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	# The floor shot is about the keepsake name, so the first-night hint stays down.
	var hint_path := ProjectSettings.globalize_path(NightHunt.HINT_FILE)
	var hint_file := FileAccess.open(hint_path, FileAccess.WRITE)
	if hint_file != null:
		hint_file.store_string("seen")
		hint_file.close()
	var hunt: NightHunt = HuntScene.instantiate()
	hunt.autostart = true
	hunt.seed_value = 42
	add_child(hunt)
	await _frames(40)
	# The floor shot is the default camera: Willie framed, the paw stick, one name at most.
	await _frames(8)
	await _shot(hunt, "night_floor")
	if await _frame_label(hunt):
		await _shot(hunt, "night_label")
	else:
		print("LABEL TRY none in frame")
	hunt._arm.collision_mask = 1
	if hunt.moths.size() > 0:
		var moth: Node3D = hunt.moths[0]
		hunt.cam_lock = true
		hunt.cam_dist = 1.15
		hunt.cam_pitch = -0.22
		for _i in 10:
			hunt.cam_lock_pos = moth.global_position
			await get_tree().process_frame
		await _shot(hunt, "moths")
		hunt.cam_lock = false
		hunt.cam_dist = 1.25
		hunt.cam_pitch = -0.5
	hunt.ledger.note_catch(1.0, true)
	hunt.ledger.note_catch(2.0, true)
	hunt.ledger.note_catch(3.0, false)
	hunt.debug_force_gift()
	hunt.cat.global_position = hunt.glenys_pos + Vector3(0, 0.12, -0.7)
	hunt.cat.velocity = Vector3.ZERO
	hunt.cam_lock = true
	hunt.cam_lock_pos = hunt.glenys_pos + Vector3(0, 0.75, -0.35)
	hunt.cam_dist = 3.1
	hunt.cam_pitch = -0.3
	hunt._arm.collision_mask = 0
	await _frames(8)
	await _shot(hunt, "gift")
	get_tree().quit()
