class_name Ghost
extends CharacterBody2D

## One maze ghost. Grid movement like the player, but instead of reading input it
## steers toward a personality-specific target tile: at every tile centre it takes
## the exit (never reversing) whose next tile lands closest to that target.
##
## States:
##   HOUSE      - parked inside / in front of the house, bobbing, waiting
##   LEAVING    - scripted walk out through the door
##   SCATTER    - head for my own corner
##   CHASE      - head for my personality target near Pac-Man
##   FRIGHTENED - edible: slow, random turns, blue (flashing white near the end)
##   EYES       - eaten: fast straight line to the house centre, then revives and
##                leaves again immediately (no waiting, never blue)

enum Personality { BLINKY, PINKY, INKY, CLYDE }
enum State { HOUSE, LEAVING, SCATTER, CHASE, FRIGHTENED, EYES }

@export var personality: Personality = Personality.BLINKY
@export var speed: float = 100.0
@export var frightened_speed_mult: float = 0.5
@export var eyes_speed: float = 220.0
@export var anim_speed_scale: float = 2.0
## The coordinator (pacman_map / game node) that exposes player + blinky info.
@export var game_path: NodePath = ^"../game"

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

const _BLUE_FRAMES: SpriteFrames = preload("res://ghost_frames_blue.tres")
const _WHITE_FRAMES: SpriteFrames = preload("res://ghost_frames_white.tres")
const _EYES_FRAMES: SpriteFrames = preload("res://ghost_frames_eyes.tres")

const _DIR_ANIM := {
	Vector2i.RIGHT: "move_east",
	Vector2i.LEFT: "move_west",
	Vector2i.UP: "move_north",
	Vector2i.DOWN: "move_south",
}
## Tie-break order when two exits are equally close (classic: up, left, down, right).
const _PREFER: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]

## World position just outside the door, one tile above it.
const _DOOR_OUT := Vector2(240, 280)
## World position centred under the door, inside the house.
const _DOOR_IN := Vector2(240, 328)

## Fixed scatter-mode target tiles, one per ghost, at the four corners of the
## 30x30 grid (= (COLS-1, ROWS-1)). They sit on the border wall, so each ghost
## just circles its own corner while scatter mode lasts.
const SCATTER_BLINKY := Vector2i(29, 0)    # top-right
const SCATTER_PINKY := Vector2i(0, 0)      # top-left
const SCATTER_INKY := Vector2i(29, 29)     # bottom-right
const SCATTER_CLYDE := Vector2i(0, 29)     # bottom-left

var _game: Node
var _home_pos: Vector2
var _normal_frames: SpriteFrames
var _state: int = State.HOUSE
var _mode: int = State.SCATTER          ## global wave the map is in (SCATTER/CHASE)
var _pending_state_after_leave: int = State.SCATTER
var _cell: Vector2i                     ## tile currently occupied (centre reached)
var _target: Vector2i                   ## tile being travelled toward
var _target_pos: Vector2                ## world centre of _target
var _dir: Vector2i = Vector2i.LEFT      ## direction currently travelling
var _next_dir: Vector2i = Vector2i.LEFT ## turn to take on reaching _target (decided one tile early)
var _leave_queue: Array[Vector2] = []
var _bob_t: float = 0.0
var _flash_white: bool = false
var _house_look_blue: bool = false      ## blue skin while LEAVING into an active fright


func _ready() -> void:
	_sprite.speed_scale = anim_speed_scale
	_normal_frames = _sprite.sprite_frames
	_home_pos = global_position
	_game = get_node_or_null(game_path)
	reset()


func _physics_process(delta: float) -> void:
	match _state:
		State.HOUSE:
			if personality != Personality.BLINKY:
				_bob(delta)   # Blinky waits outside the house, not in it
		State.LEAVING:
			_leave(delta)
		State.EYES:
			_travel_eyes(delta)
		_:
			_navigate(delta)
	_update_anim()


# --- public API for the game coordinator ------------------------------------

## On the map, whether dangerous, edible or on its way home.
func is_on_map() -> bool:
	return _state == State.SCATTER or _state == State.CHASE or _state == State.FRIGHTENED


## On the map and able to kill the player.
func is_dangerous() -> bool:
	return _state == State.SCATTER or _state == State.CHASE


func is_frightened() -> bool:
	return _state == State.FRIGHTENED


func is_in_house() -> bool:
	return _state == State.HOUSE


## Eaten and travelling home as a pair of eyes.
func is_eyes() -> bool:
	return _state == State.EYES


## Can Pac-Man eat me right now? True while roaming frightened (blue or flashing
## white), and also while walking out of the house into a still-active fright.
func is_edible() -> bool:
	return _state == State.FRIGHTENED or (_state == State.LEAVING and _house_look_blue)


func cell() -> Vector2i:
	return _cell


## Send the ghost out of the house. No-op once it is already out. A ghost let out
## while frightened mode is running comes out blue.
func release() -> bool:
	if _state != State.HOUSE:
		return false
	var enter_state: int = _mode
	if _game != null and _game.is_frightened_active():
		enter_state = State.FRIGHTENED
	_pending_state_after_leave = enter_state
	# stay blue (and flash) while walking out into a still-active fright
	_house_look_blue = enter_state == State.FRIGHTENED
	if personality == Personality.BLINKY:
		# already sitting in front of the door - just start driving
		_cell = MazeGrid.world_to_cell(global_position)
		global_position = MazeGrid.cell_to_world(_cell)
		_target = _cell
		_target_pos = global_position
		_dir = Vector2i.LEFT
		_next_dir = Vector2i.LEFT
		_state = enter_state
	else:
		_state = State.LEAVING
		_dir = Vector2i.UP
		_leave_queue = [_DOOR_IN, _DOOR_OUT]
	_update_anim()
	return true


## Global wave change (SCATTER <-> CHASE), pushed by the game's wave timer every
## phase boundary. A ghost out on the maze switches mode AND reverses 180 degrees
## on the spot - the only time a ghost turns around on its own. Ghosts in the
## house / frightened / eyes just note the new mode for when they rejoin; a ghost
## still walking out keeps its pending mode in sync (unless it is heading out
## blue).
func set_mode(mode: int) -> void:
	_mode = mode
	if _state == State.SCATTER or _state == State.CHASE:
		_state = mode
		_reverse()
	elif _state == State.LEAVING and _pending_state_after_leave != State.FRIGHTENED:
		_pending_state_after_leave = mode


## A power pill was eaten. Only affects ghosts that are out on the maze, or in the
## middle of leaving the house - they reverse 180 degrees and turn blue. Ghosts
## still in the house are exempt; eyes (already eaten) are exempt.
func frighten() -> void:
	if _state == State.SCATTER or _state == State.CHASE:
		_state = State.FRIGHTENED
		_reverse()
		_flash_white = false
		_update_anim()
	elif _state == State.LEAVING:
		_pending_state_after_leave = State.FRIGHTENED
		_house_look_blue = true
		_flash_white = false
		_update_anim()


## The frightened window ran out: resume the current wave, drop the blue skin.
func end_frighten() -> void:
	if _state == State.FRIGHTENED:
		_state = _mode
	if _pending_state_after_leave == State.FRIGHTENED:
		_pending_state_after_leave = _mode
	_house_look_blue = false
	_flash_white = false
	_update_anim()


## Toggle the blue/white warning flash near the end of the frightened window.
func set_frightened_flash(on: bool) -> void:
	_flash_white = on


## Pac-Man touched me while I was edible: become eyes and head home.
func get_eaten() -> void:
	_state = State.EYES
	_leave_queue.clear()
	_flash_white = false
	_house_look_blue = false
	_update_anim()


func reset() -> void:
	_state = State.HOUSE
	_mode = State.SCATTER
	global_position = _home_pos
	_cell = MazeGrid.world_to_cell(_home_pos)
	_target = _cell
	_target_pos = _home_pos
	_dir = Vector2i.LEFT
	_next_dir = Vector2i.LEFT
	_leave_queue.clear()
	_bob_t = 0.0
	_flash_white = false
	_house_look_blue = false
	_pending_state_after_leave = State.SCATTER
	_update_anim()


# --- movement --------------------------------------------------------------

func _bob(delta: float) -> void:
	_bob_t += delta * 3.0
	global_position = _home_pos + Vector2(0.0, sin(_bob_t) * 4.0)


func _leave(delta: float) -> void:
	if _leave_queue.is_empty():
		_cell = MazeGrid.world_to_cell(global_position)
		global_position = MazeGrid.cell_to_world(_cell)
		_target = _cell
		_target_pos = global_position
		_dir = Vector2i.LEFT
		_next_dir = Vector2i.LEFT   # ghosts always exit the house heading left
		_house_look_blue = false
		# _pending_state_after_leave is kept in step with the fright window by
		# end_frighten(): FRIGHTENED while it's running, _mode once it ended.
		_state = _pending_state_after_leave
		return
	var wp: Vector2 = _leave_queue[0]
	var to := wp - global_position
	var step := speed * delta
	if step >= to.length():
		global_position = wp
		_leave_queue.pop_front()
	else:
		global_position += to.normalized() * step
	if absf(to.x) > absf(to.y):
		_dir = Vector2i.RIGHT if to.x > 0.0 else Vector2i.LEFT
	elif to.y != 0.0:
		_dir = Vector2i.DOWN if to.y > 0.0 else Vector2i.UP


func _travel_eyes(delta: float) -> void:
	var to := _DOOR_IN - global_position
	var step := eyes_speed * delta
	if step >= to.length():
		global_position = _DOOR_IN
		_revive_and_leave()
	else:
		global_position += to.normalized() * step


## Eyes reached the house centre: revive right there and head straight back out,
## no waiting. Revived ghosts leave in the current wave mode, never blue - so the
## order out is simply the order the eyes got home (FIFO) and the player can't
## park at the door for an easy re-eat.
func _revive_and_leave() -> void:
	_cell = MazeGrid.world_to_cell(_DOOR_IN)
	_target = _cell
	_target_pos = _DOOR_IN
	_dir = Vector2i.UP
	_house_look_blue = false
	_flash_white = false
	_pending_state_after_leave = _mode
	_state = State.LEAVING
	_leave_queue = [_DOOR_OUT]
	_update_anim()


## Local, tile-by-tile pathing (no global A*). Glide toward the tile centre; on
## reaching it, take the turn that was decided one tile ago, then immediately
## look ahead and decide the turn for the tile we are now heading into.
func _navigate(delta: float) -> void:
	var eff_speed := speed * (frightened_speed_mult if _state == State.FRIGHTENED else 1.0)
	var to := _target_pos - global_position
	var step := eff_speed * delta
	if step < to.length():
		global_position += to.normalized() * step
		return
	global_position = _target_pos
	_cell = _target
	_dir = _next_dir
	_set_target(_dir)
	_next_dir = _decide_dir(_target, _dir)


## Pick the exit direction for [param tile], given the ghost will arrive there
## travelling [param incoming_dir]. Rules:
##  - never the reverse of incoming_dir (the "no 180" law);
##  - Scatter/Chase on a no-up tile: UP is off limits;
##  - Frightened: uniformly random among the remaining options;
##  - otherwise: the neighbour tile with the smallest straight-line
##    (distance_squared) to the current target tile wins, ties broken by
##    up > left > down > right (the order of _PREFER).
func _decide_dir(tile: Vector2i, incoming_dir: Vector2i) -> Vector2i:
	var banned := -incoming_dir

	if _state == State.FRIGHTENED:
		var options: Array[Vector2i] = []
		for d: Vector2i in _PREFER:
			if d != banned and _passable(tile, d):
				options.append(d)
		return options[randi() % options.size()] if not options.is_empty() else banned

	var goal := Vector2(_target_cell())
	var no_up := MazeGrid.is_no_up(tile)
	var best := Vector2i.ZERO
	var best_dist := INF
	for d: Vector2i in _PREFER:
		if d == banned:
			continue
		if no_up and d == Vector2i.UP:
			continue
		if not _passable(tile, d):
			continue
		var dist := Vector2(_next_cell(tile, d)).distance_squared_to(goal)
		if dist < best_dist:
			best_dist = dist
			best = d
	# genuine dead end (only the way back is open) -> forced to turn around
	return best if best != Vector2i.ZERO else banned


## Flip 180 and re-path. Only ever triggered externally (fright start, or a
## Scatter<->Chase phase boundary) - the caller sets _state first so _decide_dir
## picks the right kind of turn for the tile we now head into.
func _reverse() -> void:
	_dir = -_dir
	var heading_to := _target
	_target = _cell
	_cell = heading_to
	_target_pos = MazeGrid.cell_to_world(_target)
	_next_dir = _decide_dir(_target, _dir)


func _set_target(dir: Vector2i) -> void:
	var n := _cell + dir
	if n.x < 0:
		global_position = MazeGrid.cell_to_world(Vector2i(MazeGrid.COLS, _cell.y))
		n = Vector2i(MazeGrid.COLS - 1, _cell.y)
	elif n.x >= MazeGrid.COLS:
		global_position = MazeGrid.cell_to_world(Vector2i(-1, _cell.y))
		n = Vector2i(0, _cell.y)
	_target = n
	_target_pos = MazeGrid.cell_to_world(n)


func _passable(from: Vector2i, dir: Vector2i) -> bool:
	if MazeGrid.is_tunnel_exit(from, dir):
		return true
	return _can_enter(from + dir)


func _can_enter(c: Vector2i) -> bool:
	if not MazeGrid.is_free(c):
		return false
	if MazeGrid.is_ghost_house(c) and _state != State.EYES and _state != State.LEAVING:
		return false
	return true


func _next_cell(from: Vector2i, dir: Vector2i) -> Vector2i:
	var n := from + dir
	if n.x < 0:
		return Vector2i(MazeGrid.COLS - 1, from.y)
	if n.x >= MazeGrid.COLS:
		return Vector2i(0, from.y)
	return n


# --- targeting ------------------------------------------------------------
#
# Every ghost aims for a personality-specific "target tile" (may sit outside the
# maze). At a junction it takes the non-reversing exit whose neighbouring tile is
# the shortest straight-line (Euclidean) distance from that target - see
# _choose_dir(). These are the exact original-arcade chase rules.

func _target_cell() -> Vector2i:
	if _state == State.CHASE:
		return _chase_target()
	return _scatter_target()


## The fixed corner this ghost heads for during Scatter mode.
func _scatter_target() -> Vector2i:
	match personality:
		Personality.BLINKY: return SCATTER_BLINKY
		Personality.PINKY:  return SCATTER_PINKY
		Personality.INKY:   return SCATTER_INKY
		Personality.CLYDE:  return SCATTER_CLYDE
	return SCATTER_BLINKY


func _chase_target() -> Vector2i:
	if _game == null:
		return _scatter_target()
	var pac: Vector2i = _game.player_cell()
	var head: Vector2i = _game.player_heading()
	match personality:
		Personality.BLINKY:
			# Shadow: straight at Pac-Man's tile.
			return pac
		Personality.PINKY:
			# Ambusher: 4 tiles in front of Pac-Man.
			return _tiles_ahead(pac, head, 4)
		Personality.INKY:
			# Bashful: take the tile 2 in front of Pac-Man, draw the vector from
			# Blinky to it, then double that vector - the far end is Inky's target.
			var pivot := _tiles_ahead(pac, head, 2)
			return pivot * 2 - _game.blinky_cell()
		Personality.CLYDE:
			# Pokey: chases like Blinky while > 8 tiles from Pac-Man, but bolts for
			# his own corner once he is 8 tiles or closer.
			var me := MazeGrid.world_to_cell(global_position)
			if (pac - me).length_squared() > 64:
				return pac
			return _scatter_target()
	return pac


## The tile [param n] steps ahead of [param from] along [param dir]. Reproduces
## the original arcade overflow bug: when Pac-Man faces UP the target is also
## shifted [param n] tiles to the LEFT.
func _tiles_ahead(from: Vector2i, dir: Vector2i, n: int) -> Vector2i:
	var t := from + dir * n
	if dir == Vector2i.UP:
		t.x -= n
	return t


# --- animation --------------------------------------------------------------

func _update_anim() -> void:
	if _state == State.EYES:
		_set_frames(_EYES_FRAMES)
		_sprite.play("move_all_directions")
	elif _state == State.FRIGHTENED or _house_look_blue:
		if _flash_white:
			_set_frames(_WHITE_FRAMES)
			_sprite.play(_DIR_ANIM.get(_dir, "move_west"))
		else:
			_set_frames(_BLUE_FRAMES)
			_sprite.play("move_all_directions")
	else:
		_set_frames(_normal_frames)
		_sprite.play(_DIR_ANIM.get(_dir, "move_west"))


func _set_frames(frames: SpriteFrames) -> void:
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
