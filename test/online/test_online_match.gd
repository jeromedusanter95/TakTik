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


func test_it_opens_on_the_nickname_entry_with_find_disabled() -> void:
	assert_true(_panel().visible)
	assert_true(_button("%FindButton").disabled)
	_nickname_edit().text = "Ada"
	_nickname_edit().text_changed.emit("Ada")
	assert_false(_button("%FindButton").disabled)


func test_finding_an_opponent_joins_quick_match() -> void:
	_find("Ada")
	assert_eq(_sockets.size(), 1)
	assert_eq(_sockets[0].opened_url, "ws://referee.test/quick-match")
	assert_eq(_sockets[0].last_sent(), {"type": "join", "nickname": "Ada"})
	assert_eq(_label("%MessageLabel").text, "Looking for an Opponent...")
	assert_true(_button("%CancelButton").visible)


func test_a_refused_nickname_is_explained() -> void:
	_find("Ada")
	_sockets[0].receive({"type": "refused", "reason": "invalid_nickname"})
	_frame()
	assert_true(_panel().visible)
	assert_string_contains(_label("%MessageLabel").text, "not allowed")


func test_an_unreachable_server_is_explained() -> void:
	_find("Ada")
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
	assert_eq(_button("%ActionButton").text, "Find a new Opponent")
	_button("%ActionButton").pressed.emit()
	assert_true(_panel().visible)


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


func _find(nickname: String) -> void:
	_nickname_edit().text = nickname
	_nickname_edit().text_changed.emit(nickname)
	_button("%FindButton").pressed.emit()


func _pair_and_arrange() -> void:
	_find("Ada")
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


func _panel() -> FindOpponentPanel:
	var node: Node = _match.get_node("%FindOpponentPanel")
	assert_true(node is FindOpponentPanel)
	return node


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
