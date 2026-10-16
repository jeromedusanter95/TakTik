import type { ReadonlyBoard } from "./board";
import { DIRECTIONS, holdsEnemy, isWalkable, type MovementRule } from "./movement-rule";
import type { Side } from "./side";
import { stepFrom, type Square } from "./square";

/** Crosses any number of empty Squares in a straight line and may Attack the first enemy Piece in that line. */
export class SlideMovement implements MovementRule {
	destinations(from: Square, board: ReadonlyBoard, side: Side): Square[] {
		return DIRECTIONS.flatMap((direction) => slideAlong(from, direction, board, side));
	}
}

function slideAlong(from: Square, direction: Square, board: ReadonlyBoard, side: Side): Square[] {
	const squares: Square[] = [];
	let target = stepFrom(from, direction);
	while (isWalkable(target) && !board.hasPiece(target)) {
		squares.push(target);
		target = stepFrom(target, direction);
	}
	if (isWalkable(target) && holdsEnemy(board, target, side)) {
		squares.push(target);
	}
	return squares;
}
