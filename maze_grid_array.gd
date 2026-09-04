class_name MazeGrid
extends RefCounted

## Maze collision grid for the Pac-Man clone.
##
##   0 = walkable: the player and the ghosts may move and stop here.
##   1 = blocked:  neither the player nor a ghost may enter.
##       (Exception handled elsewhere: ghost_catched_eye may cross walls
##        straight back to the ghost house in the centre.)
##
## The grid describes the 30 x 30 play field only. Grid row 0 maps to map
## tile row 8, i.e. 0-indexed tile_y 7 (ROW_OFFSET). Grid column 0 maps to
## map tile column 0. Every cell is CELL_SIZE (16) pixels.

const CELL_SIZE := 16
const COLS := 30
const ROWS := 30
const ROW_OFFSET := 7      ## grid row 0 == map tile_y 7
const TUNNEL_ROW := 13     ## grid row with the left/right wrap corridor (tile_y 20)

## "No-up" intersections (original arcade rule): a ghost in Scatter or Chase mode
## may never turn UPWARD when sitting on one of these tiles. The pair on row 10
## sits in the lane right above the ghost house; the pair on row 19 guards the
## routes that feed back up toward it from below. (Frightened ghosts ignore this.)
const NO_UP: Array[Vector2i] = [
	Vector2i(13, 10), Vector2i(16, 10),
	Vector2i(10, 19), Vector2i(19, 19),
]

## Pill layer kinds (kept separate from the collision GRID above, so eating a
## pill never touches the maze and extra levels only need their own pill data).
const PILL_SMALL := 1      ## normal maze dot
const PILL_BIG := 2        ## power pill / energizer

## The four power pills, one per corner (grid space).
const BIG_PILLS: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(27, 3),
	Vector2i(2, 25), Vector2i(27, 25),
]

const GRID := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1],
	[1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1],
	[1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1],
	[1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
]


## True when [param cell] (grid space) is inside the field and walkable.
static func is_free(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= ROWS or cell.x < 0 or cell.x >= COLS:
		return false
	return GRID[cell.y][cell.x] == 0


## The ghost house: door tiles + inner area. Ghosts may move through it,
## the player must not enter it (the maze GRID itself stays walkable here).
static func is_ghost_house(cell: Vector2i) -> bool:
	return cell.x >= 11 and cell.x <= 18 and cell.y >= 11 and cell.y <= 15


## The ghost house plus the one-tile lane hugging it on all four sides.
## Used only to keep that ring dot-free, like the original maze.
static func is_around_ghost_house(cell: Vector2i) -> bool:
	return cell.x >= 10 and cell.x <= 19 and cell.y >= 10 and cell.y <= 16


## Walkable *and* allowed for the player (everything except the ghost house).
static func is_free_for_player(cell: Vector2i) -> bool:
	return is_free(cell) and not is_ghost_house(cell)


## World-space pixel centre of a grid cell.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		(cell.y + ROW_OFFSET) * CELL_SIZE + CELL_SIZE / 2.0)


## Grid cell that contains a world-space position.
static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / CELL_SIZE)),
		int(floor(pos.y / CELL_SIZE)) - ROW_OFFSET)


## True when a ghost on [param cell] must not turn upward (Scatter/Chase only).
static func is_no_up(cell: Vector2i) -> bool:
	return cell in NO_UP


## True when leaving [param cell] in [param dir] means entering the side tunnel
## (which wraps to the opposite edge instead of hitting a wall).
static func is_tunnel_exit(cell: Vector2i, dir: Vector2i) -> bool:
	if cell.y != TUNNEL_ROW:
		return false
	return (dir == Vector2i.LEFT and cell.x == 0) \
		or (dir == Vector2i.RIGHT and cell.x == COLS - 1)


## Nearest walkable cell to [param cell], searched in growing rings.
## Returns [param cell] unchanged if nothing free is found.
static func nearest_free(cell: Vector2i) -> Vector2i:
	if is_free(cell):
		return cell
	for r in range(1, maxi(COLS, ROWS)):
		for y in range(cell.y - r, cell.y + r + 1):
			for x in range(cell.x - r, cell.x + r + 1):
				var c := Vector2i(x, y)
				if is_free(c):
					return c
	return cell


## Default pill layout for this maze: { Vector2i(grid cell): PILL_SMALL | PILL_BIG }.
## A dot on every walkable tile except the ghost house, the tunnel mouths and the
## player's start strip; the four corner tiles become power pills.
static func build_pills() -> Dictionary:
	var pills := {}
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			if is_free(cell) and not _pill_excluded(cell):
				pills[cell] = PILL_SMALL
	for cell in BIG_PILLS:
		if pills.has(cell):
			pills[cell] = PILL_BIG
		else:
			push_warning("MazeGrid: big pill %s is not a free tile" % cell)
	return pills


static func _pill_excluded(cell: Vector2i) -> bool:
	# ghost house and the lane wrapping it
	if is_around_ghost_house(cell):
		return true
	# the six short 2-tile spurs that feed into that ring from outside it
	# (top: cols 13/16 rows 8-9; bottom: cols 10/19 rows 17-18; tunnel row
	# either side of the house between the col 7 / col 22 junctions and it)
	if (cell.x == 13 or cell.x == 16) and (cell.y == 8 or cell.y == 9):
		return true
	if (cell.x == 10 or cell.x == 19) and (cell.y == 17 or cell.y == 18):
		return true
	# dot-free warp corridor, except the two junctions where it crosses the
	# north-south corridors (col 7 and col 22)
	if cell.y == TUNNEL_ROW and cell.x != 7 and cell.x != 22 and (cell.x <= 9 or cell.x >= 20):
		return true
	# the two centre tiles Pac-Man straddles at the start
	if cell.y == 22 and (cell.x == 14 or cell.x == 15):
		return true
	return false
