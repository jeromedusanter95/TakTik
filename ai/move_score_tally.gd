class_name MoveScoreTally
extends RefCounted
## Adds up each Move's score over the imagined worlds and names the best
## Moves. A cap keeps one world's win or loss from outweighing every other
## world, and each Move may pay a fixed penalty in every world.

var _penalties: Array[int]
var _cap: int
var _totals: Array[int] = []


## [param penalties] holds one cost per Move, in the Moves' order.
## [param cap] limits each world's score to between -cap and cap; 0 keeps
## scores as searched.
func _init(penalties: Array[int], cap: int) -> void:
	_penalties = penalties
	_cap = cap
	_totals.resize(penalties.size())
	_totals.fill(0)


## [param scores] holds one world's score for every Move, in the same order.
func add_world(scores: Array[int]) -> void:
	for index: int in scores.size():
		_totals[index] += _capped(scores[index]) - _penalties[index]


## The indexes of the Moves with the highest total.
func best_indexes() -> Array[int]:
	var best: Array[int] = []
	for index: int in _totals.size():
		if best.is_empty() or _totals[index] > _totals[best[0]]:
			best = [index]
		elif _totals[index] == _totals[best[0]]:
			best.append(index)
	return best


func _capped(score: int) -> int:
	if _cap <= 0:
		return score
	return clampi(score, -_cap, _cap)
