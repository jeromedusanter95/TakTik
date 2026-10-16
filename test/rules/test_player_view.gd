extends GutTest


func test_a_player_view_shows_own_types_and_only_enemy_squares() -> void:
	var game: Game = _game()
	var view: PlayerView = PlayerView.of(game, Side.Id.RED)
	assert_eq(view.own_squares().size(), 18)
	assert_eq(view.enemy_squares().size(), 18)
	for square: Vector2i in view.own_squares():
		assert_eq(view.own_type_at(square), game.board().piece_at(square).type)


func test_two_games_differing_only_in_hidden_types_give_identical_views() -> void:
	var first: Game = BoardNotation.parse_board_game(["p.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "S....."])
	var second: Game = BoardNotation.parse_board_game(["k.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "S....."])
	var first_view: PlayerView = PlayerView.of(first, Side.Id.RED)
	var second_view: PlayerView = PlayerView.of(second, Side.Id.RED)
	assert_eq(first_view.enemy_squares(), second_view.enemy_squares())
	assert_eq(first_view.own_squares(), second_view.own_squares())


func test_a_public_event_reveals_fight_types_but_no_piece_ids() -> void:
	var game: Game = BoardNotation.parse_board_game(["s.....", "......", "......", ".#..#.", ".#t.#.", "..N...", "......", "......"])
	var record: MoveRecord = game.try_play(BoardNotation.parse_move("c3-c4"))
	var event: PublicMoveEvent = PublicMoveEvent.of(record)
	assert_true(event.has_fight)
	assert_eq(event.attacker_type, PieceType.Id.KNIGHT)
	assert_eq(event.defender_type, PieceType.Id.THIEF)
	assert_eq(event.outcome, FightOutcome.Id.ATTACKER_WINS)
	assert_eq(event.mover_side, Side.Id.RED)


func test_duplicate_game_is_independent() -> void:
	var game: Game = _game()
	var copy: Game = game.duplicate_game()
	copy.try_play(copy.legal_moves()[0])
	assert_eq(game.side_to_move(), Side.Id.RED)
	assert_eq(copy.side_to_move(), Side.Id.GREEN)


func test_placeholder_bot_plays_a_legal_move() -> void:
	var game: Game = _game()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var bot: Bot = Bot.new(BotProfile.new(), Side.Id.RED, rng)
	bot.begin(PlayerView.of(game, Side.Id.RED))
	var thinking: BotThinking = bot.start_thinking(PlayerView.of(game, Side.Id.RED))
	while not thinking.is_done():
		thinking.step()
	assert_true(game.is_legal(thinking.chosen_move()))


func _game() -> Game:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	return GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))
