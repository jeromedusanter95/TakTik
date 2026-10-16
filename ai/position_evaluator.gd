@abstract
class_name PositionEvaluator
extends RefCounted
## Scores a Game that is still in progress from one side's point of view:
## higher is better for [param side]. Finished games are scored by the
## MoveSearcher itself.


@abstract func evaluate(game: Game, side: Side.Id) -> int
