@abstract
class_name HiddenTypeChooser
extends RefCounted
## Gives every enemy Piece a Piece Type consistent with a Bot's memory: the
## types it remembers stay, the rest come from the unknown pool, and a Piece
## that has moved is never a Monster.


## One Piece Type per Square of [param view]'s enemy Pieces.
@abstract func choose(
		view: PlayerView,
		tracker: EnemyTracker,
		rng: RandomNumberGenerator,
) -> Dictionary[Vector2i, PieceType.Id]
