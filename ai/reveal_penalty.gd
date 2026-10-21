class_name RevealPenalty
extends MovePenalty
## Charges a Move that would show the opponent the type of one of the Bot's
## Pieces it has not seen yet: an Attack starts a Fight and its Reveal, and a
## Buffoon crossing several Squares gives itself away. The search imagines an
## opponent who already knows every Bot Piece, so it cannot value hiding them.

var _exposure: EnemyTracker
var _percent: int


## [param exposure] is the opponent's memory of the Bot's Army. The cost is
## [param percent] of the revealed Piece's value.
func _init(exposure: EnemyTracker, percent: int) -> void:
	_exposure = exposure
	_percent = percent


func cost(move: Move, view: PlayerView) -> int:
	if _exposure.enemy_at(move.from).is_known() or not _reveals(move, view):
		return 0
	var type: PieceType.Id = view.own_type_at(move.from)
	return HeuristicEvaluator.PIECE_VALUES[type] * _percent / 100


static func _reveals(move: Move, view: PlayerView) -> bool:
	var length: int = absi(move.to.x - move.from.x) + absi(move.to.y - move.from.y)
	return length > 1 or view.enemy_squares().has(move.to)
