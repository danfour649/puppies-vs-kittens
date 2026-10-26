class_name ZoneConnector
extends Area3D
## ZONE CONNECTOR — a walk-in trigger volume between Massey zones.
## Placed from HouseSpec.connectors() by HouseBuilder.add_connectors
## (and by main.gd for the outside door). Only the PLAYER cat trips
## it; the ZoneManager moves both cats together.
##
## The faint floor disc is deliberate: at cat scale a doorway should
## read as "step here" without a UI prompt.

var target_zone := ""
var target_entry := ""


func setup(cfg: Dictionary) -> void:
	target_zone = String(cfg.get("target_zone", ""))
	target_entry = String(cfg.get("target_entry", ""))
	position = cfg.get("at", Vector3.ZERO)
	collision_layer = 0
	collision_mask = 1 # the cats ride on layer 1
	monitoring = true
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = cfg.get("size", Vector3.ONE)
	cs.shape = shape
	add_child(cs)
	var size: Vector3 = cfg.get("size", Vector3.ONE)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = minf(size.x, size.z) * 0.38
	cm.bottom_radius = cm.top_radius
	cm.height = 0.02
	cm.radial_segments = 24
	disc.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var win := LightMood.window_color(target_zone)
	m.albedo_color = Color(win.r, win.g, win.b, 0.4)
	disc.material_override = m
	disc.position = Vector3(0, -position.y + 0.02, 0) # hug this zone's floor
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var mgr := get_tree().get_first_node_in_group("zone_manager") as ZoneManager
	if mgr == null:
		return
	if body == mgr.player_cat() and mgr.can_travel():
		mgr.travel(target_zone, target_entry)
