import type { FightOutcome } from "../rules/fight-outcome";
import type { Move } from "../rules/move";
import type { MoveRecord } from "../rules/move-record";
import type { PieceType } from "../rules/piece-type";
import type { Side } from "../rules/side";

/** The Reveal of a Fight: both Piece Types and how it ended. */
export interface RevealedFight {
	readonly attackerType: PieceType;
	readonly defenderType: PieceType;
	readonly outcome: FightOutcome;
}

/**
 * What both players learn from a Move: which Squares it used and, when it
 * caused a Fight, its Reveal. Carries no Piece ids, which are private to the
 * referee.
 */
export interface PublicMoveEvent {
	readonly moverSide: Side;
	readonly move: Move;
	readonly fight?: RevealedFight;
}

export function publicMoveEventOf(record: MoveRecord): PublicMoveEvent {
	const moverSide = record.mover.side;
	const move = { from: record.move.from, to: record.move.to };
	if (record.fight === undefined) {
		return { moverSide, move };
	}
	const { attacker, defender, outcome } = record.fight;
	return { moverSide, move, fight: { attackerType: attacker.type, defenderType: defender.type, outcome } };
}
