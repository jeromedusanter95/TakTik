extends GutTest
## Game behaviour not covered by the shared rule cases of res://spec/rules/.


func test_changing_the_returned_legal_moves_does_not_change_the_game() -> void:
	var game: Game = _game()
	var count: int = game.legal_moves().size()
	game.legal_moves().clear()
	assert_eq(game.legal_moves().size(), count)


func test_legal_moves_follow_each_played_move() -> void:
	var game: Game = _game()
	game.legal_moves()
	game.try_play(BoardNotation.parse_move("a1-a2"))
	assert_eq(_texts(game.legal_moves()), ["e8-d8", "e8-e7", "e8-f8"], "Green to move")


func test_a_copy_lists_the_same_moves_and_then_plays_on_its_own() -> void:
	var game: Game = _game()
	var before: Array[String] = _texts(game.legal_moves())
	var copy: Game = game.duplicate_game()
	assert_eq(_texts(copy.legal_moves()), before)
	copy.try_play(BoardNotation.parse_move("a1-a2"))
	assert_eq(_texts(game.legal_moves()), before)


func test_a_side_with_moves_has_a_legal_move() -> void:
	var game: Game = _game()
	assert_true(game.has_legal_move())
	game.legal_moves()
	assert_true(game.has_legal_move(), "once the moves are listed")


func test_a_side_whose_pieces_cannot_move_has_no_legal_move() -> void:
	var rows: Array[String] = ["....k.", "......", "......", ".#..#.", ".#..#.", "......", "......", "O....."]
	var game: Game = Game.new(BoardNotation.parse_board(rows), Side.Id.RED)
	assert_false(game.has_legal_move())
	assert_eq(game.legal_moves().size(), 0)


func test_playing_a_listed_move_ends_as_trying_it_does() -> void:
	# The King takes the Princess, a Fight that ends the game.
	var rows: Array[String] = ["....k.", "......", "......", ".#..#.", ".#..#.", "......", "p.....", "K....."]
	var tried: Game = Game.new(BoardNotation.parse_board(rows), Side.Id.RED)
	var played: Game = tried.duplicate_game()
	var move: Move = BoardNotation.parse_move("a1-a2")
	var record: MoveRecord = played.play_legal(move)
	tried.try_play(move)
	assert_eq(record.fight.outcome, FightOutcome.Id.ATTACKER_WINS)
	assert_eq(played.result().status, tried.result().status)
	assert_eq(played.result().reason, GameResult.Reason.PRINCESS_CAPTURED)
	assert_eq(played.side_to_move(), tried.side_to_move())
	assert_eq(played.plies_without_fight(), tried.plies_without_fight())
	assert_true(played.last_move_of(Side.Id.RED).equals(move))


func test_playing_a_listed_quiet_move_passes_the_turn() -> void:
	var game: Game = _game()
	game.play_legal(BoardNotation.parse_move("a1-a2"))
	assert_eq(game.side_to_move(), Side.Id.GREEN)
	assert_eq(game.plies_without_fight(), 1)
	assert_eq(_texts(game.legal_moves()), ["e8-d8", "e8-e7", "e8-f8"])


func _game() -> Game:
	var rows: Array[String] = ["....k.", "......", "......", ".#..#.", ".#..#.", "......", "......", "K....."]
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)


func _texts(moves: Array[Move]) -> Array[String]:
	var texts: Array[String] = []
	for move: Move in moves:
		texts.append("%s-%s" % [BoardNotation.format_square(move.from), BoardNotation.format_square(move.to)])
	texts.sort()
	return texts
