extends GutTest
## The Lobby as the client drives it, against a fake socket.

const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const SERVER_URL: String = "ws://referee.test"

var _socket: FakeWireSocket = null
var _lobby: LobbyClient = null


func before_each() -> void:
	_socket = FakeWireSocket.new()
	_lobby = LobbyClient.new(_socket)
	watch_signals(_lobby)
	_lobby.enter(SERVER_URL, "Ada")


func test_it_enters_the_lobby_with_the_nickname() -> void:
	assert_eq(_socket.opened_url, "ws://referee.test/lobby")
	assert_eq(_socket.last_sent(), {"type": "enter", "nickname": "Ada"})
	assert_false(_lobby.has_entered())


func test_it_lists_the_other_guests_once_entered() -> void:
	_entered_with_bob()
	assert_true(_lobby.has_entered())
	assert_eq(_lobby.guests().size(), 1)
	assert_eq(_lobby.guests()[0].nickname, "Bob")
	assert_signal_emitted(_lobby, "changed")


func test_quick_match_shows_this_guest_waiting() -> void:
	_entered_with_bob()
	_lobby.join_quick_match()
	assert_eq(_socket.last_sent(), {"type": "quick_match"})
	_socket.receive({"type": "quick_match", "waiting": true})
	_lobby.poll()
	assert_true(_lobby.is_waiting())
	_lobby.stop_waiting()
	assert_eq(_socket.last_sent(), {"type": "stop_waiting"})


func test_a_challenge_sent_is_remembered_until_it_ends() -> void:
	_entered_with_bob()
	_lobby.challenge("g2")
	assert_eq(_socket.last_sent(), {"type": "challenge", "guestId": "g2"})
	_socket.receive({"type": "challenge_sent", "guestId": "g2"})
	_lobby.poll()
	assert_eq(_lobby.challenged_guest().nickname, "Bob")
	_socket.receive({"type": "challenge_ended", "guestId": "g2", "reason": "declined"})
	_lobby.poll()
	assert_null(_lobby.challenged_guest())
	assert_signal_emitted_with_parameters(_lobby, "challenge_ended", ["Bob", "declined"])


func test_withdrawing_ones_own_challenge_is_not_announced() -> void:
	_entered_with_bob()
	_socket.receive({"type": "challenge_sent", "guestId": "g2"})
	_lobby.poll()
	_lobby.withdraw_challenge()
	assert_eq(_socket.last_sent(), {"type": "withdraw_challenge"})
	_socket.receive({"type": "challenge_ended", "guestId": "g2", "reason": "withdrawn"})
	_lobby.poll()
	assert_null(_lobby.challenged_guest())
	assert_signal_not_emitted(_lobby, "challenge_ended")


func test_challenges_received_wait_for_an_answer() -> void:
	_entered_with_bob()
	_socket.receive({"type": "challenged", "guestId": "g2", "nickname": "Bob"})
	_lobby.poll()
	assert_eq(_lobby.challengers().size(), 1)
	_lobby.answer_challenge("g2", false)
	assert_eq(_socket.last_sent(), {"type": "answer_challenge", "guestId": "g2", "accept": false})
	assert_eq(_lobby.challengers().size(), 0)


func test_a_challenger_withdrawing_is_announced() -> void:
	_entered_with_bob()
	_socket.receive({"type": "challenged", "guestId": "g2", "nickname": "Bob"})
	_socket.receive({"type": "challenge_ended", "guestId": "g2", "reason": "withdrawn"})
	_lobby.poll()
	assert_eq(_lobby.challengers().size(), 0)
	assert_signal_emitted_with_parameters(_lobby, "challenge_ended", ["Bob", "withdrawn"])


func test_it_hands_over_the_seat_and_closes_its_socket_when_paired() -> void:
	_entered_with_bob()
	_socket.receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_lobby.poll()
	assert_signal_emitted(_lobby, "paired")
	var seat: Variant = get_signal_parameters(_lobby, "paired")[0]
	assert_true(seat is PairedSeat)
	var paired_seat: PairedSeat = seat
	assert_eq(paired_seat.game_id, "g1")
	assert_eq(_socket.state(), WireSocket.State.CLOSED)
	assert_false(_lobby.is_active())
	_lobby.poll()
	assert_signal_not_emitted(_lobby, "failed")


func test_it_fails_with_the_reason_from_the_close_frame() -> void:
	_socket.close_from_server("invalid_nickname")
	_lobby.poll()
	assert_signal_emitted_with_parameters(_lobby, "failed", ["invalid_nickname"])


func test_it_fails_when_the_connection_drops() -> void:
	_socket.close()
	_lobby.poll()
	assert_signal_emitted_with_parameters(_lobby, "failed", [LobbyClient.CONNECTION_LOST])


func test_leaving_closes_the_socket_without_failing() -> void:
	_lobby.leave()
	_lobby.poll()
	assert_eq(_socket.state(), WireSocket.State.CLOSED)
	assert_signal_not_emitted(_lobby, "failed")


func test_nicknames_follow_the_servers_rules() -> void:
	assert_eq(Nickname.cleaned("  Ada  "), "Ada")
	assert_eq(Nickname.cleaned("é".repeat(Nickname.MAX_LENGTH)), "é".repeat(Nickname.MAX_LENGTH))
	assert_eq(Nickname.cleaned(""), "")
	assert_eq(Nickname.cleaned("   "), "")
	assert_eq(Nickname.cleaned("a".repeat(Nickname.MAX_LENGTH + 1)), "")
	assert_eq(Nickname.cleaned("Ad" + char(7) + "a"), "")
	assert_eq(Nickname.cleaned("Ada" + char(7)), "Ada", "edge control characters are trimmed away")
	assert_eq(Nickname.cleaned("A" + char(0x200B) + "da"), "")


func _entered_with_bob() -> void:
	_socket.receive({"type": "entered", "guestId": "g1"})
	_socket.receive({"type": "guests", "guests": [{"guestId": "g2", "nickname": "Bob", "waiting": false}]})
	_lobby.poll()
