import type { Side } from "../rules/side";

/** A place in a new game, with the secret its Guest needs to take it. */
export interface Seat {
	readonly nickname: string;
	readonly seatToken: string;
}

/** Who plays each side of an online game. */
export type Seating = Readonly<Record<Side, Seat>>;
