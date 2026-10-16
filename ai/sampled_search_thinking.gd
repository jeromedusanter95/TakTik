class_name SampledSearchThinking
extends BotThinking
## Imagines worlds one after the other, scores every legal Move in each, and
## once all worlds are searched picks the Move with the best total score
## (ADR 0002), drawing lots between equally good Moves.
##
## Each step stops once it has searched about [constant NODES_PER_STEP]
## positions, so one frame never freezes the single threaded web build, while
## small searches still finish in a frame or two. A turn that has searched
## [constant NODES_PER_TURN] positions decides on the worlds it has fully
## searched, so rare crowded positions do not keep the player waiting.

const NODES_PER_STEP: int = 300
const NODES_PER_TURN: int = 12_000

var _view: PlayerView
var _sampler: WorldSampler
var _searcher: MoveSearcher
var _worlds_left: int
var _rng: RandomNumberGenerator
var _turn_end: int
var _world: Game = null
var _world_scores: Array[int] = []
var _moves: Array[Move] = []
var _totals: Array[int] = []
var _searched_worlds: int = 0
var _chosen: Move = null
var _is_done: bool = false


func _init(
		view: PlayerView,
		sampler: WorldSampler,
		searcher: MoveSearcher,
		world_count: int,
		rng: RandomNumberGenerator,
) -> void:
	_view = view
	_sampler = sampler
	_searcher = searcher
	_worlds_left = maxi(world_count, 1)
	_rng = rng
	_turn_end = searcher.nodes_searched() + NODES_PER_TURN


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
	for index: int in _world_scores.size():
		_totals[index] += _world_scores[index]
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
	if _totals.is_empty():
		_moves = _world.legal_moves()
		_totals.resize(_moves.size())
		_totals.fill(0)


func _finish() -> void:
	_is_done = true
	var best: Array[int] = _best_indexes()
	if not best.is_empty():
		_chosen = _moves[best[_rng.randi_range(0, best.size() - 1)]]


func _best_indexes() -> Array[int]:
	var best: Array[int] = []
	for index: int in _totals.size():
		if best.is_empty() or _totals[index] > _totals[best[0]]:
			best = [index]
		elif _totals[index] == _totals[best[0]]:
			best.append(index)
	return best
