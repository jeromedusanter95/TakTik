class_name StillMovement
extends MovementRule
## Never moves.


func destinations(_from: Vector2i, _board: Board, _side: Side.Id) -> Array[Vector2i]:
	return []


func reach() -> Reach:
	return Reach.NONE


func can_attack() -> bool:
	return false
