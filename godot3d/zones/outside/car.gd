class_name PvKCar
extends Node3D
## Willie and Aggie — a Massey Street car. Dumb body, smart
## (hostile) driver: OutsideSystem decides targeting; this node
## just drives — forward at its speed, drifting laterally toward
## target_z at the bounded swerve rate, nose angled into the
## drift like it means it. Box-idiom build (body, cabin, wheels),
## varied colours, headlights on. It is NOT the Corolla: the
## parked silver Corolla in the driveway is scenery in
## OutsideSystem and never moves. It is indestructible.

var dir := 1.0 ## travel direction along X (+1 east, -1 west)
var lane_z := 0.0 ## lane centre this car belongs to
var cruise_speed := 7.5
var speed := 7.5
var hostile := false ## a driver has decided to aim at the cat
var target_z := 0.0 ## desired lateral position (lane centre + swerve)
var honked := false
var hit_cd := 0.0

var _wheels: Array = []
var _voice: AudioStreamPlayer3D
var _mats := {}
var _meshes := {}


func setup(p_dir: float, p_lane_z: float, p_speed: float, colour: Color) -> void:
	dir = p_dir
	lane_z = p_lane_z
	cruise_speed = p_speed
	speed = p_speed
	target_z = p_lane_z
	_build(colour)
	_voice = OutsideAudio.make_voice(self, -6.0)
	_voice.position = Vector3(0, 0.6, 0)


func honk() -> void:
	honked = true
	if _voice != null:
		_voice.stream = OutsideAudio.horn_stream()
		_voice.play()


func _physics_process(delta: float) -> void:
	if hit_cd > 0.0:
		hit_cd -= delta
	# Lateral drift toward the target line, bounded rate.
	var dz := target_z - global_position.z
	var step := clampf(dz, -OutsideLayout.CAR_SWERVE_RATE * delta, OutsideLayout.CAR_SWERVE_RATE * delta)
	global_position.z += step
	global_position.x += dir * speed * delta
	# Nose into the drift a little — the swerve should READ.
	var fwd := Vector3(dir, 0, clampf(dz * 0.4, -0.45, 0.45)).normalized()
	rotation.y = atan2(-fwd.x, -fwd.z)
	for w: Variant in _wheels:
		(w as MeshInstance3D).rotate_object_local(Vector3.RIGHT, speed * delta / 0.33 * dir)


func _mat(c: Color, rough := 0.6) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rough := 0.6) -> MeshInstance3D:
	if not _meshes.has(size):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[size] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[size]
	mi.material_override = _mat(c, rough)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build(colour: Color) -> void:
	var glass := Color(0.13, 0.16, 0.2)
	var tyre := Color(0.08, 0.08, 0.09)
	# Body + cabin (length along Z: 3.8 long, 1.66 wide).
	_box(self, Vector3(1.66, 0.52, 3.8), Vector3(0, 0.55, 0), colour, 0.35)
	_box(self, Vector3(1.46, 0.48, 1.9), Vector3(0, 1.02, 0.15), glass, 0.15)
	_box(self, Vector3(1.5, 0.1, 0.7), Vector3(0, 1.28, 0.15), colour, 0.35) # roof
	# Headlights (front = -Z) and tail lights, unshaded-ish bright.
	var hl := Color(1.0, 0.95, 0.7)
	var tl := Color(0.75, 0.1, 0.1)
	for sx: float in [-0.58, 0.58]:
		_box(self, Vector3(0.3, 0.12, 0.05), Vector3(sx, 0.58, -1.91), hl, 0.2)
		_box(self, Vector3(0.3, 0.1, 0.05), Vector3(sx, 0.62, 1.91), tl, 0.2)
	# Wheels: cylinders turned on their side.
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-1.28, 1.28]:
			var wm := CylinderMesh.new()
			wm.top_radius = 0.33
			wm.bottom_radius = 0.33
			wm.height = 0.2
			wm.radial_segments = 14
			var w := MeshInstance3D.new()
			w.mesh = wm
			w.material_override = _mat(tyre, 0.9)
			w.position = Vector3(sx, 0.33, sz)
			w.rotation.z = PI * 0.5
			add_child(w)
			_wheels.append(w)
