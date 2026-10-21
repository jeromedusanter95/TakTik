extends GutTest
## The cost of showing the opponent a Bot Piece it has not seen. The Bot
## plays Red (uppercase).


func test_an_attack_by_a_piece_the_opponent_has_not_seen_costs_part_of_its_value() -> void:
	var game: Game = _game(["......", "......", "......", ".#..#.", ".#..#.", "s.....", "K.....", ".....P"])
	var penalty: RevealPenalty = _penalty_for(game, 50)
	var cost: int = penalty.cost(_move("a2-a3"), PlayerView.of(game, Side.Id.RED))
	assert_eq(cost, HeuristicEvaluator.PIECE_VALUES[PieceType.Id.KING] / 2)


func test_a_quiet_step_reveals_nothing() -> void:
	var game: Game = _game(["......", "......", "......", ".#..#.", ".#..#.", "s.....", "K.....", ".....P"])
	var penalty: RevealPenalty = _penalty_for(game, 50)
	assert_eq(penalty.cost(_move("a2-b2"), PlayerView.of(game, Side.Id.RED)), 0)


func test_a_buffoon_crossing_several_squares_reveals_itself() -> void:
	var game: Game = _game(["......", "......", "......", ".#..#.", ".#..#.", "s.....", "B.....", ".....P"])
	var penalty: RevealPenalty = _penalty_for(game, 100)
	var cost: int = penalty.cost(_move("a2-d2"), PlayerView.of(game, Side.Id.RED))
	assert_eq(cost, HeuristicEvaluator.PIECE_VALUES[PieceType.Id.BUFFOON])


func test_a_piece_the_opponent_already_saw_is_free_to_attack_again() -> void:
	var game: Game = _game([".....p", "......", "......", ".#..#.", "e#..#.", "s.....", "K.....", ".....P"])
	var exposure: EnemyTracker = EnemyTracker.of_own_army(PlayerView.of(game, Side.Id.RED))
	var penalty: RevealPenalty = RevealPenalty.new(exposure, 50)
	_play(game, exposure, "a2-a3")
	_play(game, exposure, "f8-f7")
	assert_eq(penalty.cost(_move("a3-a4"), PlayerView.of(game, Side.Id.RED)), 0)


func _penalty_for(game: Game, percent: int) -> RevealPenalty:
	return RevealPenalty.new(EnemyTracker.of_own_army(PlayerView.of(game, Side.Id.RED)), percent)


func _play(game: Game, tracker: EnemyTracker, move_text: String) -> void:
	var record: MoveRecord = game.try_play(BoardNotation.parse_move(move_text))
	assert_not_null(record, "%s should be legal" % move_text)
	tracker.observe(PublicMoveEvent.of(record))


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)


func _move(text: String) -> Move:
	return BoardNotation.parse_move(text)
