extends GutTest
## One Guest's online game, driven by the referee's messages on a fake socket.

const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const SERVER_URL: String = "ws://referee.test"

var _socket: FakeWireSocket = null
var _session: OnlineSession = null


func before_each() -> void:
	_socket = FakeWireSocket.new()
	var seat: PairedSeat = PairedSeat.new()
	seat.game_id = "g1"
	seat.side = Side.Id.RED
	seat.seat_token = "t1"
	seat.opponent = "Bob"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	_session = OnlineSession.new(_socket, seat, rng)
	watch_signals(_session)
	_session.connect_to(SERVER_URL)


func test_it_takes_its_seat_on_the_games_socket() -> void:
	assert_eq(_socket.opened_url, "ws://referee.test/games/g1")
	assert_eq(_socket.last_sent(), {"type": "take_seat", "seatToken": "t1"})
	assert_eq(_session.phase(), OnlineSession.Phase.CONNECTING)


func test_it_arranges_a_random_setup_until_confirmed() -> void:
	_arranging()
	assert_eq(_session.phase(), OnlineSession.Phase.ARRANGING)
	assert_true(_session.setup().is_valid())
	assert_eq(_session.display_board().squares_of(Side.Id.RED).size(), 18)
	assert_eq(_session.display_board().squares_of(Side.Id.GREEN).size(), 0)


func test_swapping_two_setup_squares_changes_the_arrangement() -> void:
	_arranging()
	var first: Vector2i = Vector2i(0, 0)
	var second: Vector2i = Vector2i(5, 2)
	var first_type: PieceType.Id = _session.setup().type_at(first)
	assert_true(_session.swap_in_setup(first, second))
	assert_eq(_session.setup().type_at(second), first_type)
	assert_false(_session.swap_in_setup(first, Vector2i(0, 5)), "not a Square of Red's Setup")


func test_confirming_sends_the_whole_setup() -> void:
	_arranging()
	_session.confirm_setup()
	var message: Dictionary = _socket.last_sent()
	var placements: Array = message["placements"]
	assert_eq(placements.size(), 18)
	assert_true(_session.is_awaiting_answer())


func test_it_waits_once_the_referee_has_its_setup() -> void:
	_arranging()
	_session.confirm_setup()
	_socket.receive({"type": "setup_status", "ownSetupDone": true, "opponentSetupDone": false})
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP)
	assert_false(_session.is_awaiting_answer())


func test_play_starts_with_the_referees_game_state() -> void:
	_playing("red")
	assert_eq(_session.phase(), OnlineSession.Phase.PLAYING)
	assert_true(_session.is_own_turn())
	assert_eq(_session.display_board().piece_at(Vector2i(2, 3)).type, PieceType.Id.KNIGHT)


func test_a_legal_move_is_sent_and_waits_for_the_referee() -> void:
	_playing("red")
	assert_true(_session.play(Move.new(Vector2i(2, 3), Vector2i(2, 4))))
	assert_eq(_socket.last_sent(), {
		"type": "move",
		"move": {"from": {"column": 2.0, "row": 3.0}, "to": {"column": 2.0, "row": 4.0}},
	})
	assert_false(_session.is_own_turn(), "no second Move before the answer")


func test_an_illegal_move_is_never_sent() -> void:
	_playing("red")
	var sent_before: int = _socket.sent.size()
	assert_false(_session.play(Move.new(Vector2i(2, 3), Vector2i(2, 6))))
	assert_eq(_socket.sent.size(), sent_before)


func test_no_move_is_sent_on_the_opponents_turn() -> void:
	_playing("green")
	assert_false(_session.is_own_turn())
	assert_false(_session.play(Move.new(Vector2i(2, 3), Vector2i(2, 4))))


func test_each_move_joins_the_history_and_the_graveyard() -> void:
	_playing("red")
	_session.play(Move.new(Vector2i(2, 3), Vector2i(2, 4)))
	_socket.receive({
		"type": "moved",
		"event": {
			"moverSide": "red",
			"move": {"from": {"column": 2, "row": 3}, "to": {"column": 2, "row": 4}},
			"fight": {"attackerType": "knight", "defenderType": "soldier", "outcome": "attacker_wins"},
		},
		"view": _view("green", [{"square": {"column": 2, "row": 4}, "type": "knight"}], []),
	})
	_session.poll()
	assert_eq(_session.history().size(), 1)
	assert_eq(_session.last_event().defender_type, PieceType.Id.SOLDIER)
	assert_eq(_session.graveyard(Side.Id.GREEN), [PieceType.Id.SOLDIER] as Array[PieceType.Id])
	assert_eq(_session.graveyard(Side.Id.RED), [] as Array[PieceType.Id])
	assert_false(_session.is_own_turn())


func test_a_refusal_frees_the_guest_to_try_again() -> void:
	_playing("red")
	_session.play(Move.new(Vector2i(2, 3), Vector2i(2, 4)))
	_socket.receive({"type": "refused", "reason": "illegal_move"})
	_session.poll()
	assert_signal_emitted_with_parameters(_session, "refused", ["illegal_move"])
	assert_true(_session.is_own_turn())


func test_the_game_ends_with_every_piece_shown() -> void:
	_playing("red")
	var view: Dictionary = _view("green", [{"square": {"column": 2, "row": 4}, "type": "knight"}], [])
	view["result"] = {"status": "red_wins", "reason": "princess_captured"}
	_socket.receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": {"from": {"column": 2, "row": 3}, "to": {"column": 2, "row": 4}}},
		"view": view,
		"finalBoard": [{"square": {"column": 0, "row": 7}, "type": "princess", "side": "green"}],
	})
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.OVER)
	assert_eq(_session.result().status, GameResult.Status.RED_WINS)
	assert_eq(_session.display_board().piece_at(Vector2i(0, 7)).type, PieceType.Id.PRINCESS)


func test_a_dropped_connection_can_be_resumed() -> void:
	_playing("red")
	_socket.close()
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.DISCONNECTED)
	_session.reconnect()
	assert_eq(_socket.open_count, 2)
	assert_eq(_socket.last_sent(), {"type": "take_seat", "seatToken": "t1"})


func test_it_tells_when_the_seat_was_taken_in_another_window() -> void:
	_playing("red")
	_socket.close_from_server("seat_taken_elsewhere")
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.DISCONNECTED)
	assert_eq(_session.disconnection_reason(), "seat_taken_elsewhere")


func test_a_finished_game_stays_over_when_the_socket_closes() -> void:
	_playing("red")
	var view: Dictionary = _view("red", [], [])
	view["result"] = {"status": "draw", "reason": "no_fight_limit"}
	_socket.receive({"type": "game_state", "view": view, "history": []})
	_session.poll()
	_socket.close()
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.OVER)


func test_resigning_asks_the_referee_and_waits() -> void:
	_playing("green")
	assert_true(_session.resign())
	assert_eq(_socket.last_sent(), {"type": "resign"})
	assert_true(_session.is_awaiting_answer())
	assert_false(_session.resign(), "no second resignation before the answer")


func test_no_resignation_is_sent_during_setup() -> void:
	_arranging()
	var sent_before: int = _socket.sent.size()
	assert_false(_session.resign())
	assert_eq(_socket.sent.size(), sent_before)


func test_a_resignation_ends_the_game() -> void:
	_playing("red")
	_session.resign()
	var view: Dictionary = _view("red", [], [])
	view["result"] = {"status": "green_wins", "reason": "resigned"}
	_socket.receive({"type": "game_state", "view": view, "history": []})
	_session.poll()
	assert_eq(_session.phase(), OnlineSession.Phase.OVER)
	assert_eq(_session.result().reason, GameResult.Reason.RESIGNED)
	assert_false(_session.is_awaiting_answer())


func test_it_knows_when_the_opponent_leaves_and_comes_back() -> void:
	_playing("red")
	assert_true(_session.is_opponent_connected())
	_socket.receive({"type": "opponent_presence", "connected": false})
	_session.poll()
	assert_false(_session.is_opponent_connected())
	assert_signal_emitted(_session, "changed")
	_socket.receive({"type": "opponent_presence", "connected": true})
	_session.poll()
	assert_true(_session.is_opponent_connected())


func test_reconnecting_forgets_the_opponents_old_presence() -> void:
	_playing("red")
	_socket.receive({"type": "opponent_presence", "connected": false})
	_session.poll()
	_socket.close()
	_session.poll()
	_session.reconnect()
	assert_true(_session.is_opponent_connected(), "the referee says again if they are still away")


func _arranging() -> void:
	_socket.receive({"type": "seated", "side": "red", "opponent": "Bob"})
	_socket.receive({"type": "setup_status", "ownSetupDone": false, "opponentSetupDone": false})
	_session.poll()


## Play has started with Red's Knight on c4 facing a Hidden Piece on c6.
func _playing(side_to_move: String) -> void:
	_arranging()
	var view: Dictionary = _view(side_to_move, [{"square": {"column": 2, "row": 3}, "type": "knight"}], [{"column": 2, "row": 5}])
	_socket.receive({"type": "game_state", "view": view, "history": []})
	_session.poll()


func _view(side_to_move: String, own: Array[Dictionary], enemy: Array[Dictionary]) -> Dictionary:
	return {
		"side": "red",
		"sideToMove": side_to_move,
		"pliesWithoutFight": 0,
		"result": {"status": "in_progress", "reason": "none"},
		"ownPieces": own,
		"enemySquares": enemy,
		"lastMoves": {},
	}
