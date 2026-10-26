extends Node
## Night-ledger shots. Run under Xvfb:
##   xvfb-run godot --path godot3d res://zones/basement/tools_night_shots.tscn
## Saves screenshots/hunt/night_floor.png, moths.png, gift.png.


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
	print("SHOT ", name, " ", img.get_size())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	var hunt: NightHunt = HuntScene.instantiate()
	hunt.autostart = true
	hunt.seed_value = 42
	add_child(hunt)
	await _frames(40)
	# Pull the camera back enough to read Willie, the lamps, and the ledger.
	hunt.cam_dist = 7.2
	hunt.cam_pitch = -0.55
	await _frames(8)
	await _shot(hunt, "night_floor")
	if hunt.moths.size() > 0:
		var moth: Node3D = hunt.moths[0]
		hunt.cam_dist = 3.2
		hunt._rig.global_position = moth.global_position
		await _frames(6)
		await _shot(hunt, "moths")
	hunt.ledger.note_catch(1.0, true)
	hunt.ledger.note_catch(2.0, true)
	hunt.ledger.note_catch(3.0, false)
	hunt.debug_force_gift()
	hunt.cat.global_position = hunt.glenys_pos + Vector3(0, 0.12, -0.7)
	hunt.cat.velocity = Vector3.ZERO
	await _frames(6)
	hunt.cam_dist = 4.6
	await _frames(4)
	await _shot(hunt, "gift")
	get_tree().quit()
