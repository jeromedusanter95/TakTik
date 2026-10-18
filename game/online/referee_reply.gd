class_name RefereeReply
extends RefCounted
## One message from an online game's socket.

enum Kind {
	SEATED,
	SETUP_STATUS,
	GAME_STATE,
	MOVED,
	OPPONENT_PRESENCE,
	QUICK_CHAT,
	REMATCH_OFFERED,
	REMATCH_READY,
	REFUSED,
	MALFORMED,
}

## What a time left holds when the referee did not say.
const NO_TIMER: int = -1

var kind: Kind = Kind.MALFORMED
## SEATED: the side taken and the Opponent's nickname.
var side: Side.Id = Side.Id.RED
var opponent: String = ""
## SETUP_STATUS.
var own_setup_done: bool = false
var opponent_setup_done: bool = false
## SETUP_STATUS: how long the Setup Timer still ran when the referee sent it,
## or NO_TIMER when the referee did not say.
var setup_time_left_msec: int = NO_TIMER
## GAME_STATE and MOVED: the game as this player now knows it.
var position: KnownPosition = null
## GAME_STATE: every Move so far.
var history: Array[PublicMoveEvent] = []
## MOVED: the Move just played.
var event: PublicMoveEvent = null
## GAME_STATE and MOVED while play goes on: how long the player to move still
## had when the referee sent it, or NO_TIMER when the referee did not say.
var turn_time_left_msec: int = NO_TIMER
## GAME_STATE and MOVED once the game is over: every Piece left, Types shown.
## Null before.
var final_board: Board = null
## OPPONENT_PRESENCE: whether the Opponent has a connection to the game.
var opponent_connected: bool = true
## QUICK_CHAT: who sent it and which of QuickChat.MESSAGES it is.
var chat_side: Side.Id = Side.Id.RED
var chat_message: String = ""
## REMATCH_READY: this player's seat in the new game.
var rematch_seat: PairedSeat = null
## REFUSED: the server's reason, for example "illegal_move".
var refusal: String = ""
