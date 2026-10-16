extends GutTest
## The searcher on fully known Games, Red to move.


func test_it_takes_a_princess_it_can_reach() -> void:
	var game: Game = _game(["k.....", "......", "......", ".#..#.", ".#p.#.", "..N...", "......", "K....."])
	for depth: int in [1, 2, 3]:
		assert_eq(_best_move(game, depth), "c3-c4", "depth %d" % depth)


func test_at_depth_two_it_does_not_trade_its_princess_for_a_soldier() -> void:
	# Taking d3 moves the Knight out of the Buffoon's line to the Princess.
	var game: Game = _game(["......", "......", "..b...", ".#..#.", ".#..#.", "..Ns..", "..P...", "......"])
	assert_eq(_best_move(game, 1), "c3-d3", "depth 1 falls for the lure")
	assert_ne(_best_move(game, 2), "c3-d3")


func test_it_prefers_a_faster_win() -> void:
	var game: Game = _game(["......", "..P...", "......", ".#..#.", ".#..#.", "......", "......", "....k."])
	assert_eq(_best_move(game, 3), "c7-c8")


func _best_move(game: Game, depth: int) -> String:
	var searcher: MoveSearcher = MoveSearcher.new(HeuristicEvaluator.new(), depth)
	var moves: Array[Move] = game.legal_moves()
	var scores: Array[int] = searcher.score_moves(game, moves)
	var best: int = 0
	for index: int in scores.size():
		if scores[index] > scores[best]:
			best = index
	var move: Move = moves[best]
	return "%s-%s" % [BoardNotation.format_square(move.from), BoardNotation.format_square(move.to)]


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)
