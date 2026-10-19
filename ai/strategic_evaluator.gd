class_name StrategicEvaluator
extends PositionEvaluator
## Adds a style's positional preferences to the underlying evaluation.

var _base: PositionEvaluator
var _priorities: PositionPriorities
var _side: Side.Id


func _init(base: PositionEvaluator, priorities: PositionPriorities, side: Side.Id) -> void:
	_base = base
	_priorities = priorities
	_side = side


func evaluate(game: Game, side: Side.Id) -> int:
	var bonus: int = _own_bonus(game.board())
	return _base.evaluate(game, side) + (bonus if side == _side else -bonus)


func _own_bonus(board: Board) -> int:
	var score: int = 0
	for square: Vector2i in board.squares_of(_side):
		var type: PieceType.Id = board.piece_at(square).type
		var advance: int = absi(square.y - Board.home_row(_side))
		if type == PieceType.Id.PRINCESS:
			score += _princess_guards(board, square) * _priorities.princess_guard_bonus
			score -= advance * _priorities.princess_advance_penalty
		elif type != PieceType.Id.MONSTER:
			score += advance * _priorities.advancement_bonus
			if type == PieceType.Id.KING:
				score += advance * _priorities.king_activity_bonus
	return score


func _princess_guards(board: Board, princess: Vector2i) -> int:
	var count: int = 0
	for square: Vector2i in Board.steps_from(princess):
		var piece: Piece = board.piece_at(square)
		if piece != null and piece.side == _side:
			count += 1
	return count
