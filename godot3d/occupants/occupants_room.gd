extends Node3D
## Occupants — a stand-in ground floor for 255 Massey: kitchen
## counter along the west wall, a couch on the north wall, a porch
## frame to the east. Both occupants run their station routines
## here; Willie is spawned and wired as the player cat.
##
## The foundation lane's real hub replaces this room at
## integration — the OccupantSystem + MasseyOccupant actors are
## the deliverable, this room is their test harness and demo.

const OccupantScript := preload("res://occupants/occupant.gd")
const SystemScript := preload("res://occupants/occupant_system.gd")
const CatScript := preload("res://cat_kit/cat.gd")

var daniel: Node3D
var folasade: Node3D
var system: Node3D
var cat: Node3D


static func daniel_look() -> Dictionary:
	return {
		"id": "daniel", "name": "Daniel",
		"skin": Color(0.87, 0.67, 0.53), "hair": Color(0.13, 0.11, 0.10),
		"top": Color(0.30, 0.36, 0.50), "bottom": Color(0.18, 0.18, 0.20),
		"shoes": Color(0.10, 0.09, 0.09),
		"dress": false, "hair_long": false, "gold": false, "height": 1.012,
	}


static func folasade_look() -> Dictionary:
	return {
		"id": "folasade", "name": "Folasade",
		"skin": Color(0.34, 0.20, 0.13), "hair": Color(0.04, 0.03, 0.03),
		"top": Color(0.85, 0.42, 0.08), "skirt": Color(0.78, 0.33, 0.05),
		"bottom": Color(0.78, 0.33, 0.05), "shoes": Color(0.25, 0.15, 0.08),
		"dress": true, "hair_long": true, "gold": true, "height": 0.985,
	}


static func stations(seat_x: float) -> Array:
	return [
		{"pos": Vector3(-3.05, 0, -1.2), "yaw": PI / 2.0, "action": "stand", "dwell": 6.0},
		{"pos": Vector3(0.2, 0, 0.7), "yaw": -PI / 2.0, "action": "stand", "dwell": 2.5},
		{"pos": Vector3(seat_x, 0, -2.18), "yaw": PI, "action": "sit", "dwell": 16.0},
		{"pos": Vector3(3.6, 0, 2.6), "yaw": PI * 0.8, "action": "stand", "dwell": 5.0},
		{"pos": Vector3(-1.2, 0, 1.9), "yaw": 0.0, "action": "stand", "dwell": 2.5},
	]


func _ready() -> void:
	_build_environment()
	_build_room()
	daniel = OccupantScript.new()
	daniel.name = "Daniel"
	add_child(daniel)
	daniel.place_at(Vector3(-1.5, 0, 2.8), 0.0)
	daniel.setup(daniel_look(), stations(2.33))
	folasade = OccupantScript.new()
	folasade.name = "Folasade"
	add_child(folasade)
	folasade.place_at(Vector3(3.9, 0, -0.4), PI)
	var f_stations := stations(3.27)
	f_stations.push_front(f_stations.pop_at(2)) # she starts at the couch
	folasade.setup(folasade_look(), f_stations)
	system = SystemScript.new()
	system.name = "OccupantSystem"
	add_child(system)
	system.register_occupant(daniel)
	system.register_occupant(folasade)
	cat = CatScript.new()
	cat.name = "Cat"
	cat.set_character("willie")
	add_child(cat)
	cat.global_position = Vector3(0.2, 0.05, 1.9)
	system.set_player_cat(cat)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.28, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.82, 0.74)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)


func _prop(pos: Vector3, size: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.94
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _build_room() -> void:
	# Floor (the room's one physics body) + rug.
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(11, 0.1, 9)
	fcol.shape = fbox
	fcol.position = Vector3(0, -0.05, 0)
	floor_body.add_child(fcol)
	_prop(Vector3(0, -0.051, 0), Vector3(11, 0.1, 9), Color(0.42, 0.31, 0.20))
	_prop(Vector3(0.2, 0.012, 0.7), Vector3(4.8, 0.024, 3.4), Color(0.47, 0.20, 0.22))
	# North + west walls, and a lit window panel in the north wall.
	_prop(Vector3(0, 1.35, -3.55), Vector3(11, 2.7, 0.2), Color(0.76, 0.71, 0.63))
	_prop(Vector3(-4.45, 1.35, 0), Vector3(0.2, 2.7, 9), Color(0.72, 0.67, 0.60))
	_prop(Vector3(0.5, 1.62, -3.44), Vector3(1.7, 1.15, 0.04), Color(0.88, 0.92, 0.96))
	_prop(Vector3(0.5, 1.0, -3.42), Vector3(1.9, 0.07, 0.08), Color(0.55, 0.48, 0.40))
	# Kitchen counter run (west), with a mug and Willie's water bowl.
	_prop(Vector3(-3.95, 0.46, -1.2), Vector3(0.85, 0.92, 3.6), Color(0.52, 0.52, 0.55))
	_prop(Vector3(-3.92, 0.945, -1.2), Vector3(1.0, 0.05, 3.8), Color(0.78, 0.76, 0.72))
	var mug := CylinderMesh.new()
	mug.top_radius = 0.045
	mug.bottom_radius = 0.045
	mug.height = 0.09
	var mug_mi := MeshInstance3D.new()
	mug_mi.mesh = mug
	var mug_mat := StandardMaterial3D.new()
	mug_mat.albedo_color = Color(0.65, 0.16, 0.14)
	mug_mi.material_override = mug_mat
	mug_mi.position = Vector3(-3.9, 1.015, -0.4)
	add_child(mug_mi)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.115
	bowl.bottom_radius = 0.085
	bowl.height = 0.055
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = bowl
	var bowl_mat := StandardMaterial3D.new()
	bowl_mat.albedo_color = Color(0.25, 0.45, 0.75)
	bowl_mi.material_override = bowl_mat
	bowl_mi.position = Vector3(-3.85, 0.998, 0.55)
	add_child(bowl_mi)
	# The couch (north wall): base, cushions, back, arms.
	var couch := Node3D.new()
	couch.position = Vector3(2.8, 0, -2.45)
	add_child(couch)
	_prop(Vector3(0, 0.21, 0), Vector3(2.0, 0.42, 0.9), Color(0.30, 0.38, 0.40), couch)
	_prop(Vector3(-0.47, 0.485, 0.03), Vector3(0.92, 0.13, 0.78), Color(0.37, 0.46, 0.48), couch)
	_prop(Vector3(0.47, 0.485, 0.03), Vector3(0.92, 0.13, 0.78), Color(0.37, 0.46, 0.48), couch)
	_prop(Vector3(0, 0.62, -0.36), Vector3(2.0, 0.85, 0.22), Color(0.28, 0.35, 0.37), couch)
	_prop(Vector3(-0.47, 0.74, -0.27), Vector3(0.92, 0.5, 0.14), Color(0.35, 0.43, 0.45), couch)
	_prop(Vector3(0.47, 0.74, -0.27), Vector3(0.92, 0.5, 0.14), Color(0.35, 0.43, 0.45), couch)
	_prop(Vector3(-0.95, 0.33, 0), Vector3(0.24, 0.66, 0.9), Color(0.28, 0.35, 0.37), couch)
	_prop(Vector3(0.95, 0.33, 0), Vector3(0.24, 0.66, 0.9), Color(0.28, 0.35, 0.37), couch)
	# Porch frame (east): step, posts, lintel.
	_prop(Vector3(3.8, 0.06, 3.1), Vector3(1.8, 0.12, 1.0), Color(0.55, 0.53, 0.50))
	_prop(Vector3(3.05, 1.2, 3.45), Vector3(0.12, 2.4, 0.12), Color(0.60, 0.52, 0.42))
	_prop(Vector3(4.55, 1.2, 3.45), Vector3(0.12, 2.4, 0.12), Color(0.60, 0.52, 0.42))
	_prop(Vector3(3.8, 2.42, 3.45), Vector3(1.75, 0.14, 0.14), Color(0.60, 0.52, 0.42))
	# A plant by the porch.
	var pot := CylinderMesh.new()
	pot.top_radius = 0.16
	pot.bottom_radius = 0.12
	pot.height = 0.3
	var pot_mi := MeshInstance3D.new()
	pot_mi.mesh = pot
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.55, 0.30, 0.18)
	pot_mi.material_override = pot_mat
	pot_mi.position = Vector3(-4.0, 0.15, 3.6)
	add_child(pot_mi)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.25, 0.45, 0.22)
	leaf_mat.roughness = 0.9
	for off in [Vector3(0, 0.55, 0), Vector3(0.13, 0.42, 0.05), Vector3(-0.12, 0.46, -0.04)]:
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		var smi := MeshInstance3D.new()
		smi.mesh = s
		smi.material_override = leaf_mat
		smi.position = Vector3(-4.0, 0.3, 3.6) + off
		add_child(smi)
