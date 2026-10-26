extends Node
## Frames the sculpted body and saves a fur-off and a fur-on shot.
##   xvfb-run godot --path godot3d res://tools/sculpt_frame.tscn -- --out /path.png

func _ready() -> void:
	var out := "/tmp/sculpt_frame.png"
	var args := OS.get_cmdline_user_args()
	var fur := true
	var spins := 0
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		if args[i] == "--nofur":
			fur = false
		if args[i] == "--spin" and i + 1 < args.size():
			spins = int(args[i + 1])
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.4
	add_child(key)
	var cat_script = load("res://cat_kit/cat.gd")
	var cat = cat_script.new()
	add_child(cat)
	cat.set_physics_process(false)
	cat.set_process(false)
	if not fur:
		for node in cat.find_children("FurShell", "MeshInstance3D", true, false):
			(node as Node3D).visible = false
	var sculpt = cat.get("_sculpt")
	var mesh_node: MeshInstance3D = sculpt.body
	var aabb: AABB = mesh_node.global_transform * mesh_node.get_aabb()
	print("AABB ", aabb, " size ", aabb.size, " bones ", sculpt.skeleton.get_bone_count())
	var center: Vector3 = aabb.get_center()
	var cam := Camera3D.new()
	cam.fov = 32
	cam.current = true
	add_child(cam)
	cam.look_at_from_position(center + Vector3(aabb.size.x * 1.1 + 0.15, aabb.size.y * 0.35, aabb.size.z * 0.9 + 0.25), center)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if spins > 1:
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		for s in spins:
			cat.rotation.y = TAU * float(s) / float(spins)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.save_png("%s/frame_%02d.png" % [out.get_base_dir(), s])
		print("SPIN ", spins, " ", out.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	print("FRAME ", out, " ", img.get_size(), " ", img.save_png(out))
	get_tree().quit()
