extends GutTest
## Drives the real HomeScreen the way a Guest would: set a name, appear in the
## Lobby, Quick Match, Challenge and answer Challenges, with the server's
## messages fed through fake sockets.

const HomeScreenScene: PackedScene = preload("res://game/home/home_screen.tscn")
const FakeWireSocket: GDScript = preload("res://test/online/fake_wire_socket.gd")
const MemoryPreferenceStore: GDScript = preload("res://test/preferences/memory_preference_store.gd")
const SERVER_URL: String = "ws://referee.test"

var _home: HomeScreen = null
var _sockets: Array[FakeWireSocket] = []
var _store: MemoryPreferenceStore = null
var _preferences: PlayerPreferences = null


func before_each() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	_sockets.clear()
	_store = MemoryPreferenceStore.new()
	_preferences = PlayerPreferences.new(_store, "en", false)
	var instance: Node = HomeScreenScene.instantiate()
	if instance is not HomeScreen:
		fail_test("home_screen.tscn root should be a HomeScreen")
		return
	_home = instance
	add_child_autofree(_home)
	_home.configure(SERVER_URL, _open_socket)
	_home.use_preferences(_preferences)
	var profiles: Array[BotProfile] = [BotProfile.new(), BotProfile.new(), BotProfile.new()]
	_home.show_difficulties(profiles)
	watch_signals(_home)


func test_without_a_name_nobody_is_contacted() -> void:
	_home.open()
	assert_eq(_sockets.size(), 0)
	assert_eq(_label("%MessageLabel", _panel()).text, "Set your name to appear online.")


func test_a_saved_name_enters_the_lobby_at_once() -> void:
	_preferences.set_nickname("Ada")
	_home.open()
	assert_eq(_sockets[0].opened_url, "ws://referee.test/lobby")
	assert_eq(_sockets[0].last_sent(), {"type": "enter", "nickname": "Ada"})


func test_setting_a_name_saves_it_and_enters_the_lobby() -> void:
	_home.open()
	_type_name("  Ada ")
	assert_eq(_store.values["nickname"], "Ada")
	assert_eq(_sockets[0].last_sent(), {"type": "enter", "nickname": "Ada"})


func test_a_one_letter_name_is_refused_with_the_rule() -> void:
	_home.open()
	_type_name("A")
	assert_true(_label("%NameError", _home).visible)
	assert_eq(_label("%NameError", _home).text, "HOME_NAME_ERROR")
	assert_eq(_sockets.size(), 0)


func test_the_lobby_lists_you_first_then_the_others() -> void:
	_enter_with_guests([
		{"guestId": "g3", "nickname": "Zoe", "waiting": true},
		{"guestId": "g2", "nickname": "Bob", "waiting": false},
	])
	assert_eq(_row_names(), ["Ada", "Bob", "Zoe"] as Array[String])
	assert_false(_label("%MessageLabel", _panel()).visible, "the entering line is gone")
	assert_eq(_label("%CountLabel", _panel()).text, "3 players")


func test_guests_in_a_game_come_last_and_cannot_be_challenged() -> void:
	_enter_with_guests([
		{"guestId": "g2", "nickname": "Al", "waiting": false, "inGame": true},
		{"guestId": "g3", "nickname": "Bob", "waiting": false},
	])
	assert_eq(_row_names(), ["Ada", "Bob", "Al"] as Array[String])
	assert_true(_rows()[2].find_children("*", "Button", true, false).is_empty())
	assert_has(_row_texts(2), "In a game")


func test_a_challenge_to_a_guest_in_a_game_is_explained() -> void:
	_enter_with_guests([{"guestId": "g2", "nickname": "Bob", "waiting": false}])
	_row_button(1).pressed.emit()
	_sockets[0].receive({"type": "challenge_ended", "guestId": "g2", "reason": "busy"})
	_frame()
	assert_eq(_label("%MessageLabel", _panel()).text, "Bob is in a game.")


func test_nobody_else_online_explains_what_to_do() -> void:
	_enter_with_guests([])
	assert_true((_panel().get_node("%EmptyState") as Control).visible)


func test_quick_match_toggles_searching() -> void:
	_enter_with_guests([])
	_button("%QuickMatchButton").pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "quick_match"})
	_sockets[0].receive({"type": "quick_match", "waiting": true})
	_frame()
	assert_eq(_label("%QuickMatchTitle", _home).text, "Finding an opponent...")
	_button("%QuickMatchButton").pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "stop_waiting"})


func test_quick_match_without_a_name_asks_for_one() -> void:
	_home.open()
	_button("%QuickMatchButton").pressed.emit()
	assert_true(_label("%NameError", _home).visible)
	assert_eq(_sockets.size(), 0)


func test_challenging_shows_the_sent_challenge_and_disables_the_others() -> void:
	_enter_with_guests([
		{"guestId": "g2", "nickname": "Bob", "waiting": false},
		{"guestId": "g3", "nickname": "Cyd", "waiting": false},
	])
	_row_button(1).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "challenge", "guestId": "g2"})
	_sockets[0].receive({"type": "challenge_sent", "guestId": "g2"})
	_frame()
	assert_eq(_row_button(1).text, "Withdraw")
	assert_true(_row_button(2).disabled)
	_sockets[0].receive({"type": "challenge_ended", "guestId": "g2", "reason": "declined"})
	_frame()
	assert_eq(_label("%MessageLabel", _panel()).text, "Bob declined your Challenge.")


func test_a_received_challenge_shows_a_card_that_accepts() -> void:
	_enter_with_guests([{"guestId": "g2", "nickname": "Bob", "waiting": false}])
	_sockets[0].receive({"type": "challenged", "guestId": "g2", "nickname": "Bob"})
	_frame()
	var card: Control = _panel().get_node("%ChallengeCard")
	assert_true(card.visible)
	assert_eq(_label("%ChallengeTitle", _panel()).text, "Bob challenges you")
	_button("%AcceptButton", _panel()).pressed.emit()
	assert_eq(_sockets[0].last_sent(), {"type": "answer_challenge", "guestId": "g2", "accept": true})


func test_an_unanswered_challenge_is_declined_after_thirty_seconds() -> void:
	_enter_with_guests([{"guestId": "g2", "nickname": "Bob", "waiting": false}])
	_sockets[0].receive({"type": "challenged", "guestId": "g2", "nickname": "Bob"})
	_frame()
	_home._process(29.0)
	assert_eq(_label("%ChallengeExpiry", _panel()).text, "The Challenge expires in 0:01")
	_home._process(1.5)
	assert_eq(_sockets[0].last_sent(), {"type": "answer_challenge", "guestId": "g2", "accept": false})


func test_being_paired_hands_the_seat_on() -> void:
	_enter_with_guests([])
	_sockets[0].receive({"type": "paired", "gameId": "g1", "side": "red", "seatToken": "t1", "opponent": "Bob"})
	_frame()
	assert_signal_emitted(_home, "paired")
	var parameters: Array = get_signal_parameters(_home, "paired")
	var seat: Variant = parameters[0]
	assert_true(seat is PairedSeat)
	var paired_seat: PairedSeat = seat
	var nickname: String = parameters[1]
	assert_eq(paired_seat.game_id, "g1")
	assert_eq(nickname, "Ada")


func test_a_refused_name_is_explained() -> void:
	_preferences.set_nickname("Ada")
	_home.open()
	_sockets[0].close_from_server("invalid_nickname")
	_frame()
	assert_string_contains(_label("%MessageLabel", _panel()).text, "not allowed")
	assert_true(_label("%NameError", _home).visible)


func test_an_unreachable_server_offers_to_try_again() -> void:
	_preferences.set_nickname("Ada")
	_home.open()
	_sockets[0].close()
	_frame()
	assert_eq(_label("%MessageLabel", _panel()).text, "Could not reach the server. Try again in a moment.")
	assert_true(_button("%RetryButton", _panel()).visible)
	_button("%RetryButton", _panel()).pressed.emit()
	assert_eq(_sockets.size(), 2)


func test_a_local_game_leaves_the_lobby() -> void:
	_enter_with_guests([])
	_button("%TwoPlayersButton").pressed.emit()
	assert_signal_emitted(_home, "two_players_chosen")
	assert_eq(_sockets[0].state(), WireSocket.State.CLOSED)


func test_phones_switch_between_play_and_online() -> void:
	_home.set_phone(true)
	var tabs: SegmentedControl = _home.get_node("%PhoneTabs")
	assert_true(tabs.visible)
	assert_false(_panel().visible)
	tabs.option(1).pressed.emit()
	assert_true(_panel().visible)
	assert_false((_home.get_node("%LeftScroll") as Control).visible)


func _open_socket() -> WireSocket:
	var socket: FakeWireSocket = FakeWireSocket.new()
	_sockets.append(socket)
	return socket


func _frame() -> void:
	_home._process(0.016)


func _type_name(name: String) -> void:
	var edit: LineEdit = _home.get_node("%NameEdit")
	edit.text = name
	edit.text_submitted.emit(name)


func _enter_with_guests(guests: Array) -> void:
	_preferences.set_nickname("Ada")
	_home.open()
	_sockets[0].receive({"type": "entered", "guestId": "g1"})
	_sockets[0].receive({"type": "guests", "guests": guests})
	_frame()


func _panel() -> OnlinePanel:
	var node: Node = _home.get_node("%OnlinePanel")
	assert_true(node is OnlinePanel)
	return node


func _rows() -> Array[Node]:
	return _panel().get_node("%Rows").get_children()


func _row_names() -> Array[String]:
	var names: Array[String] = []
	for row: Node in _rows():
		var labels: Array[Node] = row.find_children("*", "Label", true, false)
		names.append((labels[0] as Label).text)
	return names


func _row_texts(index: int) -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _rows()[index].find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _row_button(index: int) -> Button:
	var buttons: Array[Node] = _rows()[index].find_children("*", "Button", true, false)
	assert_false(buttons.is_empty())
	return buttons[0]


func _label(path: String, owner_node: Node) -> Label:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Label, path)
	return node


func _button(path: String, owner_node: Node = null) -> Button:
	var node: Node = (owner_node if owner_node != null else _home).get_node(path)
	assert_true(node is Button, path)
	return node
