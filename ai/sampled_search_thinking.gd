class_name SampledSearchThinking
extends BotThinking
## Imagines one world per step, scores every legal Move in it, and once all
## worlds are searched picks the Move with the best total score (ADR 0002),
## drawing lots between equally good Moves.

var _view: PlayerView
var _sampler: WorldSampler
var _searcher: MoveSearcher
var _worlds_left: int
var _rng: RandomNumberGenerator
var _moves: Array[Move] = []
var _totals: Array[int] = []
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


func step() -> void:
	if _is_done:
		return
	var world: Game = _sampler.sample(_view)
	if _moves.is_empty():
		_start_with_moves_of(world)
	_add_scores(_searcher.score_moves(world, _moves))
	_worlds_left -= 1
	if _worlds_left == 0 or _moves.is_empty():
		_finish()


func is_done() -> bool:
	return _is_done


func chosen_move() -> Move:
	return _chosen


## A Bot's own legal Moves never depend on enemy Piece Types, so every world
## gives the same list.
func _start_with_moves_of(world: Game) -> void:
	_moves = world.legal_moves()
	_totals.resize(_moves.size())
	_totals.fill(0)


func _add_scores(scores: Array[int]) -> void:
	for index: int in scores.size():
		_totals[index] += scores[index]


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
