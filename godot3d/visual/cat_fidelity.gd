class_name CatFidelity
extends RefCounted
## Fur shells, wet eyes, and whiskers on top of the procedural cat.
## The palette meshes keep their StandardMaterial3D albedo. Smoke
## tests read those albedos; this pass only adds geometry.

static var _shader: Shader


static func dress(cat: Node) -> void:
	var layers: int = VisualQuality.fur_shells()
	var hosts: Array[MeshInstance3D] = []
	for node in cat.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if _is_fur_host(mi):
			hosts.append(mi)
	var shells := 0
	for mi in hosts:
		var src := mi.material_override as StandardMaterial3D
		for i in layers:
			var t := float(i + 1) / float(layers)
			var shell := MeshInstance3D.new()
			shell.name = "FurShell"
			# Displace the mesh itself. A vertex-shader offset was not
			# moving the silhouette under GL Compatibility.
			# Short coat. The body spheres are radius 0.5, so 0.05 is a
			# plush edge rather than a second, spikier cat.
			var sculpted := not (mi.mesh is PrimitiveMesh)
			# Sculpt shells sit just clear of the skin. Closer than this
			# z-fights in GL; much further reads as a second skin.
			var amount := lerpf(0.006, 0.016, t) if sculpted else lerpf(0.018, 0.055, t)
			shell.mesh = _extrude(mi.mesh, amount)
			shell.transform = mi.transform
			shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shell.material_override = _fur_material(src, t)
			if mi.skin != null:
				shell.skin = mi.skin
				shell.skeleton = mi.skeleton
			mi.get_parent().add_child(shell)
			shells += 1
	cat.set("fur_shells", shells)
	_finish_eyes(cat)
	_finish_ears(cat)
	cat.set("whisker_count", _add_whiskers(cat))


static func _is_fur_host(mi: MeshInstance3D) -> bool:
	if mi == null or not mi.visible or not (mi.material_override is StandardMaterial3D):
		return false
	var n := str(mi.name)
	if n == "FurShell" or n == "NoseLeather" or n.begins_with("Whisker") or n.begins_with("Pupil") or n.begins_with("Cornea") or n.begins_with("Catchlight"):
		return false
	if mi.mesh is CylinderMesh:
		var cyl := mi.mesh as CylinderMesh
		return cyl.height > 0.12 and cyl.top_radius > 0.03
	var s := mi.scale
	return minf(s.x, minf(s.y, s.z)) >= 0.07


static var _extruded: Dictionary = {}


static func _extrude(mesh: Mesh, amount: float) -> Mesh:
	var key := "%s:%.4f" % [mesh.get_instance_id(), amount]
	if _extruded.has(key):
		return _extruded[key]
	var arrays: Array = mesh.surface_get_arrays(0) if not (mesh is PrimitiveMesh) else (mesh as PrimitiveMesh).get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		var n := norms[i]
		if n.length_squared() < 0.0001:
			n = Vector3.UP
		else:
			n = n.normalized()
		moved[i] = verts[i] + n * amount
	arrays[Mesh.ARRAY_VERTEX] = moved
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_extruded[key] = out
	return out


static func _shader_res() -> Shader:
	if _shader == null:
		_shader = load("res://visual/fur.gdshader") as Shader
	return _shader


static func _fur_material(src: StandardMaterial3D, layer: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader_res()
	mat.set_shader_parameter("fur_color", src.albedo_color)
	mat.set_shader_parameter("layer", layer)
	# Mesh-local length. The body spheres are radius 0.5, then scaled,
	# so ~0.14 is a plush coat on Willie rather than a skin-tight halo.
	mat.set_shader_parameter("fur_length", 0.0)
	var tex := src.albedo_texture
	mat.set_shader_parameter("use_tex", tex != null)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
	return mat


static func _finish_eyes(cat: Node) -> void:
	var eyes: Array = cat.get("_eyes")
	var pupils: Array = []
	for eye in eyes:
		var mi := eye as MeshInstance3D
		var src := mi.material_override as StandardMaterial3D
		if src != null:
			src.roughness = 0.12
			src.clearcoat_enabled = true
			src.clearcoat = 0.85
			src.clearcoat_roughness = 0.12
		var cornea := MeshInstance3D.new()
		cornea.name = "Cornea"
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 16
		sphere.rings = 8
		cornea.mesh = sphere
		var wet := StandardMaterial3D.new()
		wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet.albedo_color = Color(1, 1, 1, 0.14)
		wet.roughness = 0.02
		wet.clearcoat_enabled = true
		wet.clearcoat = 1.0
		wet.clearcoat_roughness = 0.04
		wet.cull_mode = BaseMaterial3D.CULL_DISABLED
		cornea.material_override = wet
		cornea.scale = Vector3(1.08, 1.08, 0.72)
		cornea.position = Vector3(0, 0, -0.08)
		cornea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(cornea)
		var pupil := MeshInstance3D.new()
		pupil.name = "Pupil"
		pupil.mesh = sphere
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.01, 0.008, 0.006)
		dark.roughness = 0.35
		pupil.material_override = dark
		pupil.position = Vector3(0, 0, -0.42)
		pupil.scale = Vector3(0.62, 0.62, 0.28)
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(pupil)
		pupils.append(pupil)
		var catch := MeshInstance3D.new()
		catch.name = "Catchlight"
		var dot := SphereMesh.new()
		dot.radius = 0.5
		dot.height = 1.0
		dot.radial_segments = 8
		dot.rings = 4
		catch.mesh = dot
		var shine := StandardMaterial3D.new()
		shine.albedo_color = Color(1, 1, 1)
		shine.roughness = 0.05
		shine.emission_enabled = true
		shine.emission = Color(1, 1, 1)
		shine.emission_energy_multiplier = 0.4
		catch.material_override = shine
		catch.position = Vector3(-0.16, 0.18, -0.46)
		catch.scale = Vector3(0.14, 0.14, 0.08)
		catch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(catch)
	cat.set("_pupils", pupils)


static func _finish_ears(cat: Node) -> void:
	var ears: Array = cat.get("_inner_ears")
	for ear in ears:
		var mi := ear as MeshInstance3D
		var src := mi.material_override as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.65
		m.subsurf_scatter_transmittance_enabled = true
		m.subsurf_scatter_transmittance_color = m.albedo_color.lightened(0.15)
		m.subsurf_scatter_transmittance_depth = 0.06
		m.roughness = 0.55
		mi.material_override = m


static func _add_whiskers(cat: Node) -> int:
	var head: Node3D = cat.get("_head")
	if head == null:
		return 0
	var n := 0
	# A short stand-in. adopt_whiskers replaces this with a curved
	# strand and moves it onto the head bone. Sharing the name
	# "Whisker" made Godot drop the other eleven back to default
	# names, so those fat cylinders stayed on the head and crossed
	# above the shoulders.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.0015
	mesh.height = 0.08
	mesh.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.74, 0.66)
	mat.roughness = 0.55
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		for i in 6:
			var w := MeshInstance3D.new()
			w.name = "Whisker%s%d" % [tag, i]
			w.mesh = mesh
			w.material_override = mat
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var along := lerpf(-0.22, 0.18, float(i) / 5.0)
			w.position = Vector3(side * 0.08, along * 0.02, -0.16)
			w.rotation = Vector3(along * 0.4, 0.0, side * 1.35)
			head.add_child(w)
			n += 1
	return n
