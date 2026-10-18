import { parseMove, parseSetup } from "../../src/rules/board-notation";
import { Setup } from "../../src/rules/setup";
import type { Side } from "../../src/rules/side";
import type { Placement } from "../../src/referee/protocol";
import type { Seating } from "../../src/referee/seating";

export const SEATING: Seating = {
	red: { nickname: "Ada", seatToken: "red-token" },
	green: { nickname: "Bob", seatToken: "green-token" },
};

/** Red's Buffoon on a3 can slide up the a file onto Green's Princess on a6. */
export const RED_SETUP = ["BSNMBE", "MOSPBO", "NSOTBK"];
export const GREEN_SETUP = ["nsotbk", "mosbbo", "psnmbe"];
export const WINNING_MOVE = parseMove("a3-a6");

export function placementsOf(side: Side, rows: readonly string[]): Placement[] {
	const setup = parseSetup(side, rows);
	return Setup.squaresFor(side).flatMap((square) => {
		const type = setup.typeAt(square);
		return type === undefined ? [] : [{ square, type }];
	});
}
