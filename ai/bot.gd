class_name Bot
extends RefCounted
## A computer opponent playing one side. It only ever receives a PlayerView
## and PublicMoveEvents, so it cannot see Hidden Pieces (ADR 0002).
##
## Contract used by the match screen:
## 0. [method arrange_setup] once, to place its Army.
## 1. [method begin] once, when play starts.
## 2. [method observe] after every Move, by either side.
## 3. On its turn, [method start_thinking], then call BotThinking.step() once
##    per frame until BotThinking.is_done(), then play
##    BotThinking.chosen_move().

var _profile: BotProfile
var _side: Side.Id
var _rng: RandomNumberGenerator
var _searcher: MoveSearcher
var _tracker: EnemyTracker = null


## [param evaluator] is replaceable to try other ways of scoring positions.
func _init(
		profile: BotProfile,
		side: Side.Id,
		rng: RandomNumberGenerator,
		evaluator: PositionEvaluator = HeuristicEvaluator.new(),
) -> void:
	_profile = profile
	_side = side
	_rng = rng
	_searcher = MoveSearcher.new(evaluator, profile.search_depth, profile.attack_depth)


func profile() -> BotProfile:
	return _profile


func side() -> Side.Id:
	return _side


## Draws on [param rng], the caller's, so a match can replay its Setups.
func arrange_setup(rng: RandomNumberGenerator) -> Setup:
	if _profile.setup_plan == null:
		return Setup.random(_side, rng)
	return _profile.setup_plan.arrange(_side, rng)


func begin(view: PlayerView) -> void:
	_tracker = EnemyTracker.new(view)


func observe(event: PublicMoveEvent) -> void:
	if _tracker != null:
		_tracker.observe(event)


func start_thinking(view: PlayerView) -> BotThinking:
	if _tracker == null:
		_tracker = EnemyTracker.new(view)
	var sampler: WorldSampler = WorldSampler.new(_tracker, _rng)
	if _rng.randf() < _profile.mistake_chance:
		return DecidedThinking.new(_random_move(sampler.sample(view)))
	return SampledSearchThinking.new(
		view, sampler, _searcher, _profile.sample_count, _profile.positions_per_turn, _rng
	)


func _random_move(world: Game) -> Move:
	var moves: Array[Move] = world.legal_moves()
	if moves.is_empty():
		return null
	return moves[_rng.randi_range(0, moves.size() - 1)]
