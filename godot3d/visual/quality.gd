extends Node
## Desktop aims at Forward+. The web export and any machine that
## falls back to GL Compatibility use the low tier: fewer fur shells,
## no volumetric fog, no SSAO. Force either with `--quality high`
## or `--quality low`.

var tier_name := "high"
var rendering_method := ""


func _ready() -> void:
	resolve()


func resolve() -> void:
	rendering_method = RenderingServer.get_current_rendering_method()
	var forced := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--quality" and i + 1 < args.size():
			forced = str(args[i + 1])
		elif str(args[i]).begins_with("--quality="):
			forced = str(args[i]).split("=")[1]
	if forced == "high" or forced == "low":
		tier_name = forced
	elif OS.has_feature("web") or rendering_method == "gl_compatibility":
		tier_name = "low"
	else:
		tier_name = "high"


func is_high() -> bool:
	return tier_name == "high"


func shell_count_for(tier: String) -> int:
	return 6 if tier == "high" else 3


func fur_shells() -> int:
	return shell_count_for(tier_name)


func apply_environment(env: Environment, place: String) -> void:
	var basement := place == "basement"
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6 if basement else 0.22
	env.glow_bloom = 0.2 if basement else 0.06
	env.glow_hdr_threshold = 0.8
	if not is_high():
		if basement:
			env.fog_enabled = true
			env.fog_light_color = Color(0.32, 0.36, 0.42)
			env.fog_density = maxf(env.fog_density, 0.02)
		return
	env.ssao_enabled = true
	env.ssao_radius = 0.55 if basement else 0.7
	env.ssao_intensity = 0.95 if basement else 1.15
	env.ssao_power = 1.35 if basement else 1.2
	env.ssil_enabled = not basement
	env.ssil_radius = 2.2
	env.ssil_intensity = 0.55
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012 if basement else 0.005
	env.volumetric_fog_albedo = Color(0.58, 0.64, 0.72) if basement else Color(0.8, 0.85, 0.92)
	env.volumetric_fog_emission = Color(0.008, 0.01, 0.014) if basement else Color(0, 0, 0, 1)
	env.volumetric_fog_length = 16.0 if basement else 64.0
	env.volumetric_fog_gi_inject = 0.35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08


func dress_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = true
	if is_high():
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.light_angular_distance = 0.4
		sun.directional_shadow_max_distance = maxf(sun.directional_shadow_max_distance, 70.0)
	else:
		sun.light_angular_distance = 0.0


## A warm cone that reads as dust in a bulb or a basement window.
## Forward+ also feeds it into volumetric fog. GL Compatibility
## still shows the translucent cone.
func add_dust_shaft(parent: Node, origin: Vector3, pitch_deg: float, yaw_deg: float) -> SpotLight3D:
	var pivot := Node3D.new()
	pivot.name = "DustShaft"
	pivot.position = origin
	pivot.rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)
	parent.add_child(pivot)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.86, 0.62)
	spot.light_energy = 5.5 if is_high() else 2.4
	spot.spot_range = 7.5
	spot.spot_angle = 16.0
	spot.spot_attenuation = 0.55
	spot.shadow_enabled = is_high()
	spot.light_volumetric_fog_energy = 2.8 if is_high() else 0.0
	pivot.add_child(spot)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 1.15
	mesh.height = 5.0
	mesh.radial_segments = 10
	cone.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.7, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.82, 0.55)
	mat.emission_energy_multiplier = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	cone.material_override = mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Spot lights shine down local -Z. Lay the cylinder along that axis.
	cone.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cone.position = Vector3(0.0, 0.0, -2.5)
	pivot.add_child(cone)
	return spot
