class_name HotSeatSession
extends RefCounted
## Two players sharing one device: Red then Green arrange their Setups, then
## they take turns. Knows whose eyes the Board must be shown to.

enum Phase {
	SETUP,
	PLAYING,
	OVER,
}

var _rng: RandomNumberGenerator
var _phase: Phase = Phase.SETUP
var _setups: Dictionary[Side.Id, Setup] = {}
var _setup_side: Side.Id = Side.Id.RED
var _game: Game = null
var _last_record: MoveRecord = null
var _graveyards: Dictionary[Side.Id, Array] = {
	Side.Id.RED: [] as Array[PieceType.Id],
	Side.Id.GREEN: [] as Array[PieceType.Id],
}


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_setups[Side.Id.RED] = Setup.random(Side.Id.RED, _rng)


func phase() -> Phase:
	return _phase


## The side holding the device: the one setting up, or the one to move.
func active_side() -> Side.Id:
	if _phase == Phase.SETUP:
		return _setup_side
	return _game.side_to_move()


func active_setup() -> Setup:
	return _setups[_setup_side]


func shuffle_active_setup() -> void:
	active_setup().shuffle(_rng)


func swap_in_active_setup(first: Vector2i, second: Vector2i) -> bool:
	var setup: Setup = active_setup()
	if _phase != Phase.SETUP or not setup.is_setup_square(first) or not setup.is_setup_square(second):
		return false
	setup.swap(first, second)
	return true


func confirm_setup() -> void:
	if _phase != Phase.SETUP:
		return
	if _setup_side == Side.Id.RED:
		_setup_side = Side.Id.GREEN
		_setups[Side.Id.GREEN] = Setup.random(Side.Id.GREEN, _rng)
		return
	_game = GameFactory.from_setups(_setups[Side.Id.RED], _setups[Side.Id.GREEN])
	_phase = Phase.PLAYING


## The game being played, or null during Setup.
func game() -> Game:
	return _game


## Plays [param move] for the side to move. Returns null when it is illegal.
func play(move: Move) -> MoveRecord:
	if _phase != Phase.PLAYING:
		return null
	var record: MoveRecord = _game.try_play(move)
	if record == null:
		return null
	_last_record = record
	if record.fight != null:
		for piece: Piece in record.fight.eliminated():
			_graveyards[piece.side].append(piece.type)
	if _game.result().is_over():
		_phase = Phase.OVER
	return record


## The Move played last, or null before the first Move.
func last_record() -> MoveRecord:
	return _last_record


func graveyard(side: Side.Id) -> Array[PieceType.Id]:
	var types: Array[PieceType.Id] = []
	for type: PieceType.Id in _graveyards[side]:
		types.append(type)
	return types


## The Board to draw: during Setup, the Setups arranged so far; afterwards,
## the game's Board.
func display_board() -> Board:
	if _game != null:
		return _game.board()
	var board: Board = Board.new()
	var next_id: int = 0
	for side: Side.Id in _setups:
		var setup: Setup = _setups[side]
		for square: Vector2i in setup.squares():
			board.place(Piece.new(next_id, setup.type_at(square), side), square)
			next_id += 1
	return board
