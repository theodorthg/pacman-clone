class_name Intermission
extends CanvasLayer

## Arcade-style intermission (short cartoon) played between two levels - after
## levels 2, 5, 9 and then every 4th level. Built from the game's own sprites,
## three acts (picked by the caller):
##   1  Blinky chases Pac-Man, then Pac-Man grows and chases a frightened Blinky
##   2  Pinky and Inky chase Pac-Man, then both flee from a giant Pac-Man
##   3  all four ghosts march after Pac-Man, flee, get eaten - eyes race home
## Any key / pad button / click / tap skips it. Emits `finished` when done.

signal finished

const _TITLES := ["", "ACT 1 - THE CHASE", "ACT 2 - DOUBLE TROUBLE", "ACT 3 - ROLE REVERSAL"]
const _LEFT := -70.0
const _RIGHT := 550.0

var _player: Player
var _ghosts: Array[Ghost]
var _shift: float = 0.0
var _act: int = 1
var _tween: Tween
var _runners: Array[Node] = []
var _done := false


## `shift_y`: the design-space shift of the HUD layer (centred layout on tall phones).
func setup(act: int, player: Player, ghosts: Array[Ghost], shift_y: float) -> void:
	_act = clampi(act, 1, 3)
	_player = player
	_ghosts = ghosts
	_shift = shift_y


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var title := Label.new()
	title.text = "INTERMISSION\n" + _TITLES[_act]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 150 + _shift)
	title.size = Vector2(480, 60)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)
	var hint := Label.new()
	hint.text = "press any key to skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 520 + _shift)
	hint.size = Vector2(480, 20)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	add_child(hint)
	_play()


func _input(event: InputEvent) -> void:
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if skip and not _done:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween:
		_tween.kill()
	finished.emit()
	queue_free()


# --- sprites -----------------------------------------------------------

func _pac(dir_right: bool, scale_mul := 1.0) -> AnimatedSprite2D:
	var src := _player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var s := AnimatedSprite2D.new()
	s.sprite_frames = src.sprite_frames
	s.scale = src.scale * scale_mul
	s.speed_scale = 2.0
	s.play("move_right" if dir_right else "move_left")
	return s


## kind: Ghost.Personality; mode "normal" / "blue" / "eyes"
func _ghost(personality: int, mode: String, east: bool) -> AnimatedSprite2D:
	var g: Ghost = null
	for c in _ghosts:
		if c.personality == personality:
			g = c
	var src := g.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var s := AnimatedSprite2D.new()
	s.scale = src.scale
	s.speed_scale = 2.0
	match mode:
		"blue":
			s.sprite_frames = Ghost._BLUE_FRAMES
			s.play("move_all_directions")
		"eyes":
			s.sprite_frames = Ghost._EYES_FRAMES
			s.play("move_all_directions")
		_:
			s.sprite_frames = g._normal_frames
			s.play("move_east" if east else "move_west")
	return s


## One scene of the cartoon: `entries` = [sprite, x_offset] pairs; everything
## runs from one side to the other at the same speed (offsets keep the order).
func _run(entries: Array, y: float, rightward: bool, dur: float) -> void:
	if _done:
		return
	_runners.clear()
	_tween = create_tween().set_parallel(true)
	for e in entries:
		var sp: AnimatedSprite2D = e[0]
		var off: float = e[1]
		var from_x := (_LEFT if rightward else _RIGHT) + off
		var to_x := (_RIGHT if rightward else _LEFT) + off
		sp.position = Vector2(from_x, y + _shift)
		add_child(sp)
		_runners.append(sp)
		_tween.tween_property(sp, "position:x", to_x, dur)
	await _tween.finished
	for sp in _runners:
		if is_instance_valid(sp):
			sp.queue_free()


func _play() -> void:
	var B := Ghost.Personality.BLINKY
	var P := Ghost.Personality.PINKY
	var I := Ghost.Personality.INKY
	var C := Ghost.Personality.CLYDE
	match _act:
		1:
			await _run([[_pac(true), 0.0], [_ghost(B, "normal", true), -90.0]], 320.0, true, 3.4)
			await _run([[_ghost(B, "blue", false), 0.0], [_pac(false, 3.0), 150.0]], 320.0, false, 3.6)
		2:
			await _run([[_pac(true), 0.0], [_ghost(P, "normal", true), -80.0], [_ghost(I, "normal", true), -150.0]], 320.0, true, 3.4)
			await _run([[_ghost(P, "blue", false), 0.0], [_ghost(I, "blue", false), 70.0], [_pac(false, 3.0), 230.0]], 320.0, false, 3.8)
		_:
			await _run([[_pac(true), 0.0], [_ghost(B, "normal", true), -80.0], [_ghost(P, "normal", true), -140.0],
				[_ghost(I, "normal", true), -200.0], [_ghost(C, "normal", true), -260.0]], 320.0, true, 3.6)
			await _run([[_ghost(B, "blue", false), 0.0], [_ghost(P, "blue", false), 60.0], [_ghost(I, "blue", false), 120.0],
				[_ghost(C, "blue", false), 180.0], [_pac(false, 3.0), 330.0]], 320.0, false, 4.0)
			await _run([[_ghost(B, "eyes", true), 0.0], [_ghost(P, "eyes", true), -50.0],
				[_ghost(I, "eyes", true), -100.0], [_ghost(C, "eyes", true), -150.0]], 320.0, true, 1.8)
	if not _done:
		await get_tree().create_timer(0.3).timeout
	_finish()
