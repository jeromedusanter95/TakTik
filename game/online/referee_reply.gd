class_name RefereeReply
extends RefCounted
## One message from an online game's socket.

enum Kind {
	SEATED,
	SETUP_STATUS,
	GAME_STATE,
	MOVED,
	REFUSED,
	MALFORMED,
}

var kind: Kind = Kind.MALFORMED
## SEATED: the side taken and the Opponent's nickname.
var side: Side.Id = Side.Id.RED
var opponent: String = ""
## SETUP_STATUS.
var own_setup_done: bool = false
var opponent_setup_done: bool = false
## GAME_STATE and MOVED: the game as this player now knows it.
var position: KnownPosition = null
## GAME_STATE: every Move so far.
var history: Array[PublicMoveEvent] = []
## MOVED: the Move just played.
var event: PublicMoveEvent = null
## GAME_STATE and MOVED once the game is over: every Piece left, Types shown.
## Null before.
var final_board: Board = null
## REFUSED: the server's reason, for example "illegal_move".
var refusal: String = ""
