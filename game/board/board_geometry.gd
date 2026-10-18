class_name BoardGeometry
extends RefCounted
## Where the Board sits inside a given area: the rank labels on the left, the
## frame, the Squares inside it and the column letters below, all centred,
## with Squares as large as fit up to a limit.

## The width of the rank labels, and the gap between them and the frame.
const RANK_LABEL_WIDTH: float = 16.0
const RANK_LABEL_GAP: float = 10.0
## The height of the column letters under the frame, gap included.
const FILE_LABEL_HEIGHT: float = 26.0
## The frame's padding around the Squares.
const FRAME_PADDING: float = 12.0
## How much smaller a Piece is than its Square.
const PIECE_INSET: float = 12.0

var cell: float = 0.0
## The top left corner of the Squares.
var origin: Vector2 = Vector2.ZERO
var viewer: Side.Id = Side.Id.RED


## Fits the Board in [param area], with Squares of at most [param max_cell]
## and at least [param min_cell].
func _init(area: Vector2, max_cell: float, min_cell: float, seen_by: Side.Id) -> void:
	viewer = seen_by
	var fit_width: float = (area.x - RANK_LABEL_WIDTH - RANK_LABEL_GAP - 2.0 * FRAME_PADDING) / Board.COLUMNS
	var fit_height: float = (area.y - FILE_LABEL_HEIGHT - 2.0 * FRAME_PADDING) / Board.ROWS
	cell = clampf(minf(fit_width, fit_height), min_cell, max_cell)
	var block: Vector2 = block_size()
	var corner: Vector2 = ((area - block) / 2.0).floor()
	origin = corner + Vector2(RANK_LABEL_WIDTH + RANK_LABEL_GAP + FRAME_PADDING, FRAME_PADDING)


## The size of everything drawn: labels, frame and Squares.
func block_size() -> Vector2:
	return Vector2(
		RANK_LABEL_WIDTH + RANK_LABEL_GAP + 2.0 * FRAME_PADDING + Board.COLUMNS * cell,
		2.0 * FRAME_PADDING + Board.ROWS * cell + FILE_LABEL_HEIGHT,
	)


## The Squares' area.
func squares_rect() -> Rect2:
	return Rect2(origin, Vector2(Board.COLUMNS, Board.ROWS) * cell)


func frame_rect() -> Rect2:
	return squares_rect().grow(FRAME_PADDING)


func rect_of(square: Vector2i) -> Rect2:
	var screen_cell: Vector2i = BoardOrientation.screen_cell_of(square, viewer)
	return Rect2(origin + Vector2(screen_cell) * cell, Vector2(cell, cell))


## Where a Piece on [param square] is drawn.
func piece_rect_of(square: Vector2i) -> Rect2:
	return rect_of(square).grow(-PIECE_INSET / 2.0)


## The Square under [param point], which may be off the Board.
func square_at(point: Vector2) -> Vector2i:
	var local: Vector2 = (point - origin) / cell
	return BoardOrientation.square_at(Vector2i(floori(local.x), floori(local.y)), viewer)


## The middle of the rank label beside [param screen_row].
func rank_label_center(screen_row: int) -> Vector2:
	var frame: Rect2 = frame_rect()
	return Vector2(frame.position.x - RANK_LABEL_GAP - RANK_LABEL_WIDTH / 2.0, origin.y + (screen_row + 0.5) * cell)


## The middle of the column letter under [param screen_column].
func file_label_center(screen_column: int) -> Vector2:
	var frame: Rect2 = frame_rect()
	return Vector2(origin.x + (screen_column + 0.5) * cell, frame.end.y + FILE_LABEL_HEIGHT / 2.0)
