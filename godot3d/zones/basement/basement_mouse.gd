class_name BasementMouse
extends PvKMouse
## A night mouse in the hoarder basement. One file: the shared brain
## does the thinking (walls, runways, nibbles, scent, sound) and this
## body keeps it on the walkable cells. Mice fit the Aggie gap; the
## cat does not, which is why a nest behind it stays hidden.


var level: Dictionary = {}
var gap_blocked_for_me := false


func configure_maze(maze: Dictionary, anchors: Array) -> void:
	level = maze
	nibble_anchors = anchors
	world_hour = 23.0
	var mn := HoarderGenerator.cell_center(0, 0)
	var mx := HoarderGenerator.cell_center(HoarderGenerator.COLS - 1, HoarderGenerator.ROWS - 1)
	bounds = Rect2(mn.x - 0.45, mn.z - 0.45, (mx.x - mn.x) + 0.9, (mx.z - mn.z) + 0.9)
	wall_query = Callable(self, "_wall_pull")
	if _brain != null:
		_brain.profile["thigmotaxis"] = 2.4
		_brain.profile["runway_reuse"] = 0.75
		_brain.profile["hearing_range"] = 3.4
	cracks = _crack_points(maze)


## Corners where two stacks meet. She fits; the cat has to come in after her.
func _crack_points(maze: Dictionary) -> Array:
	var out: Array = []
	var map: Array = maze.get("map", [])
	for r in map.size():
		var row := String(map[r])
		for c in row.length():
			if not HoarderGenerator.cell_walkable(maze, c, r, false):
				continue
			var walls := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not HoarderGenerator.cell_walkable(maze, c + d.x, r + d.y, false):
					walls += 1
			if walls >= 2:
				out.append(HoarderGenerator.cell_center(c, r))
	return out


func _wall_pull(p: Vector3) -> Vector3:
	var here := _cell_of(p)
	var best := Vector3.ZERO
	var found := false
	var nearest := 2.0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := here + d
		if HoarderGenerator.cell_walkable(level, n.x, n.y, false):
			continue
		var wall := HoarderGenerator.cell_center(n.x, n.y)
		var away := Vector3(wall.x - p.x, 0.0, wall.z - p.z)
		var dist := away.length()
		if dist < nearest and dist > 0.01:
			nearest = dist
			best = away.normalized() * clampf(1.0 - dist / 1.2, 0.0, 1.0)
			found = true
	return best if found else Vector3.ZERO


func _process(delta: float) -> void:
	if state == "caught" or _body == null:
		return
	_time += delta
	var intent := _brain_intent(delta)
	var speed := float(intent.get("speed", 0.0))
	_target = intent.get("target", global_position)
	if speed <= 0.0:
		_body.position.y = 0.0
		return
	var p := global_position
	var to := _target - p
	to.y = 0.0
	if to.length() < 0.04:
		_body.position.y = 0.0
		return
	var step := to.normalized() * minf(speed * delta, to.length())
	var left := step
	var guard := 0
	while left.length() > 0.12 and guard < 8:
		var bit := left.normalized() * 0.12
		p = _slide(p, bit)
		left -= bit
		guard += 1
	p = _slide(p, left)
	var moved := p - global_position
	global_position = p
	if moved.length() > 0.001:
		var target_yaw := atan2(-moved.x, -moved.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
		_phase += delta * speed * 14.0
		_body.position.y = absf(sin(_phase)) * 0.12
	else:
		_body.position.y = 0.0


func _slide(p: Vector3, step: Vector3) -> Vector3:
	var nxt := p + step
	if _foot(nxt):
		return nxt
	var sx := Vector3(p.x + step.x, p.y, p.z)
	if _foot(sx):
		return sx
	var sz := Vector3(p.x, p.y, p.z + step.z)
	if _foot(sz):
		return sz
	return p


func _foot(p: Vector3) -> bool:
	var cell := _cell_of(p)
	return HoarderGenerator.cell_walkable(level, cell.x, cell.y, gap_blocked_for_me)


func _cell_of(p: Vector3) -> Vector2i:
	var c := int(floor(p.x - HoarderGenerator.GRID_MIN.x))
	var r := int(floor(p.z - HoarderGenerator.GRID_MIN.y))
	return Vector2i(c, r)
