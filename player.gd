class_name Player
extends CharacterBody2D

## Grid-based Pac-Man movement.
##
## The player glides from tile centre to tile centre along the maze corridors
## at a constant speed. A direction press is *remembered* (queued) and applied
## at the next tile centre where that direction is free, so the player can aim
## a turn early instead of having to hit the junction pixel-perfectly.
##
## - No key pressed yet        -> stand still, idle animation facing left.
## - Key pressed, way is free  -> start moving, keep moving on its own.
## - Runs into a wall/dead end -> stop, idle animation in the last facing.
## - Opposite key              -> reverse immediately, even between tiles.
## - Side tunnel (row 21)      -> wrap around to the other edge.
##
## Touch: a swipe anywhere on the screen queues that direction, exactly like a
## key press (works for the "press once, turn at the next chance" model).

signal died
## Emitted every time the player settles on a new tile centre (grid space).
signal reached_cell(cell: Vector2i)

## Travel speed in pixels per second.
@export var speed: float = 110.0
## Playback multiplier for every AnimatedSprite2D animation (1.0 = as authored).
@export var anim_speed_scale: float = 2.0
## Minimum travel (screen px) for a touch drag to count as a directional swipe
## mid-motion. A quick flick still registers on release at `swipe_flick_distance`.
@export var swipe_min_distance: float = 38.0
@export var swipe_flick_distance: float = 16.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

const _DIR_NAME := {
	Vector2i.RIGHT: "right",
	Vector2i.LEFT: "left",
	Vector2i.UP: "up",
	Vector2i.DOWN: "down",
}
const _ACTION_DIR := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}

var _cell: Vector2i                     ## grid cell the player last sat on
var _target: Vector2i                   ## grid cell currently gliding toward
var _target_pos: Vector2                ## world centre of _target
var _dir: Vector2i = Vector2i.ZERO      ## current travel direction
var _queued: Vector2i = Vector2i.ZERO   ## remembered desired direction
var _facing: Vector2i = Vector2i.LEFT   ## last direction faced (idle art)
var _moving: bool = false
var _dead: bool = false
var _frozen: bool = false               ## held still on the spot (death freeze-frame)
var _steered: bool = false              ## has the human pressed a direction this life?
var _home_pos: Vector2                  ## where the scene placed the player

var _touch_id: int = -1                 ## finger currently tracked for a swipe
var _touch_start: Vector2 = Vector2.ZERO
var _swipe_done: bool = false           ## this touch already fired a direction


func _ready() -> void:
	_sprite.speed_scale = anim_speed_scale
	# Keep the exact spot the scene placed us on (classic Pac-Man starts
	# straddling the two centre tiles); only derive the logical cell.
	_home_pos = global_position
	_cell = MazeGrid.nearest_free(MazeGrid.world_to_cell(global_position))
	_target = _cell
	_target_pos = MazeGrid.cell_to_world(_cell)
	_update_anim()


func _physics_process(delta: float) -> void:
	if _dead or _frozen:
		return

	_poll_input()

	# A 180° turn is always possible, even mid-tile.
	if _queued != Vector2i.ZERO and _dir != Vector2i.ZERO and _queued == -_dir:
		_reverse()

	if _moving:
		_advance(delta)
	else:
		_try_start()

	_update_anim()


## Remember the desired direction.
## A fresh press always wins (newest intent). A key that is merely held still
## counts, so players who hold the D-pad keep steering - but it never overwrites
## a turn that is still waiting for its next opportunity.
func _poll_input() -> void:
	for action in _ACTION_DIR:
		if Input.is_action_just_pressed(action):
			_queued = _ACTION_DIR[action]
			_steered = true
			return
	if _queued != Vector2i.ZERO:
		return
	for action in _ACTION_DIR:
		if Input.is_action_pressed(action):
			_queued = _ACTION_DIR[action]
			_steered = true
			return


## Touch swipes -> queued direction. A drag fires as soon as it passes the
## threshold (responsive); a quick flick still counts on release.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_id = event.index
			_touch_start = event.position
			_swipe_done = false
		elif event.index == _touch_id:
			if not _swipe_done:
				_swipe(event.position - _touch_start, swipe_flick_distance)
			_touch_id = -1
	elif event is InputEventScreenDrag and event.index == _touch_id and not _swipe_done:
		if _swipe(event.position - _touch_start, swipe_min_distance):
			_swipe_done = true


func _swipe(delta: Vector2, min_dist: float) -> bool:
	if delta.length() < min_dist:
		return false
	if absf(delta.x) > absf(delta.y):
		steer(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		steer(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)
	return true


## External steering (touch swipe / on-screen D-pad): queue a direction exactly
## like a key press, so the "turn at the next junction" logic still applies.
func steer(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	_queued = dir
	_steered = true


func _try_start() -> void:
	if _queued != Vector2i.ZERO and _can_leave(_cell, _queued):
		_dir = _queued
		_queued = Vector2i.ZERO
	elif not _can_leave(_cell, _dir):
		return
	_facing = _dir
	_set_target(_dir)
	_moving = true


func _advance(delta: float) -> void:
	var to_target := _target_pos - global_position
	var step := speed * delta
	if step < to_target.length():
		global_position += to_target.normalized() * step
		return

	# Arrived at the centre of _target -> pick the next tile.
	global_position = _target_pos
	_cell = _target
	reached_cell.emit(_cell)
	if _queued != Vector2i.ZERO and _can_leave(_cell, _queued):
		_dir = _queued
		_queued = Vector2i.ZERO
	elif not _can_leave(_cell, _dir):
		_dir = Vector2i.ZERO
		_moving = false
		return
	_facing = _dir
	_set_target(_dir)


func _reverse() -> void:
	_dir = -_dir
	_facing = _dir
	var heading_to := _target
	_target = _cell
	_cell = heading_to
	_target_pos = MazeGrid.cell_to_world(_target)
	_queued = Vector2i.ZERO
	_moving = true


func _can_leave(from: Vector2i, dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO:
		return false
	if MazeGrid.is_tunnel_exit(from, dir):
		return true
	return MazeGrid.is_free_for_player(from + dir)


func _set_target(dir: Vector2i) -> void:
	var next := _cell + dir
	if next.x < 0:
		# left tunnel mouth -> reappear on the right edge
		global_position = MazeGrid.cell_to_world(Vector2i(MazeGrid.COLS, _cell.y))
		next = Vector2i(MazeGrid.COLS - 1, _cell.y)
	elif next.x >= MazeGrid.COLS:
		# right tunnel mouth -> reappear on the left edge
		global_position = MazeGrid.cell_to_world(Vector2i(-1, _cell.y))
		next = Vector2i(0, _cell.y)
	_target = next
	_target_pos = MazeGrid.cell_to_world(next)


func _update_anim() -> void:
	if _dead:
		return
	if _dir != Vector2i.ZERO:
		_sprite.play("move_" + _DIR_NAME[_dir])
	else:
		_sprite.play("idle_animation_" + _DIR_NAME[_facing])


## Hold the player still on the current frame (the ~1 s freeze the arcade plays
## between touching a ghost and the death animation starting).
func freeze() -> void:
	_frozen = true
	_sprite.pause()


## Stop the player and play the death animation.
func die() -> void:
	if _dead:
		return
	_frozen = false
	_dead = true
	_moving = false
	_dir = Vector2i.ZERO
	_queued = Vector2i.ZERO
	velocity = Vector2.ZERO
	_sprite.play("death_animation")
	died.emit()


## Put the player back to a resting state.
## No argument -> back to the scene's start spot; pass a grid cell to respawn there.
func reset(to_cell := Vector2i(-1, -1)) -> void:
	_dead = false
	_frozen = false
	_moving = false
	_steered = false
	_dir = Vector2i.ZERO
	_queued = Vector2i.ZERO
	_facing = Vector2i.LEFT
	if to_cell == Vector2i(-1, -1):
		global_position = _home_pos
		_cell = MazeGrid.nearest_free(MazeGrid.world_to_cell(_home_pos))
	else:
		_cell = MazeGrid.nearest_free(to_cell)
		global_position = MazeGrid.cell_to_world(_cell)
	_target = _cell
	_target_pos = MazeGrid.cell_to_world(_cell)
	_update_anim()


## Kick off an initial move (e.g. when the first ghost leaves the house) if the
## player hasn't already been steered by the time this is called.
func auto_start(dir: Vector2i) -> void:
	if not _steered and _dir == Vector2i.ZERO and not _moving and _queued == Vector2i.ZERO:
		_queued = dir


## Has the human pressed a direction key since the last reset?
func was_steered() -> bool:
	return _steered


## The direction the player intends to go next: a queued turn if one is waiting,
## otherwise the current heading. Drives the on-screen swipe indicator.
func desired_dir() -> Vector2i:
	return _queued if _queued != Vector2i.ZERO else heading()


## Current grid cell (for the ghosts' targeting).
func cell() -> Vector2i:
	return _cell


## Direction the player is facing, even while standing still.
func heading() -> Vector2i:
	return _dir if _dir != Vector2i.ZERO else _facing
