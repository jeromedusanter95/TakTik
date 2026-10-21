class_name MoveSearcher
extends RefCounted
## Looks a fixed number of Moves ahead in one fully known Game (negamax with
## alpha-beta pruning) and scores each of the side to move's Moves. Past that
## horizon it can keep following Attacks and immediate Princess wins, so an
## exchange is not cut off halfway and a quiet winning Move is not overlooked.
##
## The search keeps its own stack of positions (MoveSearch) instead of
## recursing, so it can stop after any position and resume later: one deep
## root Move never has to be searched in a single frame.

## The score of a won game, minus one per Move it takes, so faster wins
## score higher and slower losses score less badly.
const WIN_SCORE: int = 10_000
const INFINITY: int = 1_000_000
const NO_NODE_LIMIT: int = 9_223_372_036_854_775_807

var _evaluator: PositionEvaluator
var _depth: int
var _attack_depth: int
var _nodes_searched: int = 0
## The last Move that cut the search short at each ply, tried first at that
## ply next time: it often refutes the neighbouring positions too.
var _killers: Dictionary[int, Move] = {}


## [param depth] counts Moves of both sides; 1 looks only at the Bot's own
## Move. [param attack_depth] is how many tactical Moves are still followed
## after that, including immediate Princess wins; 0 stops at the horizon.
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
	var search: MoveSearch = begin_move(game, move)
	advance(search, NO_NODE_LIMIT)
	return search.score()


## [method score_move] for each of [param moves], in the same order.
func score_moves(game: Game, moves: Array[Move]) -> Array[int]:
	var scores: Array[int] = []
	for move: Move in moves:
		scores.append(score_move(game, move))
	return scores


## Starts scoring [param move] in [param game] like [method score_move], but
## leaves the work to [method advance], so it can be spread over frames.
func begin_move(game: Game, move: Move) -> MoveSearch:
	var search: MoveSearch = MoveSearch.new()
	_enter(search, _game_after(game, move), false, _depth - 1, -INFINITY, INFINITY, 1)
	return search


## Searches [param search] until it is done or [method nodes_searched]
## reaches [param node_limit]; it never searches a position past that limit.
## The finished score is the same however the work was sliced.
func advance(search: MoveSearch, node_limit: int) -> void:
	while not search.is_done():
		var frame: SearchFrame = search.top()
		if frame.is_exhausted():
			search.pop()
			_answer(search, frame.best)
		elif _nodes_searched >= node_limit:
			return
		else:
			var move: Move = frame.moves[frame.next]
			frame.next += 1
			_enter(
				search, _game_after(frame.game, move), frame.is_tactical, frame.depth - 1,
				-frame.beta, -frame.alpha, frame.ply + 1,
			)


## Counts [param game] as searched and either scores it at once or pushes it
## as a new frame of [param search]. Past the horizon ([param depth] 0 when
## not [param tactical]) the side to move may stop at the static score or
## play an Attack or an immediate Princess win, up to [member _attack_depth]
## tactical Moves deep.
func _enter(
		search: MoveSearch,
		game: Game,
		tactical: bool,
		depth: int,
		alpha: int,
		beta: int,
		ply: int,
) -> void:
	_nodes_searched += 1
	if game.result().is_over():
		_answer(search, _finished_score(game, ply))
	elif tactical:
		_enter_tactics(search, game, depth, alpha, beta, ply)
	elif depth == 0:
		_enter_tactics(search, game, _attack_depth, alpha, beta, ply)
	else:
		search.push(SearchFrame.new(
			game, false, depth, alpha, beta, ply, _ordered_moves(game, ply), -INFINITY
		))


func _enter_tactics(
		search: MoveSearch,
		game: Game,
		tactics_left: int,
		alpha: int,
		beta: int,
		ply: int,
) -> void:
	var standing: int = _evaluator.evaluate(game, game.side_to_move())
	if tactics_left == 0 or standing >= beta:
		_answer(search, standing)
		return
	search.push(SearchFrame.new(
		game, true, tactics_left, maxi(alpha, standing), beta, ply, _tactical_moves(game), standing
	))


## Hands [param score], for the side to move in the position just searched,
## to the frame that played into it, or ends [param search] at the root.
func _answer(search: MoveSearch, score: int) -> void:
	if not search.has_frames():
		search.finish(-score)
		return
	var parent: SearchFrame = search.top()
	var move: Move = parent.current_move()
	if parent.take_score(-score) and not parent.is_tactical:
		_killers[parent.ply] = move


static func _game_after(game: Game, move: Move) -> Game:
	var child: Game = game.duplicate_game()
	child.play_legal(move)
	return child


## Scored for the side to move in the finished [param game].
static func _finished_score(game: Game, ply: int) -> int:
	var status: GameResult.Status = game.result().status
	if status == GameResult.Status.DRAW:
		return 0
	var red_won: bool = status == GameResult.Status.RED_WINS
	var mover_won: bool = red_won == (game.side_to_move() == Side.Id.RED)
	return WIN_SCORE - ply if mover_won else ply - WIN_SCORE


## The killer Move of [param ply] first, then Attacks that win material,
## best first, then quiet Moves, then Attacks that lose: trying the strongest
## Moves first lets alpha-beta prune more.
func _ordered_moves(game: Game, ply: int) -> Array[Move]:
	var killer: Move = _killers.get(ply)
	var board: Board = game.board()
	var first: Array[Move] = []
	var winning: Array[Move] = []
	var gains: Dictionary[Move, int] = {}
	var quiet: Array[Move] = []
	var losing: Array[Move] = []
	for move: Move in game.legal_moves():
		if move.equals(killer):
			first.append(move)
		elif not board.has_piece(move.to):
			quiet.append(move)
		else:
			var gain: int = ThreatEvaluator.attack_gain(
				board.piece_at(move.from).type, board.piece_at(move.to).type
			)
			if gain >= 0:
				gains[move] = gain
				winning.append(move)
			else:
				losing.append(move)
	winning.sort_custom(func(a: Move, b: Move) -> bool: return gains[a] > gains[b])
	first.append_array(winning)
	first.append_array(quiet)
	first.append_array(losing)
	return first


static func _tactical_moves(game: Game) -> Array[Move]:
	var moves: Array[Move] = []
	var winning_row: int = Board.home_row(Side.opponent(game.side_to_move()))
	for move: Move in game.legal_moves():
		if game.board().has_piece(move.to):
			moves.append(move)
		elif (
			move.to.y == winning_row
			and game.board().piece_at(move.from).type == PieceType.Id.PRINCESS
		):
			moves.append(move)
	return moves
