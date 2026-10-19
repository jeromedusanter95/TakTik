class_name StepMovement
extends MovementRule
## Moves one Square forward, back, left or right.

var _can_attack: bool


func _init(can_attack: bool) -> void:
	_can_attack = can_attack


func destinations(from: Vector2i, board: Board, side: Side.Id) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var target: Vector2i = from + direction
		if not _is_walkable(target):
			continue
		if not board.has_piece(target):
			squares.append(target)
		elif _can_attack and _holds_enemy(board, target, side):
			squares.append(target)
	return squares


func reach() -> Reach:
	return Reach.ONE_SQUARE


func can_attack() -> bool:
	return _can_attack
