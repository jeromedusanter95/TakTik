class_name OnlineSession
extends RefCounted
## This Guest's side of one online game. The referee holds the real game; the
## session only keeps what this Guest may know, arranges their Setup before
## sending it, checks a Move is legal before asking the referee to play it,
## knows whether the Opponent is connected and how long the Setup Timer still
## runs. Poll it once per frame.

signal changed
## The referee refused a request, for example "illegal_move".
signal refused(reason: String)
## A Quick Chat arrived, from either player, as one of QuickChat.MESSAGES.
signal quick_chat_received(sender: Side.Id, message: String)
## Both players asked for a Rematch: this Guest's seat in the new game.
signal rematch_ready(seat: PairedSeat)

enum Phase {
	CONNECTING,
	ARRANGING,
	WAITING_FOR_OPPONENT_SETUP,
	PLAYING,
	OVER,
	DISCONNECTED,
}

## What setup_seconds_left and turn_seconds_left return when their timer does
## not run, or when the referee did not say how long it runs.
const NO_TIMER: int = -1

var _socket: WireSocket
var _seat: PairedSeat
var _rng: RandomNumberGenerator
## Returns the milliseconds of a clock that never goes back, as an int.
var _ticks_msec: Callable
var _server_url: String = ""
var _phase: Phase = Phase.CONNECTING
var _setup: Setup = null
var _position: KnownPosition = null
var _history: Array[PublicMoveEvent] = []
var _final_board: Board = null
var _awaiting_answer: bool = false
var _opponent_connected: bool = true
var _disconnection_reason: String = ""
var _rematch_asked: bool = false
var _opponent_wants_rematch: bool = false
var _opponent_setup_done: bool = false
## When the Setup Timer runs out, on the _ticks_msec clock, or NO_TIMER.
var _setup_deadline_msec: int = NO_TIMER
## When the current turn runs out, on the _ticks_msec clock, or NO_TIMER.
var _turn_deadline_msec: int = NO_TIMER
var _setup_arranged_at_random: bool = false
## When an away Opponent loses by Forfeit, on the _ticks_msec clock, or
## NO_TIMER.
var _opponent_forfeit_deadline_msec: int = NO_TIMER


## [param ticks_msec] returns the milliseconds of a clock that never goes back,
## such as Time.get_ticks_msec.
func _init(
	socket: WireSocket, seat: PairedSeat, rng: RandomNumberGenerator, ticks_msec: Callable
) -> void:
	_socket = socket
	_seat = seat
	_rng = rng
	_ticks_msec = ticks_msec


## Connects to the game's referee and takes the seat. Called again after a
## disconnection, it takes the seat back and resumes the game.
func connect_to(server_url: String) -> void:
	_server_url = server_url
	_phase = Phase.CONNECTING
	_awaiting_answer = false
	_opponent_connected = true
	_socket.open("%s/games/%s" % [server_url, _seat.game_id])
	_socket.send_text(RefereeRequests.take_seat(_seat.seat_token))
	changed.emit()


func reconnect() -> void:
	connect_to(_server_url)


func leave() -> void:
	_socket.close()


func poll() -> void:
	for text: String in _socket.poll():
		_handle(RefereeReplies.read(text))
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


## Whole seconds, rounded up, until the Setup Timer runs out, as long as this
## Guest is in Setup; NO_TIMER otherwise.
func setup_seconds_left() -> int:
	var in_setup: bool = (
		_phase == Phase.ARRANGING or _phase == Phase.WAITING_FOR_OPPONENT_SETUP
	)
	return _seconds_until(_setup_deadline_msec) if in_setup else NO_TIMER


## Whole seconds, rounded up, until the player to move runs out the Turn
## Timer, as long as play goes on; NO_TIMER otherwise.
func turn_seconds_left() -> int:
	return _seconds_until(_turn_deadline_msec) if _phase == Phase.PLAYING else NO_TIMER


## True once play has started because the Setup Timer ran out before this
## Guest handed in their Setup, so the referee arranged their Army at random.
func was_setup_arranged_at_random() -> bool:
	return _setup_arranged_at_random


## Whole seconds, rounded up, until the away Opponent loses by Forfeit;
## NO_TIMER while they are connected or the referee did not say.
func opponent_forfeit_seconds_left() -> int:
	if _opponent_connected or _phase != Phase.PLAYING:
		return NO_TIMER
	return _seconds_until(_opponent_forfeit_deadline_msec)


## True once the referee said the Opponent handed in their Setup.
func is_opponent_setup_done() -> bool:
	return _opponent_setup_done


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
	_socket.send_text(RefereeRequests.setup(_setup))
	changed.emit()


## Asks the referee to play [param move]. False, and nothing sent, when it is
## not this Guest's turn or the Move is not legal.
func play(move: Move) -> bool:
	if not is_own_turn() or not _position.legal_destinations(move.from).has(move.to):
		return false
	_awaiting_answer = true
	_socket.send_text(RefereeRequests.move(move))
	changed.emit()
	return true


## Asks the referee to end the game with Victory to the Opponent. False, and
## nothing sent, unless the game is being played and no answer is awaited.
func resign() -> bool:
	if _phase != Phase.PLAYING or _awaiting_answer:
		return false
	_awaiting_answer = true
	_socket.send_text(RefereeRequests.resign())
	changed.emit()
	return true


## Sends one of QuickChat.MESSAGES to the game. It comes back to both players.
func send_quick_chat(message: String) -> void:
	if QuickChat.is_message(message):
		_socket.send_text(RefereeRequests.quick_chat(message))


## Asks for a Rematch once the game is over. False, and nothing sent, before.
func ask_for_rematch() -> bool:
	if _phase != Phase.OVER:
		return false
	_rematch_asked = true
	_socket.send_text(RefereeRequests.rematch())
	changed.emit()
	return true


func has_asked_for_rematch() -> bool:
	return _rematch_asked


func opponent_wants_rematch() -> bool:
	return _opponent_wants_rematch


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
			var forfeit_in: int = reply.forfeit_in_msec
			_opponent_forfeit_deadline_msec = _deadline_after(forfeit_in) if forfeit_in >= 0 else NO_TIMER
		RefereeReply.Kind.QUICK_CHAT:
			quick_chat_received.emit(reply.chat_side, reply.chat_message)
			return
		RefereeReply.Kind.REMATCH_OFFERED:
			_opponent_wants_rematch = true
		RefereeReply.Kind.REMATCH_READY:
			rematch_ready.emit(reply.rematch_seat)
			return
		RefereeReply.Kind.REFUSED:
			_awaiting_answer = false
			if reply.refusal == "rematch_unavailable":
				_rematch_asked = false
				_opponent_wants_rematch = false
			refused.emit(reply.refusal)
		_:
			return
	changed.emit()


## A status that says this Guest's Setup is not in yet can be the one sent
## when the Opponent finished, crossing this Guest's own Setup on its way:
## a Setup already sent then stays awaited, so it is never sent twice.
func _show_setup_status(reply: RefereeReply) -> void:
	var setup_on_its_way: bool = _phase == Phase.ARRANGING and _awaiting_answer
	_opponent_setup_done = reply.opponent_setup_done
	_setup_deadline_msec = _deadline_after(reply.setup_time_left_msec)
	if reply.own_setup_done:
		_awaiting_answer = false
		_phase = Phase.WAITING_FOR_OPPONENT_SETUP
		return
	_awaiting_answer = setup_on_its_way
	if _setup == null:
		_setup = Setup.random(_seat.side, _rng)
	_phase = Phase.ARRANGING


func _show_position(reply: RefereeReply) -> void:
	if _phase == Phase.ARRANGING and not _awaiting_answer:
		_setup_arranged_at_random = true
	_awaiting_answer = false
	_position = reply.position
	_final_board = reply.final_board
	_turn_deadline_msec = _deadline_after(reply.turn_time_left_msec)
	_phase = Phase.OVER if _position.result.is_over() else Phase.PLAYING


## When [param time_left_msec] from now falls, or NO_TIMER when it is NO_TIMER.
func _deadline_after(time_left_msec: int) -> int:
	if time_left_msec == RefereeReply.NO_TIMER:
		return NO_TIMER
	return _now_msec() + time_left_msec


func _seconds_until(deadline_msec: int) -> int:
	if deadline_msec == NO_TIMER:
		return NO_TIMER
	return ceili(maxi(0, deadline_msec - _now_msec()) / 1000.0)


func _now_msec() -> int:
	var now: Variant = _ticks_msec.call()
	if now is not int:
		push_error("ticks_msec must return an int")
		return 0
	return now
