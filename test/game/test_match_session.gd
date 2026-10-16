extends GutTest
## Two people sharing the device, and a person against a Bot.


## Records what the session tells it, and otherwise plays like a real Bot.
class RecordingBot:
	extends Bot

	var begun_views: Array[PlayerView] = []
	var events: Array[PublicMoveEvent] = []

	func begin(view: PlayerView) -> void:
		begun_views.append(view)
		super.begin(view)

	func observe(event: PublicMoveEvent) -> void:
		events.append(event)
		super.observe(event)


func test_red_sets_up_first_then_green_then_play_starts_with_red() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_eq(session.phase(), MatchSession.Phase.SETUP)
	assert_eq(session.active_side(), Side.Id.RED)
	session.confirm_setup()
	assert_eq(session.active_side(), Side.Id.GREEN)
	assert_eq(session.phase(), MatchSession.Phase.SETUP)
	session.confirm_setup()
	assert_eq(session.phase(), MatchSession.Phase.PLAYING)
	assert_eq(session.active_side(), Side.Id.RED)
	assert_not_null(session.game())


func test_during_red_setup_only_red_pieces_are_on_the_display_board() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_eq(session.display_board().squares_of(Side.Id.RED).size(), 18)
	assert_eq(session.display_board().squares_of(Side.Id.GREEN).size(), 0)


func test_swap_only_accepts_the_active_sides_setup_squares() -> void:
	var session: MatchSession = MatchSession.new(_rng())
	assert_true(session.swap_in_active_setup(Vector2i(0, 0), Vector2i(3, 2)))
	assert_false(session.swap_in_active_setup(Vector2i(0, 0), Vector2i(0, 7)))
	assert_true(session.active_setup().is_valid())


func test_playing_a_legal_move_passes_the_turn() -> void:
	var session: MatchSession = _session_in_play()
	var move: Move = session.game().legal_moves()[0]
	var record: MoveRecord = session.play(move)
	assert_not_null(record)
	assert_eq(session.last_record(), record)
	assert_eq(session.active_side(), Side.Id.GREEN)


func test_an_illegal_move_is_refused() -> void:
	var session: MatchSession = _session_in_play()
	assert_null(session.play(Move.new(Vector2i(0, 7), Vector2i(0, 6))))
	assert_eq(session.active_side(), Side.Id.RED)


func test_eliminated_pieces_go_to_their_sides_graveyard() -> void:
	var session: MatchSession = _session_in_play()
	var guard: int = 0
	while session.graveyard(Side.Id.RED).is_empty() and session.graveyard(Side.Id.GREEN).is_empty():
		var moves: Array[Move] = session.game().legal_moves()
		session.play(_first_attack_or_any(session.game(), moves))
		guard += 1
		if guard > 500 or session.phase() != MatchSession.Phase.PLAYING:
			break
	var lost: int = session.graveyard(Side.Id.RED).size() + session.graveyard(Side.Id.GREEN).size()
	assert_gt(lost, 0, "a Fight should have filled a graveyard")


func test_against_a_bot_only_red_sets_up_and_the_bot_has_a_random_setup() -> void:
	var bot: RecordingBot = _green_bot()
	var session: MatchSession = _session_against(bot)
	assert_eq(session.human_sides(), [Side.Id.RED] as Array[Side.Id])
	assert_eq(session.active_side(), Side.Id.RED)
	assert_eq(session.display_board().squares_of(Side.Id.GREEN).size(), 18)
	session.confirm_setup()
	assert_eq(session.phase(), MatchSession.Phase.PLAYING)
	assert_eq(session.active_side(), Side.Id.RED, "the person moves first")
	assert_false(session.is_bot_turn())


func test_the_bot_receives_its_own_view_when_play_starts() -> void:
	var bot: RecordingBot = _green_bot()
	var session: MatchSession = _session_against(bot)
	assert_eq(bot.begun_views.size(), 0, "not during Setup")
	session.confirm_setup()
	assert_eq(bot.begun_views.size(), 1)
	assert_eq(bot.begun_views[0].side, Side.Id.GREEN)
	assert_eq(bot.begun_views[0].own_squares().size(), 18)


func test_the_bot_observes_every_move_of_both_sides() -> void:
	var bot: RecordingBot = _green_bot()
	var session: MatchSession = _session_against(bot)
	session.confirm_setup()
	var red_move: Move = session.game().legal_moves()[0]
	session.play(red_move)
	assert_true(session.is_bot_turn())
	var green_move: Move = _think(session)
	session.play(green_move)
	assert_eq(bot.events.size(), 2)
	assert_eq(bot.events[0].mover_side, Side.Id.RED)
	assert_true(bot.events[0].move.equals(red_move))
	assert_eq(bot.events[1].mover_side, Side.Id.GREEN)
	assert_true(bot.events[1].move.equals(green_move))


func test_an_illegal_move_is_not_shown_to_the_bot() -> void:
	var bot: RecordingBot = _green_bot()
	var session: MatchSession = _session_against(bot)
	session.confirm_setup()
	session.play(Move.new(Vector2i(0, 7), Vector2i(0, 6)))
	assert_eq(bot.events.size(), 0)


func test_the_bot_plays_only_legal_moves_for_a_whole_game() -> void:
	var session: MatchSession = _session_against(_green_bot())
	session.confirm_setup()
	var plies: int = 0
	while session.phase() == MatchSession.Phase.PLAYING and plies < 300:
		var move: Move = session.game().legal_moves()[0]
		if session.is_bot_turn():
			move = _think(session)
			assert_true(session.game().is_legal(move), "Bot Move %s" % _notation(move))
		assert_not_null(session.play(move))
		plies += 1
	assert_gt(plies, 10)


func test_there_is_nothing_to_think_about_on_the_persons_turn() -> void:
	var session: MatchSession = _session_against(_green_bot())
	session.confirm_setup()
	assert_null(session.start_bot_thinking())


func test_the_last_move_of_each_side_is_remembered() -> void:
	var session: MatchSession = _session_against(_green_bot())
	session.confirm_setup()
	var red_record: MoveRecord = session.play(session.game().legal_moves()[0])
	var green_record: MoveRecord = session.play(_think(session))
	assert_eq(session.last_record_of(Side.Id.RED), red_record)
	assert_eq(session.last_record_of(Side.Id.GREEN), green_record)
	assert_eq(session.last_record(), green_record)


func _think(session: MatchSession) -> Move:
	var thinking: BotThinking = session.start_bot_thinking()
	var steps: int = 0
	while not thinking.is_done() and steps < 10_000:
		thinking.step()
		steps += 1
	return thinking.chosen_move()


func _notation(move: Move) -> String:
	return "%s-%s" % [BoardNotation.format_square(move.from), BoardNotation.format_square(move.to)]


func _green_bot() -> RecordingBot:
	var profile: BotProfile = BotProfile.new()
	profile.display_name = "Test"
	return RecordingBot.new(profile, Side.Id.GREEN, _rng())


func _session_against(bot: Bot) -> MatchSession:
	var bots: Dictionary[Side.Id, Bot] = {bot.side(): bot}
	return MatchSession.new(_rng(), bots)


func _first_attack_or_any(game: Game, moves: Array[Move]) -> Move:
	for move: Move in moves:
		if game.board().has_piece(move.to):
			return move
	return moves[0]


func _session_in_play() -> MatchSession:
	var session: MatchSession = MatchSession.new(_rng())
	session.confirm_setup()
	session.confirm_setup()
	return session


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	return rng
