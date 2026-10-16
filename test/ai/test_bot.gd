extends GutTest
## The Bot through its public contract.

const PROFILE_PATHS: Array[String] = [
	"res://ai/profiles/easy.tres",
	"res://ai/profiles/medium.tres",
	"res://ai/profiles/hard.tres",
]


func test_every_difficulty_plays_a_legal_move() -> void:
	var game: Game = _starting_game()
	for path: String in PROFILE_PATHS:
		var move: Move = _bot_move(_profile(path), game, 7)
		assert_true(game.is_legal(move), path)


func test_a_hard_turn_is_spread_over_several_steps() -> void:
	var game: Game = _starting_game()
	var bot: Bot = Bot.new(_profile(PROFILE_PATHS[2]), Side.Id.RED, _rng(4))
	bot.begin(PlayerView.of(game, Side.Id.RED))
	var thinking: BotThinking = bot.start_thinking(PlayerView.of(game, Side.Id.RED))
	thinking.step()
	assert_false(thinking.is_done(), "one step should not search a whole Hard turn")
	while not thinking.is_done():
		thinking.step()
	assert_true(game.is_legal(thinking.chosen_move()))


func test_the_bot_never_peeks_at_hidden_pieces() -> void:
	# Identical to Red, but every Green Piece Type differs: a peeking Bot
	# would attack the Soldier next to its Knight and flee the Monster.
	var weak: Game = _game(["p...k.", "......", "......", ".#s.#.", ".#N.#.", "......", "......", "K....P"])
	var strong: Game = _game(["k...o.", "......", "......", ".#o.#.", ".#N.#.", "......", "......", "K....P"])
	for path: String in PROFILE_PATHS:
		for seed_value: int in [1, 2, 3]:
			var on_weak: Move = _bot_move(_profile(path), weak, seed_value)
			var on_strong: Move = _bot_move(_profile(path), strong, seed_value)
			assert_true(on_weak.equals(on_strong), "%s seed %d" % [path, seed_value])


func test_a_bot_remembers_a_reveal_after_the_screen_hides_it_again() -> void:
	# The Green Magician survived the Buffoon's Attack, so the Bot knows its
	# Soldier beats it, even though the screen shows a Hidden Piece again.
	var game: Game = _game(["......", ".....k", "......", ".#..#.", ".#..#.", "mS....", "B.....", ".....K"])
	var bot: Bot = Bot.new(_search_only_profile(), Side.Id.RED, _rng(1))
	bot.begin(PlayerView.of(game, Side.Id.RED))
	_play(game, bot, "a2-a3")
	_play(game, bot, "f7-f6")
	var move: Move = _think(bot, PlayerView.of(game, Side.Id.RED))
	assert_true(move.equals(BoardNotation.parse_move("b3-a3")))


func _bot_move(profile: BotProfile, game: Game, seed_value: int) -> Move:
	var bot: Bot = Bot.new(profile, Side.Id.RED, _rng(seed_value))
	bot.begin(PlayerView.of(game, Side.Id.RED))
	return _think(bot, PlayerView.of(game, Side.Id.RED))


func _play(game: Game, bot: Bot, move_text: String) -> void:
	var record: MoveRecord = game.try_play(BoardNotation.parse_move(move_text))
	assert_not_null(record, "%s should be legal" % move_text)
	bot.observe(PublicMoveEvent.of(record))


func _think(bot: Bot, view: PlayerView) -> Move:
	var thinking: BotThinking = bot.start_thinking(view)
	var steps: int = 0
	while not thinking.is_done() and steps < 1000:
		thinking.step()
		steps += 1
	return thinking.chosen_move()


func _search_only_profile() -> BotProfile:
	var profile: BotProfile = BotProfile.new()
	profile.search_depth = 2
	profile.sample_count = 4
	return profile


func _profile(path: String) -> BotProfile:
	var resource: Resource = load(path)
	if resource is not BotProfile:
		push_error("%s is not a BotProfile" % path)
		return BotProfile.new()
	return resource as BotProfile


func _game(rows: Array[String]) -> Game:
	return Game.new(BoardNotation.parse_board(rows), Side.Id.RED)


func _starting_game() -> Game:
	var rng: RandomNumberGenerator = _rng(9)
	return GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
