class_name PieceGuide
extends RefCounted
## The order the rules page lists Piece Types in, and whom each one beats when
## it attacks, computed from the game's own Fight rule.


## Every Piece Type, highest Attack Strength first; equal ones keep the
## order PieceType declares them in.
static func by_attack() -> Array[PieceType.Id]:
	var types: Array[PieceType.Id] = []
	types.assign(PieceType.Id.values())
	types.sort_custom(_attacks_harder)
	return types


## The Piece Types [param attacker] eliminates when it attacks them, in
## by_attack order. Empty for a Piece Type that never attacks.
static func beaten_by(attacker: PieceType.Id) -> Array[PieceType.Id]:
	var beaten: Array[PieceType.Id] = []
	if not MovementCatalog.rule_for(attacker).can_attack():
		return beaten
	for defender: PieceType.Id in by_attack():
		if FightOutcome.resolve(attacker, defender) == FightOutcome.Id.ATTACKER_WINS:
			beaten.append(defender)
	return beaten


static func _attacks_harder(first: PieceType.Id, second: PieceType.Id) -> bool:
	var first_attack: int = PieceType.attack_strength(first)
	var second_attack: int = PieceType.attack_strength(second)
	if first_attack != second_attack:
		return first_attack > second_attack
	return first < second
