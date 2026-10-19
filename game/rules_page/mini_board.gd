class_name MiniBoard
extends Control
## A small Board for the rules page: the viewer's three rows tinted red at the
## bottom, the enemy's three rows tinted at the top, the Obstacles hatched.

const CELL: float = 36.0
const LANE_STRIPE: float = 5.0
const OWN_TINT_ALPHA: float = 0.4
const ENEMY_TINT_ALPHA: float = 0.45

var _adapted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(Board.COLUMNS, Board.ROWS) * CELL


func _draw() -> void:
	for column: int in Board.COLUMNS:
		for row: int in Board.ROWS:
			_draw_square(Vector2i(column, row))


## Draws the enemy rows blue instead of green.
func set_adapted(adapted: bool) -> void:
	_adapted = adapted
	queue_redraw()


## The colour of the enemy rows' tint, for labels drawn beside the Board.
func enemy_colour() -> Color:
	return UiTokens.BLUE_400 if _adapted else UiTokens.GREEN_500


func _draw_square(square: Vector2i) -> void:
	# Rank 1 is drawn at the bottom, as the viewer sees their own side.
	var corner: Vector2 = Vector2(square.x, Board.ROWS - 1 - square.y) * CELL
	var rect: Rect2 = Rect2(corner, Vector2.ONE * CELL)
	if Board.is_obstacle(square):
		BoardShapes.draw_stripes(self, rect, UiTokens.LANE_A, UiTokens.LANE_B, LANE_STRIPE)
		return
	var light: bool = (square.x + square.y) % 2 == 1
	draw_rect(rect, UiTokens.CELL_LIGHT if light else UiTokens.CELL_DARK)
	if square.y in Setup.rows_for(Side.Id.RED):
		draw_rect(rect, Color(UiTokens.RED_400, OWN_TINT_ALPHA))
	elif square.y in Setup.rows_for(Side.Id.GREEN):
		draw_rect(rect, Color(enemy_colour(), ENEMY_TINT_ALPHA))
