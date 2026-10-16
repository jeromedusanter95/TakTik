class_name Board
extends RefCounted
## The 6 by 8 grid of Squares and the Pieces standing on them.
##
## Squares are Vector2i(column, row): column 0 is "a", row 0 is rank 1,
## Red's Home Row.

const COLUMNS: int = 6
const ROWS: int = 8
const OBSTACLES: Array[Vector2i] = [
	Vector2i(1, 3),
	Vector2i(1, 4),
	Vector2i(4, 3),
	Vector2i(4, 4),
]

var _pieces: Dictionary[Vector2i, Piece] = {}


static func is_inside(square: Vector2i) -> bool:
	return (
		square.x >= 0 and square.x < COLUMNS
		and square.y >= 0 and square.y < ROWS
	)


static func is_obstacle(square: Vector2i) -> bool:
	return OBSTACLES.has(square)


static func home_row(side: Side.Id) -> int:
	return 0 if side == Side.Id.RED else ROWS - 1


func piece_at(square: Vector2i) -> Piece:
	if not _pieces.has(square):
		return null
	return _pieces[square]


func has_piece(square: Vector2i) -> bool:
	return _pieces.has(square)


func squares_of(side: Side.Id) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for square: Vector2i in _pieces:
		if _pieces[square].side == side:
			squares.append(square)
	return squares


func place(piece: Piece, square: Vector2i) -> void:
	_pieces[square] = piece


func remove(square: Vector2i) -> void:
	_pieces.erase(square)


func relocate(from: Vector2i, to: Vector2i) -> void:
	var piece: Piece = piece_at(from)
	_pieces.erase(from)
	_pieces[to] = piece
