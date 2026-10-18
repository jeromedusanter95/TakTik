extends GutTest
## Drives the real LocalMatch scene the way two people, or a person against a
## Bot, would.

const LocalMatchScene: PackedScene = preload("res://game/match/local_match.tscn")

var _match: LocalMatch = null
var _session: MatchSession = null


func before_each() -> void:
	TranslationServer.set_locale(Languages.ENGLISH)
	var instance: Node = LocalMatchScene.instantiate()
	if instance is not LocalMatch:
		fail_test("local_match.tscn root should be a LocalMatch")
		return
	_match = instance
	add_child_autofree(_match)
	_match.start(_create_session)


func test_the_game_opens_on_the_handoff_screen_for_red_setup() -> void:
	assert_true(_handoff().visible)
	assert_eq(_label("%TitleLabel", _handoff()).text, "Red, set up your Army")


func test_both_setups_then_red_sees_its_turn() -> void:
	_continue()
	assert_eq(_status(), "Red: arrange your Army")
	_press_action()
	assert_eq(_label("%TitleLabel", _handoff()).text, "Pass the device to Green")
	_continue()
	assert_eq(_status(), "Green: arrange your Army")
	_press_action()
	_continue()
	assert_eq(_status(), "Red to move")
	assert_false(_button("%ActionButton").visible, "no button until a Move is played")


func test_a_move_ends_the_turn_and_hands_the_device_to_green() -> void:
	_play_through_setups()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	assert_eq(_status(), "Your turn is over")
	assert_true(_button("%ActionButton").visible)
	_press_action()
	assert_eq(_label("%TitleLabel", _handoff()).text, "Pass the device to Green")
	_continue()
	assert_eq(_status(), "Green to move")


func test_tapping_an_illegal_square_plays_nothing() -> void:
	_play_through_setups()
	_board_view().square_pressed.emit(Vector2i(0, 0))
	_board_view().square_pressed.emit(Vector2i(0, 7))
	assert_eq(_session.game().side_to_move(), Side.Id.RED)
	assert_eq(_status(), "Red to move")


func test_against_a_bot_red_sets_up_without_a_handoff_screen() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	assert_false(_handoff().visible)
	assert_eq(_status(), "Arrange your Army")
	_press_action()
	assert_false(_handoff().visible)
	assert_eq(_status(), "Your turn")


func test_against_a_bot_the_bot_answers_each_move_and_red_reads_it() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	_press_action()
	for turn: int in 4:
		if _session.phase() != MatchSession.Phase.PLAYING:
			break
		var move: Move = _session.game().legal_moves()[0]
		_board_view().square_pressed.emit(move.from)
		_board_view().square_pressed.emit(move.to)
		if _session.phase() != MatchSession.Phase.PLAYING:
			break
		assert_eq(_status(), "Easy Bot is thinking...")
		assert_false(_button("%ActionButton").visible)
		await wait_until(_is_persons_turn, 2.0)
		assert_true(_is_persons_turn(), "the Bot should have played")
		assert_false(_handoff().visible)
		assert_eq(_session.game().side_to_move(), Side.Id.RED)
		var bot_record: MoveRecord = _session.last_record()
		assert_eq(bot_record.mover.side, Side.Id.GREEN)
		assert_eq(_board_view().state().last_move, bot_record.move, "the Bot's Move stays marked")
		if _session.phase() == MatchSession.Phase.PLAYING:
			assert_eq(_status(), "Your turn")


func test_against_a_bot_taps_are_ignored_while_the_bot_thinks() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	_match.minimum_bot_turn_seconds = 10.0
	_press_action()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	var green_square: Vector2i = _session.game().board().squares_of(Side.Id.GREEN)[0]
	_board_view().square_pressed.emit(green_square)
	assert_true(_session.is_bot_turn())
	assert_eq(_status(), "Easy Bot is thinking...")


func test_the_menu_button_asks_for_the_menu_and_stops_the_bot() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	_match.minimum_bot_turn_seconds = 10.0
	_press_action()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	watch_signals(_match)
	_button("%QuitButton").pressed.emit()
	assert_signal_emitted(_match, "menu_requested")
	_match.minimum_bot_turn_seconds = 0.0
	await wait_process_frames(3)
	assert_true(_session.is_bot_turn(), "the Bot of a left game does not play on")


func test_against_a_bot_setup_hides_the_bot_army_under_stripes() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	var state: BoardViewState = _board_view().state()
	assert_true(state.cover_enemy_zone)
	assert_eq(state.board.squares_of(Side.Id.GREEN).size(), 0)
	assert_eq(state.enemy_zone_label, "Easy Bot's zone · Pieces hidden")


func test_a_tapped_piece_shows_in_the_selected_card_during_setup() -> void:
	_match.start(_create_bot_session, "Easy Bot")
	var square: Vector2i = _session.active_setup().squares()[0]
	_board_view().square_pressed.emit(square)
	var card: Node = _screen().get_node("%SelectedPieceCard")
	var name_label: Label = card.get_node("%NameLabel")
	assert_eq(name_label.text, PieceNames.display_name(_session.active_setup().type_at(square)))


func _is_persons_turn() -> bool:
	return not _session.is_bot_turn()


func _create_bot_session() -> MatchSession:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	_match.minimum_bot_turn_seconds = 0.0
	var bots: Dictionary[Side.Id, Bot] = {
		Side.Id.GREEN: Bot.new(BotProfile.new(), Side.Id.GREEN, rng),
	}
	_session = MatchSession.new(rng, bots)
	return _session


func _create_session() -> MatchSession:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	_session = MatchSession.new(rng)
	return _session


func _play_through_setups() -> void:
	_continue()
	_press_action()
	_continue()
	_press_action()
	_continue()


func _continue() -> void:
	_button("%ContinueButton", _handoff()).pressed.emit()


func _press_action() -> void:
	_button("%ActionButton").pressed.emit()


func _handoff() -> HandoffScreen:
	var node: Node = _match.get_node("%HandoffScreen")
	assert_true(node is HandoffScreen)
	return node


func _screen() -> MatchScreen:
	var node: Node = _match.get_node("%MatchScreen")
	assert_true(node is MatchScreen)
	return node


func _status() -> String:
	var bar: Node = _screen().get_node("%TopBar")
	var label: Node = bar.get_node("%StatusLabel")
	assert_true(label is Label)
	return (label as Label).text


func _board_view() -> BoardView:
	var node: Node = _screen().get_node("%BoardView")
	assert_true(node is BoardView)
	return node


func _label(path: String, owner_node: Node) -> Label:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Label, path)
	return node


func _button(path: String, owner_node: Node = null) -> Button:
	var node: Node = (owner_node if owner_node != null else _screen()).get_node_or_null(path)
	if node == null:
		node = _screen().get_node("%GameMenu").get_node(path)
	assert_true(node is Button, path)
	return node
