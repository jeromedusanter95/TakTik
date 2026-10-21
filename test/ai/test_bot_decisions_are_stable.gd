extends GutTest
## Pins each Difficulty's chosen Move and searched position count on the
## timing benchmark's positions, so speed work cannot change how Bots play.
## The values were recorded before the search was made faster.

## [profile, position index, from, to, positions searched]
const DECISIONS: Array[Array] = [
	["easy", 0, Vector2i(2, 2), Vector2i(2, 3), 154],
	["easy", 1, Vector2i(5, 2), Vector2i(5, 3), 99],
	["easy", 2, Vector2i(3, 2), Vector2i(3, 3), 74],
	["easy", 3, Vector2i(0, 2), Vector2i(1, 2), 894],
	["easy", 4, Vector2i(5, 2), Vector2i(5, 5), 157],
	["easy", 5, Vector2i(2, 3), Vector2i(2, 4), 1637],
	["easy", 6, Vector2i(0, 2), Vector2i(0, 3), 72],
	["easy", 7, Vector2i(2, 4), Vector2i(2, 5), 642],
	["easy", 8, Vector2i(2, 2), Vector2i(2, 3), 130],
	["easy", 9, Vector2i(0, 2), Vector2i(0, 3), 852],
	["easy", 10, Vector2i(5, 2), Vector2i(5, 3), 71],
	["easy", 11, Vector2i(3, 2), Vector2i(4, 2), 907],
	["medium", 0, Vector2i(2, 2), Vector2i(2, 3), 856],
	["medium", 1, Vector2i(2, 2), Vector2i(2, 3), 450],
	["medium", 2, Vector2i(2, 2), Vector2i(2, 3), 308],
	["medium", 3, Vector2i(0, 2), Vector2i(1, 2), 4178],
	["medium", 4, Vector2i(2, 2), Vector2i(2, 3), 682],
	["medium", 5, Vector2i(5, 3), Vector2i(5, 4), 6298],
	["medium", 6, Vector2i(0, 2), Vector2i(0, 3), 367],
	["medium", 7, Vector2i(2, 4), Vector2i(2, 5), 3739],
	["medium", 8, Vector2i(3, 2), Vector2i(3, 3), 638],
	["medium", 9, Vector2i(4, 2), Vector2i(5, 2), 3446],
	["medium", 10, Vector2i(3, 2), Vector2i(3, 3), 252],
	["medium", 11, Vector2i(2, 3), Vector2i(2, 4), 3264],
	["hard", 0, Vector2i(2, 2), Vector2i(2, 3), 1414],
	["hard", 1, Vector2i(5, 2), Vector2i(5, 3), 726],
	["hard", 2, Vector2i(2, 2), Vector2i(2, 3), 493],
	["hard", 3, Vector2i(0, 2), Vector2i(1, 2), 9199],
	["hard", 4, Vector2i(2, 2), Vector2i(2, 3), 1033],
	["hard", 5, Vector2i(5, 3), Vector2i(5, 4), 12000],
	["hard", 6, Vector2i(5, 2), Vector2i(5, 3), 708],
	["hard", 7, Vector2i(5, 0), Vector2i(4, 0), 6711],
	["hard", 8, Vector2i(2, 2), Vector2i(2, 3), 992],
	["hard", 9, Vector2i(0, 2), Vector2i(0, 3), 7494],
	["hard", 10, Vector2i(3, 2), Vector2i(3, 3), 406],
	["hard", 11, Vector2i(2, 3), Vector2i(2, 4), 7367],
]


func test_every_difficulty_plays_and_searches_as_recorded() -> void:
	for decision: Array in DECISIONS:
		var name: String = decision[0]
		var index: int = decision[1]
		var expected_from: Vector2i = decision[2]
		var expected_to: Vector2i = decision[3]
		var expected_nodes: int = decision[4]
		var game: Game = _position(index)
		var bot: Bot = Bot.new(_without_mistakes(name), game.side_to_move(), _rng(index))
		var view: PlayerView = PlayerView.of(game, game.side_to_move())
		bot.begin(view)
		var thinking: BotThinking = bot.start_thinking(view)
		while not thinking.is_done():
			thinking.step()
		var label: String = "%s position %d" % [name, index]
		assert_eq(thinking.chosen_move().from, expected_from, label)
		assert_eq(thinking.chosen_move().to, expected_to, label)
		assert_eq(bot._searcher.nodes_searched(), expected_nodes, label)


static func _without_mistakes(name: String) -> BotProfile:
	var resource: Resource = load("res://ai/profiles/%s.tres" % name)
	if resource is not BotProfile:
		push_error("%s is not a BotProfile" % name)
		return BotProfile.new()
	var copy: BotProfile = (resource as BotProfile).duplicate()
	copy.mistake_chance = 0.0
	return copy


## The timing benchmark's positions: a start for even indexes, 30 random
## plies in for odd ones.
static func _position(index: int) -> Game:
	var rng: RandomNumberGenerator = _rng(500 + index)
	var game: Game = GameFactory.from_setups(
		Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng)
	)
	if index % 2 == 1:
		for ply: int in 30:
			var moves: Array[Move] = game.legal_moves()
			if game.result().is_over() or moves.is_empty():
				break
			game.try_play(moves[rng.randi_range(0, moves.size() - 1)])
			if game.result().is_over():
				return GameFactory.from_setups(
					Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng)
				)
	return game


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
