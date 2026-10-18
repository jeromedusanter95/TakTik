extends GutTest
## Quick Match as the client drives it, against a fake socket.

const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const SERVER_URL: String = "ws://referee.test"

var _socket: FakeWireSocket = null
var _search: QuickMatchSearch = null


func before_each() -> void:
	_socket = FakeWireSocket.new()
	_search = QuickMatchSearch.new(_socket)
	watch_signals(_search)
	_search.start(SERVER_URL, "Ada")


func test_it_joins_quick_match_with_the_nickname() -> void:
	assert_eq(_socket.opened_url, "ws://referee.test/quick-match")
	assert_eq(_socket.last_sent(), {"type": "join", "nickname": "Ada"})
	assert_true(_search.is_searching())


func test_it_reports_waiting() -> void:
	_socket.receive({"type": "waiting"})
	_search.poll()
	assert_signal_emitted(_search, "waiting_started")


func test_it_hands_over_the_seat_when_paired() -> void:
	_socket.receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_search.poll()
	assert_signal_emitted(_search, "paired")
	var seat: Variant = get_signal_parameters(_search, "paired")[0]
	assert_true(seat is PairedSeat)
	var paired_seat: PairedSeat = seat
	assert_eq(paired_seat.game_id, "g1")
	assert_false(_search.is_searching())


func test_the_server_closing_after_pairing_is_no_failure() -> void:
	_socket.receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_socket.close()
	_search.poll()
	_search.poll()
	assert_signal_not_emitted(_search, "failed")


func test_it_closes_its_socket_once_paired() -> void:
	_socket.receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_search.poll()
	assert_eq(_socket.state(), WireSocket.State.CLOSED)


func test_it_reads_the_reason_from_the_close_frame_when_the_message_is_lost() -> void:
	_socket.close_from_server("invalid_nickname")
	_search.poll()
	assert_signal_emitted_with_parameters(_search, "failed", ["invalid_nickname"])


func test_it_fails_with_the_servers_reason() -> void:
	_socket.receive({"type": "refused", "reason": "invalid_nickname"})
	_search.poll()
	assert_signal_emitted_with_parameters(_search, "failed", ["invalid_nickname"])
	assert_false(_search.is_searching())


func test_it_fails_when_the_connection_drops() -> void:
	_socket.close()
	_search.poll()
	assert_signal_emitted_with_parameters(_search, "failed", [QuickMatchSearch.CONNECTION_LOST])


func test_cancelling_closes_the_socket_without_failing() -> void:
	_search.cancel()
	_search.poll()
	assert_eq(_socket.state(), WireSocket.State.CLOSED)
	assert_signal_not_emitted(_search, "failed")


func test_nicknames_follow_the_servers_rules() -> void:
	assert_eq(Nickname.cleaned("  Ada  "), "Ada")
	assert_eq(Nickname.cleaned("é".repeat(Nickname.MAX_LENGTH)), "é".repeat(Nickname.MAX_LENGTH))
	assert_eq(Nickname.cleaned(""), "")
	assert_eq(Nickname.cleaned("   "), "")
	assert_eq(Nickname.cleaned("a".repeat(Nickname.MAX_LENGTH + 1)), "")
	assert_eq(Nickname.cleaned("Ad" + char(7) + "a"), "")
	assert_eq(Nickname.cleaned("Ada" + char(7)), "Ada", "edge control characters are trimmed away")
	assert_eq(Nickname.cleaned("A" + char(0x200B) + "da"), "")
