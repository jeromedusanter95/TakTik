class_name PositionPriorities
extends Resource
## Additional positional preferences, kept below the value of a won game.

@export_range(0, 4) var advancement_bonus: int = 0
@export_range(0, 4) var king_activity_bonus: int = 0
@export_range(0, 10) var princess_guard_bonus: int = 0
@export_range(0, 4) var princess_advance_penalty: int = 0
