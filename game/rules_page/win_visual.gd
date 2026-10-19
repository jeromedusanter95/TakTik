class_name WinVisual
extends Control
## The picture on a way-to-win card: a Piece beating the enemy Princess, or
## the player's Princess reaching the far row.

enum Way {
	CAPTURE,
	CROSSING,
}

const CELL: float = 42.0
const PIECE_INSET: float = 4.0
const SLASH_WIDTH: float = 5.0
const SLASH_DEGREES: float = -35.0
const PATH_WIDTH: float = 3.0
const PATH_DASH: float = 6.0
const FAR_ROW_ALPHA: float = 0.32
const BEATEN_TINT: Color = Color(0.55, 0.55, 0.55)

@export var way: Way = Way.CAPTURE:
	set(value):
		way = value
		queue_redraw()

var _adapted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if way == Way.CAPTURE:
		_draw_capture()
	else:
		_draw_crossing()


## Draws the green Army blue instead.
func set_adapted(adapted: bool) -> void:
	_adapted = adapted
	queue_redraw()


## A Knight below the enemy Princess, who lies beaten under a red slash.
func _draw_capture() -> void:
	var origin: Vector2 = _grid_origin(Vector2i(3, 2))
	_draw_cells(origin, Vector2i(3, 2))
	var princess: Rect2 = _piece_rect(origin, Vector2i(1, 0))
	var enemy: Texture2D = PieceArt.token(PieceType.Id.PRINCESS, Side.Id.GREEN, _adapted)
	draw_texture_rect(enemy, princess, false, BEATEN_TINT)
	var half: Vector2 = Vector2.from_angle(deg_to_rad(SLASH_DEGREES)) * princess.size.x * 0.5
	var centre: Vector2 = princess.get_center()
	draw_line(centre - half, centre + half, UiTokens.RED_400, SLASH_WIDTH, true)
	var knight: Rect2 = _piece_rect(origin, Vector2i(1, 1))
	draw_texture_rect(PieceArt.token(PieceType.Id.KNIGHT, Side.Id.RED), knight, false)


## The player's Princess on the far row, gold, with the dashed path she took.
func _draw_crossing() -> void:
	var cells: Vector2i = Vector2i(3, 3)
	var origin: Vector2 = _grid_origin(cells)
	_draw_cells(origin, cells)
	draw_rect(Rect2(origin, Vector2(cells.x * CELL, CELL)), Color(UiTokens.SELECT_RING, FAR_ROW_ALPHA))
	var start: Rect2 = _cell_rect(origin, Vector2i(1, 2))
	var end: Rect2 = _cell_rect(origin, Vector2i(1, 0))
	var path: Color = Color(UiTokens.GOLD_TEXT, 0.85)
	BoardShapes.draw_dashed_rect(self, start.grow(-PIECE_INSET), path, PATH_WIDTH, PATH_DASH)
	draw_dashed_line(start.get_center(), end.get_center(), path, PATH_WIDTH, PATH_DASH)
	var princess: Texture2D = PieceArt.token(PieceType.Id.PRINCESS, Side.Id.RED)
	draw_texture_rect(princess, _piece_rect(origin, Vector2i(1, 0)), false)


func _grid_origin(cells: Vector2i) -> Vector2:
	return (size - Vector2(cells) * CELL) / 2.0


func _draw_cells(origin: Vector2, cells: Vector2i) -> void:
	for column: int in cells.x:
		for row: int in cells.y:
			var light: bool = (column + row) % 2 == 0
			var colour: Color = UiTokens.CELL_LIGHT if light else UiTokens.CELL_DARK
			draw_rect(_cell_rect(origin, Vector2i(column, row)), colour)


func _cell_rect(origin: Vector2, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * CELL, Vector2.ONE * CELL)


func _piece_rect(origin: Vector2, cell: Vector2i) -> Rect2:
	return _cell_rect(origin, cell).grow(-PIECE_INSET)
