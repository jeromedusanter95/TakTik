class_name SearchFrame
extends RefCounted
## One position of a MoveSearch whose Moves are still being tried: what a
## call of the recursive negamax would hold on the call stack.

var game: Game
## True while following tactical Moves past the horizon.
var is_tactical: bool
## The plies still to search below this position when not tactical, or the
## tactical Moves still to follow when tactical.
var depth: int
var alpha: int
var beta: int
var ply: int
var moves: Array[Move]
## The index of the next Move of [member moves] to try.
var next: int = 0
var best: int


func _init(
		frame_game: Game,
		tactical: bool,
		frame_depth: int,
		frame_alpha: int,
		frame_beta: int,
		frame_ply: int,
		frame_moves: Array[Move],
		frame_best: int,
) -> void:
	game = frame_game
	is_tactical = tactical
	depth = frame_depth
	alpha = frame_alpha
	beta = frame_beta
	ply = frame_ply
	moves = frame_moves
	best = frame_best


func is_exhausted() -> bool:
	return next >= moves.size()


## The Move whose answer is being searched.
func current_move() -> Move:
	return moves[next - 1]


## Takes in the score of [method current_move] for this position's side to
## move, and stops trying Moves once one is good enough to cut the search.
## Returns true on that cut.
func take_score(score: int) -> bool:
	best = maxi(best, score)
	alpha = maxi(alpha, score)
	if alpha < beta:
		return false
	next = moves.size()
	return true
