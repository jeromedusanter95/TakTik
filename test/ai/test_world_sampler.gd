extends GutTest
## Every imagined world matches what the Bot (Red) knows.

const SAMPLES: int = 40


func test_a_world_keeps_own_pieces_and_gives_the_enemy_a_whole_army() -> void:
	var game: Game = _starting_game(5)
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var world: Game = WorldSampler.new(EnemyTracker.new(view), _rng(1)).sample(view)
	for square: Vector2i in view.own_squares():
		assert_eq(world.board().piece_at(square).type, view.own_type_at(square))
	var enemy_squares: Array[Vector2i] = world.board().squares_of(Side.Id.GREEN)
	enemy_squares.sort()
	assert_eq(enemy_squares, view.enemy_squares())
	assert_eq(_sorted_types(world.board(), enemy_squares), _sorted_army())


func test_a_world_keeps_the_side_to_move_and_the_move_back_rule() -> void:
	var game: Game = _starting_game(5)
	game.try_play(game.legal_moves()[0])
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var world: Game = WorldSampler.new(EnemyTracker.new(view), _rng(1)).sample(view)
	assert_eq(world.side_to_move(), Side.Id.GREEN)
	assert_true(world.last_move_of(Side.Id.RED).equals(game.last_move_of(Side.Id.RED)))


func test_a_revealed_enemy_keeps_its_type_in_every_world() -> void:
	var game: Game = Game.new(BoardNotation.parse_board(["......", "......", "......", ".#..#.", ".#..#.", "n.....", "B.....", ".....K"]), Side.Id.RED)
	var tracker: EnemyTracker = EnemyTracker.new(PlayerView.of(game, Side.Id.RED))
	tracker.observe(PublicMoveEvent.of(game.try_play(BoardNotation.parse_move("a2-a3"))))
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var sampler: WorldSampler = WorldSampler.new(tracker, _rng(2))
	for i: int in SAMPLES:
		var world: Game = sampler.sample(view)
		assert_eq(world.board().piece_at(BoardNotation.parse_square("a3")).type, PieceType.Id.KNIGHT)


func test_a_piece_that_moved_is_never_imagined_as_a_monster() -> void:
	var game: Game = _starting_game(11)
	var tracker: EnemyTracker = EnemyTracker.new(PlayerView.of(game, Side.Id.RED))
	var moved_ids: Array[int] = _play_quiet_moves(game, tracker, 40, _rng(3))
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var moved_squares: Array[Vector2i] = _squares_of_ids(game.board(), moved_ids)
	assert_gt(moved_squares.size(), 3, "the scenario should move several enemy Pieces")
	var sampler: WorldSampler = WorldSampler.new(tracker, _rng(4))
	var monster_seen: bool = false
	for i: int in SAMPLES:
		var world: Game = sampler.sample(view)
		for square: Vector2i in moved_squares:
			assert_ne(world.board().piece_at(square).type, PieceType.Id.MONSTER)
		monster_seen = monster_seen or _types_of(world.board(), view.enemy_squares()).has(PieceType.Id.MONSTER)
		assert_eq(_sorted_types(world.board(), view.enemy_squares()), _sorted_army())
	assert_true(monster_seen, "unmoved Pieces may still be Monsters")


func test_the_same_seed_imagines_the_same_world() -> void:
	var game: Game = _starting_game(5)
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var first: Game = WorldSampler.new(EnemyTracker.new(view), _rng(8)).sample(view)
	var second: Game = WorldSampler.new(EnemyTracker.new(view), _rng(8)).sample(view)
	assert_eq(BoardNotation.format_board(first.board()), BoardNotation.format_board(second.board()))


## Plays [param plies] Moves without any Fight, telling [param tracker], and
## returns the ids of the enemy Pieces that moved.
func _play_quiet_moves(game: Game, tracker: EnemyTracker, plies: int, rng: RandomNumberGenerator) -> Array[int]:
	var moved_ids: Array[int] = []
	for i: int in plies:
		var quiet: Array[Move] = []
		for move: Move in game.legal_moves():
			if not game.board().has_piece(move.to):
				quiet.append(move)
		if quiet.is_empty():
			break
		var record: MoveRecord = game.try_play(quiet[rng.randi_range(0, quiet.size() - 1)])
		tracker.observe(PublicMoveEvent.of(record))
		if record.mover.side == Side.Id.GREEN and not moved_ids.has(record.mover.id):
			moved_ids.append(record.mover.id)
	return moved_ids


func _squares_of_ids(board: Board, ids: Array[int]) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for square: Vector2i in board.squares_of(Side.Id.GREEN):
		if ids.has(board.piece_at(square).id):
			squares.append(square)
	return squares


func _types_of(board: Board, squares: Array[Vector2i]) -> Array[PieceType.Id]:
	var types: Array[PieceType.Id] = []
	for square: Vector2i in squares:
		types.append(board.piece_at(square).type)
	return types


func _sorted_types(board: Board, squares: Array[Vector2i]) -> Array[PieceType.Id]:
	var types: Array[PieceType.Id] = _types_of(board, squares)
	types.sort()
	return types


func _sorted_army() -> Array[PieceType.Id]:
	var army: Array[PieceType.Id] = PieceType.army()
	army.sort()
	return army


func _starting_game(seed_value: int) -> Game:
	var rng: RandomNumberGenerator = _rng(seed_value)
	return GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
