extends SceneTree
## Times Bot turns and plays Bot against Bot. Not a GUT test (no test_ prefix).
##
## Godot --headless --path . -s test/ai/bot_benchmark.gd -- timing [positions] [profiles...]
## Godot --headless --path . -s test/ai/bot_benchmark.gd -- match hard easy [games]
## Godot --headless --path . -s test/ai/bot_benchmark.gd -- match 3/8/0 hard [games] [first game]

const PROFILE_DIRECTORY: String = "res://ai/profiles/%s.tres"
const MAX_PLIES: int = 600

## Every turn's duration and the longest single step, per profile name,
## during matches, in milliseconds.
var _turn_times: Dictionary[String, PackedFloat64Array] = {}
var _longest_step: Dictionary[String, float] = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "timing":
		var names: PackedStringArray = args.slice(2) if args.size() > 2 else PackedStringArray(["easy", "medium", "hard"])
		_time_turns(int(args[1]) if args.size() >= 2 else 10, names)
	elif args.size() >= 3 and args[0] == "match":
		var first_game: int = int(args[4]) if args.size() >= 5 else 0
		_play_matches(args[1], args[2], int(args[3]) if args.size() >= 4 else 20, first_game)
	else:
		print("usage: -- timing [positions] | -- match <first> <second> [games]")
	quit()


func _time_turns(position_count: int, names: PackedStringArray) -> void:
	var positions: Array[Game] = []
	for index: int in position_count:
		positions.append(_position(index))
	for name: String in names:
		var profile: BotProfile = _search_only(_profile(name))
		var turn_times: PackedFloat64Array = PackedFloat64Array()
		var longest_step: float = 0.0
		for index: int in positions.size():
			var game: Game = positions[index]
			var bot: Bot = Bot.new(profile, game.side_to_move(), _rng(index))
			var view: PlayerView = PlayerView.of(game, game.side_to_move())
			bot.begin(view)
			var thinking: BotThinking = bot.start_thinking(view)
			var turn_start: int = Time.get_ticks_usec()
			while not thinking.is_done():
				var step_start: int = Time.get_ticks_usec()
				thinking.step()
				longest_step = maxf(longest_step, (Time.get_ticks_usec() - step_start) / 1000.0)
			turn_times.append((Time.get_ticks_usec() - turn_start) / 1000.0)
		turn_times.sort()
		print("%-8s turn ms: mean %.0f, median %.0f, max %.0f; longest step %.0f ms" % [
			name, _mean(turn_times), turn_times[turn_times.size() / 2], turn_times[-1], longest_step,
		])


## Plays games [param first_game] to [param first_game] + [param game_count]
## - 1, so several processes can share one long series.
func _play_matches(first_name: String, second_name: String, game_count: int, first_game: int) -> void:
	var first_wins: int = 0
	var second_wins: int = 0
	var draws: int = 0
	var plies_total: int = 0
	var reasons: Dictionary[String, int] = {}
	var start: int = Time.get_ticks_msec()
	for index: int in range(first_game, first_game + game_count):
		var first_side: Side.Id = Side.Id.RED if index % 2 == 0 else Side.Id.GREEN
		var outcome: Array[int] = _play_one(_profile(first_name), _profile(second_name), first_side, index)
		plies_total += outcome[1]
		var reason: String = "%s %s" % [
			["lost", "draw", "won"][outcome[0] + 1],
			GameResult.Reason.keys()[outcome[2]],
		]
		reasons[reason] = reasons.get(reason, 0) + 1
		print("game %d: %s" % [index, reason])
		match outcome[0]:
			1:
				first_wins += 1
			-1:
				second_wins += 1
			_:
				draws += 1
	print("%s vs %s over %d games: %d wins, %d losses, %d draws (mean %.0f plies, %.0f s)" % [
		first_name, second_name, game_count, first_wins, second_wins, draws,
		float(plies_total) / game_count, (Time.get_ticks_msec() - start) / 1000.0,
	])
	print("  %s by reason: %s" % [first_name, reasons])
	for name: String in _turn_times:
		var times: PackedFloat64Array = _turn_times[name]
		times.sort()
		print("  %s turn ms: mean %.0f, median %.0f, p95 %.0f, longest %.0f; longest step %.0f ms" % [
			name, _mean(times), times[times.size() / 2], times[int(times.size() * 0.95)],
			times[-1], _longest_step[name],
		])


## Returns [1 when the first Bot won, -1 when it lost, 0 for a draw, plies,
## GameResult.Reason].
func _play_one(first: BotProfile, second: BotProfile, first_side: Side.Id, seed_value: int) -> Array[int]:
	var bots: Dictionary[Side.Id, Bot] = {
		first_side: Bot.new(first, first_side, _rng(2_000 + seed_value)),
		Side.opponent(first_side): Bot.new(second, Side.opponent(first_side), _rng(3_000 + seed_value)),
	}
	var setup_rng: RandomNumberGenerator = _rng(1_000 + seed_value)
	var game: Game = GameFactory.from_setups(
		bots[Side.Id.RED].arrange_setup(setup_rng), bots[Side.Id.GREEN].arrange_setup(setup_rng)
	)
	for side: Side.Id in bots:
		bots[side].begin(PlayerView.of(game, side))
	var plies: int = 0
	while not game.result().is_over() and plies < MAX_PLIES:
		var mover: Bot = bots[game.side_to_move()]
		var record: MoveRecord = game.try_play(_timed_turn(mover, game))
		var event: PublicMoveEvent = PublicMoveEvent.of(record)
		for side: Side.Id in bots:
			bots[side].observe(event)
		plies += 1
	return [_score_for(game.result(), first_side), plies, game.result().reason]


func _timed_turn(bot: Bot, game: Game) -> Move:
	var name: String = Translated.text(bot.profile().display_name)
	var turn_start: int = Time.get_ticks_usec()
	var thinking: BotThinking = bot.start_thinking(PlayerView.of(game, bot.side()))
	while not thinking.is_done():
		var step_start: int = Time.get_ticks_usec()
		thinking.step()
		var step_ms: float = (Time.get_ticks_usec() - step_start) / 1000.0
		var longest_step: float = _longest_step.get(name, 0.0)
		_longest_step[name] = maxf(longest_step, step_ms)
	if not _turn_times.has(name):
		_turn_times[name] = PackedFloat64Array()
	_turn_times[name].append((Time.get_ticks_usec() - turn_start) / 1000.0)
	return thinking.chosen_move()


static func _score_for(result: GameResult, side: Side.Id) -> int:
	if result.status == GameResult.Status.RED_WINS:
		return 1 if side == Side.Id.RED else -1
	if result.status == GameResult.Status.GREEN_WINS:
		return 1 if side == Side.Id.GREEN else -1
	return 0


## A starting position for even indexes, a middle game position for odd ones.
func _position(index: int) -> Game:
	var rng: RandomNumberGenerator = _rng(500 + index)
	var game: Game = GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))
	if index % 2 == 1:
		for ply: int in 30:
			var moves: Array[Move] = game.legal_moves()
			if game.result().is_over() or moves.is_empty():
				break
			var record: MoveRecord = game.try_play(moves[rng.randi_range(0, moves.size() - 1)])
			if game.result().is_over():
				return GameFactory.from_setups(Setup.random(Side.Id.RED, rng), Setup.random(Side.Id.GREEN, rng))
			assert(record != null)
	return game


## The timing is about the search, so deliberate mistakes are switched off.
static func _search_only(profile: BotProfile) -> BotProfile:
	var copy: BotProfile = BotProfile.new()
	copy.search_depth = profile.search_depth
	copy.sample_count = profile.sample_count
	copy.attack_depth = profile.attack_depth
	copy.positions_per_turn = profile.positions_per_turn
	return copy


## [param name] is a profile file name ("hard") or an ad hoc
## "depth/samples/mistake_chance[/attack_depth[/positions_per_turn]]" such as
## "2/16/0.1" or "3/8/0/4/30000". Ad hoc profiles shuffle their Setup at
## random, so "3/8/0/4" is Hard before it guarded its Princess.
static func _profile(name: String) -> BotProfile:
	if name.contains("/"):
		var parts: PackedStringArray = name.split("/")
		var custom: BotProfile = BotProfile.new()
		custom.display_name = name
		custom.search_depth = int(parts[0])
		custom.sample_count = int(parts[1])
		custom.mistake_chance = float(parts[2])
		if parts.size() >= 4:
			custom.attack_depth = int(parts[3])
		if parts.size() >= 5:
			custom.positions_per_turn = int(parts[4])
		return custom
	var resource: Resource = load(PROFILE_DIRECTORY % name)
	if resource is not BotProfile:
		push_error("%s is not a BotProfile" % name)
		return BotProfile.new()
	return resource as BotProfile


static func _mean(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

