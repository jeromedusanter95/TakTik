import type { Side } from "./side";

export type GameStatus = "in_progress" | "red_wins" | "green_wins" | "draw";

export type GameEndReason = "none" | "princess_captured" | "princess_reached_home_row" | "blocked" | "no_fight_limit";

/** Whether a game is still going, and if not, who won and why. */
export interface GameResult {
	readonly status: GameStatus;
	readonly reason: GameEndReason;
}

export const IN_PROGRESS: GameResult = { status: "in_progress", reason: "none" };

export function victoryOf(winner: Side, reason: GameEndReason): GameResult {
	return { status: winner === "red" ? "red_wins" : "green_wins", reason };
}

export function drawBecause(reason: GameEndReason): GameResult {
	return { status: "draw", reason };
}

export function isOver(result: GameResult): boolean {
	return result.status !== "in_progress";
}
