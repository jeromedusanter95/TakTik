extends GutTest


func test_red_sets_up_first_then_green_then_play_starts_with_red() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_eq(session.phase(), MatchSession.Phase.SETUP)
	assert_eq(session.active_side(), Side.Id.RED)
	session.confirm_setup()
	assert_eq(session.active_side(), Side.Id.GREEN)
	assert_eq(session.phase(), MatchSession.Phase.SETUP)
	session.confirm_setup()
	assert_eq(session.phase(), MatchSession.Phase.PLAYING)
	assert_eq(session.active_side(), Side.Id.RED)
	assert_not_null(session.game())


func test_during_red_setup_only_red_pieces_are_on_the_display_board() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_eq(session.display_board().squares_of(Side.Id.RED).size(), 18)
	assert_eq(session.display_board().squares_of(Side.Id.GREEN).size(), 0)


func test_swap_only_accepts_the_active_sides_setup_squares() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_true(session.swap_in_active_setup(Vector2i(0, 0), Vector2i(3, 2)))
	assert_false(session.swap_in_active_setup(Vector2i(0, 0), Vector2i(0, 7)))
	assert_true(session.active_setup().is_valid())


func test_playing_a_legal_move_passes_the_turn() -> void:
	var session: MatchSession = _session_in_play()
	var move: Move = session.game().legal_moves()[0]
	var record: MoveRecord = session.play(move)
	assert_not_null(record)
	assert_eq(session.last_record(), record)
	assert_eq(session.active_side(), Side.Id.GREEN)


func test_an_illegal_move_is_refused() -> void:
	var session: MatchSession = _session_in_play()
	assert_null(session.play(Move.new(Vector2i(0, 7), Vector2i(0, 6))))
	assert_eq(session.active_side(), Side.Id.RED)


func test_eliminated_pieces_go_to_their_sides_graveyard() -> void:
	var session: MatchSession = _session_in_play()
	var guard: int = 0
	while session.graveyard(Side.Id.RED).is_empty() and session.graveyard(Side.Id.GREEN).is_empty():
		var moves: Array[Move] = session.game().legal_moves()
		session.play(_first_attack_or_any(session.game(), moves))
		guard += 1
		if guard > 500 or session.phase() != MatchSession.Phase.PLAYING:
			break
	var lost: int = session.graveyard(Side.Id.RED).size() + session.graveyard(Side.Id.GREEN).size()
	assert_gt(lost, 0, "a Fight should have filled a graveyard")


func _first_attack_or_any(game: Game, moves: Array[Move]) -> Move:
	for move: Move in moves:
		if game.board().has_piece(move.to):
			return move
	return moves[0]


func _session_in_play() -> MatchSession:
	var session: MatchSession = MatchSession.new(_rng())
	session.confirm_setup()
	session.confirm_setup()
	return session


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	return rng
