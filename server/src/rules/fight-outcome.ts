import { attackStrengthOf, defenseStrengthOf, type PieceType } from "./piece-type";

/** How a Fight ends. */
export type FightOutcome = "attacker_wins" | "defender_wins" | "both_eliminated";

/**
 * The stronger Piece wins and a tie eliminates both, except that a Monster
 * beats every Attacker but a Magician, which beats it.
 */
export function resolveFight(attacker: PieceType, defender: PieceType): FightOutcome {
	if (defender === "monster") {
		return attacker === "magician" ? "attacker_wins" : "defender_wins";
	}
	return compareStrengths(attackStrengthOf(attacker), defenseStrengthOf(defender));
}

function compareStrengths(attack: number, defense: number): FightOutcome {
	if (attack > defense) {
		return "attacker_wins";
	}
	if (attack < defense) {
		return "defender_wins";
	}
	return "both_eliminated";
}
