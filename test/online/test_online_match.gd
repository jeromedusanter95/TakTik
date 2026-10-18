extends GutTest
## Drives the real OnlineMatch scene the way a Guest would, from taking the
## seat to the end of the game, with the referee's messages fed through fake
## sockets.

const OnlineMatchScene: PackedScene = preload("res://game/online/online_match.tscn")
const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const SERVER_URL: String = "ws://referee.test"

var _match: OnlineMatch = null
var _sockets: Array[FakeWireSocket] = []
var _now_msec: int = 5_000


func before_each() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	_sockets.clear()
	var instance: Node = OnlineMatchScene.instantiate()
	if instance is not OnlineMatch:
		fail_test("online_match.tscn root should be an OnlineMatch")
		return
	_match = instance
	add_child_autofree(_match)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	_match.configure(SERVER_URL, _open_socket, rng, _ticks_msec)


func test_it_takes_the_seat_and_shows_the_setup() -> void:
	_seat_and_arrange()
	assert_eq(_sockets[0].opened_url, "ws://referee.test/games/g1")
	assert_eq(_sockets[0].last_sent(), {"type": "take_seat", "seatToken": "t1"})
	assert_eq(_status(), "Arrange your Army")
	assert_true(_button("%ShuffleButton").visible)
	assert_eq(_button("%ActionButton").text, "Ready")
	assert_eq(_subtitle(), "Online against Bob")


func test_the_setup_covers_the_enemy_rows() -> void:
	_seat_and_arrange()
	var state: BoardViewState = _board_view().state()
	assert_true(state.cover_enemy_zone)
	assert_eq(state.enemy_zone_label, "Bob's zone · Pieces hidden")


func test_the_chat_announces_the_setup_time() -> void:
	_seat_and_arrange()
	assert_eq(_chat_texts(), ["3 minutes to place your Pieces"] as Array[String])


func test_ready_sends_the_setup_and_waits_for_the_opponent() -> void:
	_seat_and_arrange()
	_button("%ActionButton").pressed.emit()
	var sent_type: String = _sockets[0].last_sent()["type"]
	assert_eq(sent_type, "setup")
	_sockets[0].receive({"type": "setup_status", "ownSetupDone": true, "opponentSetupDone": false})
	_frame()
	assert_eq(_status(), "Waiting for Bob to arrange their Army...")
	assert_true(_button("%ActionButton").disabled)
	assert_false(_button("%ShuffleButton").visible)
	assert_eq(_card_status("%OpponentCard"), "Arranging their Army...")
	assert_eq(_card_status("%YouCard"), "Ready")


func test_the_opponent_card_says_ready_once_their_army_is_in() -> void:
	_seat_and_arrange()
	_sockets[0].receive({"type": "setup_status", "ownSetupDone": false, "opponentSetupDone": true})
	_frame()
	assert_eq(_card_status("%OpponentCard"), "Ready")


func test_a_guest_plays_a_move_by_tapping_two_squares() -> void:
	_start_play()
	assert_eq(_status(), "Your turn")
	_board_view().square_pressed.emit(Vector2i(2, 3))
	_board_view().square_pressed.emit(Vector2i(2, 4))
	assert_eq(_sockets[0].last_sent(), {
		"type": "move",
		"move": {"from": {"column": 2.0, "row": 3.0}, "to": {"column": 2.0, "row": 4.0}},
	})
	assert_eq(_status(), "Sending...")


func test_a_move_waiting_long_for_the_referee_says_the_connection_is_slow() -> void:
	_start_play()
	_board_view().square_pressed.emit(Vector2i(2, 3))
	_board_view().square_pressed.emit(Vector2i(2, 4))
	assert_eq(_board_view().state().pending_move.to, Vector2i(2, 4), "the Piece shows faded on its target")
	_now_msec += 3_100
	_frame()
	assert_eq(_status(), "Slow connection...")
	_sockets[0].receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": _move(2, 3, 2, 4)},
		"view": _view("green", [_own(2, 4, "knight")], [_square(2, 5)]),
	})
	_frame()
	assert_null(_board_view().state().pending_move)
	assert_eq(_status(), "Bob is playing...")


func test_the_opponents_turn_shows_in_the_status_and_on_their_card() -> void:
	_start_play()
	_sockets[0].receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": _move(2, 3, 2, 4)},
		"view": _view("green", [_own(2, 4, "knight")], [_square(2, 5)]),
	})
	_frame()
	assert_eq(_status(), "Bob is playing...")
	assert_eq(_card(&"%OpponentCard").theme_type_variation, &"CardActive")
	assert_eq(_journal_texts(), ["1. Red moved a Piece from c4 to c5."] as Array[String])


func test_a_new_move_is_animated() -> void:
	_start_play()
	_sockets[0].receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": _move(2, 3, 2, 4)},
		"view": _view("green", [_own(2, 4, "knight")], [_square(2, 5)]),
	})
	_frame()
	assert_true(_board_view().is_animating())


func test_a_fight_shows_in_the_card_and_as_a_pill_in_the_chat() -> void:
	_start_play()
	_sockets[0].receive({
		"type": "moved",
		"event": {
			"moverSide": "red",
			"move": _move(2, 3, 2, 4),
			"fight": {"attackerType": "knight", "defenderType": "soldier", "outcome": "attacker_wins"},
		},
		"view": _view("green", [_own(2, 4, "knight")], []),
	})
	_frame()
	var fight_card: Node = _screen().get_node("%FightCard")
	var result: Label = fight_card.get_node("%ResultLabel")
	assert_eq(result.text, "The Knight wins")
	assert_has(_chat_texts(), "Knight 4 against Soldier 3: The Knight wins")


func test_a_quick_chat_chip_sends_and_the_relayed_chat_shows_as_bubbles() -> void:
	_start_play()
	var chips: Node = _screen().get_node("%ChatPanel").get_node("%Chips")
	var good_luck: Node = chips.get_child(QuickChat.MESSAGES.find("good_luck"))
	assert_true(good_luck is Button)
	(good_luck as Button).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "quick_chat", "message": "good_luck"})
	_sockets[0].receive({"type": "quick_chat", "side": "green", "message": "thanks"})
	_sockets[0].receive({"type": "quick_chat", "side": "red", "message": "good_luck"})
	_frame()
	assert_has(_chat_texts(), "Thanks!")
	assert_has(_chat_texts(), "Good luck!")
	assert_has(_chat_texts(), "Bob")
	assert_has(_chat_texts(), "You")


func test_the_end_opens_the_result_modal_and_leads_back_to_the_lobby() -> void:
	_start_play()
	var view: Dictionary = _view("green", [_own(2, 4, "knight")], [])
	view["result"] = {"status": "red_wins", "reason": "princess_captured"}
	_sockets[0].receive({
		"type": "moved",
		"event": {
			"moverSide": "red",
			"move": _move(2, 3, 2, 4),
			"fight": {"attackerType": "knight", "defenderType": "princess", "outcome": "attacker_wins"},
		},
		"view": view,
		"finalBoard": [{"square": _square(2, 4), "type": "knight", "side": "red"}],
	})
	_frame()
	assert_eq(_status(), "Game over")
	assert_true(_modal().visible)
	assert_eq(_modal_label("%TitleLabel").text, "Victory!")
	assert_eq(_modal_label("%ReasonLabel").text, "The enemy Princess was captured.")
	watch_signals(_match)
	_button("%SecondaryButton", _modal()).pressed.emit()
	assert_signal_emitted(_match, "lobby_requested")
	assert_eq(_sockets[0].state(), WireSocket.State.CLOSED)


func test_a_defeat_is_titled_as_such() -> void:
	_start_play()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	view["result"] = {"status": "green_wins", "reason": "resigned"}
	_sockets[0].receive({"type": "game_state", "view": view, "history": [], "finalBoard": []})
	_frame()
	assert_eq(_modal_label("%TitleLabel").text, "Defeat")
	assert_eq(_modal_label("%ReasonLabel").text, "Red resigned.")


func test_a_rematch_moves_both_guests_to_the_new_game() -> void:
	_start_play()
	var view: Dictionary = _view("green", [_own(2, 4, "knight")], [])
	view["result"] = {"status": "red_wins", "reason": "resigned"}
	_sockets[0].receive({"type": "game_state", "view": view, "history": []})
	_sockets[0].receive({"type": "rematch_offered"})
	_frame()
	assert_eq(_modal_label("%NoticeLabel").text, "Bob wants a Rematch")
	_button("%PrimaryButton", _modal()).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "rematch"})
	assert_true(_button("%PrimaryButton", _modal()).disabled)
	_sockets[0].receive({"type": "rematch_ready", "gameId": "g2", "side": "green", "seatToken": "t2", "opponent": "Bob"})
	_frame()
	assert_eq(_last_socket().opened_url, "ws://referee.test/games/g2")
	assert_eq(_last_socket().last_sent(), {"type": "take_seat", "seatToken": "t2"})
	assert_eq(_sockets[0].state(), WireSocket.State.CLOSED)
	assert_false(_modal().visible)


func test_resign_asks_for_confirmation_before_sending() -> void:
	_start_play()
	assert_true(_button("%ResignButton").visible)
	_button("%ResignButton").pressed.emit()
	var dialog: Node = _screen().get_node("%ResignDialog")
	assert_true((dialog as Control).visible)
	var sent_type: String = _sockets[0].last_sent()["type"]
	assert_eq(sent_type, "setup", "nothing sent before confirming")
	_button("%PrimaryButton", dialog).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "resign"})
	assert_false(_button("%ResignButton").visible)


func test_resign_is_offered_only_during_play() -> void:
	_seat_and_arrange()
	assert_false(_button("%ResignButton").visible)


func test_a_forfeit_is_explained_in_french() -> void:
	_start_play()
	TranslationServer.set_locale("fr")
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	view["result"] = {"status": "red_wins", "reason": "forfeited"}
	_sockets[0].receive({"type": "game_state", "view": view, "history": [], "finalBoard": []})
	_frame()
	assert_eq(_modal_label("%TitleLabel").text, "Victoire !")
	assert_eq(_modal_label("%ReasonLabel").text, "Vert est resté trop longtemps déconnecté.")
	TranslationServer.set_locale(Languages.ENGLISH)


func test_the_opponents_disconnection_shows_on_their_card() -> void:
	_start_play()
	_sockets[0].receive({"type": "opponent_presence", "connected": false})
	_frame()
	assert_eq(_card_status("%OpponentCard"), "Connection lost")
	_sockets[0].receive({"type": "opponent_presence", "connected": true})
	_frame()
	assert_eq(_card_status("%OpponentCard"), "")


func test_an_away_opponent_shows_the_time_until_they_forfeit() -> void:
	_start_play()
	_sockets[0].receive({"type": "opponent_presence", "connected": false, "forfeitInMs": 30_000})
	_frame()
	assert_eq(_card_status("%OpponentCard"), "Connection lost 0:30")
	_now_msec += 12_000
	_frame()
	assert_eq(_card_status("%OpponentCard"), "Connection lost 0:18")


func test_while_playing_the_guest_stays_listed_in_the_lobby_as_in_a_game() -> void:
	_start_play()
	var presence: FakeWireSocket = _sockets[1]
	assert_eq(presence.opened_url, "ws://referee.test/lobby")
	assert_eq(presence.last_sent(), {"type": "enter", "nickname": "Ada", "inGame": true})
	_button("%QuitButton", _screen().get_node("%GameMenu")).pressed.emit()
	assert_eq(presence.state(), WireSocket.State.CLOSED)


func test_a_lost_connection_retries_by_itself_then_offers_to_reconnect() -> void:
	_start_play()
	_sockets[0].close()
	_frame()
	var dialog: Control = _screen().get_node("%ConnectionDialog")
	assert_true(dialog.visible)
	assert_eq(_label("%TitleLabel", dialog).text, "Reconnecting...")
	await wait_seconds(1.2)
	assert_eq(_sockets[0].open_count, 2, "a first try after one second")


func test_quitting_from_the_menu_leaves_the_game() -> void:
	_start_play()
	watch_signals(_match)
	_button("%QuitButton", _screen().get_node("%GameMenu")).pressed.emit()
	assert_signal_emitted(_match, "lobby_requested")
	assert_eq(_sockets[0].state(), WireSocket.State.CLOSED)


func test_the_setup_timer_counts_down_on_the_ring() -> void:
	_seat_and_arrange()
	_sockets[0].receive({
		"type": "setup_status", "ownSetupDone": false, "opponentSetupDone": false,
		"setupTimeLeftMs": 180_000,
	})
	_frame()
	assert_true(_ring().visible)
	_now_msec += 61_000
	_frame()
	assert_eq(_ring_text(), "1:59")


func test_an_army_arranged_at_random_when_time_ran_out_is_explained() -> void:
	_seat_and_arrange()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	_sockets[0].receive({"type": "game_state", "view": view, "history": []})
	_frame()
	assert_has(_chat_texts(), "Time ran out, so your Army was arranged at random.")
	assert_eq(_status(), "Your turn")


func test_the_turn_timer_counts_down_on_the_ring_and_the_turn_bar() -> void:
	_seat_and_arrange()
	_button("%ActionButton").pressed.emit()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	_sockets[0].receive({"type": "game_state", "view": view, "history": [], "turnTimeLeftMs": 60_000})
	_frame()
	assert_eq(_ring_text(), "1:00")
	_now_msec += 15_000
	_frame()
	assert_eq(_ring_text(), "0:45")
	var bar: ProgressBar = _card(&"%YouCard").get_node("%TurnBar")
	assert_almost_eq(bar.value, 0.75, 0.01)


func _ticks_msec() -> int:
	return _now_msec


func _open_socket() -> WireSocket:
	var socket: FakeWireSocket = FakeWireSocket.new()
	_sockets.append(socket)
	return socket


func _seat_and_arrange() -> void:
	var seat: PairedSeat = PairedSeat.new()
	seat.game_id = "g1"
	seat.side = Side.Id.RED
	seat.seat_token = "t1"
	seat.opponent = "Bob"
	_match.play(seat, "Ada")
	_sockets[0].receive({"type": "seated", "side": "red", "opponent": "Bob"})
	_sockets[0].receive({"type": "setup_status", "ownSetupDone": false, "opponentSetupDone": false})
	_frame()


## Play has started, Red to move, with Red's Knight on c4 and a Hidden Piece
## on c6.
func _start_play() -> void:
	_seat_and_arrange()
	_button("%ActionButton").pressed.emit()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	_sockets[0].receive({"type": "game_state", "view": view, "history": []})
	_frame()


func _frame() -> void:
	_match._process(0.016)


func _last_socket() -> FakeWireSocket:
	return _sockets.back()


func _screen() -> MatchScreen:
	var node: Node = _match.get_node("%MatchScreen")
	assert_true(node is MatchScreen)
	return node


func _status() -> String:
	return _label("%StatusLabel", _screen().get_node("%TopBar")).text


func _subtitle() -> String:
	return _label("%Subtitle", _screen().get_node("%TopBar")).text


func _ring() -> TimerRing:
	var node: Node = _screen().get_node("%TopBar").get_node("%TimerRing")
	assert_true(node is TimerRing)
	return node


func _ring_text() -> String:
	return TimerRing.format(_ring()._seconds_left)


func _board_view() -> BoardView:
	var node: Node = _screen().get_node("%BoardView")
	assert_true(node is BoardView)
	return node


func _card(path: String) -> PlayerCard:
	var node: Node = _screen().get_node(path)
	assert_true(node is PlayerCard)
	return node


func _card_status(path: String) -> String:
	var label: Label = _card(path).get_node("%StatusLabel")
	return label.text if label.visible else ""


func _modal() -> Control:
	return _screen().get_node("%ResultModal")


func _modal_label(path: String) -> Label:
	return _label(path, _modal())


func _chat_texts() -> Array[String]:
	var texts: Array[String] = []
	for node: Node in _screen().get_node("%ChatPanel").get_node("%Messages").find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return texts


func _journal_texts() -> Array[String]:
	var texts: Array[String] = []
	for node: Node in _screen().get_node("%ChatPanel").get_node("%JournalRows").find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return texts


func _label(path: String, owner_node: Node) -> Label:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Label, path)
	return node


func _button(path: String, owner_node: Node = null) -> Button:
	var holder: Node = owner_node
	if holder == null:
		holder = _screen()
		if holder.get_node_or_null(path) == null:
			holder = _screen().get_node("%TopBar")
	var node: Node = holder.get_node(path)
	assert_true(node is Button, path)
	return node


func _move(from_column: int, from_row: int, to_column: int, to_row: int) -> Dictionary:
	return {"from": _square(from_column, from_row), "to": _square(to_column, to_row)}


func _square(column: int, row: int) -> Dictionary:
	return {"column": column, "row": row}


func _own(column: int, row: int, type: String) -> Dictionary:
	return {"square": _square(column, row), "type": type}


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
