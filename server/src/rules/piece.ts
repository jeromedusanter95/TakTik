import type { PieceType } from "./piece-type";
import type { Side } from "./side";

/** A single unit of an Army. The id is private to the referee. */
export interface Piece {
	readonly id: number;
	readonly type: PieceType;
	readonly side: Side;
}
