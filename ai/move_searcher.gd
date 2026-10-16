class_name MoveSearcher
extends RefCounted
## Looks a fixed number of Moves ahead in one fully known Game (negamax with
## alpha-beta pruning) and scores each of the side to move's Moves.

## The score of a won game, minus one per Move it takes, so faster wins
## score higher and slower losses score less badly.
const WIN_SCORE: int = 10_000
const INFINITY: int = 1_000_000

var _evaluator: PositionEvaluator
var _depth: int
var _nodes_searched: int = 0


## [param depth] counts Moves of both sides; 1 looks only at the Bot's own
## Move.
func _init(evaluator: PositionEvaluator, depth: int) -> void:
	_evaluator = evaluator
	_depth = maxi(depth, 1)


## How many positions this searcher has looked at so far, a measure of work
## that does not depend on the machine.
func nodes_searched() -> int:
	return _nodes_searched


## The score of [param move] in [param game] for the side to move. The score
## is exact, so scores from different sampled worlds can be added up.
func score_move(game: Game, move: Move) -> int:
	var child: Game = game.duplicate_game()
	child.try_play(move)
	return -_negamax(child, _depth - 1, -INFINITY, INFINITY, 1)


## [method score_move] for each of [param moves], in the same order.
func score_moves(game: Game, moves: Array[Move]) -> Array[int]:
	var scores: Array[int] = []
	for move: Move in moves:
		scores.append(score_move(game, move))
	return scores


func _negamax(game: Game, depth: int, alpha: int, beta: int, ply: int) -> int:
	_nodes_searched += 1
	if game.result().is_over():
		return _finished_score(game, ply)
	if depth == 0:
		return _evaluator.evaluate(game, game.side_to_move())
	var best: int = -INFINITY
	for move: Move in _attacks_first(game):
		var child: Game = game.duplicate_game()
		child.try_play(move)
		var score: int = -_negamax(child, depth - 1, -beta, -alpha, ply + 1)
		best = maxi(best, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			break
	return best


## Scored for the side to move in the finished [param game].
static func _finished_score(game: Game, ply: int) -> int:
	var status: GameResult.Status = game.result().status
	if status == GameResult.Status.DRAW:
		return 0
	var red_won: bool = status == GameResult.Status.RED_WINS
	var mover_won: bool = red_won == (game.side_to_move() == Side.Id.RED)
	return WIN_SCORE - ply if mover_won else ply - WIN_SCORE


## Attacks are tried first: they change the score most, so alpha-beta
## prunes more.
static func _attacks_first(game: Game) -> Array[Move]:
	var attacks: Array[Move] = []
	var quiet: Array[Move] = []
	for move: Move in game.legal_moves():
		if game.board().has_piece(move.to):
			attacks.append(move)
		else:
			quiet.append(move)
	attacks.append_array(quiet)
	return attacks
