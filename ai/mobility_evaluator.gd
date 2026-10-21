class_name MobilityEvaluator
extends PositionEvaluator
## Adds to the underlying evaluation the danger of running out of Pieces
## that can move: a player with no legal Move is Blocked and loses, which
## often happens to a Princess walled in by her own Monsters once the last
## mobile Pieces fall. Material alone values those last Pieces like any
## other, so the danger is charged as the count of Pieces able to move drops.

## The penalty for a side with 0, 1, 2 or 3 Pieces able to move; more is
## safe.
const SHORTAGE_PENALTIES: Array[int] = [200, 100, 50, 25]

var _base: PositionEvaluator
var _percent: int


## [param percent] scales [constant SHORTAGE_PENALTIES].
func _init(base: PositionEvaluator, percent: int) -> void:
	_base = base
	_percent = percent


func evaluate(game: Game, side: Side.Id) -> int:
	var board: Board = game.board()
	var own: int = shortage_penalty(board, side)
	var enemy: int = shortage_penalty(board, Side.opponent(side))
	return _base.evaluate(game, side) + (enemy - own) * _percent / 100


static func shortage_penalty(board: Board, side: Side.Id) -> int:
	var movers: int = mobile_piece_count(board, side)
	if movers >= SHORTAGE_PENALTIES.size():
		return 0
	return SHORTAGE_PENALTIES[movers]


## How many of [param side]'s Pieces have a Square to step to: an empty one,
## or an enemy Piece they may Attack. The Move Back rule is ignored.
static func mobile_piece_count(board: Board, side: Side.Id) -> int:
	var count: int = 0
	for square: Vector2i in board.squares_of(side):
		var type: PieceType.Id = board.piece_at(square).type
		if type != PieceType.Id.MONSTER and _has_step(board, square, side, type):
			count += 1
	return count


static func _has_step(board: Board, square: Vector2i, side: Side.Id, type: PieceType.Id) -> bool:
	for target: Vector2i in Board.steps_from(square):
		var piece: Piece = board.piece_at(target)
		if piece == null:
			return true
		if piece.side != side and type != PieceType.Id.PRINCESS:
			return true
	return false
