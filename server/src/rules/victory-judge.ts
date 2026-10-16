import { Board, type ReadonlyBoard } from "./board";
import { eliminatedIn } from "./fight";
import { drawBecause, IN_PROGRESS, victoryOf, type GameResult } from "./game-result";
import type { MoveRecord } from "./move-record";
import type { Piece } from "./piece";
import { opponentOf } from "./side";

/** 50 Rounds of one Move by each player. */
export const NO_FIGHT_PLY_LIMIT = 100;

/** The state the judge reads right after a Move, with the turn already passed to the opponent. */
export interface PositionAfterMove {
	readonly board: ReadonlyBoard;
	readonly pliesWithoutFight: number;
	hasLegalMove(): boolean;
}

/** Decides, after each Move, whether the game has ended. */
export function judgeAfterMove(position: PositionAfterMove, record: MoveRecord): GameResult {
	const capturedPrincess = eliminatedPrincessOf(record);
	if (capturedPrincess !== undefined) {
		return victoryOf(opponentOf(capturedPrincess.side), "princess_captured");
	}
	if (princessReachedEnemyHomeRow(position.board, record)) {
		return victoryOf(record.mover.side, "princess_reached_home_row");
	}
	if (!position.hasLegalMove()) {
		return victoryOf(record.mover.side, "blocked");
	}
	if (position.pliesWithoutFight >= NO_FIGHT_PLY_LIMIT) {
		return drawBecause("no_fight_limit");
	}
	return IN_PROGRESS;
}

function eliminatedPrincessOf(record: MoveRecord): Piece | undefined {
	if (record.fight === undefined) {
		return undefined;
	}
	return eliminatedIn(record.fight).find((piece) => piece.type === "princess");
}

function princessReachedEnemyHomeRow(board: ReadonlyBoard, record: MoveRecord): boolean {
	const { mover, move } = record;
	return (
		mover.type === "princess" &&
		board.pieceAt(move.to) === mover &&
		move.to.row === Board.homeRowOf(opponentOf(mover.side))
	);
}
