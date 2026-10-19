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

## The Squares a Piece could step to from each Square, worked out once.
static var _steps: Dictionary[Vector2i, Array] = _all_steps()

var _pieces: Dictionary[Vector2i, Piece] = {}


static func is_inside(square: Vector2i) -> bool:
	return (
		square.x >= 0 and square.x < COLUMNS
		and square.y >= 0 and square.y < ROWS
	)


static func is_obstacle(square: Vector2i) -> bool:
	return OBSTACLES.has(square)


## The Squares one step forward, back, left or right of [param square] that
## are inside the Board and not Obstacles. Shared and read-only: move
## generation asks for it for every Piece of every searched position.
static func steps_from(square: Vector2i) -> Array:
	return _steps[square]


static func home_row(side: Side.Id) -> int:
	return 0 if side == Side.Id.RED else ROWS - 1


func duplicate_board() -> Board:
	var copy: Board = Board.new()
	copy._pieces = _pieces.duplicate()
	return copy


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


static func _all_steps() -> Dictionary[Vector2i, Array]:
	var steps: Dictionary[Vector2i, Array] = {}
	for column: int in COLUMNS:
		for row: int in ROWS:
			var square: Vector2i = Vector2i(column, row)
			var targets: Array[Vector2i] = []
			for direction: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var target: Vector2i = square + direction
				if is_inside(target) and not is_obstacle(target):
					targets.append(target)
			steps[square] = targets
	return steps
