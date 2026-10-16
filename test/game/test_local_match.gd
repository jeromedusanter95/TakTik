extends GutTest
## Drives the real LocalMatch scene the way two players would.

const LocalMatchScene: PackedScene = preload("res://game/hot_seat/local_match.tscn")

var _match: LocalMatch = null
var _session: HotSeatSession = null


func before_each() -> void:
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


func _create_session() -> HotSeatSession:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	_session = HotSeatSession.new(rng)
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
