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


func _wall(x: int, y: int) -> bool:
	# outside the grid counts as wall, except the tunnel mouths (left open)
	if x < 0 or x >= MazeGrid.COLS:
		return false
	if y < 0 or y >= MazeGrid.ROWS:
		return true
	return MazeGrid.GRID[y][x] == 1


func _draw() -> void:
	var pal: Array = COLORS[clampi(maze_index, 0, COLORS.size() - 1)]
	var fill: Color = (pal[0] as Color).lerp(Color.WHITE, flash)
	var col: Color = (pal[1] as Color).lerp(Color.WHITE, flash)
	var s := float(MazeGrid.CELL_SIZE)
	var lines: Array = []   # [from, to]
	for y in MazeGrid.ROWS:
		var run_start := -1
		for x in MazeGrid.COLS + 1:
			var w := x < MazeGrid.COLS and _wall(x, y)
			if w and run_start < 0:
				run_start = x
			elif not w and run_start >= 0:
				draw_rect(Rect2(run_start * s, (y + MazeGrid.ROW_OFFSET) * s, (x - run_start) * s, s), fill)
				run_start = -1
		for x in MazeGrid.COLS:
			if not _wall(x, y):
				continue
			var ox := x * s
			var oy := (y + MazeGrid.ROW_OFFSET) * s
			if x > 0 and not _wall(x - 1, y):
				lines.append([Vector2(ox, oy), Vector2(ox, oy + s)])
			if x < MazeGrid.COLS - 1 and not _wall(x + 1, y):
				lines.append([Vector2(ox + s, oy), Vector2(ox + s, oy + s)])
			if y > 0 and not _wall(x, y - 1):
				lines.append([Vector2(ox, oy), Vector2(ox + s, oy)])
			if y < MazeGrid.ROWS - 1 and not _wall(x, y + 1):
				lines.append([Vector2(ox, oy + s), Vector2(ox + s, oy + s)])
	for l in lines:
		var d: Vector2 = (l[1] - l[0]).normalized()
		draw_line(l[0] - d * 1.5, l[1] + d * 1.5, col, 3.0)
	# ghost-house door (the two walkable cells on the house's top row)
	var door_y := (11 + MazeGrid.ROW_OFFSET) * s
	draw_line(Vector2(14 * s + 1, door_y), Vector2(16 * s - 1, door_y),
		Color(1.0, 0.72, 0.85).lerp(Color.WHITE, flash), 3.0)
