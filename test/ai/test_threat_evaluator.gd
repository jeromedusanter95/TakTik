extends GutTest
## The pending Attack of the side not to move. Boards are written from rank 8
## down to rank 1.


func test_a_hanging_piece_of_the_side_to_move_costs_part_of_its_value() -> void:
	# Red to move; Green's Executioner can take Red's Knight next turn.
	var game: Game = _game(["k.....", "......", "......", ".#..#.", ".#..#.", "..e...", "..N...", "K....P"])
	var plain: int = HeuristicEvaluator.new().evaluate(game, Side.Id.RED)
	var aware: int = ThreatEvaluator.new(HeuristicEvaluator.new(), 50).evaluate(game, Side.Id.RED)
	assert_eq(aware, plain - HeuristicEvaluator.PIECE_VALUES[PieceType.Id.KNIGHT] / 2)
	var green: int = ThreatEvaluator.new(HeuristicEvaluator.new(), 50).evaluate(game, Side.Id.GREEN)
	assert_eq(green, -aware, "the same position seen from Green")


func test_an_attack_that_would_lose_is_no_threat() -> void:
	var game: Game = _game(["k.....", "......", "......", ".#..#.", ".#..#.", "..s...", "..N...", "K....P"])
	assert_eq(ThreatEvaluator.best_attack_gain(game.board(), Side.Id.GREEN), 0)


func test_a_magician_threatens_a_monster_and_a_thief_threatens_a_king() -> void:
	var game: Game = _game(["k.....", "......", "......", ".#..#.", ".#..#.", "..m.t.", "..O.K.", "......"])
	var gain: int = ThreatEvaluator.best_attack_gain(game.board(), Side.Id.GREEN)
	assert_eq(gain, HeuristicEvaluator.PIECE_VALUES[PieceType.Id.KING])


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)
