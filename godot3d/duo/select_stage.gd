class_name SelectStage
extends Node3D
## SELECT — the spotlight stage inside the character-select viewport.
##
## A dark room, a slowly turning pedestal, one warm key spotlight and
## a cool rim light. Holds one preview build of each roster cat — the
## REAL cat_kit actor, character data applied exactly the way
## DuoSystem builds the sibling — idling in the light. Only the
## highlighted cat is visible and processing; the other is parked
## disabled so the hidden stage costs nothing.

const CatScene := preload("res://cat_kit/cat.gd")

var _pedestal: Node3D
var _camera: Camera3D
var _holders: Dictionary = {} # id -> Node3D (cat parent, rides the pedestal)
var _cats: Dictionary = {} # id -> PvKCat
var _current := ""
var _t := 0.0


func setup(chars: Dictionary, order: Array) -> void:
	_build_room()
	for id: Variant in order:
		_build_cat(String(id), chars.get(id, {}))


func show_character(id: String) -> void:
	_current = id
	for key: Variant in _holders:
		var on := String(key) == id
		(_holders[key] as Node3D).visible = on
		(_cats[key] as Node).process_mode = (
			Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		)
	var cat := _cats.get(id) as PvKCat
	if cat != null and _camera != null:
		# Frame by the cat's real scale: Willie 0.35 fills more of the
		# light than Aggie 0.25, exactly as he should.
		var s := float(cat.model_scale)
		_camera.position = Vector3(0.0, 0.15 + 0.58 * s, -(0.28 + 2.55 * s))
		_camera.rotation = Vector3(deg_to_rad(-6.0), PI, 0.0)


func _process(delta: float) -> void:
	# A gentle sway, never a full turn: the cat stays front-facing in
	# the light while the presentation breathes.
	if _pedestal != null and _current != "":
		_t += delta
		_pedestal.rotation.y = 0.55 * sin(_t * 0.35)


func _build_room() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.022, 0.019, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.145, 0.17)
	env.ambient_light_energy = 0.65
	we.environment = env
	add_child(we)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.055, 0.052, 0.065)
	floor_mat.roughness = 0.75
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(16, 0.1, 16)
	floor_mesh.material = floor_mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(0, -0.05, 0)
	add_child(floor_mi)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.042, 0.038, 0.058)
	wall_mat.roughness = 1.0
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(16, 8, 0.2)
	wall_mesh.material = wall_mat
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 4, 2.4)
	add_child(wall)

	# Halo glow on the wall behind the pedestal: the spotlight reads
	# against a composed backdrop, not a void.
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0.16, 0.12, 0.04)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.50, 0.36, 0.10)
	halo_mat.emission_energy_multiplier = 0.45
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.85
	halo_mesh.height = 1.7
	halo_mesh.radial_segments = 48
	halo_mesh.rings = 24
	halo_mesh.material = halo_mat
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.scale = Vector3(1, 1, 0.06)
	halo.position = Vector3(0, 0.52, 2.26)
	add_child(halo)

	# Physics: the floor, plus the pedestal disc as a static shape (the
	# disc MESH rides the turntable; its collision stays put — the disc
	# is round, so the two never disagree).
	var body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(8, 0.1, 8)
	floor_shape.shape = fb
	floor_shape.position = Vector3(0, -0.05, 0)
	body.add_child(floor_shape)
	var disc_shape := CollisionShape3D.new()
	var dc := CylinderShape3D.new()
	dc.radius = 0.52
	dc.height = 0.05
	disc_shape.shape = dc
	disc_shape.position = Vector3(0, 0.025, 0)
	body.add_child(disc_shape)
	add_child(body)

	_pedestal = Node3D.new()
	_pedestal.name = "Pedestal"
	add_child(_pedestal)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.14, 0.13, 0.12)
	disc_mat.roughness = 0.55
	disc_mat.metallic = 0.15
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.52
	disc_mesh.bottom_radius = 0.55
	disc_mesh.height = 0.05
	disc_mesh.material = disc_mat
	var disc := MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.position = Vector3(0, 0.025, 0)
	_pedestal.add_child(disc)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.55, 0.42, 0.15)
	ring_mat.metallic = 0.8
	ring_mat.roughness = 0.35
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.30, 0.22, 0.06)
	ring_mat.emission_energy_multiplier = 0.6
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.47
	ring_mesh.outer_radius = 0.525
	ring_mesh.material = ring_mat
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.051, 0)
	_pedestal.add_child(ring)

	# The spotlight: warm key from up-left-front, shadows on — this is
	# what makes the moment read as a spotlight rather than a room.
	var spot := SpotLight3D.new()
	spot.position = Vector3(-1.5, 2.9, -1.7)
	spot.light_color = Color(1.0, 0.92, 0.78)
	spot.light_energy = 4.2
	spot.spot_range = 9.0
	spot.spot_angle = 30.0
	spot.spot_attenuation = 1.1
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at(Vector3(0, 0.05, 0), Vector3.UP)
	# Cool rim from behind-right: separates the cat from the dark.
	var rim := OmniLight3D.new()
	rim.position = Vector3(1.2, 1.0, 1.5)
	rim.light_color = Color(0.50, 0.65, 1.0)
	rim.light_energy = 1.3
	rim.omni_range = 4.5
	add_child(rim)
	# A whisper of front fill so the face never goes pitch black.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.3, 0.55, -1.6)
	fill.light_color = Color(1.0, 0.95, 0.85)
	fill.light_energy = 0.35
	fill.omni_range = 3.5
	add_child(fill)

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.position = Vector3(0, 0.38, -1.3)
	_camera.rotation = Vector3(deg_to_rad(-6.0), PI, 0.0)
	add_child(_camera)
	_camera.current = true


func _build_cat(id: String, ch: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Holder_" + id
	holder.position = Vector3(0, 0.05, 0)
	holder.visible = false
	_pedestal.add_child(holder)
	var cat := CatScene.new() as PvKCat
	cat.set_character(id) # kit loads the character's own record
	DuoCharacters.apply(cat, ch) # then the duo data, DuoSystem-style
	cat.name = String(ch.get("name", id))
	holder.add_child(cat)
	cat.process_mode = Node.PROCESS_MODE_DISABLED
	_holders[id] = holder
	_cats[id] = cat
