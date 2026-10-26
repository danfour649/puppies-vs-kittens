class_name HoarderGenerator
extends RefCounted
## Seeded rooms for 255 Massey Street.
##
## The floor plan comes out in the basement's own map format:
## strings, one character a cell, the same legend basement.gd walks
## ('.' open, '#' kept things, 'T' tunnel, 'G' the Aggie gap, 'H'
## heart, 'A' alcove). A level is playable when the entrance reaches
## the heart with the gap shut, the alcove opens only through the
## gap, and every nest pocket is reachable.
##
## `generate(seed)` is the basement (14×10). `generate_floor` uses
## the same legend for the ground floor and the attic, with a
## one-cell spine so the real doors stay on the route. Decade bands
## still run deep-to-near: older things sit on the smaller rows.
##
## Tone: a long life, kept. Glenys saved lecture notes, the good
## teapot, a school jumper. The stacks are years, not a punchline.


const COLS := 14
const ROWS := 10
const GRID_MIN := Vector2(-7, -5)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const DECADES: Array[int] = [1960, 1970, 1980, 1990, 2000, 2010]

## Warm names, one household, six decades. Older things sit deeper
## (smaller row, the north wall). Nothing here is a joke about mess.
const KEEPSAKES := {
	1960: [
		"Glenys's master's notes, tied with string",
		"a bakelite radio, still plugged in in spirit",
		"the good wool coat, in its paper bag",
	],
	1970: [
		"a box of family photographs",
		"the yellow teapot, wrapped in a tea towel",
		"knitting, still on the needles",
	],
	1980: [
		"Daniel's school jumper, folded",
		"a stack of computer magazines, labelled",
		"the Christmas ornaments, tissue between them",
	],
	1990: [
		"a box labelled KEEPSAKES, in her handwriting",
		"the spare kettle",
		"board games with the pieces counted back in",
	],
	2000: [
		"photo albums, dates on the spine",
		"a lampshade saved for the spare room",
		"winter boots, paired",
	],
	2010: [
		"the cats' old carrier",
		"a basket of clean rags",
		"a jar of string, because you never know",
	],
}


static func cell_center(c: int, r: int) -> Vector3:
	return Vector3(GRID_MIN.x + c + 0.5, 0.0, GRID_MIN.y + r + 0.5)


static func walkable(ch: String, block_gap: bool) -> bool:
	if ch == "#":
		return false
	if ch == "G" and block_gap:
		return false
	return true


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := _blank()
	var entry := Vector2i(11, 9)
	var heart := Vector2i(rng.randi_range(3, 8), rng.randi_range(1, 3))
	var path := _carve_path(cells, rng, entry, heart)
	for _i in rng.randi_range(5, 8):
		var start: Vector2i = path[rng.randi() % path.size()]
		_carve_spur(cells, rng, start, rng.randi_range(2, 5), {})
	# A small heart chamber so the den reads as a room, not a crack.
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var h := heart + d
		if _inside(h) and cells[h.y][h.x] != "G":
			cells[h.y][h.x] = "H"
	var gap_info := _place_gap(cells, rng, entry, heart)
	var gap: Vector2i = gap_info["gap"]
	var gap_dir: Vector2i = gap_info["dir"]
	var alcove: Array = gap_info["alcove"]
	var protected := _protected_cells(gap_info)
	_mark_tunnel(cells, path, rng, protected)
	var nests := _place_nests(cells, rng, entry, heart, protected, 3)
	_repair(cells, entry, heart, gap, alcove, nests, protected)

	var stacks := _place_stacks(cells, rng, gap, alcove)
	var routes := _vertical_routes(cells, stacks)
	var items := _place_items(cells, rng, alcove)
	var level := {
		"seed": seed_value,
		"map": _to_strings(cells),
		"cols": COLS,
		"rows": ROWS,
		"entry_cell": entry,
		"heart_cell": heart,
		"gap_cell": gap,
		"gap_dir": gap_dir,
		"alcove_cells": alcove,
		"nests": nests,
		"stacks": stacks,
		"vertical_routes": routes,
		"items": items,
		"decades": DECADES.duplicate(),
	}
	return level


static func char_at(level: Dictionary, c: int, r: int) -> String:
	var map: Array = level["map"]
	if r < 0 or c < 0 or r >= map.size():
		return "#"
	var row := String(map[r])
	if c >= row.length():
		return "#"
	return row.substr(c, 1)


static func cell_walkable(level: Dictionary, c: int, r: int, block_gap: bool) -> bool:
	return walkable(char_at(level, c, r), block_gap)


static func bfs(level: Dictionary, start: Vector2i, goal: Vector2i, block_gap: bool) -> Array:
	if not cell_walkable(level, start.x, start.y, block_gap):
		return []
	if not cell_walkable(level, goal.x, goal.y, block_gap):
		return []
	var prev := {}
	var queue: Array[Vector2i] = [start]
	prev[start] = start
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if prev.has(n) or not cell_walkable(level, n.x, n.y, block_gap):
				continue
			prev[n] = cur
			queue.append(n)
	if not prev.has(goal):
		return []
	var out: Array = []
	var walk := goal
	while walk != start:
		out.push_front(walk)
		walk = prev[walk]
	out.push_front(start)
	return out


static func reachable_from(level: Dictionary, start: Vector2i, block_gap: bool) -> Dictionary:
	var seen := {}
	if not cell_walkable(level, start.x, start.y, block_gap):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if seen.has(n) or not cell_walkable(level, n.x, n.y, block_gap):
				continue
			seen[n] = true
			queue.append(n)
	return seen


static func narrow_fraction(level: Dictionary) -> float:
	var map: Array = level["map"]
	var considered := 0
	var narrow := 0
	for r in map.size():
		var row := String(map[r])
		for c in row.length():
			var ch := row.substr(c, 1)
			if ch == "#" or ch == "H" or ch == "A" or ch == "G":
				continue
			considered += 1
			if _open_degree(level, c, r, false) <= 2:
				narrow += 1
	if considered == 0:
		return 0.0
	return float(narrow) / float(considered)


## Connectivity in the basement's sense, plus the hoarder dressing
## the generator promises. `strict` asks for narrow corridors, nests,
## decade layers and vertical routes — the hand-authored basement
## map passes the connectivity half with strict = false.
static func playable(level: Dictionary, strict: bool = true) -> Dictionary:
	var reasons: Array[String] = []
	var rows := int(level.get("rows", ROWS))
	var cols := int(level.get("cols", COLS))
	var map: Array = level.get("map", [])
	if map.size() != rows:
		reasons.append("map should have %d rows (got %d)" % [rows, map.size()])
	for row: Variant in map:
		if String(row).length() != cols:
			reasons.append("a row is not %d wide" % cols)
			break
	var entry: Vector2i = level.get("entry_cell", Vector2i(-1, -1))
	var heart: Vector2i = level.get("heart_cell", Vector2i(-1, -1))
	var gap: Vector2i = level.get("gap_cell", Vector2i(-1, -1))
	if not cell_walkable(level, entry.x, entry.y, true):
		reasons.append("entry is not walkable with the gap shut")
	if bfs(level, entry, heart, true).is_empty():
		reasons.append("entrance cannot reach the heart with the gap shut")
	if char_at(level, gap.x, gap.y) != "G":
		reasons.append("gap cell is not G")
	var alcove: Array = level.get("alcove_cells", [])
	if alcove.is_empty():
		reasons.append("alcove is missing")
	for a: Variant in alcove:
		var cell: Vector2i = a
		if not bfs(level, entry, cell, true).is_empty():
			reasons.append("alcove %s is reachable with the gap shut" % cell)
		if bfs(level, entry, cell, false).is_empty():
			reasons.append("alcove %s is unreachable through the gap" % cell)
	var seen_open := reachable_from(level, entry, false)
	var seen_shut := reachable_from(level, entry, true)
	for r in rows:
		for c in cols:
			var ch := char_at(level, c, r)
			if ch == "#" or ch == "G":
				continue
			var cell := Vector2i(c, r)
			if ch == "A":
				continue
			if not seen_shut.has(cell):
				reasons.append("cell %s (%s) unreachable with the gap shut" % [cell, ch])
	if not seen_open.has(gap):
		reasons.append("the gap itself is unreachable")
	var nests: Array = level.get("nests", [])
	if strict and nests.size() < 2:
		reasons.append("expected hidden nest pockets")
	for n: Variant in nests:
		var cell: Vector2i = n
		if not seen_open.has(cell):
			reasons.append("nest %s is unreachable" % cell)
		if strict and _open_degree(level, cell.x, cell.y, false) != 1:
			reasons.append("nest %s is not a pocket (degree %d)" % [cell, _open_degree(level, cell.x, cell.y, false)])
	if strict and narrow_fraction(level) < 0.50:
		reasons.append("paths are not narrow (fraction %.2f)" % narrow_fraction(level))
	if strict:
		var decades_seen := {}
		var row_sum := {}
		var row_n := {}
		for item: Variant in level.get("items", []):
			var it: Dictionary = item
			var decade := int(it.get("decade", 0))
			decades_seen[decade] = true
			row_sum[decade] = float(row_sum.get(decade, 0.0)) + float(it.get("row", 0))
			row_n[decade] = int(row_n.get(decade, 0)) + 1
			var name := String(it.get("name", ""))
			for bad: String in ["hoarder", "filthy", "disgusting", "junk pile", "lazy", "crazy"]:
				if name.to_lower().contains(bad):
					reasons.append("item copy slips: %s" % name)
		for decade: int in DECADES:
			if not decades_seen.has(decade):
				reasons.append("missing the %ds" % decade)
		if row_n.has(1960) and row_n.has(2010):
			var mean_old := float(row_sum[1960]) / float(row_n[1960])
			var mean_new := float(row_sum[2010]) / float(row_n[2010])
			if mean_old >= mean_new:
				reasons.append("older keepsakes should sit deeper than newer ones")
		var routes: Array = level.get("vertical_routes", [])
		if routes.size() < 3:
			reasons.append("expected tall stacks with vertical routes")
		for route: Variant in routes:
			var rd: Dictionary = route
			var floor_cell: Vector2i = rd.get("floor_cell", Vector2i(-1, -1))
			if not seen_shut.has(floor_cell) and not seen_open.has(floor_cell):
				reasons.append("vertical route floor %s is unreachable" % floor_cell)
			if float(rd.get("height", 0.0)) < 1.0:
				reasons.append("stack shorter than a cat's jump")
		var landmarks: Dictionary = level.get("landmarks", {})
		for mark_name: Variant in landmarks.keys():
			var mark: Vector2i = landmarks[mark_name]
			if not seen_shut.has(mark):
				reasons.append("landmark %s %s is unreachable with the gap shut" % [String(mark_name), mark])
	return {"ok": reasons.is_empty(), "reasons": reasons}


static func maps_equal(a: Dictionary, b: Dictionary) -> bool:
	var ma: Array = a.get("map", [])
	var mb: Array = b.get("map", [])
	if ma.size() != mb.size():
		return false
	for i in ma.size():
		if String(ma[i]) != String(mb[i]):
			return false
	return true


# --- carving ----------------------------------------------------------------

static func _blank() -> Array:
	var cells: Array = []
	for _r in ROWS:
		var row: Array = []
		for _c in COLS:
			row.append("#")
		cells.append(row)
	return cells


static func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


static func _carve_path(cells: Array, rng: RandomNumberGenerator, start: Vector2i, goal: Vector2i) -> Array:
	var path: Array = []
	var cur := start
	cells[cur.y][cur.x] = "."
	path.append(cur)
	var guard := 0
	while cur != goal and guard < 600:
		guard += 1
		var options: Array[Vector2i] = []
		var best := 999
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + d
			if not _inside(n):
				continue
			options.append(n)
			best = mini(best, _manhattan(n, goal))
		if options.is_empty():
			break
		var toward: Array[Vector2i] = []
		for n: Vector2i in options:
			if _manhattan(n, goal) == best:
				toward.append(n)
		var pick: Vector2i = toward[rng.randi() % toward.size()] if rng.randf() < 0.82 else options[rng.randi() % options.size()]
		cur = pick
		if cells[cur.y][cur.x] == "#":
			cells[cur.y][cur.x] = "."
		if path.is_empty() or path[path.size() - 1] != cur:
			path.append(cur)
	if cur != goal:
		cur = path[path.size() - 1]
		while cur.x != goal.x:
			cur.x += 1 if goal.x > cur.x else -1
			cells[cur.y][cur.x] = "."
			path.append(cur)
		while cur.y != goal.y:
			cur.y += 1 if goal.y > cur.y else -1
			cells[cur.y][cur.x] = "."
			path.append(cur)
	return path


static func _carve_spur(cells: Array, rng: RandomNumberGenerator, start: Vector2i, length: int, protected: Dictionary) -> void:
	var cur := start
	var dir: Vector2i = DIRS[rng.randi() % DIRS.size()]
	for _i in length:
		var n: Vector2i = cur + dir
		if not _inside(n) or protected.has(n):
			break
		if cells[n.y][n.x] == "#":
			cells[n.y][n.x] = "."
		cur = n
		if rng.randf() < 0.25:
			dir = DIRS[rng.randi() % DIRS.size()]


static func _place_gap(cells: Array, rng: RandomNumberGenerator, entry: Vector2i, heart: Vector2i) -> Dictionary:
	var candidates: Array = []
	for r in ROWS:
		for c in COLS:
			if cells[r][c] == "#":
				continue
			var from := Vector2i(c, r)
			if from == entry or from == heart:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var gap := from + d
				var a1 := from + d * 2
				var a2 := from + d * 3
				if not _inside(gap) or not _inside(a1) or not _inside(a2):
					continue
				if cells[gap.y][gap.x] != "#" or cells[a1.y][a1.x] != "#" or cells[a2.y][a2.x] != "#":
					continue
				# The pocket must not already touch the paths, except
				# through the gap cell we are about to open.
				if _touches_open(cells, a1, gap) or _touches_open(cells, a2, gap):
					continue
				candidates.append({"from": from, "gap": gap, "dir": d, "alcove": [a1, a2]})
	var picked: Dictionary
	if candidates.is_empty():
		# Force a pocket on the east edge, carving back into solid.
		picked = _force_gap(cells)
	else:
		picked = candidates[rng.randi() % candidates.size()]
	var gap_cell: Vector2i = picked["gap"]
	cells[gap_cell.y][gap_cell.x] = "G"
	var alcove: Array = picked["alcove"]
	for a: Variant in alcove:
		var cell: Vector2i = a
		cells[cell.y][cell.x] = "A"
	return picked


static func _force_gap(cells: Array) -> Dictionary:
	var from := Vector2i(10, 5)
	for r in range(5, 1, -1):
		for c in range(9, 2, -1):
			if cells[r][c] != "#":
				from = Vector2i(c, r)
				break
	var dir := Vector2i(1, 0)
	var gap := from + dir
	var a1 := from + dir * 2
	var a2 := from + dir * 3
	if not _inside(a2):
		dir = Vector2i(-1, 0)
		gap = from + dir
		a1 = from + dir * 2
		a2 = from + dir * 3
	return {"from": from, "gap": gap, "dir": dir, "alcove": [a1, a2]}


static func _touches_open(cells: Array, cell: Vector2i, ignore: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell + d
		if n == ignore or not _inside(n):
			continue
		if cells[n.y][n.x] != "#":
			return true
	return false


static func _protected_cells(gap_info: Dictionary) -> Dictionary:
	var prot := {}
	var gap: Vector2i = gap_info["gap"]
	prot[gap] = true
	for a: Variant in gap_info["alcove"]:
		var cell: Vector2i = a
		prot[cell] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + d
			if n != gap_info["from"]:
				prot[n] = true
	return prot


static func _mark_tunnel(cells: Array, path: Array, rng: RandomNumberGenerator, protected: Dictionary) -> void:
	var run: Array = []
	var best: Array = []
	var dir := Vector2i.ZERO
	for cell: Vector2i in path:
		if protected.has(cell) or cells[cell.y][cell.x] != ".":
			run = []
			dir = Vector2i.ZERO
			continue
		if run.is_empty():
			run = [cell]
			continue
		var step: Vector2i = cell - run[run.size() - 1]
		if step == dir or dir == Vector2i.ZERO:
			dir = step
			run.append(cell)
		else:
			run = [cell]
			dir = Vector2i.ZERO
		if run.size() > best.size():
			best = run.duplicate()
	if best.size() >= 4:
		var start := rng.randi() % maxi(1, best.size() - 3)
		for i in 4:
			var cell: Vector2i = best[start + i]
			if cells[cell.y][cell.x] == ".":
				cells[cell.y][cell.x] = "T"
	else:
		var marked := 0
		for cell: Vector2i in path:
			if marked >= 4:
				break
			if cells[cell.y][cell.x] == "." and not protected.has(cell):
				cells[cell.y][cell.x] = "T"
				marked += 1


static func _place_nests(cells: Array, rng: RandomNumberGenerator, entry: Vector2i, heart: Vector2i, protected: Dictionary, want: int) -> Array:
	var nests: Array = []
	var guard := 0
	while nests.size() < want and guard < 80:
		guard += 1
		var starts: Array[Vector2i] = []
		for r in ROWS:
			for c in COLS:
				if cells[r][c] == "#":
					continue
				var cell := Vector2i(c, r)
				if cell == entry or cell == heart or protected.has(cell):
					continue
				starts.append(cell)
		if starts.is_empty():
			break
		var from: Vector2i = starts[rng.randi() % starts.size()]
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var placed := false
		for _try in dirs.size():
			var d: Vector2i = dirs[rng.randi() % dirs.size()]
			var pocket := from + d
			if not _inside(pocket) or protected.has(pocket):
				continue
			if cells[pocket.y][pocket.x] != "#":
				continue
			# Only the entrance may be open, so the pocket stays hidden.
			var leaks := false
			for nd: Vector2i in dirs:
				var nn := pocket + nd
				if nn == from or not _inside(nn):
					continue
				if cells[nn.y][nn.x] != "#":
					leaks = true
			if leaks:
				continue
			cells[pocket.y][pocket.x] = "."
			nests.append(pocket)
			protected[pocket] = true
			placed = true
			break
		if not placed and guard > 40:
			break
	return nests


static func _repair(cells: Array, entry: Vector2i, heart: Vector2i, gap: Vector2i, alcove: Array, nests: Array, protected: Dictionary) -> void:
	# The heart was carved before the gap, and the gap only replaced
	# solid cells, so this is a safety net: if a later edit ever
	# pinched the Willie route, open a one-cell bypass that does not
	# touch the alcove.
	var level := {"map": _to_strings(cells), "cols": COLS, "rows": ROWS}
	if bfs(level, entry, heart, true).is_empty():
		var cur := entry
		while cur != heart:
			var step := Vector2i.ZERO
			if cur.x != heart.x:
				step.x = 1 if heart.x > cur.x else -1
			elif cur.y != heart.y:
				step.y = 1 if heart.y > cur.y else -1
			cur += step
			if protected.has(cur):
				continue
			if cells[cur.y][cur.x] == "#" or cells[cur.y][cur.x] == "G":
				cells[cur.y][cur.x] = "."
		level = {"map": _to_strings(cells)}
	for n: Variant in nests:
		var cell: Vector2i = n
		if bfs(level, entry, cell, false).is_empty() and not protected.has(cell):
			cells[cell.y][cell.x] = "."


static func _place_stacks(cells: Array, rng: RandomNumberGenerator, gap: Vector2i, alcove: Array) -> Array:
	var banned := {gap: true}
	for a: Variant in alcove:
		banned[a] = true
	var candidates: Array[Vector2i] = []
	for r in ROWS:
		for c in COLS:
			if cells[r][c] != "#":
				continue
			var cell := Vector2i(c, r)
			if banned.has(cell):
				continue
			if _has_open_neighbor(cells, cell):
				candidates.append(cell)
	var stacks: Array = []
	var guard := 0
	while stacks.size() < 4 and not candidates.is_empty() and guard < 30:
		guard += 1
		var i := rng.randi() % candidates.size()
		var cell: Vector2i = candidates[i]
		candidates.remove_at(i)
		var height := rng.randf_range(1.25, 2.15)
		stacks.append({
			"cell": cell,
			"height": height,
		})
	return stacks


static func _vertical_routes(cells: Array, stacks: Array) -> Array:
	var routes: Array = []
	for s: Variant in stacks:
		var sd: Dictionary = s
		var cell: Vector2i = sd["cell"]
		var floor_cell := Vector2i(-1, -1)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + d
			if _inside(n) and cells[n.y][n.x] != "#":
				floor_cell = n
				break
		if floor_cell.x < 0:
			continue
		routes.append({
			"stack_cell": cell,
			"floor_cell": floor_cell,
			"height": float(sd["height"]),
			"perch": cell_center(cell.x, cell.y) + Vector3(0, float(sd["height"]) + 0.05, 0),
		})
	return routes


static func _place_items(cells: Array, rng: RandomNumberGenerator, alcove: Array) -> Array:
	var items: Array = []
	var alcove_set := {}
	for a: Variant in alcove:
		alcove_set[a] = true
	for decade: int in DECADES:
		var band := _decade_rows(decade)
		var spots: Array[Vector2i] = []
		for r in range(band.x, band.y + 1):
			for c in COLS:
				if cells[r][c] == "#":
					continue
				var cell := Vector2i(c, r)
				if alcove_set.has(cell):
					continue
				spots.append(cell)
		if spots.is_empty():
			for r in ROWS:
				for c in COLS:
					if cells[r][c] != "#" and not alcove_set.has(Vector2i(c, r)):
						spots.append(Vector2i(c, r))
		var names: Array = KEEPSAKES[decade]
		for k in mini(2, names.size()):
			if spots.is_empty():
				break
			var cell: Vector2i = spots[rng.randi() % spots.size()]
			items.append({
				"decade": decade,
				"name": String(names[k]),
				"cell": cell,
				"row": cell.y,
				"col": cell.x,
				"pos": cell_center(cell.x, cell.y) + Vector3(0, 0.18, 0),
			})
	return items


static func _decade_rows(decade: int) -> Vector2i:
	match decade:
		1960:
			return Vector2i(0, 1)
		1970:
			return Vector2i(2, 3)
		1980:
			return Vector2i(4, 5)
		1990:
			return Vector2i(6, 7)
		2000:
			return Vector2i(8, 8)
		_:
			return Vector2i(9, 9)


static func _to_strings(cells: Array) -> Array:
	var map: Array = []
	for r in cells.size():
		var s := ""
		var row: Array = cells[r]
		for ch: Variant in row:
			s += String(ch)
		map.append(s)
	return map


static func _open_degree(level: Dictionary, c: int, r: int, block_gap: bool) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cell_walkable(level, c + d.x, r + d.y, block_gap):
			n += 1
	return n


static func _has_open_neighbor(cells: Array, cell: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell + d
		if _inside(n) and cells[n.y][n.x] != "#":
			return true
	return false


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# --- ground floor and attic --------------------------------------------------

const GROUND_KEEPSAKES := {
	1960: [
		"the good china, tissue between each plate",
		"Glenys's fountain pen, capped",
		"a lecture timetable, pinned by the kitchen door",
	],
	1970: [
		"the yellow teapot, on a folded tea towel",
		"a box of family photographs",
		"knitting, still on the needles by the chair",
	],
	1980: [
		"Daniel's school photograph, in a wooden frame",
		"computer magazines, dated and kept",
		"the Christmas cards, in their box",
	],
	1990: [
		"a tin labelled KEEPSAKES, in her handwriting",
		"the spare kettle",
		"a board game with the pieces counted back in",
	],
	2000: [
		"photo albums, dates on the spine",
		"a lamp saved for the spare room",
		"the pair of slippers by the sofa",
	],
	2010: [
		"the cats' blanket, folded",
		"a basket of clean rags",
		"a jar of string, because you never know",
	],
}

const ATTIC_KEEPSAKES := {
	1960: [
		"the wedding letters, tied with ribbon",
		"a trunk of winter coats, cedar between them",
		"the bakelite radio, brought up to be safe",
	],
	1970: [
		"holiday ornaments, tissue between each one",
		"a box of baby clothes, labelled",
		"the spare yellow teapot lid, wrapped",
	],
	1980: [
		"school exercise books, the year on the cover",
		"a box of computer printouts, kept",
		"the tree skirt, folded for next year",
	],
	1990: [
		"a suitcase of letters",
		"board games waiting for a rainy day",
		"the good curtains, in a pillowcase",
	],
	2000: [
		"photo albums too heavy for the shelf downstairs",
		"a lampshade saved for the spare room",
		"winter blankets, aired and stacked",
	],
	2010: [
		"the cats' old carrier, the door latched",
		"a basket of clean rags",
		"string, ribbon, and the good scissors",
	],
}


## Same legend as the basement, fitted to another floor. The basement
## itself stays on `generate` so a seed there does not move.
static func generate_floor(floor_id: String, seed_value: int) -> Dictionary:
	if floor_id == "basement" or floor_id == "":
		var basement := generate(seed_value)
		basement["floor"] = "basement"
		basement["mood"] = "night"
		basement["grid_min"] = GRID_MIN
		basement["cell_size"] = Vector2.ONE
		return basement
	return _generate_profiled(floor_id, seed_value)


static func world_pos(level: Dictionary, c: int, r: int) -> Vector3:
	var gmin: Vector2 = level.get("grid_min", GRID_MIN)
	var cell: Vector2 = level.get("cell_size", Vector2.ONE)
	return Vector3(gmin.x + (float(c) + 0.5) * cell.x, 0.0, gmin.y + (float(r) + 0.5) * cell.y)


static func decade_for_row(row: int, rows: int) -> int:
	var span := maxi(1, rows - 1)
	var t := clampf(float(row) / float(span), 0.0, 0.999)
	var idx := clampi(int(t * float(DECADES.size())), 0, DECADES.size() - 1)
	return int(DECADES[idx])


static func _profile(floor_id: String) -> Dictionary:
	if floor_id == "attic":
		return {
			"id": "attic",
			"cols": 11,
			"rows": 8,
			"grid_min": Vector2(-5.5, -4.0),
			"cell": Vector2.ONE,
			"entry": Vector2i(9, 1),
			"heart_min": Vector2i(3, 3),
			"heart_max": Vector2i(5, 4),
			"mood": "dawn",
			"keepsakes": ATTIC_KEEPSAKES,
			"spine": [
				Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 1),
				Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4),
				Vector2i(3, 4), Vector2i(2, 4), Vector2i(2, 5),
			],
			"landmarks": {
				"hatch_side": Vector2i(9, 1),
				"landing": Vector2i(4, 3),
				"eave": Vector2i(2, 5),
			},
		}
	return {
		"id": "ground_floor",
		"cols": 16,
		"rows": 8,
		"grid_min": Vector2(-8.0, -4.0),
		"cell": Vector2.ONE,
		"entry": Vector2i(10, 7),
		"heart_min": Vector2i(8, 2),
		"heart_max": Vector2i(10, 3),
		"mood": "dusk",
		"keepsakes": GROUND_KEEPSAKES,
		"spine": [
			Vector2i(10, 7), Vector2i(10, 6), Vector2i(10, 5), Vector2i(10, 4),
			Vector2i(9, 4), Vector2i(8, 4), Vector2i(7, 4), Vector2i(6, 4), Vector2i(6, 3),
			Vector2i(5, 4), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4),
			Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1),
			Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4),
			Vector2i(14, 3), Vector2i(14, 2), Vector2i(14, 1),
			Vector2i(5, 5), Vector2i(5, 6),
		],
		"landmarks": {
			"door": Vector2i(10, 7),
			"stairs": Vector2i(1, 1),
			"hatch": Vector2i(14, 1),
			"bowl": Vector2i(5, 6),
			"doorway": Vector2i(6, 3),
		},
	}


static func _generate_profiled(floor_id: String, seed_value: int) -> Dictionary:
	var profile := _profile(floor_id)
	var cols := int(profile["cols"])
	var rows := int(profile["rows"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := _blank_wh(cols, rows)
	var entry: Vector2i = profile["entry"]
	var spine: Array = profile["spine"]
	for s: Variant in spine:
		var sc: Vector2i = s
		if _inside_wh(sc, cols, rows):
			cells[sc.y][sc.x] = "."
	var hmin: Vector2i = profile["heart_min"]
	var hmax: Vector2i = profile["heart_max"]
	var anchor := _nearest_on_spine(spine, Vector2i(int((hmin.x + hmax.x) / 2), int((hmin.y + hmax.y) / 2)))
	var heart := _step_into_rect(anchor, hmin, hmax, cols, rows)
	if heart == entry:
		heart = anchor
	_open_line(cells, anchor, heart)
	var path: Array = spine.duplicate()
	if heart != anchor:
		path.append(heart)
	# A couple of short side pockets off the route. The spine itself
	# stays the way through; pinching puts back anything that widens it.
	for _i in rng.randi_range(2, 3):
		var start: Vector2i = path[rng.randi() % path.size()]
		_carve_spur_p(cells, rng, start, rng.randi_range(2, 3), {}, cols, rows)
	var guarded := {}
	for s: Variant in spine:
		guarded[s] = true
	guarded[entry] = true
	guarded[heart] = true
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var h := heart + d
		if _inside_wh(h, cols, rows) and cells[h.y][h.x] != "G":
			cells[h.y][h.x] = "H"
			guarded[h] = true
	var gap_info := _place_gap_p(cells, rng, entry, heart, guarded, cols, rows)
	var gap: Vector2i = gap_info["gap"]
	var gap_dir: Vector2i = gap_info["dir"]
	var alcove: Array = gap_info["alcove"]
	var protected := _protected_cells(gap_info)
	for key: Variant in guarded.keys():
		protected[key] = true
	_mark_tunnel(cells, path, rng, protected)
	var nests := _place_nests_p(cells, rng, entry, heart, protected, profile["landmarks"], 3, cols, rows)
	_pinch_wide(cells, cols, rows, entry, heart, profile["landmarks"], nests, protected)
	_ensure_open_route(cells, cols, rows, entry, heart, protected, true)
	for n: Variant in nests:
		var nc: Vector2i = n
		_ensure_open_route(cells, cols, rows, entry, nc, protected, false)
	_pinch_wide(cells, cols, rows, entry, heart, profile["landmarks"], nests, protected)
	_close_orphans(cells, cols, rows, entry)
	var stacks := _place_stacks_p(cells, rng, gap, alcove, protected, cols, rows, 6)
	var gmin: Vector2 = profile["grid_min"]
	var cell: Vector2 = profile["cell"]
	var routes := _vertical_routes_p(cells, stacks, cols, rows, gmin, cell)
	var items := _place_items_p(cells, rng, alcove, profile["keepsakes"], cols, rows, gmin, cell)
	return {
		"floor": floor_id,
		"mood": String(profile["mood"]),
		"seed": seed_value,
		"map": _to_strings(cells),
		"cols": cols,
		"rows": rows,
		"grid_min": gmin,
		"cell_size": cell,
		"entry_cell": entry,
		"heart_cell": heart,
		"gap_cell": gap,
		"gap_dir": gap_dir,
		"alcove_cells": alcove,
		"nests": nests,
		"stacks": stacks,
		"vertical_routes": routes,
		"items": items,
		"decades": DECADES.duplicate(),
		"landmarks": profile["landmarks"],
	}


static func _blank_wh(cols: int, rows: int) -> Array:
	var cells: Array = []
	for _r in rows:
		var row: Array = []
		for _c in cols:
			row.append("#")
		cells.append(row)
	return cells


static func _inside_wh(c: Vector2i, cols: int, rows: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


static func _world(gmin: Vector2, cell: Vector2, c: int, r: int) -> Vector3:
	return Vector3(gmin.x + (float(c) + 0.5) * cell.x, 0.0, gmin.y + (float(r) + 0.5) * cell.y)


static func _carve_path_p(cells: Array, rng: RandomNumberGenerator, start: Vector2i, goal: Vector2i, cols: int, rows: int) -> Array:
	var path: Array = []
	var cur := start
	cells[cur.y][cur.x] = "."
	path.append(cur)
	var guard := 0
	while cur != goal and guard < 800:
		guard += 1
		var options: Array[Vector2i] = []
		var best := 999
		for d: Vector2i in DIRS:
			var n := cur + d
			if not _inside_wh(n, cols, rows):
				continue
			options.append(n)
			best = mini(best, _manhattan(n, goal))
		if options.is_empty():
			break
		var toward: Array[Vector2i] = []
		for n: Vector2i in options:
			if _manhattan(n, goal) == best:
				toward.append(n)
		var pick: Vector2i = toward[rng.randi() % toward.size()] if rng.randf() < 0.82 else options[rng.randi() % options.size()]
		cur = pick
		if cells[cur.y][cur.x] == "#":
			cells[cur.y][cur.x] = "."
		if path.is_empty() or path[path.size() - 1] != cur:
			path.append(cur)
	if cur != goal:
		cur = path[path.size() - 1]
		while cur.x != goal.x:
			cur.x += 1 if goal.x > cur.x else -1
			if cells[cur.y][cur.x] == "#":
				cells[cur.y][cur.x] = "."
			path.append(cur)
		while cur.y != goal.y:
			cur.y += 1 if goal.y > cur.y else -1
			if cells[cur.y][cur.x] == "#":
				cells[cur.y][cur.x] = "."
			path.append(cur)
	return path


static func _carve_spur_p(cells: Array, rng: RandomNumberGenerator, start: Vector2i, length: int, protected: Dictionary, cols: int, rows: int) -> void:
	var cur := start
	var dir: Vector2i = DIRS[rng.randi() % DIRS.size()]
	for _i in length:
		var n: Vector2i = cur + dir
		if not _inside_wh(n, cols, rows) or protected.has(n):
			break
		if cells[n.y][n.x] == "#":
			cells[n.y][n.x] = "."
		cur = n
		if rng.randf() < 0.25:
			dir = DIRS[rng.randi() % DIRS.size()]


static func _place_gap_p(cells: Array, rng: RandomNumberGenerator, entry: Vector2i, heart: Vector2i, protected: Dictionary, cols: int, rows: int) -> Dictionary:
	var candidates: Array = []
	for r in rows:
		for c in cols:
			if cells[r][c] == "#":
				continue
			var from := Vector2i(c, r)
			if from == entry or from == heart:
				continue
			for d: Vector2i in DIRS:
				var gap := from + d
				var a1 := from + d * 2
				var a2 := from + d * 3
				if not _inside_wh(gap, cols, rows) or not _inside_wh(a1, cols, rows) or not _inside_wh(a2, cols, rows):
					continue
				if protected.has(gap) or protected.has(a1) or protected.has(a2):
					continue
				if cells[gap.y][gap.x] != "#" or cells[a1.y][a1.x] != "#" or cells[a2.y][a2.x] != "#":
					continue
				if _touches_open_wh(cells, a1, gap, cols, rows) or _touches_open_wh(cells, a2, gap, cols, rows):
					continue
				candidates.append({"from": from, "gap": gap, "dir": d, "alcove": [a1, a2]})
	var picked: Dictionary
	if candidates.is_empty():
		picked = _force_gap_p(cells, entry, heart, protected, cols, rows)
	else:
		picked = candidates[rng.randi() % candidates.size()]
	var gap_cell: Vector2i = picked["gap"]
	cells[gap_cell.y][gap_cell.x] = "G"
	for a: Variant in picked["alcove"]:
		var ac: Vector2i = a
		cells[ac.y][ac.x] = "A"
	return picked


static func _force_gap_p(cells: Array, entry: Vector2i, heart: Vector2i, protected: Dictionary, cols: int, rows: int) -> Dictionary:
	for r in rows:
		for c in cols:
			if cells[r][c] == "#":
				continue
			var from := Vector2i(c, r)
			if from == entry or from == heart:
				continue
			for d: Vector2i in DIRS:
				var gap := from + d
				var a1 := from + d * 2
				var a2 := from + d * 3
				if not _inside_wh(a2, cols, rows):
					continue
				if protected.has(gap) or protected.has(a1) or protected.has(a2):
					continue
				var leak := false
				for pocket: Vector2i in [a1, a2]:
					for nd: Vector2i in DIRS:
						var nn := pocket + nd
						if nn == gap or nn == a1 or nn == a2 or not _inside_wh(nn, cols, rows):
							continue
						if cells[nn.y][nn.x] != "#":
							leak = true
				if leak:
					continue
				cells[gap.y][gap.x] = "#"
				cells[a1.y][a1.x] = "#"
				cells[a2.y][a2.x] = "#"
				return {"from": from, "gap": gap, "dir": d, "alcove": [a1, a2]}
	# A corner pocket. Seal its sides so the alcove stays private.
	var a2 := Vector2i(cols - 1, 0)
	var a1 := Vector2i(cols - 2, 0)
	var gap := Vector2i(cols - 3, 0)
	var from := Vector2i(cols - 4, 0)
	for cell: Vector2i in [gap, a1, a2]:
		if not protected.has(cell):
			cells[cell.y][cell.x] = "#"
	if cells[from.y][from.x] == "#":
		cells[from.y][from.x] = "."
	return {"from": from, "gap": gap, "dir": Vector2i(1, 0), "alcove": [a1, a2]}


static func _touches_open_wh(cells: Array, cell: Vector2i, ignore: Vector2i, cols: int, rows: int) -> bool:
	for d: Vector2i in DIRS:
		var n := cell + d
		if n == ignore or not _inside_wh(n, cols, rows):
			continue
		if cells[n.y][n.x] != "#":
			return true
	return false


static func _place_nests_p(cells: Array, rng: RandomNumberGenerator, entry: Vector2i, heart: Vector2i, protected: Dictionary, landmarks: Dictionary, want: int, cols: int, rows: int) -> Array:
	var nests: Array = []
	var order: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			order.append(Vector2i(c, r))
	for i in order.size():
		var j := rng.randi() % order.size()
		var tmp: Vector2i = order[i]
		order[i] = order[j]
		order[j] = tmp
	for pocket: Vector2i in order:
		if nests.size() >= want:
			break
		if protected.has(pocket):
			continue
		var ch := String(cells[pocket.y][pocket.x])
		if ch == "G" or ch == "A" or ch == "H":
			continue
		var entrances: Array[Vector2i] = []
		for d: Vector2i in DIRS:
			var n := pocket + d
			if not _inside_wh(n, cols, rows):
				continue
			var nch := String(cells[n.y][n.x])
			if nch != "#" and nch != "G" and nch != "A":
				entrances.append(n)
		if entrances.is_empty():
			continue
		var entrance: Vector2i = entrances[rng.randi() % entrances.size()]
		var saved := {}
		var blocked := false
		for extra: Vector2i in entrances:
			if extra == entrance:
				continue
			if protected.has(extra):
				blocked = true
				break
			saved[extra] = cells[extra.y][extra.x]
			cells[extra.y][extra.x] = "#"
		if blocked:
			for key: Variant in saved.keys():
				var sc: Vector2i = key
				cells[sc.y][sc.x] = saved[key]
			continue
		var prev: String = String(cells[pocket.y][pocket.x])
		cells[pocket.y][pocket.x] = "."
		var degree := _degree_cells(cells, pocket, cols, rows, false)
		var routes_ok := degree == 1 and _fully_connected(cells, cols, rows, entry, heart, landmarks, nests + [pocket])
		if not routes_ok:
			cells[pocket.y][pocket.x] = prev
			for key: Variant in saved.keys():
				var sc: Vector2i = key
				cells[sc.y][sc.x] = saved[key]
			continue
		nests.append(pocket)
		protected[pocket] = true
	return nests


static func _pinch_wide(cells: Array, cols: int, rows: int, entry: Vector2i, heart: Vector2i, landmarks: Dictionary, nests: Array, protected: Dictionary) -> void:
	var skip := {}
	var guard := 0
	while guard < cols * rows:
		guard += 1
		var level := {"map": _to_strings(cells), "cols": cols, "rows": rows}
		if narrow_fraction(level) >= 0.55:
			return
		var candidate := Vector2i(-1, -1)
		var best := 0
		for r in rows:
			for c in cols:
				var cell := Vector2i(c, r)
				if skip.has(cell) or protected.has(cell):
					continue
				var ch := String(cells[r][c])
				if ch != "." and ch != "T":
					continue
				var deg := _degree_cells(cells, cell, cols, rows, false)
				if deg > best:
					best = deg
					candidate = cell
		if candidate.x < 0 or best < 3:
			return
		var prev: String = String(cells[candidate.y][candidate.x])
		cells[candidate.y][candidate.x] = "#"
		if not _fully_connected(cells, cols, rows, entry, heart, landmarks, nests):
			cells[candidate.y][candidate.x] = prev
			skip[candidate] = true


static func _fully_connected(cells: Array, cols: int, rows: int, entry: Vector2i, heart: Vector2i, landmarks: Dictionary, nests: Array) -> bool:
	if not _routes_hold(cells, cols, rows, entry, heart, landmarks, nests):
		return false
	var level := {"map": _to_strings(cells), "cols": cols, "rows": rows}
	var shut := reachable_from(level, entry, true)
	var opened := reachable_from(level, entry, false)
	for r in rows:
		for c in cols:
			var ch := String(cells[r][c])
			var cell := Vector2i(c, r)
			if ch == "#":
				continue
			if ch == "A":
				if shut.has(cell) or not opened.has(cell):
					return false
			elif ch == "G":
				if not opened.has(cell):
					return false
			elif not shut.has(cell):
				return false
	return true


static func _close_orphans(cells: Array, cols: int, rows: int, entry: Vector2i) -> void:
	var level := {"map": _to_strings(cells), "cols": cols, "rows": rows}
	var shut := reachable_from(level, entry, true)
	for r in rows:
		for c in cols:
			var ch := String(cells[r][c])
			if ch == "#" or ch == "A" or ch == "G" or ch == "H":
				continue
			if not shut.has(Vector2i(c, r)):
				cells[r][c] = "#"


static func _routes_hold(cells: Array, cols: int, rows: int, entry: Vector2i, heart: Vector2i, landmarks: Dictionary, nests: Array) -> bool:
	var level := {"map": _to_strings(cells), "cols": cols, "rows": rows}
	if bfs(level, entry, heart, true).is_empty():
		return false
	for mark_name: Variant in landmarks.keys():
		var mark: Vector2i = landmarks[mark_name]
		if bfs(level, entry, mark, true).is_empty():
			return false
	for n: Variant in nests:
		var pocket: Vector2i = n
		if bfs(level, entry, pocket, false).is_empty():
			return false
		if _degree_cells(cells, pocket, cols, rows, false) != 1:
			return false
	return true


static func _degree_cells(cells: Array, cell: Vector2i, cols: int, rows: int, block_gap: bool) -> int:
	var level := {"map": _to_strings(cells)}
	return _open_degree(level, cell.x, cell.y, block_gap)


static func _nearest_on_spine(spine: Array, target: Vector2i) -> Vector2i:
	var best: Vector2i = spine[0]
	var best_d := 999
	for s: Variant in spine:
		var cell: Vector2i = s
		var d := _manhattan(cell, target)
		if d < best_d:
			best_d = d
			best = cell
	return best


static func _step_into_rect(anchor: Vector2i, hmin: Vector2i, hmax: Vector2i, cols: int, rows: int) -> Vector2i:
	if anchor.x >= hmin.x and anchor.x <= hmax.x and anchor.y >= hmin.y and anchor.y <= hmax.y:
		return anchor
	var target := Vector2i(int((hmin.x + hmax.x) / 2), int((hmin.y + hmax.y) / 2))
	var best := anchor
	var best_d := _manhattan(anchor, target)
	for d: Vector2i in DIRS:
		var n := anchor + d
		if not _inside_wh(n, cols, rows):
			continue
		if n.x < hmin.x or n.x > hmax.x or n.y < hmin.y or n.y > hmax.y:
			continue
		var dist := _manhattan(n, target)
		if dist < best_d:
			best_d = dist
			best = n
	return best


static func _open_line(cells: Array, a: Vector2i, b: Vector2i) -> void:
	var cur := a
	while cur != b:
		if cur.x != b.x:
			cur.x += 1 if b.x > cur.x else -1
		elif cur.y != b.y:
			cur.y += 1 if b.y > cur.y else -1
		if cells[cur.y][cur.x] == "#":
			cells[cur.y][cur.x] = "."


static func _ensure_open_route(cells: Array, cols: int, rows: int, start: Vector2i, goal: Vector2i, protected: Dictionary, block_gap: bool) -> void:
	var level := {"map": _to_strings(cells), "cols": cols, "rows": rows}
	if not bfs(level, start, goal, block_gap).is_empty():
		return
	var prev := {}
	var queue: Array[Vector2i] = [start]
	prev[start] = start
	var found := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for d: Vector2i in DIRS:
			var n := cur + d
			if prev.has(n) or not _inside_wh(n, cols, rows):
				continue
			var ch := String(cells[n.y][n.x])
			if ch == "A" or (block_gap and ch == "G"):
				continue
			if ch == "#" and protected.has(n):
				continue
			prev[n] = cur
			queue.append(n)
	if not found:
		return
	var walk := goal
	while walk != start:
		if cells[walk.y][walk.x] == "#":
			cells[walk.y][walk.x] = "."
		walk = prev[walk]


static func _place_stacks_p(cells: Array, rng: RandomNumberGenerator, gap: Vector2i, alcove: Array, protected: Dictionary, cols: int, rows: int, want: int) -> Array:
	var banned := {gap: true}
	for a: Variant in alcove:
		banned[a] = true
	var candidates: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			if cells[r][c] != "#":
				continue
			var cell := Vector2i(c, r)
			if banned.has(cell) or protected.has(cell):
				continue
			var open_n := false
			for d: Vector2i in DIRS:
				var n := cell + d
				if _inside_wh(n, cols, rows) and cells[n.y][n.x] != "#":
					open_n = true
			if open_n:
				candidates.append(cell)
	var stacks: Array = []
	var guard := 0
	while stacks.size() < want and not candidates.is_empty() and guard < 40:
		guard += 1
		var i := rng.randi() % candidates.size()
		var cell: Vector2i = candidates[i]
		candidates.remove_at(i)
		stacks.append({"cell": cell, "height": rng.randf_range(1.25, 2.15)})
	return stacks


static func _vertical_routes_p(cells: Array, stacks: Array, cols: int, rows: int, gmin: Vector2, cell_sz: Vector2) -> Array:
	var routes: Array = []
	for s: Variant in stacks:
		var sd: Dictionary = s
		var cell: Vector2i = sd["cell"]
		var floor_cell := Vector2i(-1, -1)
		for d: Vector2i in DIRS:
			var n := cell + d
			if _inside_wh(n, cols, rows) and cells[n.y][n.x] != "#":
				floor_cell = n
				break
		if floor_cell.x < 0:
			continue
		var h := float(sd["height"])
		routes.append({
			"stack_cell": cell,
			"floor_cell": floor_cell,
			"height": h,
			"perch": _world(gmin, cell_sz, cell.x, cell.y) + Vector3(0, h + 0.05, 0),
		})
	return routes


static func _place_items_p(cells: Array, rng: RandomNumberGenerator, alcove: Array, keepsakes: Dictionary, cols: int, rows: int, gmin: Vector2, cell_sz: Vector2) -> Array:
	var items: Array = []
	var alcove_set := {}
	for a: Variant in alcove:
		alcove_set[a] = true
	for decade: int in DECADES:
		var band := _decade_rows_for(decade, rows)
		var spots: Array[Vector2i] = []
		for r in range(band.x, band.y + 1):
			for c in cols:
				if cells[r][c] == "#":
					continue
				var cell := Vector2i(c, r)
				if alcove_set.has(cell):
					continue
				spots.append(cell)
		if spots.is_empty():
			var target := int(round((float(band.x) + float(band.y)) * 0.5))
			var best := 999
			var pick := Vector2i.ZERO
			var found := false
			for r in rows:
				for c in cols:
					if cells[r][c] == "#" or alcove_set.has(Vector2i(c, r)):
						continue
					var dist := absi(r - target)
					if dist < best:
						best = dist
						pick = Vector2i(c, r)
						found = true
			if found:
				spots.append(pick)
		var names: Array = keepsakes[decade]
		for k in mini(2, names.size()):
			if spots.is_empty():
				break
			var cell: Vector2i = spots[rng.randi() % spots.size()]
			items.append({
				"decade": decade,
				"name": String(names[k]),
				"cell": cell,
				"row": cell.y,
				"col": cell.x,
				"pos": _world(gmin, cell_sz, cell.x, cell.y) + Vector3(0, 0.18, 0),
			})
	return items


static func _decade_rows_for(decade: int, rows: int) -> Vector2i:
	var base := _decade_rows(decade)
	var span := maxi(1, rows - 1)
	var r0 := clampi(int(round(float(base.x) / 9.0 * float(span))), 0, rows - 1)
	var r1 := clampi(int(round(float(base.y) / 9.0 * float(span))), 0, rows - 1)
	if r1 < r0:
		return Vector2i(r1, r0)
	return Vector2i(r0, r1)
