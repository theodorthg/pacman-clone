class_name Pills
extends Node2D

## Maze dots and power pills.
##
## Kept fully separate from MazeGrid's collision data: this node owns only the
## collectibles. It spawns one sprite per pill from MazeGrid.build_pills() and
## removes it when the player reaches that tile.

## kind is MazeGrid.PILL_SMALL or MazeGrid.PILL_BIG.
signal pill_eaten(kind: int, cell: Vector2i)
signal all_eaten

const _SMALL_TEX: Texture2D = preload("res://assets/items/pill_small.png")
const _BIG_TEX: Texture2D = preload("res://assets/items/pill_big.png")

## Player to listen to; defaults to a sibling node named "player".
@export var player_path: NodePath = ^"../player"

var _kind: Dictionary = {}   ## Vector2i -> int
var _node: Dictionary = {}   ## Vector2i -> Sprite2D
var _total: int = 0          ## pill count of a full board


func _ready() -> void:
	_build()
	var player := get_node_or_null(player_path)
	if player and player.has_signal("reached_cell"):
		player.reached_cell.connect(_on_player_reached_cell)
	else:
		push_warning("Pills: no player with a 'reached_cell' signal at %s" % player_path)


func _build() -> void:
	var layout := MazeGrid.build_pills()
	_total = layout.size()
	for cell in layout.keys():
		var kind: int = layout[cell]
		var s := Sprite2D.new()
		if kind == MazeGrid.PILL_BIG:
			s.texture = _BIG_TEX
			s.scale = Vector2(2.0, 2.0)
		else:
			s.texture = _SMALL_TEX
		s.position = MazeGrid.cell_to_world(cell)
		add_child(s)
		if kind == MazeGrid.PILL_BIG:
			_start_blink(s)
		_kind[cell] = kind
		_node[cell] = s


## Wipe the board and lay every pill out fresh (used when a new level starts).
func reset_all() -> void:
	for s in _node.values():
		s.queue_free()
	_kind.clear()
	_node.clear()
	_build()


## Pill count of a full, fresh board.
func total() -> int:
	return _total


func _on_player_reached_cell(cell: Vector2i) -> void:
	if not _kind.has(cell):
		return
	var kind: int = _kind[cell]
	_node[cell].queue_free()
	_node.erase(cell)
	_kind.erase(cell)
	pill_eaten.emit(kind, cell)
	if _kind.is_empty():
		all_eaten.emit()


## Pills still on the board (for the HUD / win check later).
func remaining() -> int:
	return _kind.size()


## Looping fade so the power pills are easy to spot. The tween is owned by the
## sprite, so it stops by itself once the pill is eaten.
func _start_blink(s: Sprite2D) -> void:
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.2, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
