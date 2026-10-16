import type { FightOutcome } from "./fight-outcome";
import type { Piece } from "./piece";

/** The record of one Attack: who fought and how it ended. */
export interface Fight {
	readonly attacker: Piece;
	readonly defender: Piece;
	readonly outcome: FightOutcome;
}

export function eliminatedIn(fight: Fight): Piece[] {
	switch (fight.outcome) {
		case "attacker_wins":
			return [fight.defender];
		case "defender_wins":
			return [fight.attacker];
		case "both_eliminated":
			return [fight.attacker, fight.defender];
	}
}
