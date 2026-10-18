extends SceneTree
## Plays a whole online game between two clients through a running server:
## both enter the Lobby, one Challenges the other, who accepts, then each plays
## random legal Moves. Not a GUT test (no test_ prefix).
##
## cd server && npm run dev   (in another terminal)
## Godot --headless --path . -s test/online/online_smoke.gd -- [server url] [max plies]

const DEFAULT_SERVER_URL: String = "ws://localhost:8787"
const DEFAULT_MAX_PLIES: int = 400
const TIMEOUT_MSEC: int = 120_000

var _server_url: String = DEFAULT_SERVER_URL
var _max_plies: int = DEFAULT_MAX_PLIES
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lobbies: Dictionary[String, LobbyClient] = {}
var _sessions: Array[OnlineSession] = []
var _started_msec: int = 0
var _challenge_sent: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_server_url = args[0]
	if args.size() >= 2:
		_max_plies = int(args[1])
	_rng.seed = 11
	_started_msec = Time.get_ticks_msec()
	for nickname: String in ["Ada", "Bob"]:
		var lobby: LobbyClient = LobbyClient.new(WebSocketWireSocket.new())
		lobby.paired.connect(_on_paired)
		lobby.failed.connect(_on_failed)
		lobby.enter(_server_url, nickname)
		_lobbies[nickname] = lobby


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started_msec > TIMEOUT_MSEC:
		return _finish(false, "timed out")
	for lobby: LobbyClient in _lobbies.values():
		lobby.poll()
	_challenge_through_the_lobby()
	for session: OnlineSession in _sessions:
		session.poll()
		_act(session)
	if _sessions.size() == 2 and _sessions.all(_is_done):
		return _check_ending()
	return false


## Ada Challenges Bob once she sees him; Bob accepts once challenged.
func _challenge_through_the_lobby() -> void:
	var ada: LobbyClient = _lobbies["Ada"]
	var bob: LobbyClient = _lobbies["Bob"]
	if ada.is_active() and not _challenge_sent and not ada.guests().is_empty():
		ada.challenge(ada.guests()[0].guest_id)
		_challenge_sent = true
	if bob.is_active() and not bob.challengers().is_empty():
		bob.answer_challenge(bob.challengers()[0].guest_id, true)


func _on_paired(seat: PairedSeat) -> void:
	print("Paired as %s against %s in game %s" % [WireNames.side_name(seat.side), seat.opponent, seat.game_id])
	var session: OnlineSession = OnlineSession.new(WebSocketWireSocket.new(), seat, _rng, Time.get_ticks_msec)
	session.refused.connect(func(reason: String) -> void: print("Refused: ", reason))
	session.connect_to(_server_url)
	_sessions.append(session)


func _on_failed(reason: String) -> void:
	_finish(false, "the Lobby failed: " + reason)


func _act(session: OnlineSession) -> void:
	if session.phase() == OnlineSession.Phase.ARRANGING and not session.is_awaiting_answer():
		session.confirm_setup()
	elif session.is_own_turn() and session.history().size() < _max_plies:
		var moves: Array[Move] = _legal_moves(session)
		if not moves.is_empty():
			session.play(moves[_rng.randi_range(0, moves.size() - 1)])


func _legal_moves(session: OnlineSession) -> Array[Move]:
	var moves: Array[Move] = []
	var board: Board = session.display_board()
	for from: Vector2i in board.squares_of(session.side()):
		for to: Vector2i in session.legal_destinations(from):
			moves.append(Move.new(from, to))
	return moves


func _is_done(session: OnlineSession) -> bool:
	var at_limit: bool = session.history().size() >= _max_plies and not session.is_awaiting_answer()
	return session.phase() == OnlineSession.Phase.OVER or (session.phase() == OnlineSession.Phase.PLAYING and at_limit)


func _check_ending() -> bool:
	var first: OnlineSession = _sessions[0]
	var second: OnlineSession = _sessions[1]
	if first.history().size() != second.history().size():
		return _finish(false, "the two clients saw different histories")
	if first.phase() != second.phase():
		return _finish(false, "the two clients disagree on whether the game is over")
	if first.phase() == OnlineSession.Phase.OVER:
		if first.result().status != second.result().status:
			return _finish(false, "the two clients saw different results")
		var red_left: int = first.display_board().squares_of(Side.Id.RED).size()
		var green_left: int = first.display_board().squares_of(Side.Id.GREEN).size()
		print("Game over after %d plies: %s (pieces left %d red, %d green)" % [
			first.history().size(), GameResult.Status.find_key(first.result().status), red_left, green_left,
		])
	else:
		print("Stopped after %d plies with the game still going" % first.history().size())
	return _finish(true, "both clients agree")


func _finish(passed: bool, message: String) -> bool:
	print(("PASS: " if passed else "FAIL: ") + message)
	for session: OnlineSession in _sessions:
		session.leave()
	quit(0 if passed else 1)
	return true
