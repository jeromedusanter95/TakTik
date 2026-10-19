class_name SlideMovement
extends MovementRule
## Crosses any number of empty Squares in a straight line and may Attack the
## first enemy Piece in that line.


func destinations(from: Vector2i, board: Board, side: Side.Id) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var target: Vector2i = from + direction
		while _is_walkable(target) and not board.has_piece(target):
			squares.append(target)
			target += direction
		if _is_walkable(target) and _holds_enemy(board, target, side):
			squares.append(target)
	return squares


func reach() -> Reach:
	return Reach.ANY_SQUARES


func can_attack() -> bool:
	return true
