extends Node
## Studio portrait of Willie (and Aggie beside him) for before/after
## fidelity shots. Same camera every run.
##   xvfb-run godot --path godot3d res://tools/willie_portrait.tscn -- --out /path.png

const CatScript := preload("res://cat_kit/cat.gd")


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "res://screenshots/willie_portrait.png"
	var face := false
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		elif args[i] == "--face":
			face = true
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.64)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -36, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.8, 0.86, 1.0)
	add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.2, 0.22)
	fm.roughness = 0.9
	floor.material_override = fm
	add_child(floor)
	var willie = CatScript.new()
	willie.name = "Willie"
	add_child(willie)
	# The portrait is a still. Physics gravity (22) drops the body
	# through the visual floor before the frame is grabbed.
	willie.set_physics_process(false)
	willie.set_process(false)
	willie.velocity = Vector3.ZERO
	willie.position = Vector3(-0.08, 0.0, 0.0)
	willie.rotation.y = 0.15
	var aggie = CatScript.new()
	aggie.name = "Aggie"
	aggie.set_character("aggie")
	add_child(aggie)
	aggie.set_physics_process(false)
	aggie.set_process(false)
	aggie.velocity = Vector3.ZERO
	aggie.position = Vector3(0.46, 0.0, 0.2)
	aggie.rotation.y = 0.45
	if face:
		aggie.visible = false
	var cam := Camera3D.new()
	cam.fov = 26.0 if face else 32.0
	cam.current = true
	add_child(cam)
	await get_tree().process_frame
	var focus := _face_focus(willie)
	var forward: Vector3 = -willie.global_transform.basis.z
	var right: Vector3 = willie.global_transform.basis.x
	if face:
		cam.look_at_from_position(focus + forward * 0.2 + right * 0.07 + Vector3(0, 0.025, 0), focus)
	else:
		cam.look_at_from_position(focus + forward * 0.42 + right * 0.16 + Vector3(0, 0.05, 0), focus + Vector3(0, -0.04, 0))
	print("FOCUS ", focus, " willie ", willie.global_position)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("PORTRAIT ", out, " ", img.get_size(), " save ", err, " shells ", willie.get("fur_shells"))
	get_tree().quit()


func _face_focus(cat: Node3D) -> Vector3:
	var sculpt = cat.get("_sculpt")
	if sculpt != null and sculpt.skeleton != null:
		var sk: Skeleton3D = sculpt.skeleton
		var hi := sk.find_bone("head")
		if hi >= 0:
			var origin: Vector3 = sk.to_global(sk.get_bone_global_pose(hi).origin)
			return origin + (-cat.global_transform.basis.z) * 0.045 + Vector3(0, 0.01, 0)
	return cat.global_position + Vector3(0, 0.25, 0)
