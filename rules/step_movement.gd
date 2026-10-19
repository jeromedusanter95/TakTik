class_name StepMovement
extends MovementRule
## Moves one Square forward, back, left or right.

var _can_attack: bool


func _init(can_attack: bool) -> void:
	_can_attack = can_attack


func destinations(from: Vector2i, board: Board, side: Side.Id) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for target: Vector2i in Board.steps_from(from):
		var occupant: Piece = board.piece_at(target)
		if occupant == null or (_can_attack and occupant.side != side):
			squares.append(target)
	return squares


func reach() -> Reach:
	return Reach.ONE_SQUARE


func can_attack() -> bool:
	return _can_attack
