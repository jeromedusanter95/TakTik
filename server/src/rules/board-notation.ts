import { Board, COLUMNS, ROWS, type ReadonlyBoard } from "./board";
import type { Move } from "./move";
import type { Piece } from "./piece";
import type { PieceType } from "./piece-type";
import { Setup, SETUP_ROW_COUNT } from "./setup";
import type { Side } from "./side";
import { squareAt, type Square } from "./square";

/**
 * Reads and writes the text notation of spec/rules/README.md: Squares like
 * "c3", Moves like "c3-c4" and Boards as 8 strings from rank 8 down to rank 1.
 */

export const EMPTY = ".";
export const OBSTACLE = "#";

const COLUMN_LETTERS = "abcdef";
const SQUARE_PATTERN = /^([a-f])([1-8])$/;

const LETTERS: Readonly<Record<PieceType, string>> = {
	king: "K",
	executioner: "E",
	knight: "N",
	soldier: "S",
	magician: "M",
	buffoon: "B",
	monster: "O",
	thief: "T",
	princess: "P",
};

const TYPES_BY_LETTER: ReadonlyMap<string, PieceType> = new Map(
	Object.entries(LETTERS).map(([type, letter]) => [letter, type as PieceType]),
);

export function parseSquare(text: string): Square {
	const match = SQUARE_PATTERN.exec(text);
	if (match === null) {
		throw new Error(`"${text}" is not a Square`);
	}
	const [, column = "", rank = ""] = match;
	return squareAt(COLUMN_LETTERS.indexOf(column), Number(rank) - 1);
}

export function formatSquare(square: Square): string {
	return `${COLUMN_LETTERS.charAt(square.column)}${square.row + 1}`;
}

export function parseMove(text: string): Move {
	const parts = text.split("-");
	if (parts.length !== 2) {
		throw new Error(`"${text}" is not a Move`);
	}
	const [from = "", to = ""] = parts;
	return { from: parseSquare(from), to: parseSquare(to) };
}

export function formatMove(move: Move): string {
	return `${formatSquare(move.from)}-${formatSquare(move.to)}`;
}

export function letterOf(piece: Pick<Piece, "type" | "side">): string {
	const letter = LETTERS[piece.type];
	return piece.side === "red" ? letter : letter.toLowerCase();
}

/** The Piece Type a letter names, or undefined for "." and "#". */
export function typeOfLetter(letter: string): PieceType | undefined {
	return TYPES_BY_LETTER.get(letter.toUpperCase());
}

export function sideOfLetter(letter: string): Side {
	return letter === letter.toUpperCase() ? "red" : "green";
}

/** Piece ids follow reading order of [rows]. */
export function parseBoard(rows: readonly string[]): Board {
	const board = new Board();
	let nextId = 0;
	rows.forEach((text, index) => {
		const row = ROWS - 1 - index;
		for (let column = 0; column < COLUMNS; column++) {
			const letter = text.charAt(column);
			const type = typeOfLetter(letter);
			if (type !== undefined) {
				board.place({ id: nextId++, type, side: sideOfLetter(letter) }, squareAt(column, row));
			}
		}
	});
	return board;
}

export function formatBoard(board: ReadonlyBoard): string[] {
	const rows: string[] = [];
	for (let row = ROWS - 1; row >= 0; row--) {
		let text = "";
		for (let column = 0; column < COLUMNS; column++) {
			text += characterAt(board, squareAt(column, row));
		}
		rows.push(text);
	}
	return rows;
}

function characterAt(board: ReadonlyBoard, square: Square): string {
	if (Board.isObstacle(square)) {
		return OBSTACLE;
	}
	const piece = board.pieceAt(square);
	return piece === undefined ? EMPTY : letterOf(piece);
}

/** Reads [rows], the side's setup ranks from top to bottom. Letters of the other side are left out. */
export function parseSetup(side: Side, rows: readonly string[]): Setup {
	const setup = new Setup(side);
	const topRowFirst = Setup.rowsFor(side).reverse();
	rows.forEach((text, index) => {
		const row = topRowFirst[index];
		if (row === undefined) {
			throw new Error(`A Setup has only ${SETUP_ROW_COUNT} rows`);
		}
		for (let column = 0; column < COLUMNS; column++) {
			const letter = text.charAt(column);
			const type = typeOfLetter(letter);
			if (type !== undefined && sideOfLetter(letter) === side) {
				setup.place(squareAt(column, row), type);
			}
		}
	});
	return setup;
}
