extends Node
## One frame of a floor, for the house report.
##   xvfb-run godot --path godot3d res://tools/floor_shot.tscn -- --floor ground --out /tmp/floor.png


func _ready() -> void:
	var floor_id := "ground"
	var out := "/tmp/floor.png"
	var height_mode := "stand"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--floor" and i + 1 < args.size():
			floor_id = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		elif args[i] == "--height" and i + 1 < args.size():
			height_mode = args[i + 1]
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
	if height_mode == "cat":
		eye.y = 0.5
		at.y = 0.22
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
	_quiet_for_review(zone)
	var cam := Camera3D.new()
	cam.fov = 50
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(eye, at)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("FLOOR ", floor_id, " ", height_mode, " ", out, " ", img.get_size(), " save ", err)
	get_tree().quit()


## Review frames show the rooms. World labels and the basement
## ghost figures stay in the game; they stay out of these shots.
func _quiet_for_review(zone: Node) -> void:
	for n: Node in zone.find_children("*", "Label3D", true, false):
		n.visible = false
	for n: Node in zone.find_children("*", "", true, false):
		var path := ""
		if n.get_script() != null:
			path = String(n.get_script().resource_path)
		if n is PvKGhost or path.ends_with("ghost.gd"):
			n.visible = false
		elif n is MeshInstance3D and _debug_figure(n as MeshInstance3D):
			n.visible = false


func _debug_figure(mi: MeshInstance3D) -> bool:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null or mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		return false
	var c := mat.albedo_color
	return c.a < 0.85 and c.r > 0.7 and c.b > 0.55 and c.g < 0.75
