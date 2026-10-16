import { sameSquare, type Square } from "./square";

/** A Piece going from one Square to another. */
export interface Move {
	readonly from: Square;
	readonly to: Square;
}

export function sameMove(first: Move, second: Move): boolean {
	return sameSquare(first.from, second.from) && sameSquare(first.to, second.to);
}
