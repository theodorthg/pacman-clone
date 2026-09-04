class_name PauseButton
extends Control

## Small round on-screen pause button (the touch equivalent of Esc).

signal tapped

var _down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var release: bool = (event is InputEventScreenTouch and not event.pressed) \
		or (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if press:
		_down = true
		queue_redraw()
		accept_event()
	elif release and _down:
		_down = false
		queue_redraw()
		tapped.emit()
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.34 if _down else 0.28))
	draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 2.0)
	var bw := r * 0.24
	var bh := r * 0.82
	var off := r * 0.30
	var col := Color(1, 1, 1, 0.82)
	draw_rect(Rect2(c.x - off - bw, c.y - bh * 0.5, bw, bh), col)
	draw_rect(Rect2(c.x + off, c.y - bh * 0.5, bw, bh), col)
