extends GutTest
## The client reads and writes exactly the messages the online server in
## server/src speaks.


func test_entering_the_lobby_carries_the_nickname() -> void:
	assert_eq(_parsed(LobbyRequests.enter("Ada")), {"type": "enter", "nickname": "Ada"})


func test_lobby_requests_name_the_guest_concerned() -> void:
	assert_eq(_parsed(LobbyRequests.challenge("g2")), {"type": "challenge", "guestId": "g2"})
	assert_eq(_parsed(LobbyRequests.answer_challenge("g2", true)), {
		"type": "answer_challenge", "guestId": "g2", "accept": true,
	})


func test_taking_a_seat_carries_the_seat_token() -> void:
	assert_eq(_parsed(RefereeRequests.take_seat("abc")), {"type": "take_seat", "seatToken": "abc"})


func test_a_move_names_its_squares_by_column_and_row() -> void:
	var move: Move = BoardNotation.parse_move("c3-c4")
	assert_eq(_parsed(RefereeRequests.move(move)), {
		"type": "move",
		"move": {"from": {"column": 2.0, "row": 2.0}, "to": {"column": 2.0, "row": 3.0}},
	})


func test_a_resignation_is_only_its_type() -> void:
	assert_eq(_parsed(RefereeRequests.resign()), {"type": "resign"})


func test_a_setup_places_every_piece_of_the_army() -> void:
	var setup: Setup = BoardNotation.parse_setup(Side.Id.RED, ["BSNMBE", "MOSPBO", "NSOTBK"])
	var message: Dictionary = _parsed(RefereeRequests.setup(setup))
	var placements: Array = message["placements"]
	var type: String = message["type"]
	assert_eq(type, "setup")
	assert_eq(placements.size(), 18)
	assert_has(placements, {"square": {"column": 0.0, "row": 0.0}, "type": "knight"})
	assert_has(placements, {"square": {"column": 5.0, "row": 2.0}, "type": "executioner"})


func test_the_lobby_lists_the_other_guests() -> void:
	var reply: LobbyReply = LobbyReplies.read(JSON.stringify({
		"type": "guests", "guests": [{"guestId": "g2", "nickname": "Bob", "waiting": true}],
	}))
	assert_eq(reply.kind, LobbyReply.Kind.GUESTS)
	assert_eq(reply.guests[0].guest_id, "g2")
	assert_eq(reply.guests[0].nickname, "Bob")
	assert_true(reply.guests[0].waiting)


func test_the_lobby_names_the_challenger() -> void:
	var reply: LobbyReply = LobbyReplies.read('{"type":"challenged","guestId":"g2","nickname":"Bob"}')
	assert_eq(reply.kind, LobbyReply.Kind.CHALLENGED)
	assert_eq(reply.guest_id, "g2")
	assert_eq(reply.nickname, "Bob")


func test_the_lobby_tells_why_a_challenge_ended() -> void:
	var reply: LobbyReply = LobbyReplies.read('{"type":"challenge_ended","guestId":"g2","reason":"declined"}')
	assert_eq(reply.kind, LobbyReply.Kind.CHALLENGE_ENDED)
	assert_eq(reply.reason, "declined")


func test_the_lobby_gives_the_seat_when_paired() -> void:
	var reply: LobbyReply = LobbyReplies.read(JSON.stringify({
		"type": "paired", "gameId": "g1", "side": "green", "seatToken": "t1", "opponent": "Ada",
	}))
	assert_eq(reply.kind, LobbyReply.Kind.PAIRED)
	assert_eq(reply.seat.game_id, "g1")
	assert_eq(reply.seat.side, Side.Id.GREEN)
	assert_eq(reply.seat.seat_token, "t1")
	assert_eq(reply.seat.opponent, "Ada")


func test_anything_unexpected_from_the_lobby_is_malformed() -> void:
	var texts: Array[String] = [
		"",
		"nonsense",
		'{"type":"paired","side":"blue"}',
		'{"type":"guests","guests":[{"nickname":"Bob","waiting":false}]}',
		'{"type":"quick_match","waiting":"yes"}',
		'{"type":"entered"}',
		'{"type":"dance"}',
	]
	for text: String in texts:
		assert_eq(LobbyReplies.read(text).kind, LobbyReply.Kind.MALFORMED, text)


func test_the_referee_seats_us_with_our_opponent() -> void:
	var reply: RefereeReply = RefereeReplies.read('{"type":"seated","side":"red","opponent":"Bob"}')
	assert_eq(reply.kind, RefereeReply.Kind.SEATED)
	assert_eq(reply.side, Side.Id.RED)
	assert_eq(reply.opponent, "Bob")


func test_the_referee_tells_who_finished_setup() -> void:
	var reply: RefereeReply = RefereeReplies.read(
		'{"type":"setup_status","ownSetupDone":false,"opponentSetupDone":true}'
	)
	assert_eq(reply.kind, RefereeReply.Kind.SETUP_STATUS)
	assert_false(reply.own_setup_done)
	assert_true(reply.opponent_setup_done)
	assert_eq(reply.setup_time_left_msec, RefereeReply.NO_SETUP_TIMER, "the referee did not say")


func test_the_referee_tells_how_long_the_setup_timer_still_runs() -> void:
	var reply: RefereeReply = RefereeReplies.read(
		'{"type":"setup_status","ownSetupDone":false,"opponentSetupDone":false,"setupTimeLeftMs":179500}'
	)
	assert_eq(reply.kind, RefereeReply.Kind.SETUP_STATUS)
	assert_eq(reply.setup_time_left_msec, 179_500)


func test_a_game_state_shows_own_pieces_and_hides_enemy_types() -> void:
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "game_state",
		"view": _view("red", "red", [_own("c3", "knight")], ["c6"]),
		"history": [],
	}))
	assert_eq(reply.kind, RefereeReply.Kind.GAME_STATE)
	assert_eq(reply.position.viewer, Side.Id.RED)
	assert_true(reply.position.is_viewers_turn())
	var board: Board = reply.position.board()
	assert_eq(board.piece_at(_square("c3")).type, PieceType.Id.KNIGHT)
	assert_eq(board.piece_at(_square("c6")).side, Side.Id.GREEN)
	assert_eq(board.piece_at(_square("c6")).type, KnownPosition.HIDDEN_TYPE_STAND_IN)
	assert_null(reply.final_board)


func test_a_known_position_finds_the_legal_moves_of_own_pieces() -> void:
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "game_state",
		"view": _view("red", "red", [_own("c4", "knight")], ["c5"]),
		"history": [],
	}))
	var destinations: Array[Vector2i] = reply.position.legal_destinations(_square("c4"))
	assert_has(destinations, _square("c5"), "a Knight may Attack the Hidden Piece ahead")
	assert_has(destinations, _square("c3"))
	assert_eq(reply.position.legal_destinations(_square("c5")), [] as Array[Vector2i])


func test_a_known_position_offers_no_move_on_the_opponents_turn() -> void:
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "game_state",
		"view": _view("red", "green", [_own("c4", "knight")], ["c5"]),
		"history": [],
	}))
	assert_false(reply.position.is_viewers_turn())
	assert_eq(reply.position.legal_destinations(_square("c4")), [] as Array[Vector2i])


func test_a_known_position_keeps_the_move_back_rule() -> void:
	var view: Dictionary = _view("red", "red", [_own("c4", "knight")], ["f6"])
	view["lastMoves"] = {"red": _move("c3", "c4")}
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "game_state", "view": view, "history": [],
	}))
	assert_does_not_have(reply.position.legal_destinations(_square("c4")), _square("c3"))


func test_a_game_state_carries_the_history_and_the_final_board() -> void:
	var view: Dictionary = _view("green", "green", [_own("a8", "king")], ["a6"])
	view["result"] = {"status": "red_wins", "reason": "princess_captured"}
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "game_state",
		"view": view,
		"history": [_fight_event("red", "a3", "a6", "buffoon", "princess", "attacker_wins")],
		"finalBoard": [
			{"square": _wire_square("a6"), "type": "buffoon", "side": "red"},
			{"square": _wire_square("a8"), "type": "king", "side": "green"},
		],
	}))
	assert_eq(reply.kind, RefereeReply.Kind.GAME_STATE)
	assert_eq(reply.history.size(), 1)
	assert_eq(reply.history[0].defender_type, PieceType.Id.PRINCESS)
	assert_eq(reply.position.result.status, GameResult.Status.RED_WINS)
	assert_eq(reply.position.result.reason, GameResult.Reason.PRINCESS_CAPTURED)
	assert_eq(reply.final_board.piece_at(_square("a6")).type, PieceType.Id.BUFFOON)


func test_a_moved_message_carries_the_event_and_the_new_view() -> void:
	var reply: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "moved",
		"event": _fight_event("red", "c3", "c4", "knight", "thief", "attacker_wins"),
		"view": _view("green", "green", [_own("a8", "king")], ["c4"]),
	}))
	assert_eq(reply.kind, RefereeReply.Kind.MOVED)
	assert_eq(reply.event.mover_side, Side.Id.RED)
	assert_true(reply.event.move.equals(BoardNotation.parse_move("c3-c4")))
	assert_eq(reply.event.attacker_type, PieceType.Id.KNIGHT)
	assert_eq(reply.event.outcome, FightOutcome.Id.ATTACKER_WINS)


func test_the_referee_tells_why_it_refused() -> void:
	var reply: RefereeReply = RefereeReplies.read('{"type":"refused","reason":"illegal_move"}')
	assert_eq(reply.kind, RefereeReply.Kind.REFUSED)
	assert_eq(reply.refusal, "illegal_move")


func test_the_referee_tells_whether_the_opponent_is_connected() -> void:
	var away: RefereeReply = RefereeReplies.read('{"type":"opponent_presence","connected":false}')
	assert_eq(away.kind, RefereeReply.Kind.OPPONENT_PRESENCE)
	assert_false(away.opponent_connected)
	var back: RefereeReply = RefereeReplies.read('{"type":"opponent_presence","connected":true}')
	assert_true(back.opponent_connected)


func test_a_result_can_end_by_resign_or_forfeit() -> void:
	for reason: String in ["resigned", "forfeited"]:
		var view: Dictionary = _view("red", "green", [], [])
		view["result"] = {"status": "green_wins", "reason": reason}
		var text: String = JSON.stringify({"type": "game_state", "view": view, "history": []})
		var reply: RefereeReply = RefereeReplies.read(text)
		assert_eq(reply.kind, RefereeReply.Kind.GAME_STATE, reason)
		assert_eq(WireNames.reason(reason), reply.position.result.reason)
	assert_eq(WireNames.reason("resigned"), GameResult.Reason.RESIGNED)
	assert_eq(WireNames.reason("forfeited"), GameResult.Reason.FORFEITED)


func test_anything_unexpected_from_the_referee_is_malformed() -> void:
	var off_board: Dictionary = _view("red", "red", [], [])
	off_board["enemySquares"] = [{"column": 6, "row": 0}]
	var fractional: Dictionary = _view("red", "red", [], [])
	fractional["pliesWithoutFight"] = 1.5
	var texts: Array[String] = [
		"",
		'{"type":"seated","side":"blue"}',
		'{"type":"setup_status","ownSetupDone":"yes","opponentSetupDone":false}',
		'{"type":"setup_status","ownSetupDone":false,"opponentSetupDone":false,"setupTimeLeftMs":-1}',
		'{"type":"setup_status","ownSetupDone":false,"opponentSetupDone":false,"setupTimeLeftMs":"soon"}',
		'{"type":"opponent_presence"}',
		'{"type":"opponent_presence","connected":"no"}',
		JSON.stringify({"type": "game_state", "view": off_board, "history": []}),
		JSON.stringify({"type": "game_state", "view": fractional, "history": []}),
		JSON.stringify({"type": "game_state", "view": _view("red", "red", [], []), "history": [{}]}),
		JSON.stringify({"type": "moved", "view": _view("red", "red", [], [])}),
	]
	for text: String in texts:
		assert_eq(RefereeReplies.read(text).kind, RefereeReply.Kind.MALFORMED, text)


func test_a_fight_eliminates_the_loser_of_each_side() -> void:
	var move: Move = BoardNotation.parse_move("c3-c4")
	var event: PublicMoveEvent = PublicMoveEvent.of_move(Side.Id.RED, move)
	assert_eq(event.eliminated_types(), {} as Dictionary[Side.Id, PieceType.Id])
	var won: PublicMoveEvent = event.with_fight(
		PieceType.Id.KNIGHT, PieceType.Id.THIEF, FightOutcome.Id.ATTACKER_WINS
	)
	assert_eq(won.eliminated_types(), {Side.Id.GREEN: PieceType.Id.THIEF} as Dictionary[Side.Id, PieceType.Id])
	var tied: PublicMoveEvent = event.with_fight(
		PieceType.Id.KNIGHT, PieceType.Id.KNIGHT, FightOutcome.Id.BOTH_ELIMINATED
	)
	assert_eq(tied.eliminated_types().size(), 2)


func test_quick_chat_and_rematch_requests() -> void:
	assert_eq(_parsed(RefereeRequests.quick_chat("thanks")), {"type": "quick_chat", "message": "thanks"})
	assert_eq(_parsed(RefereeRequests.rematch()), {"type": "rematch"})


func test_the_referee_relays_a_quick_chat() -> void:
	var reply: RefereeReply = RefereeReplies.read('{"type":"quick_chat","side":"green","message":"oops"}')
	assert_eq(reply.kind, RefereeReply.Kind.QUICK_CHAT)
	assert_eq(reply.chat_side, Side.Id.GREEN)
	assert_eq(reply.chat_message, "oops")
	var unknown: RefereeReply = RefereeReplies.read('{"type":"quick_chat","side":"green","message":"rude"}')
	assert_eq(unknown.kind, RefereeReply.Kind.MALFORMED)


func test_the_referee_offers_and_seats_a_rematch() -> void:
	assert_eq(RefereeReplies.read('{"type":"rematch_offered"}').kind, RefereeReply.Kind.REMATCH_OFFERED)
	var ready: RefereeReply = RefereeReplies.read(JSON.stringify({
		"type": "rematch_ready", "gameId": "g2", "side": "red", "seatToken": "t2", "opponent": "Bob",
	}))
	assert_eq(ready.kind, RefereeReply.Kind.REMATCH_READY)
	assert_eq(ready.rematch_seat.game_id, "g2")
	assert_eq(ready.rematch_seat.side, Side.Id.RED)


func _parsed(text: String) -> Dictionary:
	var value: Variant = JSON.parse_string(text)
	if value is Dictionary:
		return value
	fail_test("not a JSON object: %s" % text)
	return {}


func _view(side: String, mover: String, own: Array[Dictionary], enemy: Array[String]) -> Dictionary:
	var enemy_squares: Array[Dictionary] = []
	for square: String in enemy:
		enemy_squares.append(_wire_square(square))
	return {
		"side": side,
		"sideToMove": mover,
		"pliesWithoutFight": 0,
		"result": {"status": "in_progress", "reason": "none"},
		"ownPieces": own,
		"enemySquares": enemy_squares,
		"lastMoves": {},
	}


func _own(square: String, type: String) -> Dictionary:
	return {"square": _wire_square(square), "type": type}


func _fight_event(
		side: String, from: String, to: String, attacker: String, defender: String, outcome: String,
) -> Dictionary:
	return {
		"moverSide": side,
		"move": _move(from, to),
		"fight": {"attackerType": attacker, "defenderType": defender, "outcome": outcome},
	}


func _move(from: String, to: String) -> Dictionary:
	return {"from": _wire_square(from), "to": _wire_square(to)}


func _wire_square(text: String) -> Dictionary:
	var square: Vector2i = _square(text)
	return {"column": square.x, "row": square.y}


func _square(text: String) -> Vector2i:
	return BoardNotation.parse_square(text)
