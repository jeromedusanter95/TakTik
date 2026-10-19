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


func test_following_attacks_sees_a_capture_answered_by_a_recapture() -> void:
	# The Knight can take the Soldier, but the Executioner then takes the Knight.
	var game: Game = _game(["k....p", "......", "......", ".#e.#.", ".#s.#.", "..N...", "......", "K....P"])
	assert_eq(_best_move(game, 1), "c3-c4", "without following attacks it grabs the Soldier")
	assert_ne(_best_move(game, 1, 2), "c3-c4")


func test_following_attacks_still_counts_every_searched_position() -> void:
	var game: Game = _game(["k....p", "......", "......", ".#e.#.", ".#s.#.", "..N...", "......", "K....P"])
	var plain: MoveSearcher = MoveSearcher.new(HeuristicEvaluator.new(), 1)
	var following: MoveSearcher = MoveSearcher.new(HeuristicEvaluator.new(), 1, 2)
	plain.score_moves(game, game.legal_moves())
	following.score_moves(game, game.legal_moves())
	assert_gt(following.nodes_searched(), plain.nodes_searched())


func _best_move(game: Game, depth: int, attack_depth: int = 0) -> String:
	var searcher: MoveSearcher = MoveSearcher.new(HeuristicEvaluator.new(), depth, attack_depth)
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
