extends Node
## Six frames of Willie's walk, side by side.
##   xvfb-run godot --path godot3d res://tools/willie_walk_strip.tscn -- --out /path.png

const CatScript := preload("res://cat_kit/cat.gd")


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "res://screenshots/willie_walk_strip.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.64)
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.4
	add_child(key)
	for i in 6:
		var cat = CatScript.new()
		cat.name = "Walk%d" % i
		add_child(cat)
		cat.set_physics_process(false)
		cat.set_process(false)
		cat.velocity = Vector3(0, 0, cat.sprint_speed * 0.34)
		cat.anim_state = "walk"
		cat.position = Vector3(-0.75 + i * 0.3, 0.0, 0.0)
		cat.rotation.y = PI * 0.5
		for _step in 5:
			cat._update_pose(1.0 / 20.0)
			await get_tree().process_frame
		# Freeze this phase. The next cat keeps walking from a later point.
		cat.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.28, 1.15), Vector3(0.0, 0.16, 0.0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("WALK ", out, " ", img.get_size(), " save ", err)
	get_tree().quit()
