import { describe, expect, it } from "vitest";
import { armyTypes } from "../src/rules/piece-type";
import { Setup, type SetupDraws } from "../src/rules/setup";

/** Always draws [index], or the last choice when fewer are left. */
function always(index: number): SetupDraws {
	return { below: (count) => Math.min(index, count - 1) };
}

describe("a Random Setup", () => {
	it.each(["red", "green"] as const)("places the whole Army of %s on its own rows", (side) => {
		const setup = Setup.random(side, always(4));
		expect(setup.side).toBe(side);
		expect(setup.isValid()).toBe(true);
	});

	it("places each Piece on a Square drawn among those still free", () => {
		const setup = Setup.random("red", always(0));
		const squares = Setup.squaresFor("red");
		expect(squares.map((square) => setup.typeAt(square))).toEqual(armyTypes());
	});

	it("refuses a draw outside the Squares left", () => {
		expect(() => Setup.random("red", { below: (count) => count })).toThrow();
	});
});
