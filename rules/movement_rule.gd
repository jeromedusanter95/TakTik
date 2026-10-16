@abstract
class_name MovementRule
extends RefCounted
## How one Piece Type may travel across the Board.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]


## Every Square a Piece of [param side] standing on [param from] could reach,
## ignoring whose turn it is and the Move Back rule.
@abstract func destinations(from: Vector2i, board: Board, side: Side.Id) -> Array[Vector2i]


static func _is_walkable(square: Vector2i) -> bool:
	return Board.is_inside(square) and not Board.is_obstacle(square)


static func _holds_enemy(board: Board, square: Vector2i, side: Side.Id) -> bool:
	var piece: Piece = board.piece_at(square)
	return piece != null and piece.side != side
