extends GutTest
## Drives the real OnlineMatch scene the way a Guest would, with the server's
## messages fed through fake sockets.

const OnlineMatchScene: PackedScene = preload("res://game/online/online_match.tscn")
const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const SERVER_URL: String = "ws://referee.test"

var _match: OnlineMatch = null
var _sockets: Array[FakeWireSocket] = []


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
	_match.start(SERVER_URL, _open_socket, rng)


func test_it_opens_on_the_nickname_entry_with_enter_disabled() -> void:
	assert_true(_panel().visible)
	assert_true(_button("%EnterButton").disabled)
	_nickname_edit().text = "Ada"
	_nickname_edit().text_changed.emit("Ada")
	assert_false(_button("%EnterButton").disabled)


func test_entering_joins_the_lobby_and_lists_the_other_guests() -> void:
	_enter("Ada")
	assert_eq(_sockets[0].opened_url, "ws://referee.test/lobby")
	assert_eq(_sockets[0].last_sent(), {"type": "enter", "nickname": "Ada"})
	assert_eq(_label("%MessageLabel").text, "Entering the Lobby...")
	_in_lobby_with_bob()
	assert_true(_control("%LobbySection").visible)
	assert_eq(_guest_rows().size(), 1)
	assert_eq(_row_label(_guest_rows()[0]).text, "Bob")


func test_quick_match_toggles_waiting() -> void:
	_enter("Ada")
	_in_lobby_with_bob()
	_button("%QuickMatchButton").pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "quick_match"})
	_sockets[0].receive({"type": "quick_match", "waiting": true})
	_frame()
	assert_eq(_button("%QuickMatchButton").text, "Stop waiting")
	assert_eq(_label("%MessageLabel").text, "Waiting for an Opponent...")
	_button("%QuickMatchButton").pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "stop_waiting"})


func test_challenging_a_guest_shows_the_challenge_until_declined() -> void:
	_enter("Ada")
	_in_lobby_with_bob()
	_row_button(_guest_rows()[0]).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "challenge", "guestId": "g2"})
	_sockets[0].receive({"type": "challenge_sent", "guestId": "g2"})
	_frame()
	assert_true(_control("%ChallengeRow").visible)
	assert_eq(_label("%ChallengeLabel").text, "Challenge sent to Bob...")
	_sockets[0].receive({"type": "challenge_ended", "guestId": "g2", "reason": "declined"})
	_frame()
	assert_false(_control("%ChallengeRow").visible)
	assert_eq(_label("%MessageLabel").text, "Bob declined your Challenge.")


func test_a_challenge_received_can_be_accepted() -> void:
	_enter("Ada")
	_in_lobby_with_bob()
	_sockets[0].receive({"type": "challenged", "guestId": "g2", "nickname": "Bob"})
	_frame()
	var rows: Array[Node] = _node("%ChallengersList").get_children()
	assert_eq(rows.size(), 1)
	assert_eq(_row_label(rows[0]).text, "Bob challenges you")
	_row_button(rows[0]).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "answer_challenge", "guestId": "g2", "accept": true})


func test_a_refused_nickname_is_explained() -> void:
	_enter("Ada")
	_sockets[0].close_from_server("invalid_nickname")
	_frame()
	assert_true(_control("%EntrySection").visible)
	assert_string_contains(_label("%MessageLabel").text, "not allowed")


func test_an_unreachable_server_is_explained() -> void:
	_enter("Ada")
	_sockets[0].close()
	_frame()
	assert_eq(_label("%MessageLabel").text, "Could not reach the server. Try again in a moment.")


func test_once_paired_it_takes_the_seat_and_shows_the_setup() -> void:
	_pair_and_arrange()
	assert_false(_panel().visible)
	assert_eq(_sockets[1].opened_url, "ws://referee.test/games/g1")
	assert_eq(_sockets[1].last_sent(), {"type": "take_seat", "seatToken": "t1"})
	assert_eq(_label("%StatusLabel").text, "Arrange your Army")
	assert_eq(_label("%InfoLabel").text, "You play Red against Bob.")
	assert_true(_button("%ShuffleButton").visible)
	assert_eq(_button("%ActionButton").text, "Ready")


func test_ready_sends_the_setup_and_waits_for_the_opponent() -> void:
	_pair_and_arrange()
	_button("%ActionButton").pressed.emit()
	var sent_type: String = _sockets[1].last_sent()["type"]
	assert_eq(sent_type, "setup")
	_sockets[1].receive({"type": "setup_status", "ownSetupDone": true, "opponentSetupDone": false})
	_frame()
	assert_eq(_label("%StatusLabel").text, "Waiting for Bob to arrange their Army...")
	assert_false(_button("%ActionButton").visible)


func test_a_guest_plays_a_move_by_tapping_two_squares() -> void:
	_start_play()
	assert_eq(_label("%StatusLabel").text, "Your turn")
	_board_view().square_pressed.emit(Vector2i(2, 3))
	_board_view().square_pressed.emit(Vector2i(2, 4))
	assert_eq(_sockets[1].last_sent(), {
		"type": "move",
		"move": {"from": {"column": 2.0, "row": 3.0}, "to": {"column": 2.0, "row": 4.0}},
	})
	assert_eq(_label("%StatusLabel").text, "Sending...")


func test_the_opponents_move_is_narrated() -> void:
	_start_play()
	_sockets[1].receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": _move(2, 3, 2, 4)},
		"view": _view("green", [_own(2, 4, "knight")], [_square(2, 5)]),
	})
	_frame()
	assert_eq(_label("%StatusLabel").text, "Bob is playing...")
	assert_eq(_label("%InfoLabel").text, "Red moved a Piece from c4 to c5.")


func test_a_quick_chat_is_chosen_from_the_menu_and_shown_when_relayed() -> void:
	_start_play()
	assert_true(_button("%ChatButton").visible)
	_button("%ChatButton").pressed.emit()
	_chat_menu().id_pressed.emit(QuickChat.MESSAGES.find("good_luck"))
	assert_eq(_sockets[1].last_sent(), {"type": "quick_chat", "message": "good_luck"})
	_sockets[1].receive({"type": "quick_chat", "side": "green", "message": "thanks"})
	_frame()
	assert_eq(_label("%ChatLabel").text, "Bob: Thanks!")
	_sockets[1].receive({"type": "quick_chat", "side": "red", "message": "good_luck"})
	_frame()
	assert_eq(_label("%ChatLabel").text, "You: Good luck!")


func test_a_rematch_moves_both_guests_to_the_new_game() -> void:
	_start_play()
	assert_false(_button("%RematchButton").visible)
	var view: Dictionary = _view("green", [_own(2, 4, "knight")], [])
	view["result"] = {"status": "red_wins", "reason": "resigned"}
	_sockets[1].receive({"type": "game_state", "view": view, "history": []})
	_sockets[1].receive({"type": "rematch_offered"})
	_frame()
	assert_eq(_button("%RematchButton").text, "Bob wants a Rematch: accept")
	_button("%RematchButton").pressed.emit()
	assert_eq(_sockets[1].last_sent(), {"type": "rematch"})
	assert_true(_button("%RematchButton").disabled)
	_sockets[1].receive({"type": "rematch_ready", "gameId": "g2", "side": "green", "seatToken": "t2", "opponent": "Bob"})
	_frame()
	assert_eq(_last_socket().opened_url, "ws://referee.test/games/g2")
	assert_eq(_last_socket().last_sent(), {"type": "take_seat", "seatToken": "t2"})
	assert_eq(_sockets[1].state(), WireSocket.State.CLOSED)


func test_the_end_shows_the_result_and_offers_a_new_opponent() -> void:
	_start_play()
	var view: Dictionary = _view("green", [_own(2, 4, "knight")], [])
	view["result"] = {"status": "red_wins", "reason": "princess_captured"}
	_sockets[1].receive({
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
	assert_string_starts_with(_label("%StatusLabel").text, "Red wins")
	assert_eq(_button("%ActionButton").text, "Back to the Lobby")
	_button("%ActionButton").pressed.emit()
	assert_true(_panel().visible)
	assert_eq(_last_socket().opened_url, "ws://referee.test/lobby")
	assert_eq(_last_socket().last_sent(), {"type": "enter", "nickname": "Ada"})


func test_resign_asks_for_confirmation_before_sending() -> void:
	_start_play()
	assert_true(_button("%ResignButton").visible)
	_button("%ResignButton").pressed.emit()
	assert_true(_resign_dialog().visible)
	assert_eq(_resign_dialog().dialog_text, "Bob will win the game.")
	assert_eq(_resign_dialog().get_ok_button().text, "Resign")
	var sent_type: String = _sockets[1].last_sent()["type"]
	assert_eq(sent_type, "setup", "nothing sent before confirming")
	_resign_dialog().confirmed.emit()
	assert_eq(_sockets[1].last_sent(), {"type": "resign"})
	assert_false(_button("%ResignButton").visible)


func test_resign_is_offered_only_during_play() -> void:
	_pair_and_arrange()
	assert_false(_button("%ResignButton").visible)


func test_a_resignation_is_narrated() -> void:
	_start_play()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	view["result"] = {"status": "green_wins", "reason": "resigned"}
	_sockets[1].receive({"type": "game_state", "view": view, "history": [], "finalBoard": []})
	_frame()
	assert_eq(_label("%StatusLabel").text, "Green wins: Red resigned.")
	assert_false(_button("%ResignButton").visible)


func test_a_forfeit_is_narrated_in_french() -> void:
	_start_play()
	TranslationServer.set_locale("fr")
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	view["result"] = {"status": "red_wins", "reason": "forfeited"}
	_sockets[1].receive({"type": "game_state", "view": view, "history": [], "finalBoard": []})
	_frame()
	assert_eq(_label("%StatusLabel").text, "Rouge gagne : Vert est resté trop longtemps déconnecté.")
	TranslationServer.set_locale(Languages.ENGLISH)


func test_the_opponents_disconnection_shows_in_the_status() -> void:
	_start_play()
	_sockets[1].receive({"type": "opponent_presence", "connected": false})
	_frame()
	assert_eq(
		_label("%StatusLabel").text,
		"Your turn\nBob lost their connection. If they do not come back soon, they lose by Forfeit.",
	)
	_sockets[1].receive({"type": "opponent_presence", "connected": true})
	_frame()
	assert_eq(_label("%StatusLabel").text, "Your turn")


func test_an_opponent_who_left_on_their_turn_is_not_said_to_be_playing() -> void:
	_start_play()
	_sockets[1].receive({
		"type": "moved",
		"event": {"moverSide": "red", "move": _move(2, 3, 2, 4)},
		"view": _view("green", [_own(2, 4, "knight")], [_square(2, 5)]),
	})
	_sockets[1].receive({"type": "opponent_presence", "connected": false})
	_frame()
	assert_eq(
		_label("%StatusLabel").text,
		"Bob lost their connection. If they do not come back soon, they lose by Forfeit.",
	)


func test_a_lost_connection_offers_to_reconnect() -> void:
	_start_play()
	_sockets[1].close()
	_frame()
	assert_eq(_label("%StatusLabel").text, "Connection lost")
	assert_eq(_button("%ActionButton").text, "Reconnect")
	_button("%ActionButton").pressed.emit()
	assert_eq(_sockets[1].open_count, 2)


func test_the_menu_button_leaves_the_game() -> void:
	_start_play()
	watch_signals(_match)
	_button("%MenuButton").pressed.emit()
	assert_signal_emitted(_match, "menu_requested")
	assert_eq(_sockets[1].state(), WireSocket.State.CLOSED)


func _open_socket() -> WireSocket:
	var socket: FakeWireSocket = FakeWireSocket.new()
	_sockets.append(socket)
	return socket


func _enter(nickname: String) -> void:
	_nickname_edit().text = nickname
	_nickname_edit().text_changed.emit(nickname)
	_button("%EnterButton").pressed.emit()


func _in_lobby_with_bob() -> void:
	_sockets[0].receive({"type": "entered", "guestId": "g1"})
	_sockets[0].receive({"type": "guests", "guests": [{"guestId": "g2", "nickname": "Bob", "waiting": false}]})
	_frame()


func _guest_rows() -> Array[Node]:
	return _node("%GuestList").get_children()


func _row_label(row: Node) -> Label:
	var node: Node = row.get_child(0)
	assert_true(node is Label)
	return node


## The first button of a Lobby row.
func _row_button(row: Node) -> Button:
	var node: Node = row.get_child(1)
	assert_true(node is Button)
	return node


func _pair_and_arrange() -> void:
	_enter("Ada")
	_in_lobby_with_bob()
	_sockets[0].receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_frame()
	_sockets[1].receive({"type": "seated", "side": "red", "opponent": "Bob"})
	_sockets[1].receive({"type": "setup_status", "ownSetupDone": false, "opponentSetupDone": false})
	_frame()


## Play has started, Red to move, with Red's Knight on c4 and a Hidden Piece
## on c6.
func _start_play() -> void:
	_pair_and_arrange()
	_button("%ActionButton").pressed.emit()
	var view: Dictionary = _view("red", [_own(2, 3, "knight")], [_square(2, 5)])
	_sockets[1].receive({"type": "game_state", "view": view, "history": []})
	_frame()


func _frame() -> void:
	_match._process(0.016)


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


func _own(column: int, row: int, type: String) -> Dictionary:
	return {"square": _square(column, row), "type": type}


func _move(from_column: int, from_row: int, to_column: int, to_row: int) -> Dictionary:
	return {"from": _square(from_column, from_row), "to": _square(to_column, to_row)}


func _square(column: int, row: int) -> Dictionary:
	return {"column": column, "row": row}


func _resign_dialog() -> ConfirmationDialog:
	var node: Node = _match.get_node("%ResignDialog")
	assert_true(node is ConfirmationDialog)
	return node


func _panel() -> LobbyPanel:
	var node: Node = _match.get_node("%LobbyPanel")
	assert_true(node is LobbyPanel)
	return node


func _node(unique_name: String) -> Node:
	return _panel().get_node(unique_name)


func _control(unique_name: String) -> Control:
	var node: Node = _node(unique_name)
	assert_true(node is Control, unique_name)
	return node


func _chat_menu() -> PopupMenu:
	var node: Node = _match.get_node("%ChatMenu")
	assert_true(node is PopupMenu)
	return node


func _last_socket() -> FakeWireSocket:
	return _sockets[_sockets.size() - 1]


func _nickname_edit() -> LineEdit:
	var node: Node = _panel().get_node("%NicknameEdit")
	assert_true(node is LineEdit)
	return node


func _board_view() -> BoardView:
	var node: Node = _match.get_node("%BoardView")
	assert_true(node is BoardView)
	return node


func _button(unique_name: String) -> Button:
	var owner: Node = _panel() if _panel().has_node(unique_name) else _match
	var node: Node = owner.get_node(unique_name)
	assert_true(node is Button, unique_name)
	return node


func _label(unique_name: String) -> Label:
	var owner: Node = _panel() if _panel().has_node(unique_name) else _match
	var node: Node = owner.get_node(unique_name)
	assert_true(node is Label, unique_name)
	return node
