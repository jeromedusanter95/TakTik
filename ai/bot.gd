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
var _evaluator: PositionEvaluator
var _strategy: BotStrategy = null
var _tracker: EnemyTracker = null
## The opponent's memory of this Bot's Army.
var _exposure: EnemyTracker = null
var _reader: EnemyBehaviourReader = null


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
	_evaluator = evaluator
	if profile.threat_percent > 0:
		_evaluator = ThreatEvaluator.new(_evaluator, profile.threat_percent)
	if profile.mobility_percent > 0:
		_evaluator = MobilityEvaluator.new(_evaluator, profile.mobility_percent)
	_searcher = MoveSearcher.new(_evaluator, profile.search_depth, profile.attack_depth)


func profile() -> BotProfile:
	return _profile


func side() -> Side.Id:
	return _side


## Draws on [param rng], the caller's, so a match can replay its Setups.
func arrange_setup(rng: RandomNumberGenerator) -> Setup:
	_select_strategy(rng)
	var plan: SetupPlan = _setup_plan()
	if plan == null:
		return Setup.random(_side, rng)
	return plan.arrange(_side, rng)


func begin(view: PlayerView) -> void:
	if _strategy == null:
		_select_strategy(_rng)
	_tracker = EnemyTracker.new(view)
	_exposure = EnemyTracker.of_own_army(view)
	if _reads_behaviour():
		_reader = EnemyBehaviourReader.new(_tracker, _exposure, _profile.behaviour_evidence)


func observe(event: PublicMoveEvent) -> void:
	if _tracker == null:
		return
	if _reader != null:
		_reader.read(event)
	_tracker.observe(event)
	_exposure.observe(event)


func start_thinking(view: PlayerView) -> BotThinking:
	if _tracker == null:
		begin(view)
	var sampler: WorldSampler = WorldSampler.new(_tracker, _rng, _type_chooser())
	if _rng.randf() < _profile.mistake_chance:
		return DecidedThinking.new(_random_move(sampler.sample(view)))
	return SampledSearchThinking.new(view, sampler, _searcher, _profile, _rng, _move_penalty())


func _random_move(world: Game) -> Move:
	var moves: Array[Move] = world.legal_moves()
	if moves.is_empty():
		return null
	return moves[_rng.randi_range(0, moves.size() - 1)]


func _reads_behaviour() -> bool:
	return _profile.behaviour_evidence > 1.0


func _type_chooser() -> HiddenTypeChooser:
	if _reads_behaviour():
		return WeightedTypeChooser.new()
	return ShuffledTypeChooser.new()


func _move_penalty() -> MovePenalty:
	if _profile.reveal_cost_percent > 0:
		return RevealPenalty.new(_exposure, _profile.reveal_cost_percent)
	return NoMovePenalty.new()


func _select_strategy(rng: RandomNumberGenerator) -> void:
	if _profile.strategies.is_empty():
		return
	_strategy = _profile.strategies[rng.randi_range(0, _profile.strategies.size() - 1)]
	var evaluator: PositionEvaluator = _evaluator
	if _strategy.priorities != null:
		evaluator = StrategicEvaluator.new(evaluator, _strategy.priorities, _side)
	_searcher = MoveSearcher.new(evaluator, _profile.search_depth, _profile.attack_depth)


func _setup_plan() -> SetupPlan:
	if _strategy != null and _strategy.setup_plan != null:
		return _strategy.setup_plan
	return _profile.setup_plan
