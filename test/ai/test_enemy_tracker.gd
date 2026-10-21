extends GutTest
## The Bot's memory follows every kind of PublicMoveEvent. Boards are written
## from rank 8 down to rank 1; the Bot plays Red (uppercase).


func test_at_the_start_every_enemy_is_unknown_and_unmoved() -> void:
	var game: Game = _game(Side.Id.RED, ["s.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "K....."])
	var tracker: EnemyTracker = _tracker_for(game)
	assert_eq(tracker.enemy_squares(), [_sq("a8")])
	assert_false(tracker.enemy_at(_sq("a8")).is_known())
	assert_false(tracker.enemy_at(_sq("a8")).has_moved())
	assert_eq(tracker.unknown_pool().size(), PieceType.army().size())


func test_an_enemy_step_moves_its_memory_and_marks_it_moved() -> void:
	var game: Game = _game(Side.Id.GREEN, ["......", "s.....", "......", ".#..#.", ".#..#.", "......", "......", "K....."])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a7-a6")
	assert_eq(tracker.enemy_squares(), [_sq("a6")])
	assert_true(tracker.enemy_at(_sq("a6")).has_moved())
	assert_false(tracker.enemy_at(_sq("a6")).is_known())


func test_an_enemy_crossing_several_squares_is_known_as_a_buffoon() -> void:
	var game: Game = _game(Side.Id.GREEN, ["......", "b.....", "......", ".#..#.", ".#..#.", "......", "......", "K....."])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a7-a5")
	assert_true(tracker.enemy_at(_sq("a5")).is_known())
	assert_eq(tracker.enemy_at(_sq("a5")).known_type(), PieceType.Id.BUFFOON)
	assert_eq(tracker.unknown_pool().count(PieceType.Id.BUFFOON), 3)


func test_an_enemy_winning_its_attack_stays_known_on_the_destination() -> void:
	var game: Game = _game(Side.Id.GREEN, ["......", "......", "......", ".#..#.", ".#..#.", "n.....", "S.....", ".....K"])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a3-a2")
	assert_eq(tracker.enemy_squares(), [_sq("a2")])
	assert_eq(tracker.enemy_at(_sq("a2")).known_type(), PieceType.Id.KNIGHT)
	assert_true(tracker.enemy_at(_sq("a2")).has_moved())
	assert_eq(tracker.graveyard(), [] as Array[PieceType.Id])


func test_an_enemy_losing_its_attack_goes_to_the_graveyard() -> void:
	var game: Game = _game(Side.Id.GREEN, ["......", "......", "......", ".#..#.", ".#..#.", "s.....", "K.....", "......"])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a3-a2")
	assert_eq(tracker.enemy_squares(), [] as Array[Vector2i])
	assert_eq(tracker.graveyard(), [PieceType.Id.SOLDIER] as Array[PieceType.Id])
	assert_eq(tracker.unknown_pool().count(PieceType.Id.SOLDIER), 2)


func test_an_enemy_beaten_by_our_attack_goes_to_the_graveyard() -> void:
	var game: Game = _game(Side.Id.RED, ["......", "......", "......", ".#..#.", ".#..#.", "s.....", "K.....", "......"])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a2-a3")
	assert_eq(tracker.enemy_squares(), [] as Array[Vector2i])
	assert_eq(tracker.graveyard(), [PieceType.Id.SOLDIER] as Array[PieceType.Id])


func test_an_enemy_surviving_our_attack_stays_known_and_unmoved() -> void:
	var game: Game = _game(Side.Id.RED, ["......", "......", "......", ".#..#.", ".#..#.", "n.....", "B.....", ".....K"])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a2-a3")
	assert_eq(tracker.enemy_at(_sq("a3")).known_type(), PieceType.Id.KNIGHT)
	assert_false(tracker.enemy_at(_sq("a3")).has_moved())
	assert_eq(tracker.unknown_pool().count(PieceType.Id.KNIGHT), 1)


func test_both_pieces_eliminated_send_the_enemy_to_the_graveyard() -> void:
	var game: Game = _game(Side.Id.RED, ["......", "......", "......", ".#..#.", ".#..#.", "s.....", "S.....", ".....K"])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a2-a3")
	assert_eq(tracker.enemy_squares(), [] as Array[Vector2i])
	assert_eq(tracker.graveyard(), [PieceType.Id.SOLDIER] as Array[PieceType.Id])


func test_our_simple_move_changes_nothing_about_the_enemy() -> void:
	var game: Game = _game(Side.Id.RED, ["s.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "K....."])
	var tracker: EnemyTracker = _tracker_for(game)
	_play(game, tracker, "a1-a2")
	assert_eq(tracker.enemy_squares(), [_sq("a8")])
	assert_false(tracker.enemy_at(_sq("a8")).has_moved())


func test_the_own_army_memory_learns_what_our_reveals_showed_the_opponent() -> void:
	var game: Game = _game(Side.Id.RED, ["......", "......", "......", ".#..#.", ".#..#.", "n.....", "K.....", ".....B"])
	var exposure: EnemyTracker = EnemyTracker.of_own_army(PlayerView.of(game, Side.Id.RED))
	assert_eq(exposure.enemy_squares(), [_sq("a2"), _sq("f1")])
	_play(game, exposure, "a2-a3")
	assert_eq(exposure.enemy_at(_sq("a3")).known_type(), PieceType.Id.KING)
	assert_false(exposure.enemy_at(_sq("f1")).is_known())


func test_the_own_army_memory_ignores_the_opponents_quiet_moves() -> void:
	var game: Game = _game(Side.Id.GREEN, ["s.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "K....."])
	var exposure: EnemyTracker = EnemyTracker.of_own_army(PlayerView.of(game, Side.Id.RED))
	_play(game, exposure, "a8-a7")
	assert_eq(exposure.enemy_squares(), [_sq("a1")])
	assert_false(exposure.enemy_at(_sq("a1")).has_moved())


func _game(first_to_move: Side.Id, rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), first_to_move)


func _tracker_for(game: Game) -> EnemyTracker:
	return EnemyTracker.new(PlayerView.of(game, Side.Id.RED))


func _play(game: Game, tracker: EnemyTracker, move_text: String) -> void:
	var record: MoveRecord = game.try_play(BoardNotation.parse_move(move_text))
	assert_not_null(record, "%s should be legal" % move_text)
	tracker.observe(PublicMoveEvent.of(record))


func _sq(text: String) -> Vector2i:
	return BoardNotation.parse_square(text)
