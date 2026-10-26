extends Node
## One frame of the character-select stage, Willie under the spot.
##   xvfb-run godot --path godot3d res://tools/select_shot.tscn -- --out /path.png


func _ready() -> void:
	var out := "/tmp/select_willie.png"
	var who := "willie"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		elif args[i] == "--who" and i + 1 < args.size():
			who = args[i + 1]
	var stage = load("res://duo/select_stage.gd").new()
	stage.name = "SelectStage"
	add_child(stage)
	stage.setup(DuoCharacters.load_all(), ["willie", "aggie"])
	stage.show_character(who)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("SELECT ", out, " ", img.get_size(), " ", img.save_png(out))
	get_tree().quit()
