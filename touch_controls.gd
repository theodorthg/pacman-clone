class_name TouchControls
extends CanvasLayer

## Touch HUD, shown only on touch devices (turned on by
## `game._setup_mobile_layout()`):
##   * a non-interactive swipe indicator, in the dead strip between the SCORE
##     and HIGH SCORE labels
##   * a pause button, in the dead strip between HIGH SCORE and LEVEL
## Both sit in the reserved top scoreboard band (rows above the maze proper,
## y 0-112 in design px) rather than below the maze - that band is at a FIXED
## position in the 480-wide design canvas on every device, so unlike a strip
## below the maze it never depends on how much extra height KEEP_WIDTH happens
## to produce (on devices near the design's 3:4 aspect - most tablets,
## including iPad and the Galaxy Tab S3 - that extra height is zero; see git
## history for the bottom-strip approach this replaced).
## Steering is entirely by swiping anywhere on the screen (player.gd). Both
## elements hide while any menu is open.

@export var player_path: NodePath = ^"../player"
@export var overlay_path: NodePath = ^"../overlay"

@onready var _indicator: SwipeIndicator = $indicator
@onready var _pause: PauseButton = $pause_btn

var _player: Node
var _overlay: Node
var _enabled: bool = false


## Other nodes (game / settings_menu / overlay_menu) join this group and expose
## an `apply_touch_layout()` method; see `confirm_touch_seen()`.
const LAYOUT_GROUP := "touch_layout_listeners"

static var _confirmed := false
static var _initial_checked := false
static var _initial_result := false


## True on a native mobile export (Android/iOS), when the current device
## reports a touchscreen (covers the Web export opened in a phone/tablet
## browser - Safari/Firefox on iPhone/iPad included), or once a real touch
## input has actually been observed this session (see `confirm_touch_seen`).
## `OS.has_feature("mobile")` alone misses the Web case, since the Web export
## only ever reports the "web" feature tag regardless of the device it runs on.
##
## The OS/DisplayServer check is evaluated only ONCE per run - on whichever of
## game.gd / settings_menu.gd / overlay_menu.gd happens to call this first -
## and the result is cached for everyone else. Without that, three separate
## _ready()-time calls (one per script, each a hair apart in time) could race:
## on some browsers `DisplayServer.is_touchscreen_available()` isn't stable in
## that first instant, so two call sites a fraction of a second apart could get
## different answers (seen in practice: the start menu correctly detects touch
## and pins itself to the top, while the game itself never does).
static func is_touch_device() -> bool:
	if not _initial_checked:
		_initial_checked = true
		_initial_result = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	return _confirmed or _initial_result


## Call the moment ANY touch input is observed anywhere in the game. Idempotent
## - only the first call does anything. This retroactively flips every
## registered listener over to the touch layout even if it had already decided
## "desktop" at its own _ready() time: some Web browsers (certain iPadOS
## Safari / Firefox combinations seen in practice) don't report touchscreen
## availability synchronously at page load, only once a real touch has
## actually happened.
static func confirm_touch_seen() -> void:
	if _confirmed:
		return
	_confirmed = true
	var loop := Engine.get_main_loop()
	if loop:
		loop.call_group(LAYOUT_GROUP, "apply_touch_layout")


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group(LAYOUT_GROUP)
	_player = get_node_or_null(player_path)
	_overlay = get_node_or_null(overlay_path)
	_pause.tapped.connect(_on_pause)


## `_input`, not `_unhandled_input`: this must see the very first touch even if
## it lands on a menu button that consumes it (e.g. tapping "Play"), and this
## node runs PROCESS_MODE_ALWAYS so it sees it even while the start menu has
## the tree paused.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		confirm_touch_seen()


## Broadcast target for confirm_touch_seen(); also called directly below.
func apply_touch_layout() -> void:
	set_enabled(true)


## Turned on by game._setup_mobile_layout(). May run before this node's _ready(),
## so it only flips a flag; _process() does the actual layout.
func set_enabled(on: bool) -> void:
	_enabled = on


func _process(_dt: float) -> void:
	var want := _enabled and not get_tree().paused
	if want != visible:
		visible = want
	if not visible:
		return
	_layout()
	if _player and _player.has_method("desired_dir"):
		_indicator.set_dir(_player.desired_dir())


## Row (canvas px) both elements sit on - between the label row (ends ~y60)
## and the maze's own top wall (starts y112, = 7 reserved tile rows).
const _ROW_Y := 84.0
const _INDICATOR_X := 150.0   ## between the SCORE (ends x135) and HIGH SCORE (starts ~x201) labels
const _INDICATOR_SIZE := 42.0
const _PAUSE_X := 330.0       ## between HIGH SCORE (ends ~x278) and LEVEL (starts x390)
const _PAUSE_SIZE := 40.0


func _layout() -> void:
	if _indicator == null or _pause == null:
		return
	_indicator.size = Vector2(_INDICATOR_SIZE, _INDICATOR_SIZE)
	_indicator.position = Vector2(_INDICATOR_X - _INDICATOR_SIZE * 0.5, _ROW_Y - _INDICATOR_SIZE * 0.5)

	_pause.size = Vector2(_PAUSE_SIZE, _PAUSE_SIZE)
	_pause.position = Vector2(_PAUSE_X - _PAUSE_SIZE * 0.5, _ROW_Y - _PAUSE_SIZE * 0.5)


func _on_pause() -> void:
	if _overlay and _overlay.has_method("show_pause") and not get_tree().paused:
		_overlay.show_pause()
