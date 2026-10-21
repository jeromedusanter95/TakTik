class_name ThreatEvaluator
extends PositionEvaluator
## Adds to the underlying evaluation the Attack the side not to move is
## threatening. The search already follows the side to move's own Attacks
## past its horizon, but stops before the opponent can answer, so a Piece
## left hanging there looked safe. Only part of the threat counts: the side
## to move may still save that Piece.

var _base: PositionEvaluator
var _percent: int


## [param percent] is the share of the best threatened gain that counts.
func _init(base: PositionEvaluator, percent: int) -> void:
	_base = base
	_percent = percent


func evaluate(game: Game, side: Side.Id) -> int:
	var mover: Side.Id = game.side_to_move()
	var threat: int = best_attack_gain(game.board(), Side.opponent(mover)) * _percent / 100
	return _base.evaluate(game, side) + (-threat if side == mover else threat)


## The most material [param attacker_side] wins with one step Attack, counting
## a trade as the difference in value; 0 when no Attack wins anything.
static func best_attack_gain(board: Board, attacker_side: Side.Id) -> int:
	var best: int = 0
	for square: Vector2i in board.squares_of(attacker_side):
		var attacker: PieceType.Id = board.piece_at(square).type
		if attacker == PieceType.Id.MONSTER or attacker == PieceType.Id.PRINCESS:
			continue
		for target: Vector2i in Board.steps_from(square):
			var defender: Piece = board.piece_at(target)
			if defender != null and defender.side != attacker_side:
				best = maxi(best, attack_gain(attacker, defender.type))
	return best


## What an Attack by [param attacker] on [param defender] wins in material:
## negative when the attacker loses.
static func attack_gain(attacker: PieceType.Id, defender: PieceType.Id) -> int:
	var values: Dictionary[PieceType.Id, int] = HeuristicEvaluator.PIECE_VALUES
	match FightOutcome.resolve(attacker, defender):
		FightOutcome.Id.ATTACKER_WINS:
			return values[defender]
		FightOutcome.Id.BOTH_ELIMINATED:
			return values[defender] - values[attacker]
	return -values[attacker]
