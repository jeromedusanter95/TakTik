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
## Each imagined world's score for a Move is kept between -cap and cap, so a
## win or loss in one world cannot outweigh all the others (0 = no cap).
@export_range(0, 10_000) var world_score_cap: int = 0
## How much more likely the Bot finds an enemy Piece type that fits that
## Piece's Moves than one that does not (EnemyBehaviourReader). 1 ignores
## behaviour and shuffles the unknown types evenly.
@export_range(1.0, 10.0) var behaviour_evidence: float = 1.0
## The share, in percent, of a Bot Piece's value charged to a Move that shows
## its type to the opponent for the first time (RevealPenalty). 0 charges
## nothing.
@export_range(0, 100) var reveal_cost_percent: int = 0
## The share, in percent, of the opponent's best pending Attack that counts
## against the side to move at the search horizon (ThreatEvaluator). 0
## leaves the evaluation as it is.
@export_range(0, 100) var threat_percent: int = 0
## The share, in percent, of MobilityEvaluator's penalty for running out of
## Pieces able to move. 0 leaves the evaluation as it is.
@export_range(0, 200) var mobility_percent: int = 0
