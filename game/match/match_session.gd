class_name MatchSession
extends RefCounted
## One game played on this device, where each side is played by a person or
## by a Bot. People arrange their own Setups, Red first; Bots get a Random
## Setup. Every Bot receives only what its side may know: a PlayerView when
## play starts and a PublicMoveEvent after every Move.

enum Phase {
	SETUP,
	PLAYING,
	OVER,
}

const _SIDES: Array[Side.Id] = [Side.Id.RED, Side.Id.GREEN]

var _rng: RandomNumberGenerator
var _bots: Dictionary[Side.Id, Bot] = {}
var _phase: Phase = Phase.SETUP
var _setups: Dictionary[Side.Id, Setup] = {}
var _setup_side: Side.Id = Side.Id.RED
var _game: Game = null
var _last_record: MoveRecord = null
var _last_records: Dictionary[Side.Id, MoveRecord] = {}
var _graveyards: Dictionary[Side.Id, Array] = {
	Side.Id.RED: [] as Array[PieceType.Id],
	Side.Id.GREEN: [] as Array[PieceType.Id],
}


## [param bots] holds the Bot playing each bot-controlled side; the other
## sides are played by people. Empty means two people share the device.
func _init(rng: RandomNumberGenerator, bots: Dictionary[Side.Id, Bot] = {}) -> void:
	_rng = rng
	for side: Side.Id in bots:
		var bot: Bot = bots[side]
		if bot.side() != side:
			push_error("A Bot was given for the side it does not play")
			continue
		_bots[side] = bot
		_setups[side] = bot.arrange_setup(_rng)
	_advance_setup()


func phase() -> Phase:
	return _phase


## The sides played by people, Red first.
func human_sides() -> Array[Side.Id]:
	var sides: Array[Side.Id] = []
	for side: Side.Id in _SIDES:
		if not _bots.has(side):
			sides.append(side)
	return sides


func is_bot(side: Side.Id) -> bool:
	return _bots.has(side)


## The side setting up, or the one to move.
func active_side() -> Side.Id:
	if _phase == Phase.SETUP:
		return _setup_side
	return _game.side_to_move()


func is_bot_turn() -> bool:
	return _phase == Phase.PLAYING and is_bot(_game.side_to_move())


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
	_advance_setup()


## The game being played, or null during Setup.
func game() -> Game:
	return _game


## Asks the Bot whose turn it is to choose a Move. Returns null when it is not
## a Bot's turn. Play the chosen Move with [method play].
func start_bot_thinking() -> BotThinking:
	if not is_bot_turn():
		return null
	var side: Side.Id = _game.side_to_move()
	return _bots[side].start_thinking(PlayerView.of(_game, side))


## Plays [param move] for the side to move. Returns null when it is illegal.
func play(move: Move) -> MoveRecord:
	if _phase != Phase.PLAYING:
		return null
	var record: MoveRecord = _game.try_play(move)
	if record == null:
		return null
	_last_record = record
	_last_records[record.mover.side] = record
	if record.fight != null:
		for piece: Piece in record.fight.eliminated():
			_graveyards[piece.side].append(piece.type)
	if _game.result().is_over():
		_phase = Phase.OVER
	_tell_bots(record)
	return record


## The Move played last, or null before the first Move.
func last_record() -> MoveRecord:
	return _last_record


## The Move [param side] played last, or null before its first Move.
func last_record_of(side: Side.Id) -> MoveRecord:
	if not _last_records.has(side):
		return null
	return _last_records[side]


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


## Hands Setup to the next person who has none yet, or starts play once every
## side has one.
func _advance_setup() -> void:
	for side: Side.Id in human_sides():
		if not _setups.has(side):
			_setup_side = side
			_setups[side] = Setup.random(side, _rng)
			return
	_start_play()


func _start_play() -> void:
	_game = GameFactory.from_setups(_setups[Side.Id.RED], _setups[Side.Id.GREEN])
	_phase = Phase.PLAYING
	for side: Side.Id in _bots:
		_bots[side].begin(PlayerView.of(_game, side))


func _tell_bots(record: MoveRecord) -> void:
	var event: PublicMoveEvent = PublicMoveEvent.of(record)
	for side: Side.Id in _bots:
		_bots[side].observe(event)
