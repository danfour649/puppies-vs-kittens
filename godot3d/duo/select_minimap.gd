class_name SelectMinimap
extends Control
## SELECT — top-down schematic of the house-and-yard for the
## character-select screen. Draws the lawn, the house along the north
## edge, the porch, the tree, the crates and the garden chair from the
## yard's real layout numbers, and marks each roster cat's actual
## start (gold and pulsing for the highlighted cat, a dim dot for the
## other). North (-Z) is up.

const GOLD := Color(1.0, 0.80, 0.38)
const W_MIN := Vector2(-13.4, -10.6) # world x/z bounds the map covers
const W_MAX := Vector2(13.4, 10.6)

var starts: Dictionary = {} # id -> Vector2(x, z), the cat's real spawn
var order: Array = []
var highlight_id := ""


func _process(_delta: float) -> void:
	queue_redraw() # the highlight marker pulses


func set_highlight(id: String) -> void:
	highlight_id = id
	queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return Vector2(
		(p.x - W_MIN.x) / (W_MAX.x - W_MIN.x) * size.x,
		(p.y - W_MIN.y) / (W_MAX.y - W_MIN.y) * size.y
	)


func _rect(x1: float, z1: float, x2: float, z2: float, col: Color) -> void:
	var a := _to_map(Vector2(x1, z1))
	var b := _to_map(Vector2(x2, z2))
	draw_rect(Rect2(a, b - a), col)


func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.05, 0.065))
	# Lawn inside the fence.
	_rect(-13.0, -10.0, 13.0, 10.0, Color(0.115, 0.175, 0.085))
	# The house along the north edge, and its porch deck.
	_rect(-8.5, -10.4, 8.5, -9.9, Color(0.44, 0.41, 0.37))
	_rect(-0.7, -10.0, 5.7, -7.4, Color(0.30, 0.22, 0.15))
	# Tree canopy, crates, the garden chair (Aggie's throne).
	var tree := _to_map(Vector2(-8.5, -5.0))
	draw_circle(tree, 1.5 / (W_MAX.x - W_MIN.x) * size.x, Color(0.085, 0.20, 0.07))
	_rect(9.2, -6.8, 10.6, -5.3, Color(0.35, 0.27, 0.17))
	_rect(4.15, 4.15, 4.85, 4.85, Color(0.55, 0.53, 0.48))
	# Fence line.
	var fa := _to_map(Vector2(-13.0, -10.0))
	var fb := _to_map(Vector2(13.0, 10.0))
	draw_rect(Rect2(fa, fb - fa), Color(0.38, 0.29, 0.19), false, 2.0)
	# Start markers.
	for id: Variant in order:
		if not starts.has(id):
			continue
		var p := _to_map(starts[id])
		if String(id) == highlight_id:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
			draw_circle(p, 11.0 + 3.0 * pulse, Color(GOLD, 0.16 + 0.12 * pulse))
			draw_arc(p, 8.5 + 2.0 * pulse, 0, TAU, 40, GOLD, 2.0)
			draw_circle(p, 4.0, GOLD)
		else:
			draw_arc(p, 5.5, 0, TAU, 32, Color(0.75, 0.76, 0.82, 0.65), 1.5)
			draw_circle(p, 2.6, Color(0.78, 0.79, 0.85, 0.8))
	draw_string(
		get_theme_default_font(),
		Vector2(size.x - 20.0, 20.0),
		"N",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color(0.62, 0.64, 0.70)
	)
	# Frame.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.28, 0.29, 0.34), false, 1.0)
