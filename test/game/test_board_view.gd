extends GutTest
## The Board fits its area, maps taps and keys to Squares, and plays Moves on
## copies of the Pieces.

const BoardViewScene: PackedScene = preload("res://game/board/board_view.tscn")

var _view: BoardView = null
var _pressed: Array[Vector2i] = []


func before_each() -> void:
	_pressed.clear()
	var instance: Node = BoardViewScene.instantiate()
	if instance is not BoardView:
		fail_test("board_view.tscn root should be a BoardView")
		return
	_view = instance
	_view.size = Vector2(600, 760)
	add_child_autofree(_view)
	_view.square_pressed.connect(_on_square_pressed)
	var state: BoardViewState = BoardViewState.new()
	state.board = GameFactory.from_setups(
		Setup.random(Side.Id.RED, _rng()), Setup.random(Side.Id.GREEN, _rng())
	).board()
	_view.show_state(state)


func test_squares_grow_to_the_limit_and_no_further() -> void:
	var roomy: BoardGeometry = BoardGeometry.new(Vector2(2000, 2000), 78.0, 40.0, Side.Id.RED)
	assert_eq(roomy.cell, 78.0)
	var tight: BoardGeometry = BoardGeometry.new(Vector2(400, 2000), 78.0, 40.0, Side.Id.RED)
	assert_lt(tight.cell, 78.0)
	assert_lte(tight.block_size().x, 400.0)


func test_the_board_is_centred_in_its_area() -> void:
	var geometry: BoardGeometry = BoardGeometry.new(Vector2(1000, 900), 78.0, 40.0, Side.Id.RED)
	var block: Vector2 = geometry.block_size()
	var left: float = geometry.frame_rect().position.x - BoardGeometry.RANK_LABEL_GAP - BoardGeometry.RANK_LABEL_WIDTH
	assert_almost_eq(left, floorf((1000.0 - block.x) / 2.0), 0.01)


func test_red_sees_a1_bottom_left() -> void:
	var geometry: BoardGeometry = BoardGeometry.new(Vector2(600, 760), 78.0, 40.0, Side.Id.RED)
	var a1: Rect2 = geometry.rect_of(Vector2i(0, 0))
	assert_eq(geometry.square_at(a1.get_center()), Vector2i(0, 0))
	assert_almost_eq(a1.end.y, geometry.squares_rect().end.y, 0.01)


func test_a_piece_is_its_square_less_twelve() -> void:
	var geometry: BoardGeometry = BoardGeometry.new(Vector2(2000, 2000), 78.0, 40.0, Side.Id.RED)
	assert_eq(geometry.piece_rect_of(Vector2i(2, 2)).size, Vector2(66, 66))


func test_a_tap_reports_the_square_under_it() -> void:
	var centre: Vector2 = _view.geometry().rect_of(Vector2i(3, 1)).get_center()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = centre
	_view._gui_input(click)
	assert_eq(_pressed, [Vector2i(3, 1)] as Array[Vector2i])


func test_enter_presses_the_square_under_the_cursor_after_arrows() -> void:
	_view._gui_input(_action(&"ui_right"))
	_view._gui_input(_action(&"ui_up"))
	_view._gui_input(_action(&"ui_accept"))
	assert_eq(_pressed, [Vector2i(1, 1)] as Array[Vector2i])


func test_arrows_wrap_around_the_board() -> void:
	_view._gui_input(_action(&"ui_left"))
	_view._gui_input(_action(&"ui_accept"))
	assert_eq(_pressed, [Vector2i(5, 0)] as Array[Vector2i])


func test_a_move_plays_on_copies_then_shows_the_square_again() -> void:
	var state: BoardViewState = _view.state()
	var piece: Piece = state.board.piece_at(Vector2i(0, 2))
	state.board.remove(Vector2i(0, 2))
	state.board.place(piece, Vector2i(0, 3))
	_view.show_state(state)
	_view.play_move(PublicMoveEvent.of_move(Side.Id.RED, Move.new(Vector2i(0, 2), Vector2i(0, 3))))
	assert_true(_view.is_animating())
	await wait_seconds(0.6)
	assert_false(_view.is_animating())
	assert_eq(_view.find_children("*", "PiecePicture", false, false).size(), 0)


func test_a_fight_plays_out_and_ends() -> void:
	var event: PublicMoveEvent = PublicMoveEvent.of_move(
		Side.Id.RED, Move.new(Vector2i(1, 2), Vector2i(1, 5))
	).with_fight(PieceType.Id.KNIGHT, PieceType.Id.SOLDIER, FightOutcome.Id.ATTACKER_WINS)
	_view.play_move(event)
	assert_true(_view.is_animating())
	await wait_seconds(2.0)
	assert_false(_view.is_animating())


func test_reduced_motion_plays_a_short_move() -> void:
	_view.reduced_motion = true
	_view.play_move(PublicMoveEvent.of_move(Side.Id.RED, Move.new(Vector2i(0, 2), Vector2i(0, 3))))
	await wait_seconds(0.3)
	assert_false(_view.is_animating())


func _action(name: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func _on_square_pressed(square: Vector2i) -> void:
	_pressed.append(square)


func test_a_shuffle_matches_pieces_of_a_type_in_square_order() -> void:
	var before: Board = Board.new()
	before.place(Piece.new(0, PieceType.Id.SOLDIER, Side.Id.RED), Vector2i(0, 0))
	before.place(Piece.new(1, PieceType.Id.KING, Side.Id.RED), Vector2i(1, 0))
	var after: Board = Board.new()
	after.place(Piece.new(0, PieceType.Id.KING, Side.Id.RED), Vector2i(0, 0))
	after.place(Piece.new(1, PieceType.Id.SOLDIER, Side.Id.RED), Vector2i(1, 0))
	var moves: Array[Move] = BoardMotion.shuffle_moves(before, after, Side.Id.RED)
	assert_eq(moves.size(), 2)
	assert_eq(moves[0].from, Vector2i(0, 0))
	assert_eq(moves[0].to, Vector2i(1, 0))
	assert_eq(moves[1].to, Vector2i(0, 0))


func test_a_shuffle_plays_then_shows_the_pieces_again() -> void:
	var before: Board = _view.state().board.duplicate_board()
	_view.play_shuffle(before)
	assert_true(_view.is_animating())
	await wait_seconds(1.0)
	assert_false(_view.is_animating())
