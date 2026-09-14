class_name OverlayMenu
extends CanvasLayer

## Frosted-glass overlay: the pause screen (Resume / Stats / How to Play /
## Settings / Restart / Exit), the in-game stats view, the read-only high
## score board, and the game-over / win screens (whole-game summary + Hall
## of Fame name entry) - all sharing one panel/button-row layout. Runs while
## the tree is paused. "Exit" is dropped on the Web build (see _open) - a
## browser tab can't self-close.

signal settings_requested
signal stats_requested
signal help_requested
## "Back" from a Stats/Highscores view opened FROM THE START MENU (see
## `_return_to_start`) - game.gd re-opens settings_menu's root screen.
signal back_to_start_requested

const HallOfFame = preload("res://hall_of_fame.gd")

enum Kind { NONE, PAUSE, STATS, GAME_OVER, WIN, HIGHSCORES }

@onready var _title: Label = $center/panel_frame/panel/title
@onready var _stats: VBoxContainer = $center/panel_frame/panel/stats
@onready var _buttons: Array = [
	$center/panel_frame/panel/btn_a, $center/panel_frame/panel/btn_b, $center/panel_frame/panel/btn_c,
	$center/panel_frame/panel/btn_d, $center/panel_frame/panel/btn_e, $center/panel_frame/panel/btn_f,
]

var _kind: int = Kind.NONE
var _action: Dictionary = {}   ## Button -> action string

## STATS/HIGHSCORES were opened from settings_menu's start screen rather than
## the in-game pause menu - "Back" needs to return there instead of to Pause.
var _return_to_start: bool = false
## Restated game-over/win stats, so "Cancel" on the restart confirmation can
## rebuild the exact same screen it interrupted.
var _last_stats: Dictionary = {}
## Which Kind the restart confirmation should return to on "Cancel".
var _confirm_return_kind: int = Kind.NONE

## Hall of Fame name entry (game-over/win only, see _fill_stats(show_hof=true)) -
## rebuilt each time _fill_stats() runs, so always re-fetch rather than cache
## across screens.
var _pending_score: int = 0
var _name_edit: LineEdit
var _hof_entry_row: Control
## True once this run's score has been saved (typed + Save, Enter, or the
## auto-commit safety net) - stops a "restart_cancel" rebuild from offering
## the entry field a second time for the same run (see show_game_over()).
var _hof_committed_this_run: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(TouchControls.LAYOUT_GROUP)
	apply_touch_layout()
	for b in _buttons:
		b.pressed.connect(_on_button.bind(b))


## Idempotent; also the broadcast target for TouchControls.confirm_touch_seen()
## (see there) - covers Web browsers that don't report touch capability until a
## real touch has actually happened.
func apply_touch_layout() -> void:
	if TouchControls.is_touch_device():
		var c := $center as BoxContainer
		c.alignment = BoxContainer.ALIGNMENT_BEGIN
		c.offset_top = 40.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _kind == Kind.STATS or _kind == Kind.HIGHSCORES:
		_do_back()
	elif _kind == Kind.PAUSE and visible:
		_resume()
	elif _kind == Kind.NONE and not get_tree().paused:
		show_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func show_pause() -> void:
	_return_to_start = false
	_open(Kind.PAUSE, "PAUSED", [
		["Resume", "resume"], ["Stats", "stats"], ["How to Play", "help"],
		["Settings", "settings"], ["Restart", "restart"], ["Exit", "exit"],
	])


## In-game snapshot of the same summary the game-over screen shows.
## `return_to_start`: opened from settings_menu's start screen (new "Stats"
## button there) rather than the in-game pause menu - "Back" goes back there.
func show_stats(stats: Dictionary, return_to_start: bool = false) -> void:
	_return_to_start = return_to_start
	_open(Kind.STATS, "STATS", [["Back", "back"]])
	_fill_stats(stats, false)


## Read-only Hall of Fame board, reachable from the start menu (and, once
## reached from a qualifying game-over/win, showing there too via _fill_stats).
func show_highscores(return_to_start: bool = false) -> void:
	_return_to_start = return_to_start
	_open(Kind.HIGHSCORES, "HIGH SCORES", [["Back", "back"]])
	_hof_grid = GridContainer.new()
	_hof_grid.columns = 3
	_hof_grid.add_theme_constant_override("h_separation", 14)
	_hof_grid.add_theme_constant_override("v_separation", 3)
	_hof_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats.add_child(_hof_grid)
	_render_hof(HallOfFame.load_list(), -1)
	_stats.visible = true


## `_keep_hof_state`: set only by "restart_cancel" below, which replays this
## same call to rebuild the interrupted game-over/win screen - without it, a
## score already committed (typed name, Save, OR the auto-commit safety net
## firing on that same "Restart" click) would offer the entry field again on
## the rebuild, since it's still true that the score QUALIFIES; entering
## another name there would double-post the same run's score under a second
## entry. `_hof_committed_this_run` only actually resets on a genuine fresh
## game-over/win from game.gd (the default, `false`), never on that replay.
func show_game_over(stats: Dictionary, _keep_hof_state: bool = false) -> void:
	_return_to_start = false
	_last_stats = stats
	if not _keep_hof_state:
		_hof_committed_this_run = false
	_open(Kind.GAME_OVER, "GAME OVER", [["Restart", "restart"], ["Exit", "exit"]])
	_fill_stats(stats, true)


func show_win(stats: Dictionary, _keep_hof_state: bool = false) -> void:
	_return_to_start = false
	_last_stats = stats
	if not _keep_hof_state:
		_hof_committed_this_run = false
	_open(Kind.WIN, "YOU WIN!", [["Restart", "restart"], ["Exit", "exit"]])
	_fill_stats(stats, true)


## Shared by _on_button()'s "back" action and the pause-key shortcut above.
func _do_back() -> void:
	if _return_to_start:
		visible = false
		back_to_start_requested.emit()
	else:
		show_pause()


func _open(kind: int, title: String, buttons: Array) -> void:
	# A browser tab can't close itself - get_tree().quit() just freezes the
	# canvas - so drop "Exit" on the Web build. "Restart" already covers
	# "start over from the title screen".
	if OS.has_feature("web"):
		buttons = buttons.filter(func(e: Array) -> bool: return e[1] != "exit")

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
			_do_back()
		"settings":
			# hand off to the settings menu, keep the tree paused and _kind = PAUSE
			visible = false
			settings_requested.emit()
		"restart":
			# User request: confirm before actually restarting. The safety-net
			# HOF auto-commit (see _maybe_auto_commit_hof()) fires HERE, not on
			# "restart_confirmed" below - _open() (called by _confirm_restart())
			# frees _stats' children, so _hof_entry_row would already be a
			# dangling reference by the time a later confirm fires. Treating
			# the first "Restart" click itself as "the player is leaving this
			# screen" matches galaga's own model (auto-commit fires on every
			# away-navigation button, no confirmation step exists there to
			# race against).
			_maybe_auto_commit_hof()
			_confirm_restart()
		"restart_confirmed":
			# Same as clicking Play on the start screen - skip straight into a
			# fresh run instead of reloading back into the start screen (user
			# report: "Restart" from Pause should be treated as if Play had
			# been clicked). See game.gd::_auto_start_next_run.
			Game._auto_start_next_run = true
			get_tree().paused = false
			get_tree().reload_current_scene()
		"restart_cancel":
			match _confirm_return_kind:
				Kind.GAME_OVER:
					show_game_over(_last_stats, true)
				Kind.WIN:
					show_win(_last_stats, true)
				_:
					show_pause()
		"exit":
			_maybe_auto_commit_hof()
			get_tree().quit()


func _confirm_restart() -> void:
	_confirm_return_kind = _kind
	_open(_kind, "RESTART?", [["Yes, Restart", "restart_confirmed"], ["Cancel", "restart_cancel"]])


## Called by the game when the settings menu closes: bring the pause menu back.
func reopen_pause() -> void:
	if _kind == Kind.PAUSE:
		visible = true
		get_tree().paused = true
		_buttons[0].grab_focus()


# --- end-game summary --------------------------------------------------

## `show_hof`: only true for game-over/win (see show_game_over()/show_win()) -
## the plain in-game "Stats" snapshot never offers a Hall of Fame entry.
func _fill_stats(d: Dictionary, show_hof: bool = false) -> void:
	for c in _stats.get_children():
		c.free()
	_name_edit = null
	_hof_entry_row = null

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

	if show_hof:
		_pending_score = int(d.get("score", 0))
		_stats.add_child(_hof_title_label("— HALL OF FAME —"))
		if not _hof_committed_this_run and HallOfFame.qualifies(_pending_score):
			_hof_entry_row = _build_hof_entry_row()
			_stats.add_child(_hof_entry_row)
		_hof_grid = GridContainer.new()
		_hof_grid.columns = 3
		_hof_grid.add_theme_constant_override("h_separation", 14)
		_hof_grid.add_theme_constant_override("v_separation", 3)
		_hof_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_stats.add_child(_hof_grid)
		_render_hof(HallOfFame.load_list(), -1)

	_stats.visible = true


# --- Hall of Fame (game-over/win only) --------------------------------

var _hof_grid: GridContainer


func _hof_title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	return l


func _build_hof_entry_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "NAME"
	_name_edit.max_length = HallOfFame.NAME_MAX_LEN
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(120, 40)
	_name_edit.add_theme_font_size_override("font_size", 18)
	# Live-capitalize as the player types (user request) - only touches
	# .text when there's an actual case difference, so the corrected,
	# already-uppercase text never re-triggers this branch on the signal's
	# own re-entry, and the caret position is restored either way.
	_name_edit.text_changed.connect(func(new_text: String) -> void:
		var upper := new_text.to_upper()
		if upper != new_text:
			var caret := _name_edit.caret_column
			_name_edit.text = upper
			_name_edit.caret_column = caret)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _commit_score())
	row.add_child(_name_edit)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 40)
	save_btn.add_theme_font_size_override("font_size", 16)
	save_btn.pressed.connect(_commit_score)
	row.add_child(save_btn)

	_name_edit.call_deferred("grab_focus")
	return row


## Saves the current name-entry field (defaulting to "YOU" if left empty,
## always stored upper-case - user request) and reveals the updated board
## with the new entry highlighted. Also the target of the auto-commit safety
## net below, so a qualifying score is never silently lost.
func _commit_score() -> void:
	var who := _name_edit.text.strip_edges()
	if who == "":
		who = "YOU"
	who = who.to_upper()
	var list := HallOfFame.insert(who, _pending_score, _last_stats.get("level", 1))
	_hof_committed_this_run = true
	_hof_entry_row.hide()
	var mine := -1
	for i in list.size():
		if str(list[i].get("name", "")) == who and int(list[i].get("score", 0)) == _pending_score:
			mine = i
			break
	_render_hof(list, mine)


## A qualifying score that's never actually entered (player leaves the
## game-over/win screen without typing a name or pressing Save) would
## otherwise just be lost - commit it as "YOU" automatically, exactly as if
## Save had been pressed with an empty field (ported from galaga's
## _maybe_auto_commit(), same reasoning). `_hof_entry_row.visible` is exactly
## "still needs to be entered" (see _fill_stats()/_commit_score() above), so
## it doubles as the "did they forget" check. Safe to call when there's no
## entry row at all (e.g. from the pause menu) - null-guarded.
func _maybe_auto_commit_hof() -> void:
	if _hof_entry_row and is_instance_valid(_hof_entry_row) and _hof_entry_row.visible:
		_commit_score()


func _render_hof(list: Array, highlight: int) -> void:
	if not _hof_grid:
		return
	for c in _hof_grid.get_children():
		c.queue_free()
	if list.is_empty():
		var l := _hof_title_label("(no scores yet)")
		_hof_grid.add_child(l)
		return
	for i in list.size():
		var e = list[i]
		var col := Color(1, 0.85, 0.35) if i == highlight else Color(1, 1, 1)
		var rank_l := Label.new()
		rank_l.text = "%d." % (i + 1)
		rank_l.add_theme_font_size_override("font_size", 15)
		rank_l.add_theme_color_override("font_color", col)
		rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := Label.new()
		name_l.text = str(e.get("name", "?")).to_upper()
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", col)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var score_l := Label.new()
		score_l.text = str(int(e.get("score", 0)))
		score_l.add_theme_font_size_override("font_size", 15)
		score_l.add_theme_color_override("font_color", col)
		score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hof_grid.add_child(rank_l)
		_hof_grid.add_child(name_l)
		_hof_grid.add_child(score_l)


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
