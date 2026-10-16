import { describe, expect, it } from "vitest";
import { parseBoard, parseMove, parseSetup, parseSquare } from "../src/rules/board-notation";
import { Game } from "../src/rules/game";
import { gameFromSetups } from "../src/rules/game-factory";
import { playerViewOf } from "../src/view/player-view";

const RED_SETUP = ["OTNSBK", "MBSPBO", "NSOMBE"];
const GREEN_SETUP = ["otnsbk", "mbspbo", "nsombe"];

function openingGame(): Game {
	return gameFromSetups(parseSetup("red", RED_SETUP), parseSetup("green", GREEN_SETUP));
}

function gameOn(rows: string[]): Game {
	return new Game({ board: parseBoard(rows), sideToMove: "red" });
}

describe("a PlayerView", () => {
	it("shows the viewer's own Piece Types and only the Squares of enemy Pieces", () => {
		const game = openingGame();
		const view = playerViewOf(game, "red");
		expect(view.ownPieces).toHaveLength(18);
		expect(view.enemySquares).toHaveLength(18);
		for (const { square, type } of view.ownPieces) {
			expect(game.board.pieceAt(square)?.type).toBe(type);
		}
	});

	it("is identical for two games that differ only in Hidden Piece Types", () => {
		const withPrincess = gameOn(["p.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "S....."]);
		const withKing = gameOn(["k.....", "......", "......", ".#..#.", ".#..#.", "......", "......", "S....."]);
		expect(playerViewOf(withPrincess, "red")).toEqual(playerViewOf(withKing, "red"));
	});

	it("carries no Piece ids", () => {
		expect(JSON.stringify(playerViewOf(openingGame(), "green"))).not.toMatch(/"id"/);
	});

	it("shows the public state: whose turn, the count without a Fight, the result and the last Moves", () => {
		const game = gameOn(["....s.", "......", "......", ".#..#.", ".#..#.", "..S...", "......", "......"]);
		game.tryPlay(parseMove("c3-c4"));
		const view = playerViewOf(game, "green");
		expect(view.sideToMove).toBe("green");
		expect(view.pliesWithoutFight).toBe(1);
		expect(view.result).toEqual({ status: "in_progress", reason: "none" });
		expect(view.lastMoves).toEqual({ red: parseMove("c3-c4") });
	});
});

describe("gameFromSetups", () => {
	it("numbers Piece ids in Square order, so an id never hints at a Piece Type", () => {
		const game = openingGame();
		expect(game.board.pieceAt(parseSquare("a1"))?.id).toBe(0);
		expect(game.board.pieceAt(parseSquare("b1"))?.id).toBe(1);
		expect(game.board.pieceAt(parseSquare("a6"))?.id).toBe(18);
		expect(game.sideToMove).toBe("red");
	});
});
