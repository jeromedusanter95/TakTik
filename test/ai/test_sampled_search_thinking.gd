extends GutTest
## Bounding the work of each step and of each turn at Very Hard's depth.

const DEPTH: int = 4
const ATTACK_DEPTH: int = 4
const MIDDLE_GAME_SEED: int = 12
const MIDDLE_GAME_PLIES: int = 20


func test_one_root_move_holds_more_positions_than_one_step() -> void:
	# Otherwise the other tests would not prove a split inside a Move.
	var game: Game = _middle_game()
	var searcher: MoveSearcher = _searcher()
	var largest: int = 0
	for move: Move in game.legal_moves():
		var before: int = searcher.nodes_searched()
		searcher.score_move(game, move)
		largest = maxi(largest, searcher.nodes_searched() - before)
	assert_gt(largest, SampledSearchThinking.NODES_PER_STEP * 2)


func test_a_step_at_depth_four_searches_at_most_its_share_of_positions() -> void:
	var searcher: MoveSearcher = _searcher()
	var thinking: SampledSearchThinking = _thinking(searcher, 2, 200_000)
	var steps: int = 0
	while not thinking.is_done():
		var before: int = searcher.nodes_searched()
		thinking.step()
		steps += 1
		assert_lte(
			searcher.nodes_searched() - before, SampledSearchThinking.NODES_PER_STEP + 1,
			"step %d" % steps,
		)
	assert_gt(steps, 3)
	assert_true(_middle_game().is_legal(thinking.chosen_move()))


func test_a_turn_stops_at_its_position_limit_inside_a_root_move() -> void:
	var first_world: MoveSearcher = _searcher()
	var one_world: SampledSearchThinking = _thinking(first_world, 1, 200_000)
	while not one_world.is_done():
		one_world.step()
	# The same seed imagines the same first world, which a turn always
	# finishes; the limit then falls inside the second world's first Move.
	var limit: int = first_world.nodes_searched() + SampledSearchThinking.NODES_PER_STEP / 2
	var searcher: MoveSearcher = _searcher()
	var thinking: SampledSearchThinking = _thinking(searcher, 1_000, limit)
	while not thinking.is_done():
		thinking.step()
	assert_lte(searcher.nodes_searched(), limit + 1)
	assert_true(_middle_game().is_legal(thinking.chosen_move()))


func _thinking(searcher: MoveSearcher, worlds: int, positions: int) -> SampledSearchThinking:
	var view: PlayerView = PlayerView.of(_middle_game(), Side.Id.RED)
	var profile: BotProfile = BotProfile.new()
	profile.search_depth = DEPTH
	profile.attack_depth = ATTACK_DEPTH
	profile.sample_count = worlds
	profile.positions_per_turn = positions
	var rng: RandomNumberGenerator = _rng(3)
	var sampler: WorldSampler = WorldSampler.new(EnemyTracker.new(view), rng)
	return SampledSearchThinking.new(view, sampler, searcher, profile, rng, NoMovePenalty.new())


func _searcher() -> MoveSearcher:
	return MoveSearcher.new(HeuristicEvaluator.new(), DEPTH, ATTACK_DEPTH)


## A crowded position after random Moves, Red to move, where one root
## Move's depth four search is large.
func _middle_game() -> Game:
	var rng: RandomNumberGenerator = _rng(MIDDLE_GAME_SEED)
	var game: Game = GameFactory.from_setups(
		Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng)
	)
	for ply: int in MIDDLE_GAME_PLIES:
		var moves: Array[Move] = game.legal_moves()
		game.try_play(moves[rng.randi_range(0, moves.size() - 1)])
	return game


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
