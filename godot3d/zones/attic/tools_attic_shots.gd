extends Node
## Shot pass for the attic zone. Run under Xvfb (real rendering):
##   xvfb-run godot --path godot3d res://zones/attic/tools_attic_shots.tscn
## Saves into res://zones/attic/screenshots/:
##   attic_overview, mother_charge, kits_scatter, window_perch.

const AtticScene := preload("res://zones/attic/attic.tscn")
const HarnessCatScene := preload("res://zones/attic/harness_cat.gd")

var _attic = null
var _cat = null
var _cam: Camera3D


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://zones/attic/screenshots/%s.png" % name)
	print("SHOT saved ", name, " ", img.get_size())


func _aim(pos: Vector3, target: Vector3) -> void:
	_cam.position = pos
	_cam.look_at(target)


func _place(node: Node3D, pos: Vector3, yaw := 0.0) -> void:
	node.velocity = Vector3.ZERO
	node.global_position = pos
	node.rotation.y = yaw


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://zones/attic/screenshots")
	_attic = AtticScene.instantiate()
	add_child(_attic)
	_cat = HarnessCatScene.new()
	_cat.name = "Willie"
	add_child(_cat)
	_place(_cat, Vector3(2.2, 0.05, 1.3), -2.2)
	_attic.setup(_cat)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true
	await _wait(1.2)

	var mother = _attic.mother
	var kits: Array = _attic.kits

	# (a) Overview: INSIDE the room, high near the hatch end of the
	# ridge, looking down the length of the attic to the nest corner.
	_aim(Vector3(2.9, 1.45, 2.2), Vector3(-2.5, 0.4, -1.6))
	await _wait(0.6)
	await _shot("attic_overview")

	# (b) Mother, mid-charge: kits parked and frozen, a clear lane,
	# camera side-on. Capture once she is properly rushing.
	for k in kits:
		_place(k, Vector3(5.4, 0.05, 4.15))
		k.set_physics_process(false)
	_place(mother, Vector3(-0.5, 0.05, -2.7))
	mother.home = mother.global_position
	mother._charge_cd = 0.0
	_place(_cat, Vector3(-0.5, 0.05, 0.3), 0.0)
	_aim(Vector3(2.7, 0.95, -1.15), Vector3(-0.6, 0.3, -1.2))
	var charged := false
	for i in 300:
		await get_tree().physics_frame
		if mother.state == "charge" and mother._state_t > 0.12:
			charged = true
			break
	if charged:
		await _shot("mother_charge")
	else:
		print("SHOT mother_charge SKIPPED — never charged (state ", mother.state, ")")
	for k in kits:
		k.set_physics_process(true)

	# (c) Kits scatter: the cat faces the family group at close range.
	_place(mother, Vector3(5.3, 0.05, -4.0))
	mother.set_physics_process(false)
	_place(kits[0], Vector3(0.5, 0.05, 0.45))
	_place(kits[1], Vector3(1.35, 0.05, 0.95))
	_place(kits[2], Vector3(-0.35, 0.05, 0.85))
	_place(_cat, Vector3(0.5, 0.05, 1.55), 0.0)
	_aim(Vector3(3.1, 1.5, 3.3), Vector3(0.3, 0.25, 0.3))
	var scattered := false
	for i in 240:
		await get_tree().physics_frame
		for k in kits:
			if k.state == "scatter":
				scattered = true
		if scattered:
			break
	await _wait(0.18)
	await _shot("kits_scatter")
	mother.set_physics_process(true)

	# (d) The reward: Mother down (hoard popped, kits fled), the cat
	# lounging on the window perch in the light.
	mother.take_hit(99, _cat.global_position)
	await _wait(0.8)
	_place(_cat, Vector3(PvKAttic.PERCH_POS.x, PvKAttic.PERCH_POS.y + 0.06, PvKAttic.PERCH_POS.z), -PI * 0.5)
	_cat.set_lounge(true)
	_aim(Vector3(3.3, 1.95, 1.7), Vector3(5.35, 1.55, 0))
	await _wait(1.3)
	await _shot("window_perch")

	print("ATTIC SHOTS DONE")
	get_tree().quit(0)
