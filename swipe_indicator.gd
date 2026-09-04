class_name SwipeIndicator
extends Control

## Non-interactive read-out shown centred just below the play field on touch
## devices: a single arrow pointing the way Pac-Man is currently steering. All
## steering is done by swiping anywhere on the screen - this is only a hint, so
## it deliberately does NOT look like a button (thin ring, no fill).

var _dir: Vector2i = Vector2i.LEFT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eats a swipe


func set_dir(d: Vector2i) -> void:
	if d != Vector2i.ZERO and d != _dir:
		_dir = d
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5

	draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 2.0)
	# faint orientation ticks at the four cardinals
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		draw_circle(c + d * (r - 8.0), 2.0, Color(1, 1, 1, 0.16))

	# the one arrow, pointing where we are steering
	var dv := Vector2(_dir)
	var perp := Vector2(-dv.y, dv.x)
	var tip := c + dv * (r * 0.62)
	var b := c - dv * (r * 0.20)
	var wing := r * 0.42
	draw_colored_polygon(
		PackedVector2Array([tip, b + perp * wing, c - dv * (r * 0.02), b - perp * wing]),
		Color(1, 0.92, 0.28, 0.98)
	)
