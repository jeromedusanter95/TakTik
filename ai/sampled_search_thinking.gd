class_name SampledSearchThinking
extends BotThinking
## Imagines worlds one after the other, scores every legal Move in each, and
## once all worlds are searched picks the Move with the best total score
## (ADR 0002), drawing lots between equally good Moves. How the scores add up
## is the MoveScoreTally's job.
##
## Each step stops once it has searched [constant NODES_PER_STEP] positions,
## even in the middle of one Move's search (MoveSearch), so one frame never
## freezes the single threaded web build, while small searches still finish
## in a frame or two. Once the first world is fully searched, a turn that
## reaches its position limit stops at once and decides on the worlds it has
## fully searched, so rare crowded positions do not keep the player waiting.

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
var _search: MoveSearch = null
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
		_search_until(step_end)


func is_done() -> bool:
	return _is_done


func chosen_move() -> Move:
	return _chosen


## Searches the current Move until it is scored or [param step_end] is
## reached. A world left half searched at the turn's end is dropped.
func _search_until(step_end: int) -> void:
	var has_turn_limit: bool = _searched_worlds > 0
	if has_turn_limit and _searcher.nodes_searched() >= _turn_end:
		_finish()
		return
	if _world == null:
		_imagine_next_world()
		if _moves.is_empty():
			_finish()
			return
	if _search == null:
		_search = _searcher.begin_move(_world, _moves[_world_scores.size()])
	_searcher.advance(_search, mini(step_end, _turn_end) if has_turn_limit else step_end)
	if not _search.is_done():
		return
	_world_scores.append(_search.score())
	_search = null
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
