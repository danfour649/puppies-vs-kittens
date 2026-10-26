extends Node
## Scripted playthrough for CI. Run under Xvfb, not --headless,
## so the viewport actually draws:
##   xvfb-run godot --rendering-method gl_compatibility --path godot3d res://tools/playthrough.tscn
## Walks the yard through the front door, then into the basement
## and the attic. Writes PNGs plus stats.json where PLAYTHROUGH_OUT
## points (default res://build/playthrough).

var _game = null
var _samples: Array[float] = []
var _recording := false
var _out := ""
var _legs: Array = []
var _failed := false


func _ready() -> void:
	_out = OS.get_environment("PLAYTHROUGH_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("res://build/playthrough")
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _process(delta: float) -> void:
	if _recording:
		_samples.append(delta * 1000.0)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _record(on: bool) -> void:
	if on:
		_samples = []
	_recording = on


func _stats() -> Dictionary:
	var s: Array = _samples.duplicate()
	s.sort()
	if s.is_empty():
		return {"n": 0, "mean_ms": 0.0, "median_ms": 0.0, "p95_ms": 0.0}
	var sum := 0.0
	for v in s:
		sum += float(v)
	var p95: float = s[mini(s.size() - 1, int(float(s.size()) * 0.95))]
	return {
		"n": s.size(),
		"mean_ms": sum / float(s.size()),
		"median_ms": float(s[s.size() / 2]),
		"p95_ms": p95,
	}


func _shot(shot_name: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 8:
		print("PLAYTHROUGH FAIL shot ", shot_name, " has no image")
		_failed = true
		return false
	var probe := img.duplicate()
	probe.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	var lo := 1.0
	var hi := 0.0
	for y in 16:
		for x in 16:
			var lum: float = probe.get_pixel(x, y).get_luminance()
			lo = minf(lo, lum)
			hi = maxf(hi, lum)
	img.save_png(_out.path_join(shot_name + ".png"))
	var small := img.duplicate()
	small.resize(480, 270, Image.INTERPOLATE_LANCZOS)
	small.save_png(_out.path_join(shot_name + "_small.png"))
	var spread := hi - lo
	print("PLAYTHROUGH shot ", shot_name, " ", img.get_size(), " spread ", snappedf(spread, 0.01))
	if spread < 0.04:
		print("PLAYTHROUGH FAIL shot ", shot_name, " looks blank")
		_failed = true
		return false
	return true


func _stop() -> void:
	_game.input_override = {"active": false, "move": Vector2.ZERO, "sprint": false, "stalk": false}


func _walk(zone_id: String, move: Vector2, limit: int) -> int:
	_game.cam_yaw = PI
	_game.input_override = {"active": true, "move": move, "sprint": true, "stalk": false}
	var n := 0
	while _game.zones.current_zone != zone_id and n < limit:
		await get_tree().physics_frame
		n += 1
	_stop()
	return n


func _settle() -> void:
	var n := 0
	while _game.zones.travelling and n < 180:
		await get_tree().physics_frame
		n += 1
	# Arrival cooldown is 1.2 s. The next connector needs can_travel().
	await _physics(80)


func _leg(leg_name: String, zone_id: String) -> void:
	_record(true)
	await _physics(40)
	_record(false)
	var st: Dictionary = _stats()
	var drew := await _shot(leg_name)
	var cat_at: Vector3 = _game.cat.global_position if _game.cat != null else Vector3.ZERO
	var row := {
		"name": leg_name,
		"zone": _game.zones.current_zone,
		"want": zone_id,
		"ok": _game.zones.current_zone == zone_id and drew,
		"mean_ms": st["mean_ms"],
		"median_ms": st["median_ms"],
		"p95_ms": st["p95_ms"],
		"frames": st["n"],
		"cat": str(cat_at),
	}
	_legs.append(row)
	print("PLAYTHROUGH leg ", leg_name, " zone ", row["zone"], " mean ", snappedf(float(st["mean_ms"]), 0.1), " ms")
	if _game.zones.current_zone != zone_id:
		print("PLAYTHROUGH FAIL wanted ", zone_id, " at ", cat_at)
		_failed = true


func _run() -> void:
	var boot := Time.get_ticks_msec()
	print("PLAYTHROUGH loading")
	_game = load("res://main.tscn").instantiate()
	add_child(_game)
	await _physics(8)
	if _game.duo != null:
		_game.duo.choose("willie")
	await _physics(10)
	var boot_ms := Time.get_ticks_msec() - boot
	print("PLAYTHROUGH boot ", boot_ms, " ms")

	await _leg("yard", HouseSpec.OUTSIDE)
	var door_frames := await _walk(HouseSpec.GROUND_FLOOR, Vector2(0, -1), 240)
	print("PLAYTHROUGH door walk frames ", door_frames, " zone ", _game.zones.current_zone)
	if _game.zones.current_zone != HouseSpec.GROUND_FLOOR:
		_failed = true
	await _settle()
	await _leg("ground_floor", HouseSpec.GROUND_FLOOR)

	# Just east of the basement stair volume. Move +x in stick space
	# is west while the camera yaw is PI.
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(-4.7, 0.2, -203.0)
	await _physics(8)
	var base_frames := await _walk(HouseSpec.BASEMENT, Vector2(1, 0), 240)
	print("PLAYTHROUGH basement walk frames ", base_frames, " pos ", _game.cat.global_position)
	if _game.zones.current_zone != HouseSpec.BASEMENT:
		_failed = true
	await _settle()
	await _leg("basement", HouseSpec.BASEMENT)

	_game.zones.travel(HouseSpec.GROUND_FLOOR, "EntryStairsTop", true)
	await _settle()
	# Just west of the attic hatch volume. Move -x is east at yaw PI.
	_game.cat.velocity = Vector3.ZERO
	_game.cat.global_position = Vector3(4.9, 0.2, -203.0)
	await _physics(8)
	var attic_frames := await _walk(HouseSpec.ATTIC, Vector2(-1, 0), 240)
	print("PLAYTHROUGH attic walk frames ", attic_frames, " pos ", _game.cat.global_position)
	if _game.zones.current_zone != HouseSpec.ATTIC:
		_failed = true
	await _settle()
	await _leg("attic", HouseSpec.ATTIC)

	var report := {
		"ok": not _failed,
		"boot_ms": boot_ms,
		"door_frames": door_frames,
		"basement_frames": base_frames,
		"attic_frames": attic_frames,
		"renderer": RenderingServer.get_current_rendering_method(),
		"legs": _legs,
	}
	var f := FileAccess.open(_out.path_join("stats.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("PLAYTHROUGH done ok=", not _failed, " out=", _out)
	get_tree().quit(1 if _failed else 0)
