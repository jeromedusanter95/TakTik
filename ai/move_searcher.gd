class_name MoveSearcher
extends RefCounted
## Looks a fixed number of Moves ahead in one fully known Game (negamax with
## alpha-beta pruning) and scores each of the side to move's Moves. Past that
## horizon it can keep following Attacks only, so a search never stops in the
## middle of an exchange and mistakes a capture that will be answered for a
## clean win.

## The score of a won game, minus one per Move it takes, so faster wins
## score higher and slower losses score less badly.
const WIN_SCORE: int = 10_000
const INFINITY: int = 1_000_000

var _evaluator: PositionEvaluator
var _depth: int
var _attack_depth: int
var _nodes_searched: int = 0
## The last Move that cut the search short at each ply, tried first at that
## ply next time: it often refutes the neighbouring positions too.
var _killers: Dictionary[int, Move] = {}


## [param depth] counts Moves of both sides; 1 looks only at the Bot's own
## Move. [param attack_depth] is how many Attacks in a row are still followed
## after that; 0 stops at the horizon.
func _init(evaluator: PositionEvaluator, depth: int, attack_depth: int = 0) -> void:
	_evaluator = evaluator
	_depth = maxi(depth, 1)
	_attack_depth = maxi(attack_depth, 0)


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
		return _follow_attacks(game, _attack_depth, alpha, beta, ply)
	var best: int = -INFINITY
	for move: Move in _ordered_moves(game, ply):
		var child: Game = game.duplicate_game()
		child.try_play(move)
		var score: int = -_negamax(child, depth - 1, -beta, -alpha, ply + 1)
		best = maxi(best, score)
		alpha = maxi(alpha, score)
		if alpha >= beta:
			_killers[ply] = move
			break
	return best


## The side to move may stop here (the static score) or play an Attack, which
## is searched the same way, up to [param attacks_left] Attacks deep.
func _follow_attacks(game: Game, attacks_left: int, alpha: int, beta: int, ply: int) -> int:
	var standing: int = _evaluator.evaluate(game, game.side_to_move())
	if attacks_left == 0 or standing >= beta:
		return standing
	var best: int = standing
	alpha = maxi(alpha, standing)
	for move: Move in _attacks(game):
		var child: Game = game.duplicate_game()
		child.try_play(move)
		_nodes_searched += 1
		var score: int = (
			-_finished_score(child, ply + 1) if child.result().is_over()
			else -_follow_attacks(child, attacks_left - 1, -beta, -alpha, ply + 1)
		)
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


## The killer Move of [param ply] first, then Attacks, which change the
## score most, so alpha-beta prunes more.
func _ordered_moves(game: Game, ply: int) -> Array[Move]:
	var killer: Move = _killers.get(ply)
	var first: Array[Move] = []
	var attacks: Array[Move] = []
	var quiet: Array[Move] = []
	for move: Move in game.legal_moves():
		if move.equals(killer):
			first.append(move)
		elif game.board().has_piece(move.to):
			attacks.append(move)
		else:
			quiet.append(move)
	first.append_array(attacks)
	first.append_array(quiet)
	return first


static func _attacks(game: Game) -> Array[Move]:
	var attacks: Array[Move] = []
	for move: Move in game.legal_moves():
		if game.board().has_piece(move.to):
			attacks.append(move)
	return attacks
