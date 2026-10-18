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
	assert_eq(_label("%StatusLabel", _match).text, "Red: arrange your Army")
	_press_action()
	assert_eq(_label("%TitleLabel", _handoff()).text, "Pass the device to Green")
	_continue()
	assert_eq(_label("%StatusLabel", _match).text, "Green: arrange your Army")
	_press_action()
	_continue()
	assert_eq(_label("%StatusLabel", _match).text, "Red to move")
	assert_false(_button("%ActionButton").visible, "no button until a Move is played")


func test_a_move_ends_the_turn_and_hands_the_device_to_green() -> void:
	_play_through_setups()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	assert_eq(_label("%StatusLabel", _match).text, "Your turn is over")
	assert_true(_button("%ActionButton").visible)
	_press_action()
	assert_eq(_label("%TitleLabel", _handoff()).text, "Pass the device to Green")
	_continue()
	assert_eq(_label("%StatusLabel", _match).text, "Green to move")


func test_tapping_an_illegal_square_plays_nothing() -> void:
	_play_through_setups()
	_board_view().square_pressed.emit(Vector2i(0, 0))
	_board_view().square_pressed.emit(Vector2i(0, 7))
	assert_eq(_session.game().side_to_move(), Side.Id.RED)
	assert_eq(_label("%StatusLabel", _match).text, "Red to move")


func test_against_a_bot_red_sets_up_without_a_handoff_screen() -> void:
	_match.start(_create_bot_session)
	assert_false(_handoff().visible)
	assert_eq(_label("%StatusLabel", _match).text, "Red: arrange your Army")
	_press_action()
	assert_false(_handoff().visible)
	assert_eq(_label("%StatusLabel", _match).text, "Red to move")


func test_against_a_bot_the_bot_answers_each_move_and_red_reads_it() -> void:
	_match.start(_create_bot_session)
	_press_action()
	for turn: int in 4:
		if _session.phase() != MatchSession.Phase.PLAYING:
			break
		var move: Move = _session.game().legal_moves()[0]
		_board_view().square_pressed.emit(move.from)
		_board_view().square_pressed.emit(move.to)
		if _session.phase() != MatchSession.Phase.PLAYING:
			break
		assert_eq(_label("%StatusLabel", _match).text, "Green is thinking...")
		assert_false(_button("%ActionButton").visible)
		await wait_until(_is_persons_turn, 2.0)
		assert_true(_is_persons_turn(), "the Bot should have played")
		assert_false(_handoff().visible)
		assert_eq(_session.game().side_to_move(), Side.Id.RED)
		var bot_record: MoveRecord = _session.last_record()
		assert_eq(bot_record.mover.side, Side.Id.GREEN)
		assert_string_contains(
			_label("%InfoLabel", _match).text, MatchNarrator.describe_move(bot_record)
		)
		if _session.phase() == MatchSession.Phase.PLAYING:
			assert_eq(_label("%StatusLabel", _match).text, "Red to move")


func test_against_a_bot_taps_are_ignored_while_the_bot_thinks() -> void:
	_match.start(_create_bot_session)
	_match.minimum_bot_turn_seconds = 10.0
	_press_action()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	var green_square: Vector2i = _session.game().board().squares_of(Side.Id.GREEN)[0]
	_board_view().square_pressed.emit(green_square)
	assert_true(_session.is_bot_turn())
	assert_eq(_label("%StatusLabel", _match).text, "Green is thinking...")


func test_the_menu_button_asks_for_the_menu_and_stops_the_bot() -> void:
	_match.start(_create_bot_session)
	_match.minimum_bot_turn_seconds = 10.0
	_press_action()
	var move: Move = _session.game().legal_moves()[0]
	_board_view().square_pressed.emit(move.from)
	_board_view().square_pressed.emit(move.to)
	watch_signals(_match)
	_button("%MenuButton").pressed.emit()
	assert_signal_emitted(_match, "menu_requested")
	_match.minimum_bot_turn_seconds = 0.0
	await wait_process_frames(3)
	assert_true(_session.is_bot_turn(), "the Bot of a left game does not play on")


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


func _board_view() -> BoardView:
	var node: Node = _match.get_node("%BoardView")
	assert_true(node is BoardView)
	return node


func _label(path: String, owner_node: Node) -> Label:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Label, path)
	return node


func _button(path: String, owner_node: Node = _match) -> Button:
	var node: Node = owner_node.get_node(path)
	assert_true(node is Button, path)
	return node
