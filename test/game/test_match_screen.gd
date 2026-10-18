extends GutTest
## The shared game screen: its phone layout, the chat sheet and the end of
## game modal.

const MatchScreenScene: PackedScene = preload("res://game/match/match_screen.tscn")

var _screen: MatchScreen = null


func before_each() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	var instance: Node = MatchScreenScene.instantiate()
	if instance is not MatchScreen:
		fail_test("match_screen.tscn root should be a MatchScreen")
		return
	_screen = instance
	add_child_autofree(_screen)
	_screen.size = Vector2(390, 844)
	watch_signals(_screen)


func test_a_chip_in_the_phone_sheet_sends_its_quick_chat_and_keeps_it_open() -> void:
	_screen.set_phone(true)
	_screen.set_chat_enabled(true)
	var sheet: ChatSheet = _screen.get_node("%ChatSheet")
	_screen._open_chat_sheet()
	var chips: Node = _screen.get_node("%ChatPanel").get_node("%Chips")
	assert_true(sheet.body().is_ancestor_of(chips), "the chat moved into the sheet")
	var chip: Button = chips.get_child(1)
	chip.pressed.emit()
	assert_signal_emitted_with_parameters(_screen, "quick_chat_chosen", [QuickChat.MESSAGES[1]])
	assert_true(sheet.is_open())


func test_the_backdrop_closes_the_phone_sheet_once_it_is_in() -> void:
	_screen.set_phone(true)
	_screen.set_chat_enabled(true)
	var sheet: ChatSheet = _screen.get_node("%ChatSheet")
	_screen._open_chat_sheet()
	var backdrop: Control = sheet.get_node("%Backdrop")
	backdrop.gui_input.emit(_press())
	assert_true(sheet.is_open(), "a tap while it slides in is ignored")
	await wait_seconds(0.5)
	backdrop.gui_input.emit(_press())
	await wait_seconds(0.4)
	assert_false(sheet.is_open())


func test_phones_get_strips_and_large_screens_get_cards() -> void:
	_screen.set_phone(true)
	assert_true((_screen.get_node("%OpponentStrip") as Control).visible)
	assert_false((_screen.get_node("%LeftColumn") as Control).visible)
	_screen.set_phone(false)
	assert_false((_screen.get_node("%OpponentStrip") as Control).visible)
	assert_true((_screen.get_node("%LeftColumn") as Control).visible)


func test_an_opponent_message_raises_the_unread_count_on_phones() -> void:
	_screen.set_phone(true)
	_screen.set_chat_enabled(true)
	_screen.add_chat("Bob", "Hello!", false)
	var badge: Control = _screen.get_node("%TopBar").get_node("%UnreadBadge")
	assert_true(badge.visible)
	_screen._open_chat_sheet()
	assert_false(badge.visible)


func test_the_result_modal_leaves_the_chat_column_free() -> void:
	_screen.set_chat_enabled(true)
	var modal: Control = _screen.get_node("%ResultModal")
	assert_lt(modal.offset_right, -360.0)
	assert_eq(modal.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func _press() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func test_the_menu_button_opens_the_game_menu() -> void:
	var bar: Node = _screen.get_node("%TopBar")
	var button: Button = bar.get_node("%MenuButton")
	assert_true(button.is_visible_in_tree())
	button.pressed.emit()
	var menu: Control = _screen.get_node("%GameMenu")
	assert_true(menu.visible)


func test_a_fight_flies_the_loser_to_its_losses_tray() -> void:
	var event: PublicMoveEvent = PublicMoveEvent.of_move(
		Side.Id.RED, Move.new(Vector2i(1, 2), Vector2i(1, 3))
	).with_fight(PieceType.Id.KNIGHT, PieceType.Id.SOLDIER, FightOutcome.Id.ATTACKER_WINS)
	_screen.play_move(event)
	var flight: Control = _screen.get_node("%CaptureFlight")
	await wait_seconds(BoardMotion.FIGHT_SECONDS + 0.1)
	assert_eq(flight.get_child_count(), 1, "the beaten Soldier is in the air")
	await wait_seconds(CaptureFlight.FLIGHT_TIME + 0.2)
	assert_eq(flight.get_child_count(), 0, "and has landed")


func test_hiding_the_chat_drops_the_opponents_messages_for_this_game() -> void:
	_screen.set_chat_enabled(true)
	var menu: GameMenu = _screen.get_node("%GameMenu")
	menu.chat_hidden_changed.emit(true)
	_screen.add_chat("Bob", "Oops!", false)
	_screen.add_chat("You", "Thanks!", true)
	var panel: ChatPanel = _screen.get_node("%ChatPanel")
	var texts: Array[String] = []
	for label: Node in panel.get_node("%Messages").find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_false("Oops!" in texts)
	assert_true("Thanks!" in texts)
	_screen.clear_chat()
	_screen.add_chat("Bob", "Hello!", false)
	assert_eq(panel.message_count(), 1, "a new game shows them again")
