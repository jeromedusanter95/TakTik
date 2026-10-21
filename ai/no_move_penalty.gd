class_name NoMovePenalty
extends MovePenalty
## Charges nothing.


func cost(_move: Move, _view: PlayerView) -> int:
	return 0
