extends GutTest
## What an enemy Piece's quiet Moves suggest about its type. The Bot plays
## Red (uppercase); boards are written from rank 8 down to rank 1.


func test_stepping_next_to_a_revealed_king_makes_weak_types_less_likely() -> void:
	# Red's King takes a3 in plain sight, then Green steps from c3 next to it.
	var game: Game = _game(["....p.", "......", "......", ".#..#.", ".#..#.", "s.n...", "K.....", ".....P"])
	var memory: Memories = Memories.new(game)
	memory.play(game, "a2-a3")
	memory.play(game, "c3-b3")
	var enemy: TrackedEnemy = memory.enemies.enemy_at(_sq("b3"))
	assert_eq(enemy.likelihood(PieceType.Id.THIEF), 1.0, "a Thief beats the King")
	assert_lt(enemy.likelihood(PieceType.Id.SOLDIER), 1.0, "a Soldier would be taken")
	assert_lt(enemy.likelihood(PieceType.Id.PRINCESS), 1.0)


func test_stepping_away_from_a_revealed_soldier_makes_strong_types_less_likely() -> void:
	# Red's Soldier takes a3 in plain sight, then Green steps from b3 away.
	var game: Game = _game(["....p.", "......", "......", ".#..#.", ".#..#.", "bn....", "S.....", ".....P"])
	var memory: Memories = Memories.new(game)
	memory.play(game, "a2-a3")
	memory.play(game, "b3-c3")
	var enemy: TrackedEnemy = memory.enemies.enemy_at(_sq("c3"))
	assert_eq(enemy.likelihood(PieceType.Id.BUFFOON), 1.0, "a Buffoon would be taken")
	assert_lt(enemy.likelihood(PieceType.Id.KNIGHT), 1.0, "a Knight had nothing to fear")


func test_moving_near_a_piece_the_opponent_never_saw_says_nothing() -> void:
	var game: Game = _game(["....p.", "......", "......", ".#..#.", ".#..#.", "..n...", "K.....", ".....P"])
	var memory: Memories = Memories.new(game)
	memory.play(game, "f1-f2")
	memory.play(game, "c3-b3")
	var enemy: TrackedEnemy = memory.enemies.enemy_at(_sq("b3"))
	for type: PieceType.Id in PieceType.Id.values():
		assert_eq(enemy.likelihood(type), 1.0)


func test_the_weighted_chooser_follows_the_likelihoods() -> void:
	var game: Game = Game.new(BoardNotation.parse_board([
		"......", "......", "......", ".#..#.", ".#..#.", "..n...", "......", "K....P",
	]), Side.Id.RED)
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var tracker: EnemyTracker = EnemyTracker.new(view)
	for type: PieceType.Id in PieceType.Id.values():
		if type != PieceType.Id.KNIGHT:
			tracker.enemy_at(_sq("c3")).weigh(type, 0.001)
	var chooser: WeightedTypeChooser = WeightedTypeChooser.new()
	var knights: int = 0
	for seed_value: int in 50:
		var types: Dictionary[Vector2i, PieceType.Id] = chooser.choose(view, tracker, _rng(seed_value))
		if types[_sq("c3")] == PieceType.Id.KNIGHT:
			knights += 1
	assert_gt(knights, 40)


func test_the_weighted_chooser_keeps_every_world_consistent() -> void:
	var rng: RandomNumberGenerator = _rng(3)
	var game: Game = GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))
	var tracker: EnemyTracker = EnemyTracker.new(PlayerView.of(game, Side.Id.RED))
	var moved: Array[int] = []
	for ply: int in 60:
		var quiet: Array[Move] = []
		for move: Move in game.legal_moves():
			if not game.board().has_piece(move.to):
				quiet.append(move)
		if quiet.is_empty():
			break
		var record: MoveRecord = game.try_play(quiet[rng.randi_range(0, quiet.size() - 1)])
		tracker.observe(PublicMoveEvent.of(record))
		if record.mover.side == Side.Id.GREEN and not moved.has(record.mover.id):
			moved.append(record.mover.id)
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	var chooser: WeightedTypeChooser = WeightedTypeChooser.new()
	var expected: Array[PieceType.Id] = PieceType.army()
	expected.sort()
	for seed_value: int in 40:
		var types: Dictionary[Vector2i, PieceType.Id] = chooser.choose(view, tracker, _rng(seed_value))
		var chosen: Array[PieceType.Id] = []
		for square: Vector2i in view.enemy_squares():
			chosen.append(types[square])
			if moved.has(game.board().piece_at(square).id):
				assert_ne(types[square], PieceType.Id.MONSTER)
		chosen.sort()
		assert_eq(chosen, expected)


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)


func _sq(text: String) -> Vector2i:
	return BoardNotation.parse_square(text)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The Bot's memory of Green, the opponent's memory of Red, and the reader
## between them, fed the way the Bot feeds them.
class Memories:
	extends RefCounted

	var enemies: EnemyTracker
	var exposure: EnemyTracker
	var reader: EnemyBehaviourReader

	func _init(game: Game) -> void:
		var view: PlayerView = PlayerView.of(game, Side.Id.RED)
		enemies = EnemyTracker.new(view)
		exposure = EnemyTracker.of_own_army(view)
		reader = EnemyBehaviourReader.new(enemies, exposure, 3.0)

	func play(game: Game, move_text: String) -> void:
		var event: PublicMoveEvent = PublicMoveEvent.of(game.try_play(BoardNotation.parse_move(move_text)))
		reader.read(event)
		enemies.observe(event)
		exposure.observe(event)
