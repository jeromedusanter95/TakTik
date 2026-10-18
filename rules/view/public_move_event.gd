class_name PublicMoveEvent
extends RefCounted
## What both players learn from a Move: which Squares it used and, when it
## caused a Fight, the two Revealed Piece Types and the outcome. Carries no
## Piece ids, which are private to the referee.

var mover_side: Side.Id:
	get:
		return _mover_side
var move: Move:
	get:
		return _move
var has_fight: bool:
	get:
		return _has_fight
## Only meaningful when [member has_fight] is true.
var attacker_type: PieceType.Id:
	get:
		return _attacker_type
## Only meaningful when [member has_fight] is true.
var defender_type: PieceType.Id:
	get:
		return _defender_type
## Only meaningful when [member has_fight] is true.
var outcome: FightOutcome.Id:
	get:
		return _outcome

var _mover_side: Side.Id
var _move: Move
var _has_fight: bool = false
var _attacker_type: PieceType.Id = PieceType.Id.KING
var _defender_type: PieceType.Id = PieceType.Id.KING
var _outcome: FightOutcome.Id = FightOutcome.Id.ATTACKER_WINS


## A Move onto an empty Square, as the online server reports it.
static func of_move(side: Side.Id, played: Move) -> PublicMoveEvent:
	var event: PublicMoveEvent = PublicMoveEvent.new()
	event._mover_side = side
	event._move = played
	return event


static func of(record: MoveRecord) -> PublicMoveEvent:
	var event: PublicMoveEvent = PublicMoveEvent.new()
	event._mover_side = record.mover.side
	event._move = record.move
	if record.fight != null:
		event._has_fight = true
		event._attacker_type = record.fight.attacker.type
		event._defender_type = record.fight.defender.type
		event._outcome = record.fight.outcome
	return event


## A copy of this event with the Reveal of the Fight it caused.
func with_fight(
		attacker: PieceType.Id,
		defender: PieceType.Id,
		fight_outcome: FightOutcome.Id,
) -> PublicMoveEvent:
	var event: PublicMoveEvent = PublicMoveEvent.of_move(_mover_side, _move)
	event._has_fight = true
	event._attacker_type = attacker
	event._defender_type = defender
	event._outcome = fight_outcome
	return event


## The Piece Types this event's Fight eliminated, by side. Empty without a
## Fight.
func eliminated_types() -> Dictionary[Side.Id, PieceType.Id]:
	var eliminated: Dictionary[Side.Id, PieceType.Id] = {}
	if not _has_fight:
		return eliminated
	var defender_side: Side.Id = Side.opponent(_mover_side)
	if _outcome != FightOutcome.Id.ATTACKER_WINS:
		eliminated[_mover_side] = _attacker_type
	if _outcome != FightOutcome.Id.DEFENDER_WINS:
		eliminated[defender_side] = _defender_type
	return eliminated
