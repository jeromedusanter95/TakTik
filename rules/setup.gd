class_name Setup
extends RefCounted
## One player's arrangement of their Army on their side of the Board, before
## play starts.

const SETUP_ROW_COUNT: int = 3

var side: Side.Id:
	get:
		return _side

var _side: Side.Id
var _placements: Dictionary[Vector2i, PieceType.Id] = {}


func _init(owner: Side.Id) -> void:
	_side = owner


## A Random Setup: the whole Army shuffled across the setup Squares.
static func random(owner: Side.Id, rng: RandomNumberGenerator) -> Setup:
	var setup: Setup = Setup.new(owner)
	setup.shuffle(rng)
	return setup


## The rows a side places its Army on: its Home Row and the two in front.
static func rows_for(owner: Side.Id) -> Array[int]:
	if owner == Side.Id.RED:
		return [0, 1, 2]
	return [Board.ROWS - 3, Board.ROWS - 2, Board.ROWS - 1]


static func squares_for(owner: Side.Id) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for row: int in rows_for(owner):
		for column: int in Board.COLUMNS:
			squares.append(Vector2i(column, row))
	return squares


func is_setup_square(square: Vector2i) -> bool:
	return square.y in rows_for(_side) and square.x >= 0 and square.x < Board.COLUMNS


func place(square: Vector2i, type: PieceType.Id) -> void:
	_placements[square] = type


func has_piece(square: Vector2i) -> bool:
	return _placements.has(square)


func type_at(square: Vector2i) -> PieceType.Id:
	return _placements[square]


func squares() -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	for square: Vector2i in _placements:
		placed.append(square)
	return placed


func swap(first: Vector2i, second: Vector2i) -> void:
	var first_type: PieceType.Id = _placements[first]
	_placements[first] = _placements[second]
	_placements[second] = first_type


func shuffle(rng: RandomNumberGenerator) -> void:
	var types: Array[PieceType.Id] = PieceType.army()
	var squares_left: Array[Vector2i] = squares_for(_side)
	_placements.clear()
	for type: PieceType.Id in types:
		var index: int = rng.randi_range(0, squares_left.size() - 1)
		_placements[squares_left[index]] = type
		squares_left.remove_at(index)


## True when every setup Square holds a Piece and the Pieces are exactly the
## Army.
func is_valid() -> bool:
	for square: Vector2i in _placements:
		if not is_setup_square(square):
			return false
	if _placements.size() != squares_for(_side).size():
		return false
	var placed_types: Array[PieceType.Id] = []
	for square: Vector2i in _placements:
		placed_types.append(_placements[square])
	for type: PieceType.Id in PieceType.Id.values():
		if placed_types.count(type) != PieceType.army_count(type):
			return false
	return true
