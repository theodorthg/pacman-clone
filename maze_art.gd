class_name MazeArt
extends Node2D

## Draws a maze from MazeGrid.GRID as neon wall outlines (mazes 1+; maze 0 keeps
## its hand-made tilemap art). Outline = every cell edge between a wall and a
## walkable cell, glow + core line, in a per-maze colour. `flash` (0..1) drives
## the level-clear flash towards white, like maze_flash.gdshader does for tiles.

## [wall fill, outline] per maze. The corridors are the project's clear colour
## (mid blue), like the tilemap art of maze 0 - walls are pastel with a darker
## outline.
const COLORS := [
	[Color(0.30, 0.65, 1.00), Color(0.10, 0.22, 0.85)],   # 0 original (unused here)
	[Color(1.00, 0.62, 0.80), Color(0.78, 0.15, 0.45)],   # 1 pink
	[Color(0.45, 0.92, 0.90), Color(0.05, 0.50, 0.60)],   # 2 teal
	[Color(1.00, 0.76, 0.42), Color(0.78, 0.38, 0.05)],   # 3 orange
	[Color(0.62, 0.92, 0.50), Color(0.18, 0.52, 0.15)],   # 4 green
]

var maze_index: int = 1
var flash: float = 0.0:
	set(v):
		flash = v
		queue_redraw()


func setup(index: int) -> void:
	maze_index = index
	queue_redraw()


## Corner rounding radius (px). Must be <= CELL_SIZE / 2.
const R := 6.0
const _ARC_STEPS := 6


## Outside the grid counts as "free" (void, same colour as the corridors), so
## the frame is outlined and rounded like any inner block.
func _wall(x: int, y: int) -> bool:
	if x < 0 or x >= MazeGrid.COLS or y < 0 or y >= MazeGrid.ROWS:
		return false
	return MazeGrid.GRID[y][x] == 1


## Pixel position of grid vertex (vx, vy) (the corner shared by 4 cells).
func _vpos(vx: int, vy: int) -> Vector2:
	var s := float(MazeGrid.CELL_SIZE)
	return Vector2(vx * s, (vy + MazeGrid.ROW_OFFSET) * s)


## 0 = straight / empty / diagonal checkerboard (no rounding), 1 = convex wall
## corner (only one wall cell around the vertex), 3 = concave (only one free).
func _vertex_kind(vx: int, vy: int) -> int:
	var n := 0
	for c in [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]:
		if _wall(c.x, c.y):
			n += 1
	return n if (n == 1 or n == 3) else 0


## Cell (relative to the vertex) the corner points into: for kind 1 the lone
## wall cell, for kind 3 the lone free cell. Returned as sign vector (-1/+1).
func _corner_dir(vx: int, vy: int, want_wall: bool) -> Vector2:
	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		var cx: int = vx + (0 if c[0] > 0 else -1)
		var cy: int = vy + (0 if c[1] > 0 else -1)
		if _wall(cx, cy) == want_wall:
			return Vector2(c[0], c[1])
	return Vector2.ZERO


func _arc_points(p: Vector2, dir: Vector2) -> PackedVector2Array:
	var c := p + dir * R
	var pts := PackedVector2Array()
	for i in _ARC_STEPS + 1:
		var phi := (PI * 0.5) * float(i) / float(_ARC_STEPS)
		pts.append(c + Vector2(-dir.x * sin(phi), -dir.y * cos(phi)) * R)
	return pts


func _draw() -> void:
	var pal: Array = COLORS[clampi(maze_index, 0, COLORS.size() - 1)]
	var fill: Color = (pal[0] as Color).lerp(Color.WHITE, flash)
	var col: Color = (pal[1] as Color).lerp(Color.WHITE, flash)
	var clear: Color = RenderingServer.get_default_clear_color()
	var s := float(MazeGrid.CELL_SIZE)

	# 1. wall cells, merged into horizontal runs
	for y in MazeGrid.ROWS:
		var run_start := -1
		for x in MazeGrid.COLS + 1:
			var w := x < MazeGrid.COLS and _wall(x, y)
			if w and run_start < 0:
				run_start = x
			elif not w and run_start >= 0:
				draw_rect(Rect2(run_start * s, (y + MazeGrid.ROW_OFFSET) * s, (x - run_start) * s, s), fill)
				run_start = -1

	# 2. rounded corners: convex corners are cut away (clear colour), concave
	# ones get a wall-coloured fillet; both outlined with an arc
	var kinds := {}
	for vy in range(0, MazeGrid.ROWS + 1):
		for vx in range(0, MazeGrid.COLS + 1):
			var k := _vertex_kind(vx, vy)
			if k == 0:
				continue
			kinds[Vector2i(vx, vy)] = true
			var p := _vpos(vx, vy)
			var dir := _corner_dir(vx, vy, k == 1)
			var arc := _arc_points(p, dir)
			var poly := PackedVector2Array([p])
			poly.append_array(arc)
			draw_colored_polygon(poly, clear if k == 1 else fill)
			draw_polyline(arc, col, 3.0)

	# 3. straight outline pieces, trimmed where a rounded corner takes over
	for y in MazeGrid.ROWS:
		for x in MazeGrid.COLS:
			if not _wall(x, y):
				continue
			if not _wall(x - 1, y):
				_edge(Vector2i(x, y), Vector2i(x, y + 1), kinds, col)
			if not _wall(x + 1, y):
				_edge(Vector2i(x + 1, y), Vector2i(x + 1, y + 1), kinds, col)
			if not _wall(x, y - 1):
				_edge(Vector2i(x, y), Vector2i(x + 1, y), kinds, col)
			if not _wall(x, y + 1):
				_edge(Vector2i(x, y + 1), Vector2i(x + 1, y + 1), kinds, col)

	# 4. ghost-house door (the two walkable cells on the house's top row)
	var door_y := (11 + MazeGrid.ROW_OFFSET) * s
	draw_line(Vector2(14 * s + 1, door_y), Vector2(16 * s - 1, door_y),
		Color(1.0, 0.72, 0.85).lerp(Color.WHITE, flash), 3.0)


func _edge(a: Vector2i, b: Vector2i, kinds: Dictionary, col: Color) -> void:
	var pa := _vpos(a.x, a.y)
	var pb := _vpos(b.x, b.y)
	var d := (pb - pa).normalized()
	var ta := R if kinds.has(a) else 0.0
	var tb := R if kinds.has(b) else 0.0
	draw_line(pa + d * (ta - 0.5), pb - d * (tb - 0.5), col, 3.0)
