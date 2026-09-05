class_name SettingsMenu
extends CanvasLayer

## The game's menu stack. Three panels inside one CenterContainer:
##
##   root   - Play / Settings           (shown at start-of-run only)
##   panel  - game parameters + Sound Settings + Back
##   sound  - per-sound volume sliders + Back
##
## Entry points:
##   open_start()            -> root panel, pauses the tree; Play emits `started`.
##   open_params_from_pause()-> panel directly (tree already paused by the pause
##                              menu); Back emits `closed` so the pause menu can
##                              come back. Value changes emit `settings_changed`
##                              for the game to apply live.
##
## Game parameters persist to section "s" of user://settings.cfg; sound volumes
## are owned by SoundManager (section "sound").

signal started(config: Dictionary)
signal settings_changed(config: Dictionary)
signal closed

const _PATH := "user://settings.cfg"

enum Mode { START, PAUSE }

@onready var _root: VBoxContainer = $center/root
@onready var _panel: VBoxContainer = $center/panel
@onready var _sound: VBoxContainer = $center/sound_panel

@onready var _play_btn: Button = $center/root/play_btn
@onready var _open_settings_btn: Button = $center/root/settings_btn

@onready var _lives: SpinBox = $center/panel/grid/lives_val
@onready var _dot_points: SpinBox = $center/panel/grid/dot_points_val
@onready var _first_extra: SpinBox = $center/panel/grid/first_extra_val
@onready var _extra_gap: SpinBox = $center/panel/grid/extra_gap_val
@onready var _gap_mult: SpinBox = $center/panel/grid/gap_mult_val
@onready var _pac_speed: SpinBox = $center/panel/grid/pac_speed_val
@onready var _ghost_speed: SpinBox = $center/panel/grid/ghost_speed_val
@onready var _sound_btn: Button = $center/panel/sound_btn
@onready var _panel_back: Button = $center/panel/back_btn

@onready var _sound_rows: GridContainer = $center/sound_panel/rows
@onready var _sound_back: Button = $center/sound_panel/back_btn

@onready var _help: VBoxContainer = $center/help_panel
@onready var _help_btn: Button = $center/root/help_btn
@onready var _help_body: Label = $center/help_panel/body
@onready var _help_back: Button = $center/help_panel/back_btn

var _mode: int = Mode.START
var _vol_slider: Dictionary = {}   ## sound key -> HSlider
var _vol_label: Dictionary = {}    ## sound key -> Label ("NN%")
var _audio: Node
var _last_preview_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(TouchControls.LAYOUT_GROUP)
	apply_touch_layout()
	_audio = get_node_or_null(^"../audio")

	_play_btn.pressed.connect(_on_play)
	_open_settings_btn.pressed.connect(_show_params)
	_sound_btn.pressed.connect(_show_sound)
	_panel_back.pressed.connect(_back_from_params)
	_sound_back.pressed.connect(_show_params)
	_help_btn.pressed.connect(func() -> void: _show(_help))
	_help_back.pressed.connect(_back_from_help)
	_help_body.text = _controls_text()

	for sb in [_lives, _dot_points, _first_extra, _extra_gap, _gap_mult, _pac_speed, _ghost_speed]:
		sb.value_changed.connect(_on_param_changed)

	_build_sound_rows()
	_load()


## On touch devices, pin the menu column to the top so the on-screen keyboard
## (SpinBox editing) can't cover the lower buttons. Idempotent; also the
## broadcast target for TouchControls.confirm_touch_seen() (see there) - covers
## Web browsers that don't report touch capability until a real touch happens.
func apply_touch_layout() -> void:
	if TouchControls.is_touch_device():
		var c := $center as BoxContainer
		c.alignment = BoxContainer.ALIGNMENT_BEGIN
		c.offset_top = 40.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _sound.visible:
		_show_params()
	elif _help.visible:
		_back_from_help()
	elif _panel.visible:
		_back_from_params()
	# on the root panel, ESC does nothing (there is nothing to go back to)


# --- entry points ------------------------------------------------------

## Start-of-run: show the root menu and pause the game underneath.
func open_start() -> void:
	_mode = Mode.START
	visible = true
	get_tree().paused = true
	_load()
	_show(_root)


## From the pause menu's "How to Play". Tree already paused by the pause overlay;
## Back emits `closed` so the pause menu returns.
func open_help_from_pause() -> void:
	_mode = Mode.PAUSE
	visible = true
	_show(_help)


## From the pause menu: jump straight to the parameter panel. The tree is
## already paused by the pause overlay.
func open_params_from_pause() -> void:
	_mode = Mode.PAUSE
	visible = true
	_load()
	_show(_panel)


# --- navigation -------------------------------------------------------

func _show(panel: Control) -> void:
	for p: Control in [_root, _panel, _sound, _help]:
		p.visible = (p == panel)
	var first: Control = {
		_root: _play_btn, _panel: _sound_btn, _sound: _sound_back, _help: _help_back,
	}.get(panel)
	if first:
		first.call_deferred("grab_focus")


## Control help, ordered by what the device most likely uses.
func _controls_text() -> String:
	var touch := (
		"—  TOUCH  —\n"
		+ "Swipe anywhere to turn (short flicks too).\n"
		+ "The compass shows the steering-direction .\n"
		+ "Tap  ❚❚  at the bottom right to pause."
	)
	var keys := (
		"—  KEYBOARD / GAMEPAD  —\n"
		+ "Arrow keys or W A S D to turn\n"
		+ "P, Esc, or the menu button to pause."
	)
	var intro := (
		"Eat every dot to clear the level.\n"
		+ "The 4 big pills turn the ghosts blue —\n"
		+ "chase them for bonus points.\n"
		+ "You can hit keys (once)/swipe always in advance.\n"
		+ "Fruit appears twice per level.\n\n"
	)
	var tune := (
		"\n\n—  SETTINGS  —\n"
		+ "Tune the difficulty there: number of lives,\n"
		+ "Pac-Man / ghost speed, points per dot,\n"
		+ "extra-life thresholds — plus per-sound volume."
	)
	if DisplayServer.is_touchscreen_available():
		return intro + touch + "\n\n" + keys + tune
	return intro + keys + "\n\n" + touch + tune


func _show_params() -> void:
	_show(_panel)


func _show_sound() -> void:
	_show(_sound)


func _on_play() -> void:
	var cfg := _read()
	_save(cfg)
	visible = false
	get_tree().paused = false
	started.emit(cfg)


func _back_from_params() -> void:
	_save(_read())
	if _mode == Mode.START:
		_show(_root)
	else:
		settings_changed.emit(_read())
		visible = false
		closed.emit()


func _back_from_help() -> void:
	if _mode == Mode.START:
		_show(_root)
	else:
		visible = false
		closed.emit()


# --- change handlers -------------------------------------------------

func _on_param_changed(_v: float) -> void:
	var cfg := _read()
	_save(cfg)
	if _mode == Mode.PAUSE:
		settings_changed.emit(cfg)


func _on_volume_changed(key: String, value: float, val_lbl: Label) -> void:
	val_lbl.text = "%d%%" % int(value)
	if _audio and _audio.has_method("set_volumes"):
		_audio.set_volumes({key: int(value)})
	# light throttle so dragging doesn't machine-gun the preview
	var now := Time.get_ticks_msec()
	if _audio and _audio.has_method("preview") and now - _last_preview_ms > 200:
		_last_preview_ms = now
		_audio.preview(key)
	if _mode == Mode.PAUSE:
		settings_changed.emit(_read())


# --- sound rows ------------------------------------------------------

func _build_sound_rows() -> void:
	for key in SoundManager.SOUNDS:
		var entry: Array = SoundManager.SOUNDS[key]

		var name_lbl := Label.new()
		name_lbl.text = entry[0]
		name_lbl.add_theme_font_size_override("font_size", 14)
		_sound_rows.add_child(name_lbl)

		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = float(entry[1])
		slider.custom_minimum_size = Vector2(170, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_sound_rows.add_child(slider)
		_vol_slider[key] = slider

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.custom_minimum_size = Vector2(42, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.text = "%d%%" % int(slider.value)
		_sound_rows.add_child(val_lbl)
		_vol_label[key] = val_lbl

		slider.value_changed.connect(func(v: float) -> void: _on_volume_changed(key, v, val_lbl))


# --- config ---------------------------------------------------------

func _read() -> Dictionary:
	var volumes := {}
	for key in _vol_slider:
		volumes[key] = int((_vol_slider[key] as HSlider).value)
	return {
		"lives": int(_lives.value),
		"dot_points": int(_dot_points.value),
		"first_extra_life": int(_first_extra.value),
		"extra_life_gap": int(_extra_gap.value),
		"extra_life_gap_mult": _gap_mult.value,
		"pacman_speed": _pac_speed.value,
		"ghost_speed": _ghost_speed.value,
		"volumes": volumes,
	}


func _load() -> void:
	# sliders reflect SoundManager's current (calibrated) values
	for key in _vol_slider:
		var s := _vol_slider[key] as HSlider
		if _audio and _audio.has_method("get_volume_pct"):
			s.set_value_no_signal(float(_audio.get_volume_pct(key)))
		var vl := _vol_label[key] as Label
		if vl:
			vl.text = "%d%%" % int(s.value)

	var c := ConfigFile.new()
	if c.load(_PATH) != OK:
		return
	_lives.set_value_no_signal(c.get_value("s", "lives", _lives.value))
	_dot_points.set_value_no_signal(c.get_value("s", "dot_points", _dot_points.value))
	_first_extra.set_value_no_signal(c.get_value("s", "first_extra_life", _first_extra.value))
	_extra_gap.set_value_no_signal(c.get_value("s", "extra_life_gap", _extra_gap.value))
	_gap_mult.set_value_no_signal(c.get_value("s", "extra_life_gap_mult", _gap_mult.value))
	_pac_speed.set_value_no_signal(c.get_value("s", "pacman_speed", _pac_speed.value))
	_ghost_speed.set_value_no_signal(c.get_value("s", "ghost_speed", _ghost_speed.value))


func _save(cfg: Dictionary) -> void:
	var c := ConfigFile.new()
	c.load(_PATH)
	for k in cfg:
		if k == "volumes":
			continue   # SoundManager owns section "sound"
		c.set_value("s", k, cfg[k])
	c.save(_PATH)
