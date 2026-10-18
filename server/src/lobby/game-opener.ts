import type { Seating } from "../referee/seating";

/** Creates the referee of a new game. */
export interface GameOpener {
	/** Resolves with the new game's id; rejects when no game could be opened. */
	open(seating: Seating): Promise<string>;
}
