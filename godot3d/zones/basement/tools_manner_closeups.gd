extends Node
## Close-ups of Willie and Aggie in the night basement, desktop mesh.
## The studio grab missed them: the cat is a physics body, that floor
## had no collision, and gravity had dropped him out of frame.
##   xvfb-run godot --path godot3d res://zones/basement/tools_manner_closeups.tscn -- --quality high

const HuntScene := preload("res://zones/basement/night_hunt.tscn")

var _hunt: NightHunt
var _cat: Node3D
var _manner := ""
var _phase := 0.0
var _frame_i := 0
var _hold: Array[Node3D] = []
var _hold_at: Array[Vector3] = []
var _fill: OmniLight3D


func _ready() -> void:
	process_priority = 100
	_run()


func _process(_delta: float) -> void:
	if _hunt == null or _cat == null:
		return
	_cat.set("manner", _manner)
	_cat.set("manner_k", 1.0)
	_cat.set("manner_phase", _phase)
	_cat.set("idle_time", 0.0)
	_cat.set("_sit_k", 0.0)
	_hunt._zoom_t = 0.0
	if _hunt._manner_label != null:
		_hunt._manner_label.visible = false
	if _hunt.other != null and _hunt.other._manner_label != null:
		_hunt.other._manner_label.visible = false
	for i in _hold.size():
		var body := _hold[i]
		if body == null:
			continue
		body.global_position = _hold_at[i]
		body.velocity = Vector3.ZERO
		body.rotation.y = PI
	if _fill != null and _cat != null:
		var mesh := _mesh(_cat)
		if mesh != null:
			var center := (mesh.global_transform * mesh.get_aabb()).get_center()
			_fill.global_position = center + Vector3(0.2, 0.55, 0.35)


func _run() -> void:
	var hint := FileAccess.open(ProjectSettings.globalize_path(NightHunt.HINT_FILE), FileAccess.WRITE)
	if hint != null:
		hint.store_string("seen")
		hint.close()
	var q := get_node_or_null("/root/VisualQuality")
	print("TIER ", q.tier_name if q != null else "?", " ", RenderingServer.get_current_rendering_method())
	_hunt = HuntScene.instantiate()
	_hunt.autostart = true
	_hunt.seed_value = 42
	add_child(_hunt)
	await _frames(36)
	if _hunt._ui != null:
		_hunt._ui.visible = false
	for lab in _hunt.keepsake_labels:
		(lab as Node3D).visible = false
	if _hunt.other != null:
		_hunt.other.set_process(false)
	var willie := _hunt.cat
	willie.velocity = Vector3.ZERO
	await _frames(8)
	willie.velocity = Vector3.ZERO
	willie.rotation.y = PI
	var home := willie.global_position
	_fill = OmniLight3D.new()
	_fill.light_color = Color(1.0, 0.93, 0.84)
	_fill.light_energy = 1.4
	_fill.omni_range = 2.4
	_fill.shadow_enabled = false
	add_child(_fill)
	_report(willie, "willie")
	if _hunt.other != null and _hunt.other.body != null:
		_report(_hunt.other.body, "aggie")
	DirAccess.make_dir_recursive_absolute("res://screenshots/hunt")
	DirAccess.make_dir_absolute("/tmp/manner_close")
	var manners: Array[String] = ["chatter", "wiggle", "zoomies", "blink", "groom", "knead", "loaf", "greet", "ambush"]
	var peaks := {
		"chatter": 0.5, "wiggle": 0.11, "zoomies": 0.2, "blink": 0.92,
		"groom": 0.0, "knead": 0.46, "loaf": 0.0, "greet": 0.0, "ambush": 0.0,
	}
	for manner in manners:
		_pin(_hunt.other.body if _hunt.other != null else null, home + Vector3(6.0, 0.0, 6.0))
		_pin(willie, home)
		_cat = willie
		_manner = manner
		for step in 5:
			_phase = float(peaks[manner]) + float(step) * 0.08
			_frame_on(willie)
			await _frames(1)
			await _grab(step == 3, "willie_%s" % manner)
	if _hunt.other != null and _hunt.other.body != null:
		var aggie := _hunt.other.body
		for manner in manners:
			_pin(willie, home + Vector3(6.0, 0.0, 6.0))
			_pin(aggie, home)
			_cat = aggie
			_manner = manner
			for step in 5:
				_phase = float(peaks[manner]) + float(step) * 0.08
				_frame_on(aggie)
				await _frames(1)
				await _grab(step == 3, "aggie_%s" % manner)
	print("CLOSEUPS ", _frame_i)
	get_tree().quit()


func _pin(cat: Node3D, at: Vector3) -> void:
	if cat == null:
		return
	cat.global_position = at
	cat.velocity = Vector3.ZERO
	cat.rotation.y = PI
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
	print("BODY ", who, " ", body.name, " faces ", body.mesh.get_faces().size() if body.mesh != null else -1, " center ", aabb.get_center(), " size ", aabb.size, " at ", cat.global_position)


func _mesh(cat: Node3D) -> MeshInstance3D:
	var sculpt = cat.get("_sculpt")
	if sculpt == null:
		return null
	return sculpt.body as MeshInstance3D


func _frame_on(cat: Node3D) -> void:
	var body := _mesh(cat)
	if body == null or _hunt == null:
		return
	var aabb := body.global_transform * body.get_aabb()
	var center := aabb.get_center()
	_hunt.cam_lock = true
	_hunt.cam_lock_pos = center
	_hunt.cam_dist = clampf(maxf(aabb.size.x, aabb.size.z) * 2.05, 0.62, 1.35)
	_hunt.cam_pitch = -0.48
	_hunt.cam_yaw = cat.rotation.y + PI * 0.72
	_hunt._rig.global_position = center
	if _hunt._arm != null:
		_hunt._arm.collision_mask = 0


func _grab(still: bool, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/manner_close/f_%03d.png" % _frame_i)
	_frame_i += 1
	if still:
		img.save_png("res://screenshots/hunt/manner_%s.png" % name)
		print("SHOT ", name, " ", img.get_size(), " cat ", _cat.global_position if _cat != null else Vector3.ZERO)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
