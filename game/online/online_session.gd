class_name OnlineSession
extends RefCounted
## This Guest's side of one online game. The referee holds the real game; the
## session only keeps what this Guest may know, arranges their Setup before
## sending it, checks a Move is legal before asking the referee to play it,
## and knows whether the Opponent is connected. Poll it once per frame.

signal changed
## The referee refused a request, for example "illegal_move".
signal refused(reason: String)

enum Phase {
	CONNECTING,
	ARRANGING,
	WAITING_FOR_OPPONENT_SETUP,
	PLAYING,
	OVER,
	DISCONNECTED,
}

var _socket: WireSocket
var _seat: PairedSeat
var _rng: RandomNumberGenerator
var _server_url: String = ""
var _phase: Phase = Phase.CONNECTING
var _setup: Setup = null
var _position: KnownPosition = null
var _history: Array[PublicMoveEvent] = []
var _final_board: Board = null
var _awaiting_answer: bool = false
var _opponent_connected: bool = true
var _disconnection_reason: String = ""


func _init(socket: WireSocket, seat: PairedSeat, rng: RandomNumberGenerator) -> void:
	_socket = socket
	_seat = seat
	_rng = rng


## Connects to the game's referee and takes the seat. Called again after a
## disconnection, it takes the seat back and resumes the game.
func connect_to(server_url: String) -> void:
	_server_url = server_url
	_phase = Phase.CONNECTING
	_awaiting_answer = false
	_opponent_connected = true
	_socket.open("%s/games/%s" % [server_url, _seat.game_id])
	_socket.send_text(OnlineRequests.take_seat(_seat.seat_token))
	changed.emit()


func reconnect() -> void:
	connect_to(_server_url)


func leave() -> void:
	_socket.close()


func poll() -> void:
	for text: String in _socket.poll():
		_handle(OnlineReplies.referee(text))
	var lost: bool = _socket.state() == WireSocket.State.CLOSED
	if lost and _phase != Phase.DISCONNECTED and _phase != Phase.OVER:
		_phase = Phase.DISCONNECTED
		_disconnection_reason = _socket.close_reason()
		changed.emit()


func phase() -> Phase:
	return _phase


## Why the referee closed the connection, for example "seat_taken_elsewhere",
## or an empty String when the connection simply dropped.
func disconnection_reason() -> String:
	return _disconnection_reason if _phase == Phase.DISCONNECTED else ""


func side() -> Side.Id:
	return _seat.side


func opponent() -> String:
	return _seat.opponent


## False from when the referee says the Opponent lost their connection until
## they take their seat again.
func is_opponent_connected() -> bool:
	return _opponent_connected


## This Guest's Setup while they arrange it, or null.
func setup() -> Setup:
	return _setup


## The game as this Guest knows it, once play has started; null before.
func position() -> KnownPosition:
	return _position


## True while a Move or a Setup waits for the referee's answer.
func is_awaiting_answer() -> bool:
	return _awaiting_answer


func is_own_turn() -> bool:
	return _phase == Phase.PLAYING and not _awaiting_answer and _position.is_viewers_turn()


func shuffle_setup() -> void:
	if _phase == Phase.ARRANGING:
		_setup.shuffle(_rng)
		changed.emit()


func swap_in_setup(first: Vector2i, second: Vector2i) -> bool:
	if _phase != Phase.ARRANGING or not _setup.is_setup_square(first) or not _setup.is_setup_square(second):
		return false
	_setup.swap(first, second)
	changed.emit()
	return true


func confirm_setup() -> void:
	if _phase != Phase.ARRANGING or _awaiting_answer:
		return
	_awaiting_answer = true
	_socket.send_text(OnlineRequests.setup(_setup))
	changed.emit()


## Asks the referee to play [param move]. False, and nothing sent, when it is
## not this Guest's turn or the Move is not legal.
func play(move: Move) -> bool:
	if not is_own_turn() or not _position.legal_destinations(move.from).has(move.to):
		return false
	_awaiting_answer = true
	_socket.send_text(OnlineRequests.move(move))
	changed.emit()
	return true


## Asks the referee to end the game with Victory to the Opponent. False, and
## nothing sent, unless the game is being played and no answer is awaited.
func resign() -> bool:
	if _phase != Phase.PLAYING or _awaiting_answer:
		return false
	_awaiting_answer = true
	_socket.send_text(OnlineRequests.resign())
	changed.emit()
	return true


func legal_destinations(from: Vector2i) -> Array[Vector2i]:
	if not is_own_turn():
		return []
	return _position.legal_destinations(from)


## What both players learned from every Move so far, oldest first.
func history() -> Array[PublicMoveEvent]:
	return _history.duplicate()


## The Move played last, or null before the first.
func last_event() -> PublicMoveEvent:
	return _history.back() if not _history.is_empty() else null


func graveyard(owner: Side.Id) -> Array[PieceType.Id]:
	var types: Array[PieceType.Id] = []
	for event: PublicMoveEvent in _history:
		var eliminated: Dictionary[Side.Id, PieceType.Id] = event.eliminated_types()
		if eliminated.has(owner):
			types.append(eliminated[owner])
	return types


## How the game ended, or null while it goes on.
func result() -> GameResult:
	if _phase != Phase.OVER:
		return null
	return _position.result


## The Board to draw: this Guest's own Setup before play, the known game
## during play and every Piece shown once it is over.
func display_board() -> Board:
	if _final_board != null:
		return _final_board
	if _position != null:
		return _position.board()
	var board: Board = Board.new()
	if _setup == null:
		return board
	var next_id: int = 0
	for square: Vector2i in _setup.squares():
		board.place(Piece.new(next_id, _setup.type_at(square), _seat.side), square)
		next_id += 1
	return board


func _handle(reply: RefereeReply) -> void:
	match reply.kind:
		RefereeReply.Kind.SEATED:
			_seat.opponent = reply.opponent
		RefereeReply.Kind.SETUP_STATUS:
			_show_setup_status(reply)
		RefereeReply.Kind.GAME_STATE:
			_history = reply.history.duplicate()
			_show_position(reply)
		RefereeReply.Kind.MOVED:
			_history.append(reply.event)
			_show_position(reply)
		RefereeReply.Kind.OPPONENT_PRESENCE:
			_opponent_connected = reply.opponent_connected
		RefereeReply.Kind.REFUSED:
			_awaiting_answer = false
			refused.emit(reply.refusal)
		_:
			return
	changed.emit()


func _show_setup_status(reply: RefereeReply) -> void:
	_awaiting_answer = false
	if reply.own_setup_done:
		_phase = Phase.WAITING_FOR_OPPONENT_SETUP
		return
	if _setup == null:
		_setup = Setup.random(_seat.side, _rng)
	_phase = Phase.ARRANGING


func _show_position(reply: RefereeReply) -> void:
	_awaiting_answer = false
	_position = reply.position
	_final_board = reply.final_board
	_phase = Phase.OVER if _position.result.is_over() else Phase.PLAYING
