class_name BotProfile
extends Resource
## The tunable settings of one Difficulty.

## Translation key of the Difficulty name, for example "DIFFICULTY_EASY".
@export var display_name: String = ""
## How many Moves ahead each sampled world is searched (1 = only the Bot's
## own Move).
@export_range(1, 4) var search_depth: int = 1
## How many plausible arrangements of the Hidden Pieces are imagined per Move.
@export_range(1, 64) var sample_count: int = 1
## How many tactical Moves are followed past [member search_depth], including
## Attacks and immediate Princess wins (0 = none).
@export_range(0, 8) var attack_depth: int = 0
## The most positions one turn may search before deciding on the worlds it
## has fully searched, which bounds how long the Bot thinks.
@export_range(1_000, 200_000) var positions_per_turn: int = 12_000
## How the Bot arranges its Army; null shuffles it at random.
@export var setup_plan: SetupPlan = null
## Alternative plans of play. One is chosen when each game's Setup is arranged.
@export var strategies: Array[BotStrategy] = []
## Chance of playing a random legal Move instead of the best one.
@export_range(0.0, 1.0) var mistake_chance: float = 0.0
