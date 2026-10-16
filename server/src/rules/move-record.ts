import type { Fight } from "./fight";
import type { Move } from "./move";
import type { Piece } from "./piece";

/** What happened when a Move was played. [fight] is absent for a Move onto an empty Square. */
export interface MoveRecord {
	readonly move: Move;
	readonly mover: Piece;
	readonly fight?: Fight;
}
