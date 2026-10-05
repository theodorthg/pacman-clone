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
## Start-screen-only: "Stats"/"High Scores" buttons - game.gd answers with
## overlay.show_stats(_game_stats(), true) / overlay.show_highscores(true),
## the `true` telling the overlay "Back" belongs to open_start() again, not
## the in-game pause menu (see overlay_menu.gd's _return_to_start).
signal stats_requested
signal hof_requested

const _PATH := "user://settings.cfg"

enum Mode { START, PAUSE }

@onready var _root: VBoxContainer = $center/panel_frame/inner/root
@onready var _panel: VBoxContainer = $center/panel_frame/inner/panel
@onready var _sound: VBoxContainer = $center/panel_frame/inner/sound_panel

@onready var _play_btn: Button = $center/panel_frame/inner/root/play_btn
@onready var _open_settings_btn: Button = $center/panel_frame/inner/root/settings_btn
@onready var _exit_btn: Button = $center/panel_frame/inner/root/exit_btn
@onready var _stats_btn: Button = $center/panel_frame/inner/root/stats_btn
@onready var _hof_btn: Button = $center/panel_frame/inner/root/hof_btn

@onready var _lives: SpinBox = $center/panel_frame/inner/panel/grid/lives_val
@onready var _dot_points: SpinBox = $center/panel_frame/inner/panel/grid/dot_points_val
@onready var _first_extra: SpinBox = $center/panel_frame/inner/panel/grid/first_extra_val
@onready var _extra_gap: SpinBox = $center/panel_frame/inner/panel/grid/extra_gap_val
@onready var _gap_mult: SpinBox = $center/panel_frame/inner/panel/grid/gap_mult_val
@onready var _pac_speed: SpinBox = $center/panel_frame/inner/panel/grid/pac_speed_val
@onready var _ghost_speed: SpinBox = $center/panel_frame/inner/panel/grid/ghost_speed_val
@onready var _sound_btn: Button = $center/panel_frame/inner/panel/sound_btn
@onready var _panel_back: Button = $center/panel_frame/inner/panel/back_btn

@onready var _sound_rows: GridContainer = $center/panel_frame/inner/sound_panel/rows
@onready var _sound_back: Button = $center/panel_frame/inner/sound_panel/back_btn

@onready var _help: VBoxContainer = $center/panel_frame/inner/help_panel
@onready var _help_btn: Button = $center/panel_frame/inner/root/help_btn
@onready var _help_page_title: Label = $center/panel_frame/inner/help_panel/page_title
@onready var _help_image: TextureRect = $center/panel_frame/inner/help_panel/image
@onready var _help_prev: Button = $center/panel_frame/inner/help_panel/nav/prev_btn
@onready var _help_next: Button = $center/panel_frame/inner/help_panel/nav/next_btn
@onready var _help_dots: HBoxContainer = $center/panel_frame/inner/help_panel/dots
@onready var _help_done: Button = $center/panel_frame/inner/help_panel/nav/done_btn

## One slide per input method, in the order a newcomer should read them -
## mouse before touch, per the design guideline that new games explain mouse
## control as a first-class option. Image-based (like tetris/galaga's help,
## assets/help_src/*.svg -> render.sh -> assets/graphics/help/<file>.png) so
## each page shows a real illustration instead of a wall of text.
const HELP_DIR := "res://assets/graphics/help/"
const HELP_PAGES: Array[Dictionary] = [
	{"title": "GOAL", "file": "goal"},
	{"title": "MOUSE — CLICK TO MOVE", "file": "mouse_click"},
	{"title": "MOUSE — CHANGE YOUR MIND", "file": "mouse_change"},
	{"title": "KEYBOARD / GAMEPAD", "file": "keyboard"},
	{"title": "TOUCH", "file": "touch"},
	{"title": "BONUS FRUIT", "file": "fruit"},
	{"title": "TWO PLAYERS", "file": "players"},
	{"title": "MAZES & CONTINUE", "file": "continue"},
	{"title": "SETTINGS", "file": "settings"},
]

var _mode: int = Mode.START
var _help_page: int = 0
var _help_touch_id: int = -1
var _help_touch_x: float = 0.0
const _HELP_SWIPE_MIN := 40.0
## Start-screen "Mode" button (built in code right below Play): opens a panel
## to pick 1 player / 2 players taking turns on this device / the same over the
## network (online relay or Wi-Fi/LAN, each on their own device).
## `_players` (1/2) is the persisted local choice ("players" in section "s").
var _players: int = 1
var _mode_btn: Button
var _mode_panel: VBoxContainer
var _mode_screen_name: String = ""
var _net: TurnsNet
var _ip_text: String = ""
var _lan_hosts: Dictionary = {}
## "Continue (Level N)": start a new run at the first level of the furthest maze
## reached so far (checkpoint written by game.gd, section "progress").
var _continue_btn: Button
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

	_play_btn.pressed.connect(func() -> void: _on_play(1))
	_mode_btn = _help_btn.duplicate() as Button
	_mode_btn.name = "mode_btn"
	_root.add_child(_mode_btn)
	_root.move_child(_mode_btn, _play_btn.get_index() + 1)
	_mode_btn.pressed.connect(func() -> void: _mode_screen("menu"))
	_mode_panel = VBoxContainer.new()
	_mode_panel.name = "mode_panel"
	_mode_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mode_panel.add_theme_constant_override("separation", 14)
	_mode_panel.custom_minimum_size = Vector2(380, 0)
	_mode_panel.visible = false
	_root.get_parent().add_child(_mode_panel)
	_net = TurnsNet.new()
	add_child(_net)
	_net.room_ready.connect(func(code: String) -> void: _mode_screen("wait", {"code": code}))
	_net.connected.connect(_on_net_connected)
	_net.cfg_received.connect(_on_net_cfg)
	_net.failed.connect(func(t: String) -> void:
		_net.cancel()
		_mode_screen("info", {"text": t}))
	_net.hosts_changed.connect(func(h: Dictionary) -> void:
		_lan_hosts = h
		if _mode_panel.visible and _mode_screen_name == "lan_join":
			_mode_screen("lan_join", {"keep_focus": true}))
	_refresh_mode_btn()
	_continue_btn = _help_btn.duplicate() as Button
	_continue_btn.name = "continue_btn"
	_root.add_child(_continue_btn)
	_root.move_child(_continue_btn, _play_btn.get_index() + 1)
	_continue_btn.pressed.connect(func() -> void: _on_play(checkpoint_level()))
	_refresh_continue_btn()
	_open_settings_btn.pressed.connect(_show_params)
	# A browser tab can't close itself - get_tree().quit() just freezes the
	# canvas - so the start screen drops Exit on the Web build, same as the
	# pause overlay already does (see overlay_menu.gd::_open()).
	if OS.has_feature("web"):
		_exit_btn.hide()
	else:
		_exit_btn.pressed.connect(func() -> void: get_tree().quit())
	_stats_btn.pressed.connect(func() -> void: visible = false; stats_requested.emit())
	_hof_btn.pressed.connect(func() -> void: visible = false; hof_requested.emit())
	_sound_btn.pressed.connect(_show_sound)
	_panel_back.pressed.connect(_back_from_params)
	_sound_back.pressed.connect(_show_params)
	_help_btn.pressed.connect(_open_help)
	_help_done.pressed.connect(_back_from_help)
	_help_prev.pressed.connect(func() -> void: _help_go(-1))
	_help_next.pressed.connect(func() -> void: _help_go(1))
	_help_image.gui_input.connect(_on_help_body_input)

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
	if not visible:
		return
	if _help.visible:
		_help_input(event)
	# B (ui_cancel) backs out the same way Esc/the pause key already does -
	# standard gamepad convention, independent of which control has focus.
	if not (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if _mode_panel.visible:
		_mode_back()
	elif _sound.visible:
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
	_refresh_continue_btn()
	_show(_root)


## From the pause menu's "How to Play". Tree already paused by the pause overlay;
## Back emits `closed` so the pause menu returns.
func open_help_from_pause() -> void:
	_mode = Mode.PAUSE
	visible = true
	_open_help()


## From the pause menu: jump straight to the parameter panel. The tree is
## already paused by the pause overlay.
func open_params_from_pause() -> void:
	_mode = Mode.PAUSE
	visible = true
	_load()
	_show(_panel)


# --- navigation -------------------------------------------------------

func _show(panel: Control) -> void:
	for p: Control in [_root, _panel, _sound, _help, _mode_panel]:
		p.visible = (p == panel)
	var first: Control = {
		_root: _play_btn, _panel: _sound_btn, _sound: _sound_back, _help: _help_done,
	}.get(panel)
	if first:
		first.call_deferred("grab_focus")


## Open the help deck fresh at page 0 - whether from the start-screen "How to
## Play" or the pause menu's, a returning player shouldn't land mid-deck from
## last time.
func _open_help() -> void:
	_show(_help)
	_help_page = 0
	_help_go(0)


## Advance the help deck by [param delta] pages (0 to (re)draw the current one),
## wrapping past either end - the last page's "next" goes back to the first and
## vice versa, so there's always something to click toward.
func _help_go(delta: int) -> void:
	_help_page = wrapi(_help_page + delta, 0, HELP_PAGES.size())
	var page: Dictionary = HELP_PAGES[_help_page]
	_help_page_title.text = str(page.get("title", ""))
	_help_image.texture = load(HELP_DIR + str(page.get("file", "")) + ".png")
	_refresh_help_dots()


func _refresh_help_dots() -> void:
	for c in _help_dots.get_children():
		c.free()
	for i in HELP_PAGES.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(7, 7)
		# Without this, each dot defaults to SIZE_FILL vertically and stretches
		# to match the tall prev/next buttons next to it in "nav" (44px) -
		# renders as a tall bar instead of a small square (user report).
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = Color(1, 0.95, 0.3, 1) if i == _help_page else Color(1, 1, 1, 0.25)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_help_dots.add_child(d)


## Click anywhere on the page image to advance too - the third way to flip
## pages, alongside the ‹ / › buttons and swipe/arrow-keys below.
func _on_help_body_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_help_go(1)
		_help_image.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_help_go(1)
		_help_image.accept_event()


## Swipe / arrow-key paging while the help deck is open. Raw keycodes (not the
## move_left/right actions, which are also bound to these same keys) so this
## never fights the game's own steering bindings.
func _help_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_help_go(-1); get_viewport().set_input_as_handled()
			KEY_RIGHT, KEY_D:
				_help_go(1); get_viewport().set_input_as_handled()
	# Gamepad D-pad paging - `ui_left`/`ui_right` rather than move_left/right,
	# since those raw WASD/arrow keycodes above already cover the keyboard case
	# and move_left/right would also fire during actual gameplay steering.
	elif event.is_action_pressed("ui_left"):
		_help_go(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_help_go(1); get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_help_touch_id = event.index
			_help_touch_x = event.position.x
		elif event.index == _help_touch_id:
			_help_touch_id = -1
			var dx: float = event.position.x - _help_touch_x
			if absf(dx) > _HELP_SWIPE_MIN:
				_help_go(-1 if dx > 0.0 else 1)   # swipe right -> previous page
				get_viewport().set_input_as_handled()


## Highest checkpoint level saved by game.gd (1 = none yet).
static func checkpoint_level() -> int:
	var c := ConfigFile.new()
	if c.load(_PATH) != OK:
		return 1
	return maxi(1, int(c.get_value("progress", "checkpoint_level", 1)))


func _refresh_continue_btn() -> void:
	var lvl := checkpoint_level()
	_continue_btn.visible = lvl > 1
	_continue_btn.text = "Continue (Level %d)" % lvl


func _refresh_mode_btn() -> void:
	_mode_btn.text = "Game mode: 2 Players (turns)" if _players == 2 else "Game mode: 1 Player"


# --- mode panel (1 / 2 players, network) -----------------------------------

func _m_clear() -> void:
	for c in _mode_panel.get_children():
		_mode_panel.remove_child(c)
		c.queue_free()


func _m_title(text: String, size: int = 30) -> void:
	var l := $center/panel_frame/inner/root/title.duplicate() as Label
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(380, 0)
	_mode_panel.add_child(l)


func _m_label(text: String, size: int = 16) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92))
	_mode_panel.add_child(l)


func _m_button(text: String, cb: Callable, selected := false) -> Button:
	var b := _help_btn.duplicate() as Button
	b.text = ("> " + text) if selected else text
	b.custom_minimum_size = Vector2(380, 50)
	b.pressed.connect(cb)
	_mode_panel.add_child(b)
	return b


func _mode_screen(screen: String, ctx: Dictionary = {}) -> void:
	_mode_screen_name = screen
	_m_clear()
	var first: Control = null
	match screen:
		"menu":
			_m_title("GAME MODE")
			_m_label("How many players? With two you take turns: when Pac-Man loses a life, " +
				"the other player is up (like the arcade).", 15)
			first = _m_button("1 Player", func() -> void: _pick_local(1), _players == 1)
			_m_button("2 Players - this device", func() -> void: _pick_local(2), _players == 2)
			if NetLink.relay_url() != "":
				_m_button("2 Players - Online (own devices)", func() -> void: _mode_screen("online"))
			if NetLink.lan_possible():
				_m_button("2 Players - Wi-Fi / LAN (own devices)", func() -> void: _mode_screen("lan"))
			_m_button("Back", _mode_back)
		"online":
			_m_title("PLAY ONLINE", 28)
			_m_label("Two players, each on their own device, anywhere (also in the browser). " +
				"You take turns; a 4-letter code connects you.", 15)
			first = _m_button("Host a game (get a code)", func() -> void:
				_mode_screen("wait", {"code": ""})
				if not _net.host_online():
					_mode_screen("info", {"text": "No online server is set up."}))
			_m_button("Join with a code", func() -> void: _mode_screen("join_code"))
			_m_button("Back", _mode_back)
		"join_code":
			_m_title("JOIN A GAME", 28)
			_m_label("Enter the code shown on the host's screen.", 15)
			var edit := LineEdit.new()
			edit.max_length = 4
			edit.placeholder_text = "CODE"
			edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			edit.custom_minimum_size = Vector2(0, 52)
			edit.add_theme_font_size_override("font_size", 30)
			_mode_panel.add_child(edit)
			edit.text_changed.connect(func(t: String) -> void:
				var c := NetLink.clean_code(t)
				if c != t:
					edit.text = c
					edit.caret_column = c.length())
			var go := func() -> void:
				var c := NetLink.clean_code(edit.text)
				if c.length() == 4:
					_mode_screen("wait", {"text": "Joining the game..."})
					if not _net.join_online(c):
						_mode_screen("info", {"text": "No online server is set up."})
			edit.text_submitted.connect(func(_t: String) -> void: go.call())
			_m_button("Join", go)
			_m_button("Back", _mode_back)
			first = edit
		"lan":
			_m_title("WI-FI / LAN", 28)
			_m_label("Two players on the same network, no server needed. You take turns.", 15)
			first = _m_button("Host a game", func() -> void:
				if _net.host_lan(NetLink.device_name()):
					_mode_screen("wait", {"ips": NetLink.local_ips()})
				else:
					_mode_screen("info", {"text": "Can't open a LAN game here (port 47111 busy?)."}))
			_m_button("Join a game", func() -> void:
				_lan_hosts = {}
				_net.search_lan()
				_mode_screen("lan_join"))
			_m_button("Back", _mode_back)
		"lan_join":
			_m_title("JOIN IN LAN / WI-FI", 26)
			if _lan_hosts.is_empty():
				_m_label("Looking for games in your network...", 15)
			else:
				_m_label("Found - pick one:", 15)
				for ip in _lan_hosts:
					if ip == "127.0.0.1" and _lan_hosts.keys().any(func(o): return o != ip and _lan_hosts[o] == _lan_hosts[ip]):
						continue
					var addr: String = ip
					var hb := _m_button("%s  (%s)" % [_lan_hosts[ip], addr], func() -> void: _lan_connect(addr))
					if first == null:
						first = hb
			_m_label("Or type the address shown on the host:", 14)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_mode_panel.add_child(row)
			var ed := LineEdit.new()
			ed.max_length = 15
			ed.placeholder_text = "192.168...."
			ed.text = _ip_text
			ed.custom_minimum_size = Vector2(0, 46)
			ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ed.add_theme_font_size_override("font_size", 20)
			row.add_child(ed)
			ed.text_changed.connect(func(t: String) -> void: _ip_text = t)
			ed.text_submitted.connect(func(t: String) -> void: _lan_connect(t))
			var cb := Button.new()
			cb.text = "Connect"
			cb.custom_minimum_size = Vector2(110, 46)
			row.add_child(cb)
			cb.pressed.connect(func() -> void: _lan_connect(ed.text))
			_m_button("Back", _mode_back)
			if bool(ctx.get("keep_focus", false)):
				first = ed
		"wait":
			var code := str(ctx.get("code", ""))
			if ctx.has("ips"):
				_m_title("WAITING FOR THE OTHER PLAYER", 22)
				_m_label("On their device: Mode > 2 Players - Wi-Fi / LAN > Join a game.", 15)
				_m_label("This game shows up there by itself, or type its address:", 14)
				var ips: Array = ctx.get("ips", [])
				_m_title("  ".join(ips) if not ips.is_empty() else "(no network)", 26)
				_m_label("Host is a PC with a firewall? Allow UDP 47110-47111 - or play Online.", 13)
			elif code != "":
				_m_title("WAITING FOR THE OTHER PLAYER", 22)
				_m_label("Tell them this code:", 16)
				_m_title(code, 56)
				_m_label("On their device: Mode > 2 Players - Online > Join with a code.", 14)
			else:
				_m_title("CONNECTING", 28)
				_m_label(str(ctx.get("text", "Opening a game on the online server...")), 16)
			first = _m_button("Cancel", _mode_back)
		"info":
			_m_title("TWO PLAYERS", 28)
			_m_label(str(ctx.get("text", "")), 16)
			first = _m_button("Back", func() -> void: _mode_screen("menu"))
	_show(_mode_panel)
	if first:
		first.call_deferred("grab_focus")


func _pick_local(n: int) -> void:
	_players = n
	_refresh_mode_btn()
	_save(_read())
	_show(_root)


func _mode_back() -> void:
	match _mode_screen_name:
		"menu":
			_show(_root)
		"online", "lan":
			_mode_screen("menu")
		"join_code":
			_mode_screen("online")
		"lan_join":
			_net.cancel()
			_mode_screen("lan")
		"wait":
			var lan := _net.discovery != null or (_net.link != null and _net.link.enet != null)
			_net.cancel()
			_mode_screen("lan" if lan else "online")
		_:
			_mode_screen("menu")


func _lan_connect(ip: String) -> void:
	ip = ip.strip_edges()
	if ip == "":
		return
	_mode_screen("wait", {"text": "Connecting to %s..." % ip})
	if not _net.join_lan(ip):
		_mode_screen("info", {"text": "Can't connect to %s." % ip})


## Host side: the other player is connected - send the game settings and go.
func _on_net_connected() -> void:
	if not _net.is_host:
		return   # the guest waits for the host's "cfg" message
	var cfg := _read()
	cfg.erase("volumes")
	_net.send_cfg(cfg)
	_start_net_game(_read(), "host")


## Guest side: the host's game settings arrived - adopt them and go.
func _on_net_cfg(host_cfg: Dictionary) -> void:
	var cfg := _read()
	for k in ["lives", "dot_points", "first_extra_life", "extra_life_gap", "extra_life_gap_mult", "pacman_speed", "ghost_speed"]:
		if host_cfg.has(k):
			cfg[k] = host_cfg[k]
	_start_net_game(cfg, "guest")


func _start_net_game(cfg: Dictionary, role: String) -> void:
	_net.in_game = true
	visible = false
	get_tree().paused = false
	cfg["players"] = 2
	cfg["net"] = _net
	cfg["net_role"] = role
	started.emit(cfg)


func _show_params() -> void:
	_show(_panel)


func _show_sound() -> void:
	_show(_sound)


func _on_play(start_level: int = 1) -> void:
	var cfg := _read()
	cfg["start_level"] = start_level
	_save(cfg)
	visible = false
	get_tree().paused = false
	started.emit(cfg)


## Lets an external caller (the pause overlay's "Restart", via a scene reload
## + Game._auto_start_next_run - see game.gd::_ready()) start a fresh run with
## the currently saved settings, without making the player click Play again.
## _ready() already calls _load() before this can run, so the fields here
## reflect user://settings.cfg, exactly like a normal Play click would.
func request_play() -> void:
	_on_play()


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
		"players": _players,
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
	_players = clampi(int(c.get_value("s", "players", _players)), 1, 2)
	_refresh_mode_btn()
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
		if k == "volumes" or k == "start_level" or k == "net" or k == "net_role":
			continue   # SoundManager owns section "sound"
		c.set_value("s", k, cfg[k])
	c.save(_PATH)
