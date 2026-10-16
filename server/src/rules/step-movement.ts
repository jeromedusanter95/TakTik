import type { ReadonlyBoard } from "./board";
import { DIRECTIONS, holdsEnemy, isWalkable, type MovementRule } from "./movement-rule";
import type { Side } from "./side";
import { stepFrom, type Square } from "./square";

/** Moves one Square forward, back, left or right, onto an empty Square or, when allowed, an enemy. */
export class StepMovement implements MovementRule {
	constructor(private readonly options: { readonly mayAttack: boolean }) {}

	destinations(from: Square, board: ReadonlyBoard, side: Side): Square[] {
		return DIRECTIONS.map((direction) => stepFrom(from, direction)).filter(
			(target) => isWalkable(target) && this.mayEnter(target, board, side),
		);
	}

	private mayEnter(target: Square, board: ReadonlyBoard, side: Side): boolean {
		if (!board.hasPiece(target)) {
			return true;
		}
		return this.options.mayAttack && holdsEnemy(board, target, side);
	}
}
