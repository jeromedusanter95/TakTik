import { describe, expect, it } from "vitest";
import { parseBoard, parseMove } from "../src/rules/board-notation";
import { Game } from "../src/rules/game";
import type { MoveRecord } from "../src/rules/move-record";
import { publicMoveEventOf } from "../src/view/public-move-event";

function recordOf(rows: string[], moveText: string): MoveRecord {
	const attempt = new Game({ board: parseBoard(rows), sideToMove: "red" }).tryPlay(parseMove(moveText));
	if (!attempt.accepted) {
		throw new Error(`${moveText} should be legal`);
	}
	return attempt.record;
}

describe("a PublicMoveEvent", () => {
	it("reveals both Piece Types and the outcome of a Fight", () => {
		const record = recordOf(["s.....", "......", "......", ".#..#.", ".#t.#.", "..N...", "......", "......"], "c3-c4");
		expect(publicMoveEventOf(record)).toEqual({
			moverSide: "red",
			move: parseMove("c3-c4"),
			fight: { attackerType: "knight", defenderType: "thief", outcome: "attacker_wins" },
		});
	});

	it("tells only the Squares of a Move onto an empty Square", () => {
		const record = recordOf(["s.....", "......", "......", ".#..#.", ".#..#.", "..N...", "......", "......"], "c3-c4");
		expect(publicMoveEventOf(record)).toEqual({ moverSide: "red", move: parseMove("c3-c4") });
	});

	it("carries no Piece ids", () => {
		const record = recordOf(["s.....", "......", "......", ".#..#.", ".#t.#.", "..N...", "......", "......"], "c3-c4");
		expect(JSON.stringify(publicMoveEventOf(record))).not.toMatch(/"id"/);
	});
});
