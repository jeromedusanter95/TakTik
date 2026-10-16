class_name BoardOrientation
extends RefCounted
## How the Board is turned for one viewer: their own Home Row is always at the
## bottom. Screen cells count columns from the left and rows from the top.


static func screen_cell_of(square: Vector2i, viewer: Side.Id) -> Vector2i:
	if viewer == Side.Id.RED:
		return Vector2i(square.x, Board.ROWS - 1 - square.y)
	return Vector2i(Board.COLUMNS - 1 - square.x, square.y)


## The Square drawn at [param screen_cell].
static func square_at(screen_cell: Vector2i, viewer: Side.Id) -> Vector2i:
	# Each flip is its own inverse, so it maps screen cells back to Squares.
	return screen_cell_of(screen_cell, viewer)


## The column letter written under [param screen_column], for example "a".
static func column_label(screen_column: int, viewer: Side.Id) -> String:
	var square: Vector2i = square_at(Vector2i(screen_column, 0), viewer)
	return BoardNotation.format_square(square).left(1)


## The rank number written beside [param screen_row], for example "8".
static func rank_label(screen_row: int, viewer: Side.Id) -> String:
	var square: Vector2i = square_at(Vector2i(0, screen_row), viewer)
	return BoardNotation.format_square(square).substr(1)
