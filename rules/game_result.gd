class_name GameResult
extends RefCounted
## Whether a game is still going, and if not, who won and why.

enum Status {
	IN_PROGRESS,
	RED_WINS,
	GREEN_WINS,
	DRAW,
}

enum Reason {
	NONE,
	PRINCESS_CAPTURED,
	PRINCESS_REACHED_HOME_ROW,
	BLOCKED,
	NO_FIGHT_LIMIT,
	## Online only: the loser gave the game away on purpose.
	RESIGNED,
	## Online only: the loser stayed disconnected too long.
	FORFEITED,
	## Online only: the loser ran out the Turn Timer, which is also a Forfeit.
	OUT_OF_TIME,
}

var status: Status:
	get:
		return _status
var reason: Reason:
	get:
		return _reason

var _status: Status
var _reason: Reason


func _init(result_status: Status, result_reason: Reason) -> void:
	_status = result_status
	_reason = result_reason


static func in_progress() -> GameResult:
	return GameResult.new(Status.IN_PROGRESS, Reason.NONE)


static func win(winner: Side.Id, why: Reason) -> GameResult:
	var winning: Status = Status.RED_WINS if winner == Side.Id.RED else Status.GREEN_WINS
	return GameResult.new(winning, why)


static func draw(why: Reason) -> GameResult:
	return GameResult.new(Status.DRAW, why)


func is_over() -> bool:
	return _status != Status.IN_PROGRESS
