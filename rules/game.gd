class_name Game
extends RefCounted
## One game being played: the Board, whose turn it is and how it ended.

## Asks [method _first_legal_moves] for every legal Move.
const _ALL_MOVES: int = -1

var _board: Board
var _side_to_move: Side.Id
var _plies_without_fight: int
var _last_move_by_side: Dictionary[Side.Id, Move] = {}
var _result: GameResult = GameResult.in_progress()
## The legal Moves of this position once computed, null until then. Bots ask
## for them many times per position, so they are worked out only once.
var _legal_moves: Variant = null


func _init(
		starting_board: Board,
		first_to_move: Side.Id = Side.Id.RED,
		plies_already_without_fight: int = 0,
		last_moves: Dictionary[Side.Id, Move] = {},
) -> void:
	_board = starting_board
	_side_to_move = first_to_move
	_plies_without_fight = plies_already_without_fight
	_last_move_by_side = last_moves.duplicate()


func board() -> Board:
	return _board


func side_to_move() -> Side.Id:
	return _side_to_move


func plies_without_fight() -> int:
	return _plies_without_fight


func result() -> GameResult:
	return _result


## The last Move [param side] played, or null before its first Move. Public:
## both players saw it.
func last_move_of(side: Side.Id) -> Move:
	if not _last_move_by_side.has(side):
		return null
	return _last_move_by_side[side]


## An independent copy, for exploring Moves without touching this game.
func duplicate_game() -> Game:
	var copy: Game = Game.new(
		_board.duplicate_board(), _side_to_move, _plies_without_fight, _last_move_by_side
	)
	copy._result = _result
	copy._legal_moves = _legal_moves
	return copy


func legal_destinations(from: Vector2i) -> Array[Vector2i]:
	var piece: Piece = _board.piece_at(from)
	if _result.is_over() or piece == null or piece.side != _side_to_move:
		return []
	var squares: Array[Vector2i] = MovementCatalog.rule_for(piece.type).destinations(
		from, _board, piece.side
	)
	var forbidden: Move = _move_back_forbidden_for(piece.side)
	if forbidden != null and forbidden.from == from:
		squares.erase(forbidden.to)
	return squares


## A new Array each call, so callers may change it freely.
func legal_moves() -> Array[Move]:
	if _legal_moves is not Array:
		_legal_moves = _first_legal_moves(_ALL_MOVES)
	var cached: Array[Move] = _legal_moves
	return cached.duplicate()


## Whether the side to move can play at all, which is cheaper to answer than
## listing every legal Move.
func has_legal_move() -> bool:
	if _legal_moves is Array:
		var cached: Array[Move] = _legal_moves
		return not cached.is_empty()
	return not _first_legal_moves(1).is_empty()


func is_legal(move: Move) -> bool:
	return legal_destinations(move.from).has(move.to)


## Plays [param move] and returns what happened, or null when the Move is not
## legal, in which case nothing changes.
func try_play(move: Move) -> MoveRecord:
	if not is_legal(move):
		return null
	return play_legal(move)


## Plays [param move], already known to be legal because it came from
## [method legal_moves], without checking it again: a Bot's search plays
## many thousands of Moves per turn.
func play_legal(move: Move) -> MoveRecord:
	var mover: Piece = _board.piece_at(move.from)
	var fight: Fight = _resolve_on_board(move)
	_plies_without_fight = 0 if fight != null else _plies_without_fight + 1
	_last_move_by_side[mover.side] = move
	_side_to_move = Side.opponent(_side_to_move)
	_legal_moves = null
	var record: MoveRecord = MoveRecord.new(move, mover, fight)
	_result = VictoryJudge.judge(self, record)
	return record


func _resolve_on_board(move: Move) -> Fight:
	var attacker: Piece = _board.piece_at(move.from)
	var defender: Piece = _board.piece_at(move.to)
	if defender == null:
		_board.relocate(move.from, move.to)
		return null
	var outcome: FightOutcome.Id = FightOutcome.resolve(attacker.type, defender.type)
	match outcome:
		FightOutcome.Id.ATTACKER_WINS:
			_board.remove(move.to)
			_board.relocate(move.from, move.to)
		FightOutcome.Id.DEFENDER_WINS:
			_board.remove(move.from)
		FightOutcome.Id.BOTH_ELIMINATED:
			_board.remove(move.from)
			_board.remove(move.to)
	return Fight.new(attacker, defender, outcome)


## Up to [param limit] legal Moves of the side to move.
func _first_legal_moves(limit: int) -> Array[Move]:
	var moves: Array[Move] = []
	if _result.is_over():
		return moves
	var forbidden: Move = _move_back_forbidden_for(_side_to_move)
	for from: Vector2i in _board.squares_of(_side_to_move):
		var type: PieceType.Id = _board.piece_at(from).type
		for to: Vector2i in MovementCatalog.rule_for(type).destinations(from, _board, _side_to_move):
			if forbidden == null or not (forbidden.from == from and forbidden.to == to):
				moves.append(Move.new(from, to))
				if moves.size() == limit:
					return moves
	return moves


## The Move Back that [param side] may not play this turn, written as the
## forbidden Move (from the Square the Piece reached, to the one it left).
func _move_back_forbidden_for(side: Side.Id) -> Move:
	if not _last_move_by_side.has(side):
		return null
	var last: Move = _last_move_by_side[side]
	return Move.new(last.to, last.from)
