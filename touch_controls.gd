class_name TouchControls
extends CanvasLayer

## Touch HUD, shown only on touch devices (turned on by
## `game._setup_mobile_layout()`):
##   * a non-interactive swipe indicator, centred just below the play field
##   * a pause button, set off to the right, just below the play field
## Steering is entirely by swiping anywhere on the screen (player.gd). Both
## elements hide while any menu is open.

@export var player_path: NodePath = ^"../player"
@export var overlay_path: NodePath = ^"../overlay"

## Y (canvas px) of the indicator / pause row - clear of the maze and the
## lives/items row just under it.
@export var strip_y: float = 744.0

@onready var _indicator: SwipeIndicator = $indicator
@onready var _pause: PauseButton = $pause_btn

var _player: Node
var _overlay: Node
var _enabled: bool = false


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_player = get_node_or_null(player_path)
	_overlay = get_node_or_null(overlay_path)
	_pause.tapped.connect(_on_pause)


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


func _layout() -> void:
	if _indicator == null or _pause == null:
		return
	var ind := 78.0
	_indicator.size = Vector2(ind, ind)
	_indicator.position = Vector2(240.0 - ind * 0.5, strip_y - ind * 0.5)

	var pb := 54.0
	_pause.size = Vector2(pb, pb)
	_pause.position = Vector2(430.0 - pb * 0.5, strip_y - pb * 0.5)


func _on_pause() -> void:
	if _overlay and _overlay.has_method("show_pause") and not get_tree().paused:
		_overlay.show_pause()
