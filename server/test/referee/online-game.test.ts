import { describe, expect, it } from "vitest";
import { parseMove, parseSetup, parseSquare } from "../../src/rules/board-notation";
import { gameFromSetups } from "../../src/rules/game-factory";
import { OnlineGame } from "../../src/referee/online-game";
import { playerViewOf } from "../../src/view/player-view";
import { GREEN_SETUP, placementsOf, RED_SETUP, SEATING, WINNING_MOVE } from "./fixtures";

function gameInPlay(): OnlineGame {
	const game = OnlineGame.open(SEATING);
	game.submitSetup("red", placementsOf("red", RED_SETUP));
	game.submitSetup("green", placementsOf("green", GREEN_SETUP));
	return game;
}

describe("an online game", () => {
	describe("its seats", () => {
		it("belong to whoever holds their Seat Token", () => {
			const game = OnlineGame.open(SEATING);
			expect(game.sideOfSeatToken("red-token")).toBe("red");
			expect(game.sideOfSeatToken("green-token")).toBe("green");
		});

		it("belong to no one for any other token", () => {
			expect(OnlineGame.open(SEATING).sideOfSeatToken("red-tokeN")).toBeUndefined();
		});

		it("name each player's Opponent", () => {
			const game = OnlineGame.open(SEATING);
			expect(game.opponentNicknameOf("red")).toBe("Bob");
			expect(game.opponentNicknameOf("green")).toBe("Ada");
		});
	});

	describe("during Setup", () => {
		it("starts in Setup with no Setup done", () => {
			const game = OnlineGame.open(SEATING);
			expect(game.phase()).toBe("setup");
			expect(game.hasSetup("red")).toBe(false);
			expect(game.hasSetup("green")).toBe(false);
		});

		it("keeps a valid Setup and waits for the other one", () => {
			const game = OnlineGame.open(SEATING);
			expect(game.submitSetup("green", placementsOf("green", GREEN_SETUP))).toEqual({ accepted: true });
			expect(game.hasSetup("green")).toBe(true);
			expect(game.phase()).toBe("setup");
		});

		it("starts play, Red to move, once both Setups are in", () => {
			const game = gameInPlay();
			const expected = gameFromSetups(parseSetup("red", RED_SETUP), parseSetup("green", GREEN_SETUP));
			expect(game.phase()).toBe("playing");
			expect(game.viewOf("red")).toEqual(playerViewOf(expected, "red"));
			expect(game.viewOf("green")).toEqual(playerViewOf(expected, "green"));
		});

		it("refuses a second Setup from the same side", () => {
			const game = OnlineGame.open(SEATING);
			game.submitSetup("red", placementsOf("red", RED_SETUP));
			expect(game.submitSetup("red", placementsOf("red", RED_SETUP))).toEqual({
				accepted: false,
				reason: "setup_already_done",
			});
		});

		it.each([
			["is missing a Piece", placementsOf("red", RED_SETUP).slice(1)],
			["stands on the other side's rows", placementsOf("green", GREEN_SETUP)],
			[
				"is not exactly the Army",
				placementsOf("red", RED_SETUP).map((placement) => ({ ...placement, type: "king" as const })),
			],
			[
				"places two Pieces on one Square",
				[...placementsOf("red", RED_SETUP), { square: parseSquare("f1"), type: "king" as const }],
			],
		])("refuses a Setup that %s", (_, placements) => {
			const game = OnlineGame.open(SEATING);
			expect(game.submitSetup("red", placements)).toEqual({ accepted: false, reason: "invalid_setup" });
			expect(game.hasSetup("red")).toBe(false);
		});

		it("refuses any Move", () => {
			const game = OnlineGame.open(SEATING);
			expect(game.play("red", parseMove("a3-a4"))).toEqual({ accepted: false, reason: "game_not_started" });
		});
	});

	describe("during play", () => {
		it("plays a legal Move and tells what both players learn", () => {
			const game = gameInPlay();
			expect(game.play("red", parseMove("c3-c4"))).toEqual({
				accepted: true,
				event: { moverSide: "red", move: parseMove("c3-c4") },
			});
			expect(game.viewOf("green").sideToMove).toBe("green");
			expect(game.history()).toEqual([{ moverSide: "red", move: parseMove("c3-c4") }]);
		});

		it("refuses a Move out of turn", () => {
			expect(gameInPlay().play("green", parseMove("c6-c5"))).toEqual({ accepted: false, reason: "not_your_turn" });
		});

		it("refuses an illegal Move", () => {
			expect(gameInPlay().play("red", parseMove("b3-b4"))).toEqual({ accepted: false, reason: "illegal_move" });
		});

		it("refuses a Setup", () => {
			expect(gameInPlay().submitSetup("red", placementsOf("red", RED_SETUP))).toEqual({
				accepted: false,
				reason: "setup_already_done",
			});
		});

		it("reveals nothing of the Board before the end", () => {
			expect(gameInPlay().finalBoard()).toBeUndefined();
		});
	});

	describe("once over", () => {
		it("ends when a Move decides it and reveals the whole Board", () => {
			const game = gameInPlay();
			const attempt = game.play("red", WINNING_MOVE);

			expect(attempt).toEqual({
				accepted: true,
				event: {
					moverSide: "red",
					move: WINNING_MOVE,
					fight: { attackerType: "buffoon", defenderType: "princess", outcome: "attacker_wins" },
				},
			});
			expect(game.phase()).toBe("over");
			expect(game.viewOf("green").result).toEqual({ status: "red_wins", reason: "princess_captured" });
			expect(game.finalBoard()).toHaveLength(35);
			expect(game.finalBoard()).toContainEqual({ square: parseSquare("a6"), type: "buffoon", side: "red" });
		});

		it("refuses any further Move", () => {
			const game = gameInPlay();
			game.play("red", WINNING_MOVE);
			expect(game.play("green", parseMove("c6-c5"))).toEqual({ accepted: false, reason: "game_over" });
		});
	});

	describe("a concession", () => {
		it("gives Victory to the Opponent of a player who Resigns", () => {
			const game = gameInPlay();
			expect(game.concede("red", "resigned")).toEqual({ accepted: true });

			expect(game.phase()).toBe("over");
			expect(game.viewOf("red").result).toEqual({ status: "green_wins", reason: "resigned" });
			expect(game.finalBoard()).toHaveLength(36);
		});

		it("gives Victory to the Opponent of a player who Forfeits", () => {
			const game = gameInPlay();
			game.concede("green", "forfeited");
			expect(game.viewOf("green").result).toEqual({ status: "red_wins", reason: "forfeited" });
		});

		it("is refused during Setup", () => {
			expect(OnlineGame.open(SEATING).concede("red", "resigned")).toEqual({
				accepted: false,
				reason: "game_not_started",
			});
		});

		it("is refused once the game is over", () => {
			const game = gameInPlay();
			game.play("red", WINNING_MOVE);
			expect(game.concede("green", "resigned")).toEqual({ accepted: false, reason: "game_over" });
			expect(game.viewOf("green").result).toEqual({ status: "red_wins", reason: "princess_captured" });
		});

		it("ends any further play", () => {
			const game = gameInPlay();
			game.concede("green", "resigned");
			expect(game.play("red", parseMove("c3-c4"))).toEqual({ accepted: false, reason: "game_over" });
		});
	});

	describe("its record", () => {
		it("rebuilds the same game during Setup", () => {
			const game = OnlineGame.open(SEATING);
			game.submitSetup("red", placementsOf("red", RED_SETUP));
			const rebuilt = OnlineGame.fromRecord(game.toRecord());

			expect(rebuilt.phase()).toBe("setup");
			expect(rebuilt.hasSetup("red")).toBe(true);
			expect(rebuilt.sideOfSeatToken("green-token")).toBe("green");
		});

		it("rebuilds the same game after Moves", () => {
			const game = gameInPlay();
			game.play("red", parseMove("c3-c4"));
			game.play("green", parseMove("c6-c5"));
			game.play("red", parseMove("c4-c5"));
			const rebuilt = OnlineGame.fromRecord(JSON.parse(JSON.stringify(game.toRecord())));

			for (const side of ["red", "green"] as const) {
				expect(rebuilt.viewOf(side)).toEqual(game.viewOf(side));
			}
			expect(rebuilt.history()).toEqual(game.history());
		});

		it("rebuilds a game someone Resigned", () => {
			const game = gameInPlay();
			game.play("red", parseMove("c3-c4"));
			game.concede("green", "resigned");
			const rebuilt = OnlineGame.fromRecord(JSON.parse(JSON.stringify(game.toRecord())));

			expect(rebuilt.phase()).toBe("over");
			expect(rebuilt.viewOf("red")).toEqual(game.viewOf("red"));
			expect(rebuilt.toRecord()).toEqual(game.toRecord());
		});

		it("refuses a record with a concession before play", () => {
			const record = OnlineGame.open(SEATING).toRecord();
			expect(() => OnlineGame.fromRecord({ ...record, concession: { loser: "red", reason: "resigned" } })).toThrow();
		});

		it("refuses a record whose Moves cannot be replayed", () => {
			const record = gameInPlay().toRecord();
			expect(() => OnlineGame.fromRecord({ ...record, moves: [parseMove("b3-b4")] })).toThrow();
		});
	});
});
