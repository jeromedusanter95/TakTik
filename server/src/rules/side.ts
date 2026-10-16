/** The two Armies. Red is Player 1, starts at the bottom and moves first. */
export type Side = "red" | "green";

export const SIDES: readonly Side[] = ["red", "green"];

export function opponentOf(side: Side): Side {
	return side === "red" ? "green" : "red";
}
