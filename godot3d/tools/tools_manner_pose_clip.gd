extends Node
## Cycles the nine manner fallbacks on Willie and writes a frame
## sequence plus a few stills.
##   xvfb-run godot --path godot3d res://tools/tools_manner_pose_clip.tscn

const CatScript := preload("res://cat_kit/cat.gd")


func _ready() -> void:
	_run()


func _run() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.15, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.4)
	env.ambient_light_energy = 0.6
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.04, 3.0)
	floor_mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.2)
	floor_mi.material_override = mat
	floor_mi.position = Vector3(0, -0.02, 0)
	add_child(floor_mi)
	var cat = CatScript.new()
	cat.position = Vector3(0, 0, 0)
	add_child(cat)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0.72, 0.36, -0.62)
	add_child(cam)
	cam.look_at(Vector3(0, 0.16, 0.02))
	var caption := Label3D.new()
	caption.font_size = 48
	caption.pixel_size = 0.0022
	caption.outline_size = 8
	caption.modulate = Color(0.96, 0.9, 0.78)
	caption.position = Vector3(0, 0.62, 0)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	add_child(caption)
	for _i in 10:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	DirAccess.make_dir_absolute("/tmp/manner_frames")
	var manners: Array[String] = ["chatter", "wiggle", "zoomies", "blink", "groom", "knead", "loaf", "greet", "ambush"]
	var frame_i := 0
	for manner in manners:
		cat.manner = manner
		cat.manner_k = 1.0
		caption.text = manner
		for step in 6:
			cat.manner_phase = float(step) * 0.16
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("/tmp/manner_frames/f_%03d.png" % frame_i)
			if step == 3 and manner in ["chatter", "greet", "ambush"]:
				img.save_png("res://screenshots/hunt/manner_%s.png" % manner)
			frame_i += 1
	print("POSE FRAMES ", frame_i)
	get_tree().quit()
