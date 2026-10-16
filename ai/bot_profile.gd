class_name BotProfile
extends Resource
## The tunable settings of one Difficulty.

@export var display_name: String = ""
## How many Moves ahead each sampled world is searched (1 = only the Bot's
## own Move).
@export_range(1, 4) var search_depth: int = 1
## How many plausible arrangements of the Hidden Pieces are imagined per Move.
@export_range(1, 64) var sample_count: int = 1
## Chance of playing a random legal Move instead of the best one.
@export_range(0.0, 1.0) var mistake_chance: float = 0.0
