import { describe, expect, it } from "vitest";
import { formatBoard, formatMove, formatSquare, parseBoard, parseMove, parseSquare } from "../src/rules/board-notation";
import { squareAt } from "../src/rules/square";

const OPENING_BOARD = ["s.....", "......", "......", ".#..#.", ".#p.#.", "..S...", "......", "K....."];

describe("board notation", () => {
	it("reads a Square from its column letter and rank", () => {
		expect(parseSquare("a1")).toEqual(squareAt(0, 0));
		expect(parseSquare("f8")).toEqual(squareAt(5, 7));
	});

	it("writes back the Square it read", () => {
		expect(formatSquare(parseSquare("c4"))).toBe("c4");
	});

	it("rejects text that names no Square", () => {
		for (const text of ["g1", "a9", "a0", "", "c", "c33"]) {
			expect(() => parseSquare(text), text).toThrow();
		}
	});

	it("reads a Move as two Squares joined by a dash", () => {
		expect(parseMove("c3-c4")).toEqual({ from: squareAt(2, 2), to: squareAt(2, 3) });
		expect(formatMove(parseMove("c3-c4"))).toBe("c3-c4");
		expect(() => parseMove("c3c4")).toThrow();
	});

	it("reads a Board from rank 8 down to rank 1 and writes it back", () => {
		const board = parseBoard(OPENING_BOARD);
		expect(board.pieceAt(parseSquare("a1"))).toMatchObject({ type: "king", side: "red" });
		expect(board.pieceAt(parseSquare("c4"))).toMatchObject({ type: "princess", side: "green" });
		expect(formatBoard(board)).toEqual(OPENING_BOARD);
	});
});
