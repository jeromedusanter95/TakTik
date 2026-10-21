class_name HeuristicEvaluator
extends PositionEvaluator
## Scores a position by material, by how far each Princess has advanced and by
## how many enemy Pieces stand next to her ready to Attack.

const PIECE_VALUES: Dictionary[PieceType.Id, int] = {
	PieceType.Id.KING: 60,
	PieceType.Id.EXECUTIONER: 45,
	PieceType.Id.KNIGHT: 35,
	PieceType.Id.SOLDIER: 25,
	PieceType.Id.MAGICIAN: 30,
	PieceType.Id.BUFFOON: 15,
	PieceType.Id.MONSTER: 25,
	PieceType.Id.THIEF: 40,
	PieceType.Id.PRINCESS: 0,
}
const PRINCESS_ADVANCE_VALUE: int = 4
const PRINCESS_THREAT_PENALTY: int = 20
const ADVANCE_VALUE: int = 1


## Walks the Board once, without a call per Piece: the search evaluates
## thousands of positions a turn, and each GDScript call is costly there.
func evaluate(game: Game, side: Side.Id) -> int:
	var board: Board = game.board()
	var pieces: Dictionary[Vector2i, Piece] = board.pieces()
	var score: int = 0
	for square: Vector2i in pieces:
		var piece: Piece = pieces[square]
		var owner: Side.Id = piece.side
		var type: PieceType.Id = piece.type
		var value: int = PIECE_VALUES[type]
		var advance: int = absi(square.y - Board.home_row(owner))
		if type == PieceType.Id.PRINCESS:
			value += advance * PRINCESS_ADVANCE_VALUE
			value -= _attackers_next_to(board, square, owner) * PRINCESS_THREAT_PENALTY
		elif type != PieceType.Id.MONSTER:
			value += advance * ADVANCE_VALUE
		score += value if owner == side else -value
	return score


static func _attackers_next_to(board: Board, square: Vector2i, side: Side.Id) -> int:
	var count: int = 0
	for direction: Vector2i in MovementRule.DIRECTIONS:
		var neighbour: Piece = board.piece_at(square + direction)
		if neighbour != null and neighbour.side != side and _can_attack(neighbour.type):
			count += 1
	return count


static func _can_attack(type: PieceType.Id) -> bool:
	return type != PieceType.Id.MONSTER and type != PieceType.Id.PRINCESS
