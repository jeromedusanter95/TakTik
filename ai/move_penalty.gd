@abstract
class_name MovePenalty
extends RefCounted
## A cost a Bot charges one of its own Moves on top of the searched score,
## for something the search cannot see.


@abstract func cost(move: Move, view: PlayerView) -> int
