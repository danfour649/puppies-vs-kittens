extends Node
## One frame of the prey rules: a songbird's alarm, then the flush
## toward the window, with Willie close enough to be the reason.
##   xvfb-run godot --path godot3d res://zones/basement/tools_prey_shots.tscn


const HuntScene := preload("res://zones/basement/night_hunt.tscn")


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


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
	await _frames(30)
	if hunt.birds.is_empty() or hunt.cat == null:
		print("PREY SHOT missing cast")
		get_tree().quit()
		return
	var bird: Songbird = hunt.birds[0]
	hunt.cat.global_position = bird.global_position + Vector3(0.7, 0.0, 0.4)
	hunt.cat.velocity = Vector3.ZERO
	hunt.cam_lock = true
	hunt.cam_lock_pos = bird.global_position + Vector3(0, 0.35, 0)
	hunt.cam_dist = 2.4
	hunt.cam_pitch = -0.28
	hunt._arm.collision_mask = 0
	var caption := Label3D.new()
	caption.text = "alarm"
	caption.font_size = 48
	caption.pixel_size = 0.004
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.outline_size = 10
	caption.modulate = Color(0.98, 0.95, 0.86)
	caption.position = bird.global_position + Vector3(0, 0.55, 0)
	hunt.add_child(caption)
	await _frames(6)
	var states := ""
	for b: Variant in hunt.birds:
		var sb := b as Songbird
		states += sb.state + " "
		if sb.state == "alarm" or sb.state == "panic_light":
			caption.text = sb.state.replace("_", " ")
			caption.position = sb.global_position + Vector3(0, 0.55, 0)
	print("PREY BIRDS ", states)
	await _frames(2)
	for _i in 2:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/hunt/prey_alarm.png")
	print("SHOT prey_alarm ", img.get_size())
	get_tree().quit()
