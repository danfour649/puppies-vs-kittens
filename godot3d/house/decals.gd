class_name HouseDecals
extends RefCounted
## Dust, stains and loose paper on the floors. No collision.


static func scatter(root: Node3D, floor_id: String) -> void:
	var dust := _tex("dust")
	var stain := _tex("stain")
	var paper := _tex("paper")
	if dust == null and stain == null and paper == null:
		return
	var spots: Array = []
	match floor_id:
		HouseSpec.GROUND_FLOOR:
			spots = [
				["dust", Vector3(3.2, 0.02, -0.6), 0.9, 0.4],
				["stain", Vector3(5.1, 0.021, -1.6), 0.55, 1.2],
				["paper", Vector3(1.4, 0.02, 0.8), 0.42, 0.6],
				["paper", Vector3(6.2, 0.02, 0.2), 0.36, 2.1],
				["dust", Vector3(-4.2, 0.02, 1.1), 0.7, 0.2],
				["stain", Vector3(-6.8, 0.02, -2.4), 0.4, 0.8],
			]
		HouseSpec.BASEMENT:
			spots = [
				["dust", Vector3(2.6, 0.015, 3.4), 1.1, 0.3],
				["stain", Vector3(1.2, 0.016, 2.2), 0.7, 1.4],
				["paper", Vector3(3.4, 0.015, 1.6), 0.38, 0.9],
				["dust", Vector3(-0.4, 0.015, -0.8), 0.8, 2.2],
				["paper", Vector3(4.6, 0.015, -1.4), 0.34, 1.7],
				["stain", Vector3(-2.2, 0.016, 1.8), 0.5, 0.5],
			]
		HouseSpec.ATTIC:
			spots = [
				["dust", Vector3(1.2, 0.02, -0.4), 0.85, 0.5],
				["stain", Vector3(-1.6, 0.021, 0.8), 0.5, 1.1],
				["paper", Vector3(2.4, 0.02, 1.2), 0.4, 2.4],
				["paper", Vector3(-3.2, 0.02, -1.4), 0.32, 0.7],
				["dust", Vector3(0.2, 0.02, 2.0), 0.6, 1.6],
			]
	for spot: Array in spots:
		var tex: Texture2D = dust
		if String(spot[0]) == "stain":
			tex = stain
		elif String(spot[0]) == "paper":
			tex = paper
		if tex == null:
			continue
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var w := float(spot[2])
		quad.size = Vector2(w, w * 0.72)
		mi.mesh = quad
		mi.position = spot[1]
		mi.rotation = Vector3(-PI * 0.5, float(spot[3]), 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.96
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mi.material_override = m
		root.add_child(mi)


static func _tex(name: String) -> Texture2D:
	var path := "res://house/textures/%s.png" % name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
