import { Board, type ReadonlyBoard } from "./board";
import type { Side } from "./side";
import { squareAt, type Square } from "./square";

/** How one Piece Type may travel across the Board. */
export interface MovementRule {
	/**
	 * Every Square a Piece of [side] standing on [from] could reach, ignoring
	 * whose turn it is and the Move Back rule.
	 */
	destinations(from: Square, board: ReadonlyBoard, side: Side): Square[];
}

/** Forward, back, left and right: never diagonally. */
export const DIRECTIONS: readonly Square[] = [squareAt(0, 1), squareAt(0, -1), squareAt(-1, 0), squareAt(1, 0)];

export function isWalkable(square: Square): boolean {
	return Board.isInside(square) && !Board.isObstacle(square);
}

export function holdsEnemy(board: ReadonlyBoard, square: Square, side: Side): boolean {
	const piece = board.pieceAt(square);
	return piece !== undefined && piece.side !== side;
}
