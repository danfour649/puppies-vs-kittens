class_name PvKSpider
extends Node3D
## A shelf spider — the basement's ambusher. It hangs motionless on a
## thread under a shelf board; when the cat passes underneath it drops,
## bites once, and scurries back up. One paw hit kills it (max_hp 1).
## A cat hiss nearby sends it straight back up its thread
## (force_retreat) — the hiss side effect, see basement.gd.
##
## Combat contract (same shape as PvKRat): take_hit(damage, from_pos),
## bite(target, damage) signal, died signal. Spiders are Node3D gliders
## (PvKMouse idiom) — no physics body; the drop is scripted.
##
## Anchor convention: this node's origin is the anchor point on the
## shelf underside; the body hangs below it on the thread.

signal bite(target: Node3D, damage: int)
signal died(spider: PvKSpider)

@export var max_hp := 1
@export var bite_damage := 1
@export var trigger_radius := 1.05 ## horizontal distance that wakes it
@export var drop_speed := 2.4
@export var retreat_speed := 3.2
@export var body_floor_y := 0.30 ## world height the body drops to
@export var bite_pause := 0.45
@export var post_bite_cooldown := 5.0
@export var active := true

var hp: int
var state := "hang" ## hang, drop, bite_pause, retreat, cooldown, dead
var target_cat: Node3D = null

var _drop := 0.06 ## current thread length (body at -_drop)
var _rest_drop := 0.06
var _max_drop := 1.0
var _timer := 0.0
var _body: Node3D
var _thread: MeshInstance3D
var _mats := {}
var _parts: Array = []
var _flash_mat: StandardMaterial3D


func _ready() -> void:
	hp = max_hp
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.albedo_color = Color(1.0, 0.3, 0.22)
	_flash_mat.roughness = 0.6
	_build_model()
	_apply_drop()


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var key := c.to_html() + "|" + str(rough)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


func _ell(parent: Node3D, pos: Vector3, dia: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = dia
	mi.rotation = rot
	parent.add_child(mi)
	_parts.append([mi, mi.material_override])
	return mi


func _build_model() -> void:
	var ink := Color(0.05, 0.045, 0.06)
	# Thread: a unit cylinder scaled to the drop length, top at anchor.
	var tm := CylinderMesh.new()
	tm.top_radius = 0.004
	tm.bottom_radius = 0.004
	tm.height = 1.0
	tm.radial_segments = 6
	_thread = MeshInstance3D.new()
	_thread.mesh = tm
	_thread.material_override = _mat(Color(0.75, 0.72, 0.68), 0.7)
	add_child(_thread)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_ell(_body, Vector3(0, -0.045, 0.02), Vector3(0.085, 0.075, 0.10), ink) # abdomen
	_ell(_body, Vector3(0, -0.01, -0.05), Vector3(0.055, 0.05, 0.055), ink) # cephalothorax
	_ell(_body, Vector3(0.018, 0.004, -0.082), Vector3(0.014, 0.014, 0.014), Color(0.8, 0.15, 0.1), Vector3.ZERO) # eye glint
	# Eight legs: thin angled boxes (boxes read fine at this size).
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var leg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.006, 0.006, 0.10)
			leg.mesh = bm
			leg.material_override = _mat(ink)
			var spread := -0.05 + i * 0.033
			leg.position = Vector3(side * 0.055, 0.005, spread)
			leg.rotation = Vector3(0.5, side * 0.5, side * 0.9)
			_body.add_child(leg)
			_parts.append([leg, leg.material_override])


func _apply_drop() -> void:
	_body.position.y = -_drop
	_thread.scale.y = maxf(_drop, 0.01)
	_thread.position.y = -_drop * 0.5


# --- combat contract ----------------------------------------------------------

func take_hit(damage: int, from_position: Vector3) -> void:
	if state == "dead":
		return
	hp -= damage
	_flash()
	if hp <= 0:
		state = "dead"
		died.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "_drop", _max_drop + 0.55, 0.3) # falls to the floor
		tw.parallel().tween_callback(_apply_drop).set_delay(0.0)
		tw.tween_property(_body, "rotation:z", PI, 0.2)


func _flash() -> void:
	for pair: Array in _parts:
		(pair[0] as MeshInstance3D).material_override = _flash_mat
	var tw := create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(_unflash)


func _unflash() -> void:
	for pair: Array in _parts:
		(pair[0] as MeshInstance3D).material_override = pair[1]


func is_dead() -> bool:
	return state == "dead"


## Hiss side effect: drop everything and climb back to the shelf NOW.
func force_retreat() -> void:
	if state in ["drop", "bite_pause", "hang"]:
		state = "retreat"


# --- brain --------------------------------------------------------------------

func _process(delta: float) -> void:
	# The drop range follows the anchor height, whenever it was set.
	_max_drop = maxf(0.2, global_position.y - body_floor_y)
	if state == "dead":
		_apply_drop()
		return
	if not active:
		return
	match state:
		"hang":
			if target_cat != null and is_instance_valid(target_cat):
				var d := Vector2(target_cat.global_position.x - global_position.x, target_cat.global_position.z - global_position.z).length()
				if d <= trigger_radius and target_cat.global_position.y < global_position.y:
					state = "drop"
		"drop":
			_drop = minf(_drop + drop_speed * delta, _max_drop)
			if _drop >= _max_drop:
				state = "bite_pause"
				_timer = bite_pause
				if target_cat != null and is_instance_valid(target_cat):
					var d := Vector2(target_cat.global_position.x - global_position.x, target_cat.global_position.z - global_position.z).length()
					if d <= trigger_radius * 1.3:
						bite.emit(target_cat, bite_damage)
		"bite_pause":
			_timer -= delta
			if _timer <= 0.0:
				state = "retreat"
		"retreat":
			_drop = maxf(_drop - retreat_speed * delta, _rest_drop)
			if _drop <= _rest_drop:
				state = "cooldown"
				_timer = post_bite_cooldown
		"cooldown":
			_timer -= delta
			if _timer <= 0.0:
				state = "hang"
	_apply_drop()
