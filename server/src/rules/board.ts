import type { Piece } from "./piece";
import type { Side } from "./side";
import { sameSquare, squareAt, type Square } from "./square";

export const COLUMNS = 6;
export const ROWS = 8;

const OBSTACLES: readonly Square[] = [squareAt(1, 3), squareAt(1, 4), squareAt(4, 3), squareAt(4, 4)];

/** What may be read about a Board without changing it. */
export interface ReadonlyBoard {
	pieceAt(square: Square): Piece | undefined;
	hasPiece(square: Square): boolean;
	squaresOf(side: Side): Square[];
}

/** The 6 by 8 grid of Squares and the Pieces standing on them. */
export class Board implements ReadonlyBoard {
	private readonly pieces = new Map<number, Piece>();

	static isInside(square: Square): boolean {
		return square.column >= 0 && square.column < COLUMNS && square.row >= 0 && square.row < ROWS;
	}

	static isObstacle(square: Square): boolean {
		return OBSTACLES.some((obstacle) => sameSquare(obstacle, square));
	}

	static homeRowOf(side: Side): number {
		return side === "red" ? 0 : ROWS - 1;
	}

	copy(): Board {
		const copy = new Board();
		this.pieces.forEach((piece, index) => copy.pieces.set(index, piece));
		return copy;
	}

	pieceAt(square: Square): Piece | undefined {
		return this.pieces.get(indexOf(square));
	}

	hasPiece(square: Square): boolean {
		return this.pieces.has(indexOf(square));
	}

	squaresOf(side: Side): Square[] {
		return [...this.pieces]
			.filter(([, piece]) => piece.side === side)
			.map(([index]) => squareOfIndex(index));
	}

	place(piece: Piece, square: Square): void {
		this.pieces.set(indexOf(square), piece);
	}

	remove(square: Square): void {
		this.pieces.delete(indexOf(square));
	}

	relocate(from: Square, to: Square): void {
		const piece = this.pieceAt(from);
		if (piece === undefined) {
			throw new Error(`No Piece to relocate on ${from.column},${from.row}`);
		}
		this.remove(from);
		this.place(piece, to);
	}
}

function indexOf(square: Square): number {
	return square.row * COLUMNS + square.column;
}

function squareOfIndex(index: number): Square {
	return squareAt(index % COLUMNS, Math.floor(index / COLUMNS));
}
