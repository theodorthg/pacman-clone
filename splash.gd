class_name Splash
extends CanvasLayer

## Start-up splash (ported from mario-clone): splash-screen.png + a fake
## loading bar for TIME seconds, ONCE per app launch (`shown` survives the
## scene reloads pacman does for every new run),
## on top of everything. Godot's native boot_splash (same image) only covers
## the real engine load, which is far too short to notice, so this continues
## seamlessly with the same picture. Any key / pad button / click / tap skips.
## Emits `done` once (game.gd then shows the title screen), fades out.

signal done

const TIME := 3.0

var _root: Control
var _fill: ColorRect
var _active := true
var _t0 := 0
static var shown := false

func _ready() -> void:
	layer = 50
	shown = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("050716")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var pic := TextureRect.new()
	pic.texture = load("res://splash-screen.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR     # hi-res art, not pixel art
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pic)
	# loading bar at the bottom centre: dark frame, gold fill with a shine line
	var frame := ColorRect.new()
	frame.color = Color("05070f")
	frame.anchor_left = 0.2
	frame.anchor_right = 0.8
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_top = -48
	frame.offset_bottom = -36
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	var track := ColorRect.new()
	track.color = Color(0.08, 0.1, 0.3)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.offset_left = 1
	track.offset_top = 1
	track.offset_right = -1
	track.offset_bottom = -1
	frame.add_child(track)
	_fill = ColorRect.new()
	_fill.color = Color("ffd800")
	_fill.anchor_bottom = 1.0
	_fill.anchor_right = 0.0
	track.add_child(_fill)
	var shine := ColorRect.new()
	shine.color = Color(1.0, 0.96, 0.7)
	shine.anchor_right = 1.0
	shine.offset_bottom = 2
	_fill.add_child(shine)
	var tw := create_tween()
	tw.tween_property(_fill, "anchor_right", 1.0, TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.15)
	tw.tween_callback(finish)

func _input(event: InputEvent) -> void:
	if not _active or Time.get_ticks_msec() - _t0 < 300:
		return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if skip:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if not _active:
		return
	_active = false
	done.emit()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
