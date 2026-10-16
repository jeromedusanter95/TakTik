class_name FightOutcome
extends RefCounted
## How a Fight ends, and the rule that decides it.

enum Id {
	ATTACKER_WINS,
	DEFENDER_WINS,
	BOTH_ELIMINATED,
}


static func resolve(attacker: PieceType.Id, defender: PieceType.Id) -> Id:
	if defender == PieceType.Id.MONSTER:
		return Id.ATTACKER_WINS if attacker == PieceType.Id.MAGICIAN else Id.DEFENDER_WINS
	var attack: int = PieceType.attack_strength(attacker)
	var defense: int = PieceType.defense_strength(defender)
	if attack > defense:
		return Id.ATTACKER_WINS
	if attack < defense:
		return Id.DEFENDER_WINS
	return Id.BOTH_ELIMINATED
