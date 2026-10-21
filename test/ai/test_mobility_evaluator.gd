extends GutTest
## The danger of running out of Pieces that can move. Boards are written from
## rank 8 down to rank 1.


func test_a_princess_walled_in_by_her_monsters_cannot_move() -> void:
	var game: Game = _game(["k....p", "......", "......", ".#..#.", ".#..#.", "......", "O.....", "PO...."])
	assert_eq(MobilityEvaluator.mobile_piece_count(game.board(), Side.Id.RED), 0)
	assert_eq(MobilityEvaluator.mobile_piece_count(game.board(), Side.Id.GREEN), 2)


func test_a_piece_next_to_an_enemy_it_may_attack_can_move() -> void:
	var game: Game = _game(["......", "......", "......", ".#..#.", ".#..#.", "......", "Os....", "PKO..."])
	assert_eq(MobilityEvaluator.mobile_piece_count(game.board(), Side.Id.RED), 1, "the King may attack b2")


func test_fewer_mobile_pieces_score_worse() -> void:
	var walled: Game = _game(["k....p", "......", "......", ".#..#.", ".#..#.", "......", "O.....", "PO...N"])
	var open: Game = _game(["k....p", "......", "......", ".#..#.", ".#..#.", "......", "......", "PO...N"])
	var evaluator: MobilityEvaluator = MobilityEvaluator.new(ZeroEvaluator.new(), 100)
	assert_eq(evaluator.evaluate(walled, Side.Id.RED), 50 - 100, "Red has 1 mover, Green 2")
	assert_eq(evaluator.evaluate(open, Side.Id.RED), 50 - 50, "the Princess can step out")
	assert_eq(evaluator.evaluate(walled, Side.Id.GREEN), 100 - 50)


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)


class ZeroEvaluator extends PositionEvaluator:
	func evaluate(_game: Game, _side: Side.Id) -> int:
		return 0
