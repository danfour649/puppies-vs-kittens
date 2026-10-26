extends Node
## One frame of a floor, for the house report.
##   xvfb-run godot --path godot3d res://tools/floor_shot.tscn -- --floor ground --out /tmp/floor.png


func _ready() -> void:
	var floor_id := "ground"
	var out := "/tmp/floor.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--floor" and i + 1 < args.size():
			floor_id = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	var scene_path := "res://zones/ground_floor/ground_floor.tscn"
	var eye := Vector3(2.4, 1.45, 1.5)
	var at := Vector3(4.6, 0.45, -2.4)
	if floor_id == "basement":
		scene_path = "res://zones/basement/basement.tscn"
		# South corridor sits inside the shell (z about 4.15). Look north into the maze.
		eye = Vector3(2.2, 1.22, 3.72)
		at = Vector3(0.15, 0.38, 0.6)
	elif floor_id == "attic":
		scene_path = "res://zones/attic/attic.tscn"
		eye = Vector3(2.2, 1.25, 2.4)
		at = Vector3(-0.8, 0.35, -1.0)
	var zone := (load(scene_path) as PackedScene).instantiate()
	add_child(zone)
	# The zone keeps its own bulbs. A weak cool fill only stops the
	# frame from going black; it does not repaint the basement.
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.78, 0.82, 0.9)
	fill.light_energy = 0.12 if floor_id == "basement" else 0.35
	fill.omni_range = 28.0
	fill.position = eye + Vector3(0, 0.4, 0)
	fill.shadow_enabled = false
	add_child(fill)
	for i in 12:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 50
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(eye, at)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("FLOOR ", floor_id, " ", out, " ", img.get_size(), " save ", err)
	get_tree().quit()
