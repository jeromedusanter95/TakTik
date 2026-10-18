import { COLUMNS, ROWS } from "./board";
import { armyCountOf, armyTypes, PIECE_TYPES, type PieceType } from "./piece-type";
import type { Side } from "./side";
import { squareAt, type Square } from "./square";

export const SETUP_ROW_COUNT = 3;

/** A source of chance. */
export interface SetupDraws {
	/** A whole number from 0 up to, but not including, [count]. */
	below(count: number): number;
}

/** One player's arrangement of their Army on their side of the Board, before play starts. */
export class Setup {
	private readonly placements = new Map<number, PieceType>();

	constructor(readonly side: Side) {}

	/** A Random Setup: the whole Army of [side], each Piece on a Square drawn among those still free. */
	static random(side: Side, draws: SetupDraws): Setup {
		const setup = new Setup(side);
		const squaresLeft = Setup.squaresFor(side);
		for (const type of armyTypes()) {
			const [square] = squaresLeft.splice(draws.below(squaresLeft.length), 1);
			if (square === undefined) {
				throw new Error(`A draw fell outside the ${squaresLeft.length + 1} Squares left`);
			}
			setup.place(square, type);
		}
		return setup;
	}

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
