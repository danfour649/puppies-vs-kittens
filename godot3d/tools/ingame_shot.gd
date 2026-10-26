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
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("INGAME ", out, " ", img.get_size(), " save ", err)
	get_tree().quit()
