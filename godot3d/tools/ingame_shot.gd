extends Node
## Grabs one frame of the live game for the fidelity report.
##   xvfb-run godot --path godot3d res://tools/ingame_shot.tscn -- --out /path.png

func _ready() -> void:
	var out := "res://screenshots/ingame.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 40:
		await get_tree().process_frame
	# Frame the player from a 3/4 front so the muzzle is in the shot
	# with the yard still behind him.
	var who := "willie"
	for i in args.size():
		if args[i] == "--who" and i + 1 < args.size():
			who = args[i + 1]
	var willie := game.find_child("Willie", true, false) as Node3D
	var aggie := game.find_child("Aggie", true, false) as Node3D
	var cat := aggie if who == "aggie" else willie
	if cat == null:
		cat = game.find_child("PvKCat", true, false) as Node3D
	var cam := get_viewport().get_camera_3d()
	if cat != null and cam != null:
		if who == "duo" and willie != null and aggie != null:
			# They spawn rooms apart. Park Aggie beside Willie for the
			# frame so both coats and her smaller scale are readable.
			aggie.set_physics_process(false)
			aggie.velocity = Vector3.ZERO
			var side := willie.global_transform.basis.x
			aggie.global_position = willie.global_position + side * 0.62 + Vector3(0, 0, 0.08)
			aggie.rotation.y = willie.rotation.y
			var focus := willie.global_position + side * 0.28 + Vector3(0, 0.2, 0)
			var forward := -willie.global_transform.basis.z
			cam.global_position = focus + forward * 1.35 + side * 0.15 + Vector3(0, 0.38, 0)
			cam.look_at(focus)
		else:
			var focus := cat.global_position + Vector3(0, 0.18, 0)
			var forward := -cat.global_transform.basis.z
			var right := cat.global_transform.basis.x
			cam.global_position = focus + forward * 0.85 + right * 0.36 + Vector3(0, 0.22, 0)
			cam.look_at(focus)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("INGAME ", out, " ", img.get_size(), " save ", err)
	get_tree().quit()
