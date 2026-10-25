extends Node
## SELECT PRESENTATION — portrait renders for the roster cells.
## Run with real rendering (weston/wayland on fola4.0):
##   godot --display-driver wayland --path godot3d \
##     res://duo/tools_portrait_shots.tscn --resolution 800x800
##
## Builds each roster cat EXACTLY the way the select stage does
## (cat_kit actor + set_character + DuoCharacters.apply) on a small
## portrait set — warm key spot, cool rim, halo backdrop disc — and
## frames the camera on the cat's real Head node: a tight
## head-and-shoulders MK-style portrait. PNGs land in
## res://duo/portraits/<id>.png and are committed as game assets.

const CatScene := preload("res://cat_kit/cat.gd")

const OUT_DIR := "res://duo/portraits"
const VIEW := Vector2i(512, 608)
## Visible height at the head plane, as a multiple of the cat's model
## scale: ~2.1x the head span (skull + ears), bust crop below.
const FRAME_H_SCALES := 0.64
const CAM_FOV := 38.0

var _viewport: SubViewport
var _holder: Node3D


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _build_set() -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = VIEW
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var root := Node3D.new()
	_viewport.add_child(root)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.030, 0.028, 0.042)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.15, 0.19)
	env.ambient_light_energy = 0.7
	we.environment = env
	root.add_child(we)

	# Backdrop wall + the halo the head sits against.
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.055, 0.050, 0.075)
	wall_mat.roughness = 1.0
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(6, 4, 0.2)
	wall_mesh.material = wall_mat
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 1.0, 0.85)
	root.add_child(wall)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0.20, 0.15, 0.05)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.55, 0.40, 0.12)
	halo_mat.emission_energy_multiplier = 0.5
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.30
	halo_mesh.height = 0.60
	halo_mesh.radial_segments = 48
	halo_mesh.rings = 24
	halo_mesh.material = halo_mat
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.scale = Vector3(1.0, 1.0, 0.10)
	halo.name = "Halo"
	root.add_child(halo)

	# Floor the cat stands on (catches the key light pool).
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.05, 0.048, 0.06)
	floor_mat.roughness = 0.8
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6, 0.1, 6)
	floor_mesh.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(0, -0.05, 0)
	root.add_child(floor_mi)
	# Still floor for the cat's feet (same trick as the select stage).
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(4, 0.1, 4)
	shape.shape = fb
	shape.position = Vector3(0, -0.05, 0)
	body.add_child(shape)
	root.add_child(body)

	# Light rig: the select stage's voices, moved in for the bust.
	var spot := SpotLight3D.new()
	spot.position = Vector3(-0.55, 0.95, -0.62)
	spot.light_color = Color(1.0, 0.92, 0.78)
	spot.light_energy = 4.2
	spot.spot_range = 6.0
	spot.spot_angle = 40.0
	spot.spot_attenuation = 1.1
	spot.shadow_enabled = true
	root.add_child(spot)
	spot.look_at(Vector3(0, 0.22, 0), Vector3.UP)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.45, 0.42, 0.55)
	rim.light_color = Color(0.50, 0.65, 1.0)
	rim.light_energy = 1.4
	rim.omni_range = 3.0
	root.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.12, 0.28, -0.55)
	fill.light_color = Color(1.0, 0.95, 0.85)
	fill.light_energy = 0.8
	fill.omni_range = 2.5
	root.add_child(fill)

	_holder = Node3D.new()
	root.add_child(_holder)


func _portrait(id: String, ch: Dictionary) -> void:
	for c: Node in _holder.get_children():
		c.queue_free()
	await _wait(0.1)
	var cat := CatScene.new() as PvKCat
	cat.set_character(id)
	DuoCharacters.apply(cat, ch)
	cat.name = String(ch.get("name", id))
	_holder.add_child(cat)
	await _wait(0.45) # model built, standing idle, facing camera (-Z)
	var head := cat.find_child("Head", true, false) as Node3D
	if head == null:
		print("PORTRAIT FAIL ", id, ": no Head node")
		return
	var s := float(cat.model_scale)
	var hp := head.global_position
	# Halo centred on the head, just in front of the wall.
	var halo := _viewport.find_child("Halo", true, false) as Node3D
	if halo != null:
		var hs := 1.30 * s / 0.35
		halo.scale = Vector3(hs, hs, 0.10)
		halo.global_position = Vector3(hp.x, hp.y + 0.01, 0.72)
	# Frame: visible height FRAME_H_SCALES * s at the head plane.
	var dist := (FRAME_H_SCALES * s) / (2.0 * tan(deg_to_rad(CAM_FOV * 0.5)))
	var cam := Camera3D.new()
	cam.fov = CAM_FOV
	cam.position = Vector3(hp.x, hp.y + 0.04 * s, hp.z - dist)
	_viewport.add_child(cam)
	cam.look_at(Vector3(hp.x, hp.y - 0.03 * s, hp.z), Vector3.UP)
	cam.current = true
	print(
		"PORTRAIT ", id, " scale=", s, " head=", hp,
		" dist=", snappedf(dist, 0.001), " cam=", cam.position
	)
	# Freeze the pose (standing, front-on) and let the frame settle.
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	img.save_png(OUT_DIR + "/" + id + ".png")
	print("PORTRAIT saved ", id, " ", img.get_size())
	cam.queue_free()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_build_set()
	var chars := DuoCharacters.load_all()
	for id: String in ["willie", "aggie"]:
		await _portrait(id, chars.get(id, {}))
	print("PORTRAITS DONE")
	get_tree().quit()
