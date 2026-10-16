class_name VictoryJudge
extends RefCounted
## Decides, after each Move, whether the game has ended.

const NO_FIGHT_PLY_LIMIT: int = 100


## [param game] is the state right after [param record] was played, with the
## turn already passed to the opponent.
static func judge(game: Game, record: MoveRecord) -> GameResult:
	var mover_side: Side.Id = record.mover.side
	if record.fight != null:
		for piece: Piece in record.fight.eliminated():
			if piece.type == PieceType.Id.PRINCESS:
				return GameResult.win(Side.opponent(piece.side), GameResult.Reason.PRINCESS_CAPTURED)
	if _princess_reached_enemy_home_row(game.board(), record):
		return GameResult.win(mover_side, GameResult.Reason.PRINCESS_REACHED_HOME_ROW)
	if game.legal_moves().is_empty():
		return GameResult.win(mover_side, GameResult.Reason.BLOCKED)
	if game.plies_without_fight() >= NO_FIGHT_PLY_LIMIT:
		return GameResult.draw(GameResult.Reason.NO_FIGHT_LIMIT)
	return GameResult.in_progress()


static func _princess_reached_enemy_home_row(board: Board, record: MoveRecord) -> bool:
	var mover: Piece = record.mover
	if mover.type != PieceType.Id.PRINCESS:
		return false
	if board.piece_at(record.move.to) != mover:
		return false
	return record.move.to.y == Board.home_row(Side.opponent(mover.side))
