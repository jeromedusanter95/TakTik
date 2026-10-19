extends GutTest

const STRATEGIES: Array[String] = ["aggressive", "balanced", "defensive"]


func test_aggressive_play_develops_the_king() -> void:
	assert_eq(_choose(_development_position(), "aggressive"), "c3-c4")


func test_defensive_play_brings_a_guard_back_to_the_princess() -> void:
	assert_eq(_choose(_development_position(), "defensive"), "f3-f2")


func test_balanced_play_develops_the_king_before_advancing_the_princess() -> void:
	assert_eq(_choose(_development_position(), "balanced"), "c3-c4")


func test_defensive_play_does_not_march_an_unprotected_princess_forward() -> void:
	var game: Game = _game([
		"kepooo", "nnssmm", "sbbbbt", ".#..#.", ".#..#.", "..K...", "......", "S....P",
	])
	assert_false(_choose(game, "defensive").begins_with("f1-"))


func test_defensive_play_still_treats_an_advancing_enemy_princess_as_a_threat() -> void:
	var game: Game = Game.new(BoardNotation.parse_board([
		"k.....", "......", "......", ".#..#.", ".#..#.", ".....p", "......", "P.K...",
	]), Side.Id.GREEN)
	var evaluator: PositionEvaluator = StrategicEvaluator.new(
		HeuristicEvaluator.new(), _strategy("defensive").priorities, Side.Id.RED
	)
	var before: int = evaluator.evaluate(game, Side.Id.RED)
	assert_not_null(game.try_play(BoardNotation.parse_move("f3-f2")))
	assert_lt(evaluator.evaluate(game, Side.Id.RED), before)


func test_a_style_respects_the_injected_evaluator() -> void:
	var profile: BotProfile = BotProfile.new()
	profile.strategies = [_strategy("aggressive")]
	var bot: Bot = Bot.new(profile, Side.Id.RED, _rng(1), SoldierAdvanceEvaluator.new())
	var view: PlayerView = PlayerView.of(_development_position(), Side.Id.RED)
	bot.begin(view)
	assert_eq(_finish_turn(bot, view), "f3-f4")


func test_each_style_keeps_opposite_scores_for_the_two_search_perspectives() -> void:
	for name: String in STRATEGIES:
		for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
			var evaluator: PositionEvaluator = StrategicEvaluator.new(
				HeuristicEvaluator.new(), _strategy(name).priorities, side
			)
			var game: Game = _development_position()
			assert_eq(
				evaluator.evaluate(game, Side.Id.RED), -evaluator.evaluate(game, Side.Id.GREEN), name
			)


func test_both_sides_can_develop_the_king_or_restore_a_princess_guard() -> void:
	var original: Board = _development_position().board()
	var mirrored: Board = Board.new()
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for square: Vector2i in original.squares_of(side):
			var piece: Piece = original.piece_at(square)
			mirrored.place(
				Piece.new(piece.id, piece.type, Side.opponent(side)),
				Vector2i(Board.COLUMNS - 1 - square.x, Board.ROWS - 1 - square.y),
			)
	var game: Game = Game.new(mirrored, Side.Id.GREEN)
	assert_eq(_choose(game, "aggressive"), "d6-d5")
	assert_eq(_choose(game, "defensive"), "a6-a7")


func test_every_style_plays_fairly_with_hidden_pieces() -> void:
	var weak: Game = _game([
		"p...k.", "......", "......", ".#s.#.", ".#N.#.", "......", "......", "K....P",
	])
	var strong: Game = _game([
		"k...o.", "......", "......", ".#o.#.", ".#N.#.", "......", "......", "K....P",
	])
	for name: String in STRATEGIES:
		assert_eq(_choose(weak, name), _choose(strong, name), name)


func test_every_style_keeps_its_intended_monster_guards_and_a_valid_army() -> void:
	var expected_guards: Dictionary[String, int] = {"aggressive": 1, "balanced": 2, "defensive": 3}
	for name: String in STRATEGIES:
		for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
			for seed_value: int in 20:
				var setup: Setup = _strategy(name).setup_plan.arrange(side, _rng(seed_value))
				assert_true(setup.is_valid(), name)
				var capacity: int = Board.steps_from(_princess_square(setup)).size()
				assert_eq(_monster_guards(setup), mini(expected_guards[name], capacity), name)


func test_every_style_takes_an_immediate_win() -> void:
	var game: Game = _game([
		"k.....", "......", "......", ".#..#.", ".#p.#.", "..K...", "......", ".....P",
	])
	for name: String in STRATEGIES:
		assert_eq(_search_move(game, name, 2), "c3-c4", name)


func test_every_style_still_wins_by_advancing_its_princess() -> void:
	var game: Game = _game([
		"......", "..P...", "......", ".#..#.", ".#..#.", "......", "......", "....k.",
	])
	for name: String in STRATEGIES:
		assert_eq(_search_move(game, name, 2), "c7-c8", name)


func test_every_style_protects_its_princess_over_a_material_gain() -> void:
	var game: Game = _game([
		"......", "......", "..b...", ".#..#.", ".#..#.", "..Ns..", "..P...", "......",
	])
	for name: String in STRATEGIES:
		assert_ne(_search_move(game, name, 2), "c3-d3", name)


func test_choosing_a_style_uses_the_callers_setup_rng() -> void:
	var profile_resource: Resource = load("res://ai/profiles/hard.tres")
	assert_true(profile_resource is BotProfile)
	if profile_resource is not BotProfile:
		return
	var profile: BotProfile = profile_resource as BotProfile
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var first: Setup = Bot.new(profile, side, _rng(1)).arrange_setup(_rng(7))
		var second: Setup = Bot.new(profile, side, _rng(99)).arrange_setup(_rng(7))
		for square: Vector2i in Setup.squares_for(side):
			assert_eq(first.type_at(square), second.type_at(square))


func test_begin_keeps_the_style_chosen_during_setup() -> void:
	var profile: BotProfile = BotProfile.new()
	profile.strategies = [_strategy("aggressive"), _strategy("defensive")]
	for seed_value: int in 12:
		var bot: Bot = Bot.new(profile, Side.Id.RED, _rng(seed_value + 100))
		var setup: Setup = bot.arrange_setup(_rng(seed_value))
		var guards: int = _monster_guards(setup)
		var view: PlayerView = PlayerView.of(_development_position(), Side.Id.RED)
		bot.begin(view)
		var expected: String = "c3-c4" if guards == 1 else "f3-f2"
		assert_eq(_finish_turn(bot, view), expected, "seed %d" % seed_value)
		assert_eq(_finish_turn(bot, view), expected, "the next turn keeps the style")


func _choose(game: Game, name: String) -> String:
	var profile: BotProfile = BotProfile.new()
	profile.strategies = [_strategy(name)]
	var bot: Bot = Bot.new(profile, game.side_to_move(), _rng(1))
	var view: PlayerView = PlayerView.of(game, game.side_to_move())
	bot.begin(view)
	return _finish_turn(bot, view)


func _finish_turn(bot: Bot, view: PlayerView) -> String:
	var thinking: BotThinking = bot.start_thinking(view)
	while not thinking.is_done():
		thinking.step()
	return _format_move(thinking.chosen_move())


func _search_move(game: Game, name: String, depth: int) -> String:
	var evaluator: PositionEvaluator = StrategicEvaluator.new(
		HeuristicEvaluator.new(), _strategy(name).priorities, game.side_to_move()
	)
	var searcher: MoveSearcher = MoveSearcher.new(evaluator, depth, 2)
	var moves: Array[Move] = game.legal_moves()
	var scores: Array[int] = searcher.score_moves(game, moves)
	var best: int = 0
	for index: int in scores.size():
		if scores[index] > scores[best]:
			best = index
	return _format_move(moves[best])


func _monster_guards(setup: Setup) -> int:
	var count: int = 0
	for neighbour: Vector2i in Board.steps_from(_princess_square(setup)):
		if setup.type_at(neighbour) == PieceType.Id.MONSTER:
			count += 1
	return count


func _princess_square(setup: Setup) -> Vector2i:
	for square: Vector2i in setup.squares():
		if setup.type_at(square) == PieceType.Id.PRINCESS:
			return square
	return Vector2i(-1, -1)


func _strategy(name: String) -> BotStrategy:
	var resource: Resource = load("res://ai/strategies/%s.tres" % name)
	assert_true(resource is BotStrategy, name)
	if resource is not BotStrategy:
		return BotStrategy.new()
	return resource as BotStrategy


func _development_position() -> Game:
	return _game([
		"kepooo", "nnssmm", "sbbbbt", ".#..#.", ".#..#.", "..K..S", "......", "....OP",
	])


func _game(rows: Array[String]) -> Game:
	return BoardNotation.parse_board_game(rows)


func _format_move(move: Move) -> String:
	return "%s-%s" % [BoardNotation.format_square(move.from), BoardNotation.format_square(move.to)]


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


class SoldierAdvanceEvaluator extends PositionEvaluator:
	func evaluate(game: Game, side: Side.Id) -> int:
		var piece: Piece = game.board().piece_at(BoardNotation.parse_square("f4"))
		if piece == null or piece.type != PieceType.Id.SOLDIER:
			return 0
		return 1_000 if piece.side == side else -1_000
