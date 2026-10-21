class_name SampledSearchThinking
extends BotThinking
## Imagines worlds one after the other, scores every legal Move in each, and
## once all worlds are searched picks the Move with the best total score
## (ADR 0002), drawing lots between equally good Moves. How the scores add up
## is the MoveScoreTally's job.
##
## Each step stops once it has searched about [constant NODES_PER_STEP]
## positions, so one frame never freezes the single threaded web build, while
## small searches still finish in a frame or two. A turn that has searched its
## position limit decides on the worlds it has fully searched, so rare crowded
## positions do not keep the player waiting.

const NODES_PER_STEP: int = 300

var _view: PlayerView
var _sampler: WorldSampler
var _searcher: MoveSearcher
var _worlds_left: int
var _score_cap: int
var _penalty: MovePenalty
var _rng: RandomNumberGenerator
var _turn_end: int
var _world: Game = null
var _world_scores: Array[int] = []
var _moves: Array[Move] = []
var _tally: MoveScoreTally = null
var _searched_worlds: int = 0
var _chosen: Move = null
var _is_done: bool = false


## Reads the number of worlds, the position limit and the score cap from
## [param profile]. [param penalty] charges each Move once per world.
func _init(
		view: PlayerView,
		sampler: WorldSampler,
		searcher: MoveSearcher,
		profile: BotProfile,
		rng: RandomNumberGenerator,
		penalty: MovePenalty,
) -> void:
	_view = view
	_sampler = sampler
	_searcher = searcher
	_worlds_left = maxi(profile.sample_count, 1)
	_score_cap = profile.world_score_cap
	_penalty = penalty
	_rng = rng
	_turn_end = searcher.nodes_searched() + profile.positions_per_turn


func step() -> void:
	var step_end: int = _searcher.nodes_searched() + NODES_PER_STEP
	while not _is_done and _searcher.nodes_searched() < step_end:
		_score_next_move()


func is_done() -> bool:
	return _is_done


func chosen_move() -> Move:
	return _chosen


func _score_next_move() -> void:
	if _searched_worlds > 0 and _searcher.nodes_searched() >= _turn_end:
		_finish()
		return
	if _world == null:
		_imagine_next_world()
		if _moves.is_empty():
			_finish()
			return
	_world_scores.append(_searcher.score_move(_world, _moves[_world_scores.size()]))
	if _world_scores.size() == _moves.size():
		_add_world_scores()


func _add_world_scores() -> void:
	_tally.add_world(_world_scores)
	_world = null
	_world_scores.clear()
	_searched_worlds += 1
	_worlds_left -= 1
	if _worlds_left == 0:
		_finish()


## A Bot's own legal Moves never depend on enemy Piece Types, so every world
## gives the same list; it is read from the first one.
func _imagine_next_world() -> void:
	_world = _sampler.sample(_view)
	if _tally == null:
		_moves = _world.legal_moves()
		var penalties: Array[int] = []
		for move: Move in _moves:
			penalties.append(_penalty.cost(move, _view))
		_tally = MoveScoreTally.new(penalties, _score_cap)


func _finish() -> void:
	_is_done = true
	if _tally == null:
		return
	var best: Array[int] = _tally.best_indexes()
	if not best.is_empty():
		_chosen = _moves[best[_rng.randi_range(0, best.size() - 1)]]
