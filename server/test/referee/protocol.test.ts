import { describe, expect, it } from "vitest";
import { parseMove, parseSquare } from "../../src/rules/board-notation";
import { formatRefereeReply, parseRefereeRequest } from "../../src/referee/protocol";

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("a Referee request", () => {
	it("reads a seat taken with its Seat Token", () => {
		expect(parseRefereeRequest(text({ type: "take_seat", seatToken: "abc" }))).toEqual({
			valid: true,
			request: { type: "take_seat", seatToken: "abc" },
		});
	});

	it("reads a Setup as Pieces placed on Squares", () => {
		const placements = [
			{ square: parseSquare("a1"), type: "king" },
			{ square: parseSquare("f3"), type: "princess" },
		];
		expect(parseRefereeRequest(text({ type: "setup", placements }))).toEqual({
			valid: true,
			request: { type: "setup", placements },
		});
	});

	it("reads a Move", () => {
		const move = parseMove("c3-c4");
		expect(parseRefereeRequest(text({ type: "move", move }))).toEqual({ valid: true, request: { type: "move", move } });
	});

	it("reads a resignation", () => {
		expect(parseRefereeRequest(text({ type: "resign" }))).toEqual({ valid: true, request: { type: "resign" } });
	});

	it.each([
		["not JSON", "move c3-c4"],
		["of an unknown type", text({ type: "dance" })],
		["a seat without a token", text({ type: "take_seat" })],
		["a seat with an empty token", text({ type: "take_seat", seatToken: "" })],
		["a seat with an overlong token", text({ type: "take_seat", seatToken: "a".repeat(129) })],
		["a Setup without placements", text({ type: "setup" })],
		["a Setup with an unknown Piece Type", text({ type: "setup", placements: [{ square: parseSquare("a1"), type: "dragon" }] })],
		["a Setup with a Square off the Board", text({ type: "setup", placements: [{ square: { column: 6, row: 0 }, type: "king" }] })],
		["a Move from a fractional Square", text({ type: "move", move: { from: { column: 0.5, row: 0 }, to: parseSquare("a2") } })],
		["a Move with a Square given as text", text({ type: "move", move: { from: "a1", to: "a2" } })],
		["a Move without a destination", text({ type: "move", move: { from: parseSquare("a1") } })],
	])("refuses a message that is %s", (_, message) => {
		expect(parseRefereeRequest(message)).toEqual({ valid: false });
	});
});

describe("a Referee reply", () => {
	it("is sent as JSON", () => {
		const reply = { type: "seated", side: "red", opponent: "Bob" } as const;
		expect(JSON.parse(formatRefereeReply(reply))).toEqual(reply);
	});
});
