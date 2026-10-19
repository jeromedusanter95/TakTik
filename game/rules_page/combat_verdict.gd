class_name CombatVerdict
extends RefCounted
## What the rules page simulator shows when one Piece Type attacks another:
## the same outcome as a Fight in the game, and which rule decided it.

enum Kind {
	NO_FIGHT,
	ATTACKER_WINS,
	DEFENDER_WINS,
	BOTH_ELIMINATED,
}

enum Reason {
	## The attacker is a Monster, which never moves.
	NEVER_MOVES,
	## The attacker moves but never attacks, as the Princess.
	NEVER_ATTACKS,
	MAGICIAN_KILLS_MONSTER,
	MONSTER_DEFENDS,
	STRONGER_ATTACK,
	STRONGER_DEFENSE,
	EQUAL,
}

var kind: Kind:
	get:
		return _kind
var reason: Reason:
	get:
		return _reason
## The defender is a Princess and she is eliminated: the attacker's side wins.
var princess_captured: bool:
	get:
		return _princess_captured

var _kind: Kind
var _reason: Reason
var _princess_captured: bool


func _init(verdict_kind: Kind, verdict_reason: Reason, captured: bool) -> void:
	_kind = verdict_kind
	_reason = verdict_reason
	_princess_captured = captured


static func judge(attacker: PieceType.Id, defender: PieceType.Id) -> CombatVerdict:
	var movement: MovementRule = MovementCatalog.rule_for(attacker)
	if movement.reach() == MovementRule.Reach.NONE:
		return CombatVerdict.new(Kind.NO_FIGHT, Reason.NEVER_MOVES, false)
	if not movement.can_attack():
		return CombatVerdict.new(Kind.NO_FIGHT, Reason.NEVER_ATTACKS, false)
	var verdict_kind: Kind = _kind_of(FightOutcome.resolve(attacker, defender))
	var captured: bool = defender == PieceType.Id.PRINCESS and verdict_kind != Kind.DEFENDER_WINS
	return CombatVerdict.new(verdict_kind, _reason_for(attacker, defender, verdict_kind), captured)


static func _kind_of(outcome: FightOutcome.Id) -> Kind:
	match outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return Kind.ATTACKER_WINS
		FightOutcome.Id.DEFENDER_WINS:
			return Kind.DEFENDER_WINS
		_:
			return Kind.BOTH_ELIMINATED


static func _reason_for(
		attacker: PieceType.Id, defender: PieceType.Id, verdict_kind: Kind
) -> Reason:
	if defender == PieceType.Id.MONSTER:
		if attacker == PieceType.Id.MAGICIAN:
			return Reason.MAGICIAN_KILLS_MONSTER
		return Reason.MONSTER_DEFENDS
	match verdict_kind:
		Kind.ATTACKER_WINS:
			return Reason.STRONGER_ATTACK
		Kind.DEFENDER_WINS:
			return Reason.STRONGER_DEFENSE
		_:
			return Reason.EQUAL
