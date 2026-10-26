extends Node
## Stills of the lived-in floors and the yard. Under Xvfb, GL
## Compatibility, so the shots match the web renderer:
##   xvfb-run godot --path godot3d --rendering-method gl_compatibility res://tools/tools_levels_shots.tscn

const GroundScene := preload("res://zones/ground_floor/ground_floor.tscn")
const AtticScene := preload("res://zones/attic/attic.tscn")

var _cam: Camera3D


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/levels/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _frame(pos: Vector3, look: Vector3) -> void:
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)


func _sun(energy: float, color: Color, rot: Vector3) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = rot
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = false
	add_child(sun)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots/levels"))
	_cam = Camera3D.new()
	_cam.fov = 58.0
	add_child(_cam)
	_cam.current = true

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.12, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.32, 0.28)
	env.ambient_light_energy = 0.45
	we.environment = env
	add_child(we)

	_sun(0.35, LightMood.window_color("ground_floor"), Vector3(-28, -40, 0))
	var ground := GroundScene.instantiate()
	add_child(ground)
	await _wait(0.6)
	# South-east window and the living-room side of the dusk floor.
	_frame(Vector3(-0.6, 2.05, 0.4), Vector3(4.6, 1.15, 3.4))
	await _wait(0.3)
	await _shot("ground_dusk")
	# Open cell (8, 4) looking north at the stack on (8, 5), steps included.
	_frame(Vector3(0.5, 0.85, 0.15), Vector3(0.5, 0.7, 1.55))
	await _wait(0.25)
	await _shot("ground_stacks")
	ground.queue_free()
	await _wait(0.2)

	env.background_color = Color(0.22, 0.16, 0.14)
	env.ambient_light_color = Color(0.55, 0.40, 0.34)
	var attic: Node3D = AtticScene.instantiate()
	add_child(attic)
	await _wait(0.6)
	# Dawn window on the east gable, with the central stack in the foreground.
	_frame(Vector3(-0.4, 1.55, 2.6), Vector3(3.8, 1.25, -0.2))
	await _wait(0.3)
	await _shot("attic_dawn")
	attic.queue_free()
	await _wait(0.2)

	env.background_color = Color(0.45, 0.55, 0.72)
	env.ambient_light_color = Color(0.62, 0.58, 0.5)
	env.ambient_light_energy = 0.7
	var yard := Node3D.new()
	add_child(yard)
	var grass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(26, 0.2, 20)
	grass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.32, 0.5, 0.22)
	grass.material_override = gmat
	grass.position = Vector3(0, -0.1, 0)
	yard.add_child(grass)
	var life := YardLife.new()
	yard.add_child(life)
	life.build()
	# In front of the shed door, so the climb crates and the rail show.
	_frame(Vector3(-3.4, 1.45, -4.35), Vector3(-5.8, 0.75, -6.7))
	await _wait(0.35)
	await _shot("yard_shed")
	_frame(Vector3(-2.2, 1.2, 3.85), Vector3(-3.3, 0.25, 1.5))
	await _wait(0.25)
	await _shot("yard_garden")

	print("LEVEL SHOTS DONE")
	get_tree().quit(0)
