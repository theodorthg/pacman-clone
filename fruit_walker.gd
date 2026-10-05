class_name FruitWalker
extends Sprite2D

## Bonus fruit that wanders through the maze (Ms. Pac-Man style): it enters
## through one of the two side tunnels, picks a random direction at every
## junction (never straight back), and - once `leave()` is called - heads for
## the nearest tunnel mouth and exits. Slower than Pac-Man, so it can be caught.
## Grid movement like the ghosts; never enters the ghost house.

signal exited

const _DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var speed: float = 55.0

var _cell: Vector2i
var _target: Vector2i
var _dir: Vector2i
var _target_pos: Vector2
var _leaving: bool = false
var _dist: Dictionary = {}   ## cell -> steps to the nearest tunnel mouth (while leaving)


## Enter from the left (heading right) or the right (heading left) tunnel mouth.
func start(from_left: bool) -> void:
	var y := MazeGrid.TUNNEL_ROW
	_dir = Vector2i.RIGHT if from_left else Vector2i.LEFT
	_cell = Vector2i(-1 if from_left else MazeGrid.COLS, y)
	_target = _cell + _dir
	global_position = MazeGrid.cell_to_world(_cell)
	_target_pos = MazeGrid.cell_to_world(_target)


func is_leaving() -> bool:
	return _leaving


## Time is up: stop wandering, walk to the nearest tunnel mouth and leave.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_dist.clear()
	var queue: Array[Vector2i] = []
	for x in [0, MazeGrid.COLS - 1]:
		var c := Vector2i(x, MazeGrid.TUNNEL_ROW)
		_dist[c] = 0
		queue.append(c)
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in _DIRS:
			var n: Vector2i = cur + d
			if MazeGrid.is_free_for_player(n) and not _dist.has(n):
				_dist[n] = int(_dist[cur]) + 1
				queue.append(n)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var to_target := _target_pos - global_position
	if to_target.length() > step:
		global_position += to_target.normalized() * step
		return
	global_position = _target_pos
	_cell = _target
	if _cell.x < 0 or _cell.x >= MazeGrid.COLS:
		exited.emit()
		queue_free()
		return
	_dir = _pick_dir()
	_target = _cell + _dir
	_target_pos = MazeGrid.cell_to_world(_target)


func _can_go(d: Vector2i) -> bool:
	if MazeGrid.is_tunnel_exit(_cell, d):
		return _leaving
	return MazeGrid.is_free_for_player(_cell + d)


func _pick_dir() -> Vector2i:
	var options: Array[Vector2i] = []
	for d in _DIRS:
		if d != -_dir and _can_go(d):
			options.append(d)
	if options.is_empty():
		return -_dir   # dead end (should not exist) - turn around
	if _leaving:
		var best: Vector2i = options[0]
		var best_d := 1 << 30
		for d in options:
			var n: Vector2i = _cell + d
			var dd := -1 if MazeGrid.is_tunnel_exit(_cell, d) else int(_dist.get(n, 1 << 29))
			if dd < best_d:
				best_d = dd
				best = d
		return best
	return options[randi() % options.size()]
