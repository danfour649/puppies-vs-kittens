class_name CatScentMap
extends RefCounted
## A fading grid of cat-scent / danger, plus novel objects for
## neophobia. Mice freeze or flee off the danger value. Rats treat
## a fresh object as something to avoid; mice do not.
##
## Coordinates are world metres. `origin` is the corner of cell (0, 0).


var origin := Vector2.ZERO
var cell := 0.5
var cols := 1
var rows := 1
var scent := PackedFloat32Array()
var novels: Array = [] ## {pos: Vector3, id: String, age: float}


func setup(world_min: Vector2, world_size: Vector2, cell_size: float) -> void:
	cell = maxf(cell_size, 0.05)
	origin = world_min
	cols = maxi(1, int(ceil(world_size.x / cell)))
	rows = maxi(1, int(ceil(world_size.y / cell)))
	scent = PackedFloat32Array()
	scent.resize(cols * rows)
	scent.fill(0.0)


func deposit(world: Vector3, amount: float) -> void:
	var idx := _index(world)
	if idx < 0:
		return
	scent[idx] = minf(scent[idx] + amount, 1.6)


func decay(delta: float) -> void:
	if delta <= 0.0:
		return
	var k := exp(-0.45 * delta)
	for i in scent.size():
		scent[i] *= k


func danger_at(world: Vector3) -> float:
	return clampf(_sample(world), 0.0, 1.0)


## Direction of increasing danger on the XZ plane (points toward the cat's trail).
## Compared across neighbouring cells so a one-cell deposit still has a slope.
func gradient(world: Vector3) -> Vector3:
	var c := int(floor((world.x - origin.x) / cell))
	var r := int(floor((world.z - origin.y) / cell))
	var dx := _at(c + 1, r) - _at(c - 1, r)
	var dz := _at(c, r + 1) - _at(c, r - 1)
	return Vector3(dx, 0.0, dz)


func add_novel(pos: Vector3, id: String) -> void:
	novels.append({"pos": pos, "id": id, "age": 0.0})


func age_novels(delta: float) -> void:
	for i in novels.size():
		var n: Dictionary = novels[i]
		n["age"] = float(n["age"]) + delta
		novels[i] = n


## 0 = just appeared, 1 = long familiar. Rats care; mice barely do.
func familiarity_of(id: String) -> float:
	for n: Variant in novels:
		var d: Dictionary = n
		if String(d.get("id", "")) == id:
			return clampf(float(d.get("age", 0.0)) / 30.0, 0.0, 1.0)
	return 1.0


func nearest_novel(pos: Vector3, radius: float) -> Dictionary:
	var best := {}
	var bd := radius
	for n: Variant in novels:
		var d: Dictionary = n
		var np: Vector3 = d.get("pos", Vector3.ZERO)
		var dist := Vector2(pos.x - np.x, pos.z - np.z).length()
		if dist <= bd:
			bd = dist
			best = d.duplicate()
			best["distance"] = dist
			best["familiarity"] = clampf(float(d.get("age", 0.0)) / 30.0, 0.0, 1.0)
	return best


func _index_cr(c: int, r: int) -> int:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return -1
	return r * cols + c


func _index(world: Vector3) -> int:
	var c := int(floor((world.x - origin.x) / cell))
	var r := int(floor((world.z - origin.y) / cell))
	return _index_cr(c, r)


func _sample(world: Vector3) -> float:
	var idx := _index(world)
	if idx < 0:
		return 0.0
	return scent[idx]


func _at(c: int, r: int) -> float:
	var idx := _index_cr(c, r)
	if idx < 0:
		return 0.0
	return scent[idx]
