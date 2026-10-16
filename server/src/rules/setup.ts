import { COLUMNS, ROWS } from "./board";
import { armyCountOf, PIECE_TYPES, type PieceType } from "./piece-type";
import type { Side } from "./side";
import { squareAt, type Square } from "./square";

export const SETUP_ROW_COUNT = 3;

/** One player's arrangement of their Army on their side of the Board, before play starts. */
export class Setup {
	private readonly placements = new Map<number, PieceType>();

	constructor(readonly side: Side) {}

	/** The rows a side places its Army on: its Home Row and the two in front. */
	static rowsFor(side: Side): number[] {
		const firstRow = side === "red" ? 0 : ROWS - SETUP_ROW_COUNT;
		return Array.from({ length: SETUP_ROW_COUNT }, (_, offset) => firstRow + offset);
	}

	static squaresFor(side: Side): Square[] {
		return Setup.rowsFor(side).flatMap((row) =>
			Array.from({ length: COLUMNS }, (_, column) => squareAt(column, row)),
		);
	}

	isSetupSquare(square: Square): boolean {
		return Setup.rowsFor(this.side).includes(square.row) && square.column >= 0 && square.column < COLUMNS;
	}

	place(square: Square, type: PieceType): void {
		this.placements.set(indexOf(square), type);
	}

	typeAt(square: Square): PieceType | undefined {
		return this.placements.get(indexOf(square));
	}

	/** True when every setup Square holds a Piece and the Pieces are exactly the Army. */
	isValid(): boolean {
		return this.fillsEverySetupSquare() && this.holdsExactlyTheArmy();
	}

	private fillsEverySetupSquare(): boolean {
		const setupSquares = Setup.squaresFor(this.side);
		return (
			this.placements.size === setupSquares.length &&
			setupSquares.every((square) => this.typeAt(square) !== undefined)
		);
	}

	private holdsExactlyTheArmy(): boolean {
		const placedTypes = [...this.placements.values()];
		return PIECE_TYPES.every(
			(type) => placedTypes.filter((placed) => placed === type).length === armyCountOf(type),
		);
	}
}

function indexOf(square: Square): number {
	return square.row * COLUMNS + square.column;
}
