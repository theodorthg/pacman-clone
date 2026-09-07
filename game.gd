class_name Game
extends Node

## Round coordinator built on the original Pac-Man rules (level 1 tuned):
##  - Blinky starts outside the house and moves the instant the round begins;
##    Pinky leaves immediately too.
##  - Inky leaves once Pac-Man has eaten `inky_dot_limit` dots (this level),
##    Clyde at `clyde_dot_limit`; a `dot_timeout` s gap forces the next one out.
##  - Eaten ghosts become eyes, run straight to the house centre and revive +
##    leave again immediately (FIFO, never blue).
##  - Frightened lasts `frightened_duration` s (only ghosts outside the house),
##    180-turns them on start, flashes white for the last `frightened_flash_time`
##    s. The scatter/chase timer is frozen while it runs.
##  - Fruit spawns twice a level (at `fruit_dot_1` / `fruit_dot_2` dots), sits
##    for 9-10 s below the house, worth a level-dependent bonus.
##  - Eating all pills -> level-clear sequence (freeze, maze flash, level up,
##    READY!). Capped at `MAX_LEVEL`, after which the win screen shows.

signal score_changed(new_score: int)

@export var player_path: NodePath = ^"../player"
@export var pills_path: NodePath = ^"../pills"
@export var maze_path: NodePath = ^"../tiles"
@export var score_label_path: NodePath = ^"../hud/score_label"
@export var highscore_label_path: NodePath = ^"../hud/hi_label"
@export var level_label_path: NodePath = ^"../hud/level_label"
@export var ready_label_path: NodePath = ^"../hud/ready_label"
@export var lives_box_path: NodePath = ^"../hud/lives_box"
@export var items_box_path: NodePath = ^"../hud/items_box"
@export var overlay_path: NodePath = ^"../overlay"
@export var settings_path: NodePath = ^"../settings"
@export var sound_path: NodePath = ^"../audio"
@export var touch_controls_path: NodePath = ^"../touch_controls"

@export var lives: int = 3

## Extra lives: first one at `first_extra_life` points (0 = disabled), then every
## `extra_life_gap` points with the gap multiplied by `extra_life_gap_mult` each
## time it is claimed (2500 -> +5000 -> +10000 -> +20000 -> ...).
@export var first_extra_life: int = 2500
@export var extra_life_gap: int = 5000
@export var extra_life_gap_mult: float = 2.0

## Highest level that can be cleared; clearing it shows the win screen.
const MAX_LEVEL := 99

## The level's start delay ("READY!"): the round waits this long before Blinky
## and Pinky go, unless the player presses a direction first.
@export var start_grace: float = 5.0

## Ghost-house exit thresholds (dots eaten this level) and the no-dot fallback.
@export var inky_dot_limit: int = 30
@export var clyde_dot_limit: int = 60
@export var dot_timeout: float = 4.0

## Death timing (arcade): on contact everything freezes for `death_freeze` s,
## THEN Pac-Man's death animation plays for `death_pause` s, THEN positions reset
## and everyone stands on "READY!" for `respawn_ready` s before moving again.
@export var death_freeze: float = 1.0
@export var death_pause: float = 1.5
@export var respawn_ready: float = 1.6

## "READY!" hold at the end of a level-clear (long enough for the level-up
## jingle to finish playing).
@export var level_clear_ready: float = 4.0

## Brief hitstop when Pac-Man eats a ghost (arcade shows only the score for ~1 s).
@export var ghost_eat_freeze: float = 0.5

## Global dot counter (arcade "death" rule): after Pac-Man loses a life the house
## exits switch from the personal counters to one shared counter that starts at 0.
@export var global_pinky_dots: int = 7
@export var global_inky_dots: int = 17
@export var global_clyde_dots: int = 32

## Frightened window (level 1: 6 s total, last ~2 s flashing = 5 white flashes).
@export var frightened_duration: float = 6.0
@export var frightened_flash_time: float = 2.0
const FRIGHTENED_FLASH_INTERVAL := 0.2

## Fruit: where it appears (on the corridor two rows below the ghost house - a
## well-travelled spot Pac-Man actually passes; set it to (240,376) for the
## dead-centre-below-the-door lane instead), the two dot counts that trigger it,
## and how long it lingers.
@export var fruit_pos: Vector2 =  Vector2(240, 472) #Vector2(240, 376) # alternative Vector2(216, 424)
@export var fruit_dot_1: int = 40
@export var fruit_dot_2: int = 100
@export var fruit_time_min: float = 9.0
@export var fruit_time_max: float = 10.0

## Points a plain dot is worth (settable in the start menu). Power pill, ghost
## chain and fruit values are fixed.
@export var points_per_dot: int = 10
const POINTS_POWER_PILL := 50
const POINTS_GHOST_BASE := 200

const _HIGHSCORE_PATH := "user://highscore.save"

## Contact radii (px, centre to centre). Eating is generous; dying needs a real
## overlap. Being in the same 16px tile always counts.
@export var touch_eat: float = 20.0
@export var touch_kill: float = 13.0

## Scatter/chase wave schedule (original level 1). [mode, seconds] phases; the
## last (INF) is chase forever. Frozen during frightened mode, reset each round.
const _WAVES: Array = [
	[Ghost.State.SCATTER, 7.0],
	[Ghost.State.CHASE, 20.0],
	[Ghost.State.SCATTER, 7.0],
	[Ghost.State.CHASE, 20.0],
	[Ghost.State.SCATTER, 5.0],
	[Ghost.State.CHASE, 20.0],
	[Ghost.State.SCATTER, 5.0],
	[Ghost.State.CHASE, INF],
]

const _FRUIT_CHERRY := preload("res://assets/items/items_cherry.png")
const _FRUIT_STRAWBERRY := preload("res://assets/items/items_strawberry.png")
const _FRUIT_PEACH := preload("res://assets/items/items_peach.png")
const _FRUIT_APPLE := preload("res://assets/items/items_apple.png")
const _FRUIT_MELON := preload("res://assets/items/items_melon.png")
const _FRUIT_GALAXIAN := preload("res://assets/items/items_galaxian.png")
const _FRUIT_BELL := preload("res://assets/items/items_bell.png")
const _FRUIT_KEY := preload("res://assets/items/items_key.png")

var score: int = 0
var highscore: int = 0
var current_level: int = 1

var _player: Player
var _pills: Node
var _maze: CanvasItem
var _score_label: Label
var _highscore_label: Label
var _level_label: Label
var _ready_label: Label
var _lives_box: Node
var _items_box: Node
var _overlay: Node
var _settings: Node
var _sound: Node
var _ghosts: Array[Ghost] = []

var _configuring: bool = true
var _next_extra_life: int = 0
var _cur_extra_gap: float = 0.0

var _started: bool = false
var _grace_t: float = 0.0
var _dots_eaten: int = 0
var _time_since_dot: float = 0.0
var _use_global_dots: bool = false     ## post-death arcade rule (see exports)
var _global_dots: int = 0
var _freeze_left: float = 0.0           ## hitstop countdown (ghost eaten)
var _wave_idx: int = 0
var _wave_elapsed: float = 0.0
var _dying: bool = false
var _game_over: bool = false
var _won: bool = false
var _level_clearing: bool = false

var _frightened_left: float = 0.0
var _flash_on: bool = false
var _flash_t: float = 0.0
var _ghost_eat_chain: int = 0

var _fruit: Node2D = null
var _fruit_time_left: float = 0.0
var _fruit_points: int = 0

## Force the mobile / touch layout (maze flush to the top, empty space below for
## touch play) even in the editor. On an actual Android/iOS build it turns on by
## itself.
@export var force_mobile_layout: bool = false

## Whole-game stats for the end screen (reset only on a fresh scene load).
var _ghosts_eaten: int = 0
var _fruit_tally: Dictionary = {}   ## tier points -> [Texture2D, count]

var _pac_prev_pos: Vector2
var _ghost_prev_pos: Dictionary = {}


func _ready() -> void:
	add_to_group(TouchControls.LAYOUT_GROUP)
	_player = get_node(player_path)
	_pills = get_node(pills_path)
	_maze = get_node_or_null(maze_path)
	_score_label = get_node_or_null(score_label_path)
	_highscore_label = get_node_or_null(highscore_label_path)
	_level_label = get_node_or_null(level_label_path)
	_ready_label = get_node_or_null(ready_label_path)
	_lives_box = get_node_or_null(lives_box_path)
	_items_box = get_node_or_null(items_box_path)
	_overlay = get_node_or_null(overlay_path)
	_settings = get_node_or_null(settings_path)
	_sound = get_node_or_null(sound_path)
	for node in get_parent().get_children():
		if node is Ghost:
			_ghosts.append(node)
	_player.died.connect(_on_player_died)
	_pills.pill_eaten.connect(_on_pill_eaten)
	if _pills.has_signal("all_eaten"):
		_pills.all_eaten.connect(_on_all_eaten)
	highscore = _load_highscore()
	_arm_extra_lives()
	_apply_mode(_WAVES[0][0])
	_update_score_label()
	_update_level_label()
	_refresh_lives()
	_rebuild_level_icons()
	_remember_positions()

	if _sound and _sound.has_method("set_pill_rate"):
		_sound.set_pill_rate(_player.speed)

	_setup_mobile_layout()

	if _overlay and _overlay.has_signal("settings_requested"):
		_overlay.settings_requested.connect(_on_pause_settings_requested)
	if _overlay and _overlay.has_signal("stats_requested"):
		_overlay.stats_requested.connect(_on_pause_stats_requested)
	if _overlay and _overlay.has_signal("help_requested"):
		_overlay.help_requested.connect(_on_pause_help_requested)

	if _settings and _settings.has_method("open_start"):
		_settings.started.connect(_on_settings_chosen)
		_settings.settings_changed.connect(_on_settings_live_change)
		_settings.closed.connect(_on_settings_closed)
		_settings.call_deferred("open_start")
	else:
		_configuring = false
		_show_ready(true)
		_sfx("play_start")


## From the pause menu's "Settings" button: show the settings panel (tree stays
## paused by the overlay), and bring the pause menu back when it closes.
func _on_pause_settings_requested() -> void:
	if _settings and _settings.has_method("open_params_from_pause"):
		_settings.open_params_from_pause()


## From the pause menu's "Stats" button: show the running totals (same summary as
## the game-over screen). "Back" returns to the pause menu.
func _on_pause_stats_requested() -> void:
	if _overlay and _overlay.has_method("show_stats"):
		_overlay.show_stats(_game_stats())


## From the pause menu's "How to Play" button.
func _on_pause_help_requested() -> void:
	if _settings and _settings.has_method("open_help_from_pause"):
		_settings.open_help_from_pause()


## On touch devices, pin the 480-wide play field to the TOP of the screen
## (KEEP_WIDTH instead of the desktop KEEP letterbox) so the space below the maze
## is free for touch play / future on-screen controls. The bottom-anchored HUD
## boxes are re-pinned just under the maze so they don't drift to the screen edge
## - but only when the device actually HAS that extra space (see `_has_extra_room`);
## on a device whose screen is already ~3:4 (most tablets, incl. iPad and the
## Galaxy Tab S3), KEEP_WIDTH yields zero extra height, so pushing the HUD row
## below the maze would push it clean off the visible screen. In that case the
## row is left at its original in-maze position (same as desktop).
## Also the broadcast target for TouchControls.confirm_touch_seen() - see
## there. Safe to call repeatedly; every step below is idempotent.
func apply_touch_layout() -> void:
	_setup_mobile_layout()


const _MAZE_H := 640.0
## Height (design px) the HUD row + touch strip need below the maze to be worth
## pushing down there at all; below this, devices near the 3:4 design ratio
## (tablets) get zero or almost-zero headroom from KEEP_WIDTH.
const _CLEAR_SPACE_NEEDED := 36.0


## The design-space viewport height KEEP_WIDTH will produce, computed straight
## from the window's physical aspect ratio - reliable the instant it's called,
## unlike get_viewport().get_visible_rect() which can lag a frame behind a
## content_scale_aspect change just made.
func _mobile_viewport_h() -> float:
	var win := get_window().size
	if win.x <= 0:
		return _MAZE_H
	return 480.0 * float(win.y) / float(win.x)


func _setup_mobile_layout() -> void:
	if not (force_mobile_layout or TouchControls.is_touch_device()):
		return
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH

	var has_room := _mobile_viewport_h() >= _MAZE_H + _CLEAR_SPACE_NEEDED
	for box in [_lives_box, _items_box]:
		if box == null:
			continue
		var c := box as Control
		if has_room:
			c.anchor_top = 0.0
			c.anchor_bottom = 0.0
			c.offset_top = _MAZE_H + 6.0
			c.offset_bottom = _MAZE_H + 32.0
		else:
			# no headroom below the maze (device ~3:4, e.g. most tablets) -
			# fall back to the desktop's in-maze bottom-anchored position.
			c.anchor_top = 1.0
			c.anchor_bottom = 1.0
			c.offset_top = -44.0
			c.offset_bottom = -18.0

	var touch := get_node_or_null(touch_controls_path)
	if touch and touch.has_method("set_enabled"):
		touch.set_enabled(true)


func _on_settings_closed() -> void:
	if _overlay and _overlay.has_method("reopen_pause"):
		_overlay.reopen_pause()


func _on_settings_live_change(cfg: Dictionary) -> void:
	_apply_config(cfg, false)


func _arm_extra_lives() -> void:
	_next_extra_life = first_extra_life if first_extra_life > 0 else 0
	_cur_extra_gap = float(extra_life_gap)


## Play pressed on the start menu.
func _on_settings_chosen(cfg: Dictionary) -> void:
	_apply_config(cfg, true)
	_configuring = false
	_show_ready(true)
	_sfx("play_start")


## Push a config dict onto the live game. `set_lives` is only true for a fresh
## start - a mid-game Settings visit must not reset the player's remaining lives.
func _apply_config(cfg: Dictionary, set_lives: bool) -> void:
	if set_lives:
		lives = int(cfg.get("lives", lives))
	points_per_dot = int(cfg.get("dot_points", points_per_dot))
	first_extra_life = int(cfg.get("first_extra_life", first_extra_life))
	extra_life_gap = int(cfg.get("extra_life_gap", extra_life_gap))
	extra_life_gap_mult = float(cfg.get("extra_life_gap_mult", extra_life_gap_mult))
	_player.speed = float(cfg.get("pacman_speed", _player.speed))
	for g in _ghosts:
		g.speed = float(cfg.get("ghost_speed", g.speed))
	if _sound:
		if _sound.has_method("set_volumes"):
			_sound.set_volumes(cfg.get("volumes", {}))
		if _sound.has_method("set_pill_rate"):
			_sound.set_pill_rate(_player.speed)
	_arm_extra_lives()
	# don't retroactively hand out extra lives for score already earned
	while _next_extra_life > 0 and score >= _next_extra_life:
		_next_extra_life += int(_cur_extra_gap)
		_cur_extra_gap *= extra_life_gap_mult
	_refresh_lives()


func _physics_process(delta: float) -> void:
	_update_audio()
	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _freeze_left <= 0.0:
			_set_actors_frozen(false)
		return
	if _configuring or _dying or _game_over or _won or _level_clearing:
		return
	if not _started:
		_grace_t += delta
		if _player.was_steered() or _grace_t >= start_grace:
			_begin_run()
		return
	_update_waves(delta)
	_update_releases(delta)
	_update_fruit(delta)
	# Contact BEFORE the fright timer can expire this frame, so touching a ghost
	# on the very frame its window ends still counts as eating it.
	_check_caught()
	_check_fruit_eaten()
	_update_frightened(delta)


func _begin_run() -> void:
	_started = true
	_time_since_dot = 0.0
	_show_ready(false)
	var blinky := _ghost(Ghost.Personality.BLINKY)
	var pinky := _ghost(Ghost.Personality.PINKY)
	if blinky:
		blinky.release()
	# Pinky normally leaves at once too - but after a death the global dot counter
	# governs her exit (7 dots), so hold her in the house until then.
	if pinky and not _use_global_dots:
		pinky.release()
	if not _player.was_steered():
		_player.auto_start(Vector2i.LEFT)


# --- info the ghosts ask for ---------------------------------------------

func player_cell() -> Vector2i:
	return MazeGrid.world_to_cell(_player.global_position)


func player_heading() -> Vector2i:
	return _player.heading()


func blinky_cell() -> Vector2i:
	var b := _ghost(Ghost.Personality.BLINKY)
	return MazeGrid.world_to_cell(b.global_position) if b else Vector2i.ZERO


func is_frightened_active() -> bool:
	return _frightened_left > 0.0


func wave_mode() -> int:
	return _WAVES[_wave_idx][0]


# --- scatter / chase waves ---------------------------------------------

func _update_waves(delta: float) -> void:
	if is_frightened_active():
		return
	if _wave_idx >= _WAVES.size() - 1:
		return
	_wave_elapsed += delta
	if _wave_elapsed >= float(_WAVES[_wave_idx][1]):
		_wave_idx += 1
		_wave_elapsed = 0.0
		_apply_mode(_WAVES[_wave_idx][0])


func _apply_mode(mode: int) -> void:
	for g in _ghosts:
		g.set_mode(mode)


# --- ghost-house releases (dot counter + fallback timer) --------------

func _update_releases(delta: float) -> void:
	var pinky := _ghost(Ghost.Personality.PINKY)
	var inky := _ghost(Ghost.Personality.INKY)
	var clyde := _ghost(Ghost.Personality.CLYDE)

	if _use_global_dots:
		# Post-death: one shared counter drives every house exit.
		if pinky and pinky.is_in_house() and _global_dots >= global_pinky_dots:
			pinky.release()
		if inky and inky.is_in_house() and _global_dots >= global_inky_dots:
			inky.release()
		if clyde and clyde.is_in_house() and _global_dots >= global_clyde_dots:
			clyde.release()
		# Once Clyde is out the special rule is done - back to normal counters.
		if clyde and not clyde.is_in_house():
			_use_global_dots = false
	else:
		if inky and inky.is_in_house() and _dots_eaten >= inky_dot_limit:
			inky.release()
		if clyde and clyde.is_in_house() and _dots_eaten >= clyde_dot_limit:
			clyde.release()

	_time_since_dot += delta
	if _time_since_dot >= dot_timeout:
		_time_since_dot = 0.0
		var waiting := _next_waiting_ghost()
		if waiting:
			waiting.release()


func _next_waiting_ghost() -> Ghost:
	for p in [Ghost.Personality.PINKY, Ghost.Personality.INKY, Ghost.Personality.CLYDE]:
		var g := _ghost(p)
		if g and g.is_in_house():
			return g
	return null


# --- frightened mode -------------------------------------------------

func _on_pill_eaten(kind: int, _cell: Vector2i) -> void:
	_dots_eaten += 1
	_time_since_dot = 0.0
	if _use_global_dots:
		_global_dots += 1
	if kind == MazeGrid.PILL_BIG:
		_add_score(POINTS_POWER_PILL)
		_sfx("play_eat_item")   # big pill uses the item sound, not the dot munch
		_start_frightened()
	else:
		_add_score(points_per_dot)
		_sfx("play_pill")
	if _dots_eaten == fruit_dot_1 or _dots_eaten == fruit_dot_2:
		_spawn_fruit()


func _start_frightened() -> void:
	_frightened_left = frightened_duration
	_flash_on = false
	_flash_t = 0.0
	_ghost_eat_chain = 0   # -> next eaten ghost is worth 200 again
	for g in _ghosts:
		g.frighten()


func _update_frightened(delta: float) -> void:
	if _frightened_left <= 0.0:
		return
	_frightened_left -= delta
	if _frightened_left <= frightened_flash_time:
		_flash_t += delta
		if _flash_t >= FRIGHTENED_FLASH_INTERVAL:
			_flash_t = 0.0
			_flash_on = not _flash_on
		for g in _ghosts:
			g.set_frightened_flash(_flash_on)
	if _frightened_left <= 0.0:
		_frightened_left = 0.0
		_flash_on = false
		for g in _ghosts:
			g.set_frightened_flash(false)
			g.end_frighten()


# --- fruit ----------------------------------------------------------

## {tex, points} for the given level. Level >13 falls through to the key.
func fruit_for_level(lvl: int) -> Dictionary:
	if lvl <= 1:  return {"tex": _FRUIT_CHERRY, "points": 100}
	if lvl == 2:  return {"tex": _FRUIT_STRAWBERRY, "points": 300}
	if lvl <= 4:  return {"tex": _FRUIT_PEACH, "points": 500}
	if lvl <= 6:  return {"tex": _FRUIT_APPLE, "points": 700}
	if lvl <= 8:  return {"tex": _FRUIT_MELON, "points": 1000}
	if lvl <= 10: return {"tex": _FRUIT_GALAXIAN, "points": 2000}
	if lvl <= 12: return {"tex": _FRUIT_BELL, "points": 3000}
	return {"tex": _FRUIT_KEY, "points": 5000}


func _spawn_fruit() -> void:
	if _fruit != null:
		return
	var f := fruit_for_level(current_level)
	var spr := Sprite2D.new()
	spr.texture = f["tex"]
	spr.scale = Vector2(2.0, 2.0)   # 16px art -> ~one tile on screen, matching the sprites
	spr.position = fruit_pos
	spr.z_index = 5
	get_parent().add_child(spr)
	# gentle pulse so it stands out on the corridor
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "scale", Vector2(2.3, 2.3), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "scale", Vector2(2.0, 2.0), 0.5).set_trans(Tween.TRANS_SINE)
	_fruit = spr
	_fruit_points = f["points"]
	_fruit_time_left = randf_range(fruit_time_min, fruit_time_max)


func _update_fruit(delta: float) -> void:
	if _fruit == null:
		return
	_fruit_time_left -= delta
	if _fruit_time_left <= 0.0:
		_remove_fruit()


func _check_fruit_eaten() -> void:
	if _fruit == null:
		return
	if _player.global_position.distance_to(_fruit.global_position) < touch_eat:
		_add_score(_fruit_points)
		_spawn_points_popup(_fruit.global_position, _fruit_points, Color(1, 1, 1))
		_sfx("play_eat_item")
		_tally_fruit(_fruit_points, (_fruit as Sprite2D).texture)
		_remove_fruit()


## Record a collected fruit for the end-of-game summary.
func _tally_fruit(points: int, tex: Texture2D) -> void:
	if _fruit_tally.has(points):
		_fruit_tally[points][1] += 1
	else:
		_fruit_tally[points] = [tex, 1]


func _remove_fruit() -> void:
	if _fruit != null:
		_fruit.queue_free()
		_fruit = null


# --- catching the player / eating ghosts -----------------------------

func _check_caught() -> void:
	var pac_now := _player.global_position
	var pac_tile := MazeGrid.world_to_cell(pac_now)
	var lethal: Ghost = null
	for g in _ghosts:
		if not (g.is_dangerous() or g.is_edible()):
			continue
		var g_now: Vector2 = g.global_position
		var same_tile := MazeGrid.world_to_cell(g_now) == pac_tile
		var gap := _swept_gap(_pac_prev_pos, pac_now, _ghost_prev_pos.get(g, g_now), g_now)
		if g.is_edible():
			if same_tile or gap < touch_eat:
				_eat_ghost(g)
				_remember_positions()
				return
		elif same_tile or gap < touch_kill:
			lethal = g
	if lethal != null:
		_dying = true
		_death_sequence()
	_remember_positions()


func _swept_gap(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> float:
	if a0.distance_to(a1) > 40.0 or b0.distance_to(b1) > 40.0:
		return a1.distance_to(b1)
	var cp := Geometry2D.get_closest_points_between_segments(a0, a1, b0, b1)
	return cp[0].distance_to(cp[1])


func _remember_positions() -> void:
	_pac_prev_pos = _player.global_position
	for g in _ghosts:
		_ghost_prev_pos[g] = g.global_position


func _eat_ghost(g: Ghost) -> void:
	_ghost_eat_chain += 1
	_ghosts_eaten += 1
	var pts := POINTS_GHOST_BASE * (1 << (_ghost_eat_chain - 1))   # 200, 400, 800, 1600
	_add_score(pts)
	_spawn_points_popup(g.global_position, pts)
	g.get_eaten()
	_sfx("play_eat_ghost")
	# brief hitstop - the arcade freezes on the score for about a second
	if ghost_eat_freeze > 0.0:
		_freeze_left = ghost_eat_freeze
		_set_actors_frozen(true)


func _set_actors_frozen(on: bool) -> void:
	_player.set_physics_process(not on)
	for g in _ghosts:
		g.set_physics_process(not on)


## Points number that floats up and fades where something was eaten.
func _spawn_points_popup(pos: Vector2, points: int, color := Color(0.55, 0.85, 1.0)) -> void:
	_spawn_text_popup(pos - Vector2(14, 6), str(points), color)


func _spawn_text_popup(screen_pos: Vector2, text: String, color: Color) -> void:
	var hud := get_node_or_null(^"../hud")
	if hud == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 100
	lbl.position = screen_pos
	hud.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 16.0, 1.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.4)
	tw.tween_callback(lbl.queue_free)


# --- death / respawn / game over ------------------------------------

## Pac-Man just ran into a lethal ghost. Arcade timing:
##   contact -> everyone frozen on the spot for `death_freeze` s
##           -> Pac-Man's death animation plays (`death_pause` s)
##           -> positions/state reset, "READY!" hold (`respawn_ready` s)
##           -> the round resumes.
func _death_sequence() -> void:
	_freeze_left = 0.0
	_player.freeze()
	for g in _ghosts:
		g.set_physics_process(false)
	_sfx("stop_all")
	await get_tree().create_timer(death_freeze).timeout
	if _game_over or not is_inside_tree():
		return
	_player.die()             # death animation + `died` -> _on_player_died
	_sfx("play_death")


func _on_player_died() -> void:
	await get_tree().create_timer(death_pause).timeout
	if _game_over or not is_inside_tree():
		return
	lives -= 1
	_refresh_lives()
	_remove_fruit()           # a fruit on screen at the moment of death is lost
	if lives <= 0:
		_end_game()
		return
	reset_after_death()
	# everyone stands still on "READY!" for a beat before moving again
	_show_ready(true)
	await get_tree().create_timer(respawn_ready).timeout
	if _game_over or not is_inside_tree():
		return
	_show_ready(false)
	_player.set_physics_process(true)
	for g in _ghosts:
		g.set_physics_process(true)
	_dying = false
	_begin_run()


## Put the board back to its round-start state WITHOUT touching the maze, the
## dots already eaten or the score. Also switches the house on to the arcade's
## post-death "global dot counter" rule.
func reset_after_death() -> void:
	_player.reset()
	_player.set_physics_process(false)   # held until the READY! beat is over
	for g in _ghosts:
		g.reset()                        # HOUSE, regular mode, blue/eyes cleared
	_started = false
	_grace_t = 0.0
	_time_since_dot = 0.0
	_wave_idx = 0                         # wave timer restarts at phase 0
	_wave_elapsed = 0.0
	_frightened_left = 0.0
	_flash_on = false
	_ghost_eat_chain = 0
	_use_global_dots = true               # <- arcade death rule
	_global_dots = 0
	_apply_mode(_WAVES[0][0])
	_update_score_label()
	_remember_positions()


func _end_game() -> void:
	_game_over = true
	_remove_fruit()
	_sfx("stop_all")
	_player.set_physics_process(false)
	for g in _ghosts:
		g.set_physics_process(false)
	if _overlay and _overlay.has_method("show_game_over"):
		_overlay.show_game_over(_game_stats())


# --- level clear / progression -------------------------------------

func _on_all_eaten() -> void:
	if _level_clearing or _won or _game_over:
		return
	if current_level >= MAX_LEVEL:
		_win_game()
	else:
		_level_clear_sequence()


func _win_game() -> void:
	_won = true
	_remove_fruit()
	_sfx("stop_all")
	_player.set_physics_process(false)
	for g in _ghosts:
		g.set_physics_process(false)
	if _overlay and _overlay.has_method("show_win"):
		_overlay.show_win(_game_stats())


## Whole-game summary for the game-over / win screen.
func _game_stats() -> Dictionary:
	var fruits: Array = []
	var tiers := _fruit_tally.keys()
	tiers.sort()   # cherry (100) -> key (5000)
	for t in tiers:
		fruits.append(_fruit_tally[t])   # [Texture2D, count]
	return {
		"score": score,
		"highscore": highscore,
		"level": current_level,
		"ghosts": _ghosts_eaten,
		"fruits": fruits,
	}


func _level_clear_sequence() -> void:
	_level_clearing = true
	_remove_fruit()
	_sfx("stop_all")
	# 1. freeze
	_player.set_physics_process(false)
	for g in _ghosts:
		g.set_physics_process(false)
	await get_tree().create_timer(1.5).timeout

	# 2. hide the actors, flash the maze
	_player.visible = false
	for g in _ghosts:
		g.visible = false
	_sfx("play_levelup")
	await _flash_maze(5)
	await get_tree().create_timer(0.5).timeout

	# 3. level up + full reset
	current_level += 1
	_pills.reset_all()
	_dots_eaten = 0
	_time_since_dot = 0.0
	_wave_idx = 0
	_wave_elapsed = 0.0
	_frightened_left = 0.0
	_flash_on = false
	_ghost_eat_chain = 0
	_use_global_dots = false
	_global_dots = 0
	_player.reset()
	_player.visible = true
	_player.set_physics_process(true)
	for g in _ghosts:
		g.reset()
		g.visible = true
		g.set_physics_process(true)
	_apply_mode(_WAVES[0][0])
	_update_level_label()
	_rebuild_level_icons()
	_remember_positions()

	# 4. READY! (held long enough for the level-up jingle to finish)
	_show_ready(true)
	await get_tree().create_timer(level_clear_ready).timeout
	_level_clearing = false
	_begin_run()


func _flash_maze(times: int) -> void:
	var mat: ShaderMaterial = _maze.material if _maze else null
	for i in times:
		if mat:
			mat.set_shader_parameter("flash", 1.0)
		await get_tree().create_timer(0.18).timeout
		if mat:
			mat.set_shader_parameter("flash", 0.0)
		await get_tree().create_timer(0.18).timeout


# --- scoring / hud -----------------------------------------------

func _add_score(points: int) -> void:
	score += points
	if score > highscore:
		highscore = score
		_save_highscore()
	while _next_extra_life > 0 and score >= _next_extra_life:
		lives += 1
		_refresh_lives()
		_spawn_text_popup(Vector2(24, 560), "1UP", Color(1, 0.9, 0.25))
		_next_extra_life += int(_cur_extra_gap)
		_cur_extra_gap *= extra_life_gap_mult
	score_changed.emit(score)
	_update_score_label()


func _update_score_label() -> void:
	if _score_label:
		_score_label.text = str(score)
	if _highscore_label:
		_highscore_label.text = str(highscore)


func _update_level_label() -> void:
	if _level_label:
		_level_label.text = str(current_level)


func _show_ready(on: bool) -> void:
	if _ready_label:
		_ready_label.visible = on


func _load_highscore() -> int:
	if not FileAccess.file_exists(_HIGHSCORE_PATH):
		return 0
	var f := FileAccess.open(_HIGHSCORE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v := f.get_64()
	f.close()
	return int(v)


func _save_highscore() -> void:
	var f := FileAccess.open(_HIGHSCORE_PATH, FileAccess.WRITE)
	if f:
		f.store_64(highscore)
		f.close()


## Bottom-left lives: one Pac-Man icon per SPARE life - i.e. `lives - 1`, since
## the Pac-Man currently on the board is not a spare (arcade convention). So a
## fresh 3-life game shows 2 icons, and the display is empty while the last
## Pac-Man is in play. One icon per spare while there are at most
## `_LIVES_ICON_MAX` of them; from one more on it collapses to a single icon
## followed by an "x 5" / "x 6" ... label; back at or below the limit it shows
## the icons again.
const _LIVES_ICON_MAX := 4

func _refresh_lives() -> void:
	if _lives_box == null:
		return
	for c in _lives_box.get_children():
		c.free()
	var frames: SpriteFrames = _player.get_node("AnimatedSprite2D").sprite_frames
	var tex: Texture2D = frames.get_frame_texture("move_left", 1)
	var n := maxi(0, lives - 1)
	if n <= _LIVES_ICON_MAX:
		for i in n:
			_lives_box.add_child(_life_icon(tex))
	else:
		_lives_box.add_child(_life_icon(tex))
		var lbl := Label.new()
		lbl.text = "x %d" % n
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lives_box.add_child(lbl)


func _life_icon(tex: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(22, 22)
	return icon


## Bottom-right indicator (arcade style): one icon per DISTINCT fruit type
## reached, up to and including the current level - so level 1 already shows the
## cherry, level 2 adds the strawberry to its left, level 3 the peach, and so on
## until all eight fruit types are shown. Independent of what was collected
## (that is the end-of-game statistic).
func _rebuild_level_icons() -> void:
	if _items_box == null:
		return
	for c in _items_box.get_children():
		c.free()   # immediate, so a rebuild in the same frame can't pile up
	var seen: Array[Texture2D] = []
	for lvl in range(1, current_level + 1):
		var tex: Texture2D = fruit_for_level(lvl)["tex"]
		if tex not in seen:
			seen.append(tex)
	seen.reverse()   # newest first -> leftmost; the cherry stays on the right
	for tex in seen:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		_items_box.add_child(icon)


# --- audio -------------------------------------------------------

## Fire a one-shot / control call on the sound manager, if present.
func _sfx(method: String) -> void:
	if _sound and _sound.has_method(method):
		_sound.call(method)


## Push the current ambient state to the sound manager every frame. It decides
## which background loop (normal siren / frightened / retreating eyes / power
## pellet) should be audible.
func _update_audio() -> void:
	if _sound == null or not _sound.has_method("update_ambient"):
		return
	var round_active := (
		_started and not _dying and not _game_over and not _won
		and not _level_clearing and not _configuring
	)
	var ghosts_on_map := false
	var eyes_active := false
	for g in _ghosts:
		if g.is_dangerous():
			ghosts_on_map = true
		if g.is_eyes():
			eyes_active = true
	_sound.update_ambient(round_active, ghosts_on_map, is_frightened_active(), eyes_active)


# --- helpers -------------------------------------------------------

func _ghost(p: int) -> Ghost:
	for g in _ghosts:
		if g.personality == p:
			return g
	return null
