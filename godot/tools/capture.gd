extends SceneTree

## Screenshot pass for Puppies vs Kittens (Godot edition).
##
## Run under a virtual display (NOT --headless):
##   xvfb-run -a -s "-screen 0 1200x1200x24" godot --path godot \
##       --resolution 1000x1000 -s res://tools/capture.gd
##
## Saves res://screenshots/splash.png, gameplay.png and bird.png.

var _game: Node = null


func _save(name: String) -> void:
    var img := root.get_texture().get_image()
    var err := img.save_png("res://screenshots/" + name + ".png")
    print("CAPTURE ", name, " err=", err, " size=", img.get_size())


func _initialize() -> void:
    var ps: PackedScene = load("res://main.tscn")
    _game = ps.instantiate()
    root.add_child(_game)
    await create_timer(1.0).timeout
    _save("splash")

    _game.start_round("medium")
    await create_timer(2.2).timeout
    # Stage a strike so the shot shows the fight stars and the wounded mouse.
    var mouse: Animal = _game.mice[0]
    _game.kitten.facing = Vector2.RIGHT
    mouse.position = _game.kitten.paw_point()
    _game.kitten.try_strike()
    await create_timer(0.3).timeout
    _save("gameplay")

    _game.toggle_bird_mode()
    var frames := 0
    while _game.player_bird.altitude < 0.85 and frames < 240:
        await physics_frame
        frames += 1
    _game.player_bird.try_strike() # dive
    await create_timer(0.42).timeout # catch it mid-dive, low over the field
    _save("bird")
    quit()
