class_name HoarderGenerator
extends RefCounted
## Seeded basement for 255 Massey Street.
##
## The floor plan comes out in the basement's own map format: 14×10
## strings, one character a cell, the same legend basement.gd walks
## ('.' open, '#' kept things, 'T' tunnel, 'G' the Aggie gap, 'H'
## heart, 'A' alcove). A level is playable when the entrance reaches
## the heart with the gap shut, the alcove opens only through the
## gap, and every nest pocket is reachable.
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
	var map: Array = level.get("map", [])
	if map.size() != ROWS:
		reasons.append("map should have %d rows (got %d)" % [ROWS, map.size()])
	for row: Variant in map:
		if String(row).length() != COLS:
			reasons.append("a row is not %d wide" % COLS)
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
	for r in ROWS:
		for c in COLS:
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
