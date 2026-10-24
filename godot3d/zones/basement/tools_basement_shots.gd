extends Node
## Standing-shot pass for the Massey basement zone. Run under Xvfb
## (real rendering, unlike the headless tests):
##   xvfb-run godot --path godot3d res://zones/basement/tools_basement_shots.tscn
## Saves PNGs into res://zones/basement/screenshots/:
##   maze_overview, rat_pack, litter_box_corner, aggie_gap, ghost_block.

const ZoneScene := preload("res://zones/basement/basement.tscn")
const CatScript := preload("res://cat_kit/cat.gd")
const ZoneScript := preload("res://zones/basement/basement.gd")

var _zone = null
var _cam: Camera3D = null


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://zones/basement/screenshots/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _frame(pos: Vector3, look: Vector3) -> void:
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://zones/basement/screenshots")
	_zone = ZoneScene.instantiate()
	_zone.standalone_drive = false
	_zone.use_follow_cam = false
	add_child(_zone)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child(_cam)
	_cam.current = true
	await _wait(1.2)
	var cat = _zone.player_cat
	# Keep the set calm: dangers frozen, spare ghosts parked away.
	for r in _zone.rats:
		r.active = false
	for sp in _zone.spiders:
		sp.active = false
	for i in range(1, _zone.ghosts.size()):
		_zone.ghosts[i].global_position = Vector3(-7.4, 0, 5.5)
		_zone.ghosts[i].target_cat = null

	# (a) Maze overview: high corner inside the room, ceiling above us.
	cat.global_position = Vector3(4.35, 0.05, 5.0)
	_frame(Vector3(7.6, 2.18, 5.8), Vector3(-1.5, 0, -1.2))
	await _wait(0.5)
	await _shot("maze_overview")

	# (b) The rat pack at the heart: alpha + guards, HP bar up.
	cat.global_position = Vector3(-0.6, 0.05, -1.55)
	cat.rotation.y = PI * 0.55
	_frame(Vector3(-1.15, 0.55, -2.35), Vector3(1.15, 0.12, -2.0))
	await _wait(0.5)
	await _shot("rat_pack")

	# (c) The litter corner — box, and the gift beside it.
	cat.global_position = Vector3(-5.2, 0.05, -4.6)
	_frame(Vector3(-6.0, 0.4, -3.0), Vector3(-7.05, 0.04, -3.85))
	await _wait(0.5)
	await _shot("litter_box_corner")

	# (d) Aggie in the gap she alone fits through.
	var aggie = CatScript.new()
	aggie.set_character("aggie")
	add_child(aggie)
	ZoneScript.apply_fit_capsule(aggie)
	aggie.global_position = Vector3(4.42, 0.02, -2.5) # half through the slot
	aggie.rotation.y = -PI * 0.5
	cat.global_position = Vector3(2.7, 0.05, -3.3) # Willie watches, too big to follow
	_frame(Vector3(3.2, 0.3, -2.45), Vector3(4.55, 0.12, -2.5))
	await _wait(0.5)
	await _shot("aggie_gap")
	aggie.queue_free()

	# (e) Ghost block: Willie face to face with the tunnel-west ghost,
	# caught mid-hiss — arched, puffed, locked.
	var g = _zone.ghosts[0]
	g.global_position = Vector3(-3.5, 0, -0.5)
	g.set("_choke_i", 0)
	g.mode = "guard"
	g.set("_guard_t", 60.0)
	g.target_cat = cat
	cat.global_position = Vector3(-4.12, 0.05, -0.5)
	cat.rotation.y = -PI * 0.5
	_frame(Vector3(-4.85, 0.72, 1.1), Vector3(-3.75, 0.6, -0.5))
	# Let the ghost's contact timer force the hiss itself, then catch
	# the arch at its peak — the ghost has only begun to yield.
	var waited := 0.0
	while not (cat as PvKHissCat).is_hissing() and waited < 4.0:
		await _wait(0.1)
		waited += 0.1
	await _wait(0.55)
	await _shot("ghost_block")

	print("BASEMENT SHOTS DONE")
	get_tree().quit(0)
