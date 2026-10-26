extends Node
## Manner stills on the ground floor, where the living room is
## hardwood and the house lights are already on. The camera here
## belongs to the shot, not to the game.
##   xvfb-run godot --path godot3d res://zones/basement/tools_manner_closeups.tscn -- --quality high

const FloorScene := preload("res://zones/ground_floor/ground_floor.tscn")
const CatScript := preload("res://cat_kit/cat.gd")

var _cat: Node3D
var _manner := ""
var _phase := 0.0
var _frame_i := 0
var _hold: Array[Node3D] = []
var _hold_at: Array[Vector3] = []
var _cam: Camera3D
var _fill: OmniLight3D


func _ready() -> void:
	process_priority = -50
	_run()


func _process(_delta: float) -> void:
	if _cat == null:
		return
	_cat.set("manner", _manner)
	_cat.set("manner_k", 1.0)
	_cat.set("manner_phase", _phase)
	_cat.set("idle_time", 0.0)
	_cat.set("_sit_k", 0.0)
	for i in _hold.size():
		var body := _hold[i]
		if body == null:
			continue
		body.global_position = _hold_at[i]
		body.velocity = Vector3.ZERO
	if _fill != null and _cat != null:
		var mesh := _mesh(_cat)
		if mesh != null:
			var center := (mesh.global_transform * mesh.get_aabb()).get_center()
			_fill.global_position = center + Vector3(-0.15, 0.42, 0.28)


func _run() -> void:
	var q := get_node_or_null("/root/VisualQuality")
	print("TIER ", q.tier_name if q != null else "?", " ", RenderingServer.get_current_rendering_method())
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.56, 0.48)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.72, 0.62)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	add_child(world)
	var floor := FloorScene.instantiate()
	add_child(floor)
	await _frames(8)
	var living := HouseSpec.anchor("living", "pvk")
	# Just south of the room centre, on the hardwood side of the divider.
	var spot := Vector3(living.x, 0.02, 0.35)
	var willie = CatScript.new()
	willie.name = "Willie"
	add_child(willie)
	var aggie = CatScript.new()
	aggie.name = "Aggie"
	aggie.set_character("aggie")
	add_child(aggie)
	willie.rotation.y = 0.35
	aggie.rotation.y = 0.35
	willie.global_position = spot
	aggie.global_position = spot + Vector3(1.6, 0.0, 1.4)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.current = true
	add_child(_cam)
	_fill = OmniLight3D.new()
	_fill.light_color = Color(1.0, 0.94, 0.86)
	_fill.light_energy = 0.55
	_fill.omni_range = 2.2
	_fill.shadow_enabled = false
	add_child(_fill)
	await _frames(24)
	willie.velocity = Vector3.ZERO
	aggie.velocity = Vector3.ZERO
	_report(willie, "willie")
	_report(aggie, "aggie")
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	DirAccess.make_dir_absolute("/tmp/manner_close")
	var shots: Array[Dictionary] = [
		{"who": willie, "name": "willie_greet", "manner": "greet", "phase": 0.0},
		{"who": willie, "name": "willie_chatter", "manner": "chatter", "phase": 0.55},
		{"who": aggie, "name": "aggie_greet", "manner": "greet", "phase": 0.0},
		{"who": aggie, "name": "aggie_loaf", "manner": "loaf", "phase": 0.0},
	]
	for shot in shots:
		var hero: Node3D = shot["who"]
		var other: Node3D = aggie if hero == willie else willie
		_pin(other, spot + Vector3(4.0, 0.0, 3.0))
		_pin(hero, spot)
		hero.rotation.y = 0.35
		_cat = hero
		_manner = str(shot["manner"])
		_phase = float(shot["phase"])
		for _step in 6:
			_frame_on(hero)
			await _frames(1)
		await _grab(str(shot["name"]))
	print("CLOSEUPS ", _frame_i)
	get_tree().quit()


func _pin(cat: Node3D, at: Vector3) -> void:
	if cat == null:
		return
	cat.global_position = at
	cat.velocity = Vector3.ZERO
	var found := false
	for i in _hold.size():
		if _hold[i] == cat:
			_hold_at[i] = at
			found = true
	if not found:
		_hold.append(cat)
		_hold_at.append(at)


func _report(cat: Node3D, who: String) -> void:
	var body := _mesh(cat)
	if body == null:
		print("NOMESH ", who)
		return
	var aabb := body.global_transform * body.get_aabb()
	print("BODY ", who, " shells ", cat.get("fur_shells"), " center ", aabb.get_center(), " size ", aabb.size, " at ", cat.global_position)


func _mesh(cat: Node3D) -> MeshInstance3D:
	var sculpt = cat.get("_sculpt")
	if sculpt == null:
		return null
	return sculpt.body as MeshInstance3D


func _frame_on(cat: Node3D) -> void:
	var body := _mesh(cat)
	if body == null or _cam == null:
		return
	var aabb := body.global_transform * body.get_aabb()
	var center := aabb.get_center()
	var side: Vector3 = cat.global_transform.basis.x
	var fwd: Vector3 = -cat.global_transform.basis.z
	# Chest height, a little in front and to the side, so the neck,
	# the full leg, and a raised tail all sit in the frame.
	# Mostly side-on, so the neck, the full leg, and the tail's hook
	# are not foreshortened. A little forward bias keeps one eye in frame.
	var from := center + side * 0.9 + fwd * 0.28 + Vector3(0.0, 0.02, 0.0)
	_cam.look_at_from_position(from, center + Vector3(0.0, 0.0, 0.0))


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/manner_close/f_%03d.png" % _frame_i)
	_frame_i += 1
	img.save_png("res://screenshots/hunt/manner_%s.png" % name)
	print("SHOT ", name, " ", img.get_size(), " cat ", _cat.global_position if _cat != null else Vector3.ZERO)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
