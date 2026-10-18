import type { Side } from "../rules/side";
import type { Seating } from "./seating";

/** A new game opened for a Rematch, with the seat of each side. */
export interface OpenedRematch {
	readonly gameId: string;
	readonly seating: Seating;
}

/** Opens the game of a Rematch. */
export interface RematchMaker {
	/** Gives each side's player a new Seat Token. Rejects when no game could be opened. */
	open(nicknames: Readonly<Record<Side, string>>): Promise<OpenedRematch>;
}
