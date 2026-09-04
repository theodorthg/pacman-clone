class_name OverlayMenu
extends CanvasLayer

## Frosted-glass overlay: the pause screen (Resume / Stats / Settings / Restart /
## Exit), the in-game stats view and the game-over / win screens - all with the
## same whole-game summary. Runs while the tree is paused.

signal settings_requested
signal stats_requested
signal help_requested

enum Kind { NONE, PAUSE, STATS, GAME_OVER, WIN }

@onready var _title: Label = $center/panel/title
@onready var _stats: VBoxContainer = $center/panel/stats
@onready var _buttons: Array = [
	$center/panel/btn_a, $center/panel/btn_b, $center/panel/btn_c,
	$center/panel/btn_d, $center/panel/btn_e, $center/panel/btn_f,
]

var _kind: int = Kind.NONE
var _action: Dictionary = {}   ## Button -> action string


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if OS.has_feature("mobile"):
		var c := $center as BoxContainer
		c.alignment = BoxContainer.ALIGNMENT_BEGIN
		c.offset_top = 40.0
	for b in _buttons:
		b.pressed.connect(_on_button.bind(b))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _kind == Kind.STATS:
		show_pause()
	elif _kind == Kind.PAUSE and visible:
		_resume()
	elif _kind == Kind.NONE and not get_tree().paused:
		show_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func show_pause() -> void:
	_open(Kind.PAUSE, "PAUSED", [
		["Resume", "resume"], ["Stats", "stats"], ["How to Play", "help"],
		["Settings", "settings"], ["Restart", "restart"], ["Exit", "exit"],
	])


## In-game snapshot of the same summary the game-over screen shows.
func show_stats(stats: Dictionary) -> void:
	_open(Kind.STATS, "STATS", [["Back", "back"]])
	_fill_stats(stats)


func show_game_over(stats: Dictionary) -> void:
	_open(Kind.GAME_OVER, "GAME OVER", [["Restart", "restart"], ["Exit", "exit"]])
	_fill_stats(stats)


func show_win(stats: Dictionary) -> void:
	_open(Kind.WIN, "YOU WIN!", [["Restart", "restart"], ["Exit", "exit"]])
	_fill_stats(stats)


func _open(kind: int, title: String, buttons: Array) -> void:
	_kind = kind
	_title.text = title
	for c in _stats.get_children():
		c.free()
	_stats.visible = false
	_action.clear()
	for i in _buttons.size():
		var b := _buttons[i] as Button
		if i < buttons.size():
			b.text = buttons[i][0]
			_action[b] = buttons[i][1]
			b.show()
		else:
			b.hide()
	visible = true
	get_tree().paused = true
	_buttons[0].grab_focus()


func _resume() -> void:
	_kind = Kind.NONE
	visible = false
	get_tree().paused = false


func _on_button(btn: Button) -> void:
	match _action.get(btn, ""):
		"resume":
			_resume()
		"stats":
			stats_requested.emit()   # game answers with show_stats(_game_stats())
		"help":
			visible = false
			help_requested.emit()    # game -> settings.open_help_from_pause()
		"back":
			show_pause()
		"settings":
			# hand off to the settings menu, keep the tree paused and _kind = PAUSE
			visible = false
			settings_requested.emit()
		"restart":
			get_tree().paused = false
			get_tree().reload_current_scene()
		"exit":
			get_tree().quit()


## Called by the game when the settings menu closes: bring the pause menu back.
func reopen_pause() -> void:
	if _kind == Kind.PAUSE:
		visible = true
		get_tree().paused = true
		_buttons[0].grab_focus()


# --- end-game summary --------------------------------------------------

func _fill_stats(d: Dictionary) -> void:
	for c in _stats.get_children():
		c.free()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stat_row(grid, "SCORE", str(int(d.get("score", 0))))
	_stat_row(grid, "HIGH SCORE", str(int(d.get("highscore", 0))))
	_stat_row(grid, "LEVEL REACHED", str(int(d.get("level", 1))))
	_stat_row(grid, "GHOSTS EATEN", str(int(d.get("ghosts", 0))))
	var fruits: Array = d.get("fruits", [])
	var total_fruit := 0
	for pair in fruits:
		total_fruit += int(pair[1])
	_stat_row(grid, "FRUITS EATEN", str(total_fruit))
	_stats.add_child(grid)

	if not fruits.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for pair in fruits:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			var icon := TextureRect.new()
			icon.texture = pair[0]
			icon.custom_minimum_size = Vector2(22, 22)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.add_child(icon)
			var cnt := Label.new()
			cnt.text = "x%d" % int(pair[1])
			cnt.add_theme_font_size_override("font_size", 14)
			cnt.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
			cell.add_child(cnt)
			row.add_child(cell)
		_stats.add_child(row)

	_stats.visible = true


func _stat_row(grid: GridContainer, label: String, value: String) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	grid.add_child(l)

	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 16)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
