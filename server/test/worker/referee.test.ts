import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { QuickMatchReply } from "../../src/quick-match/protocol";
import type { RefereeReply } from "../../src/referee/protocol";
import { parseMove } from "../../src/rules/board-notation";
import type { Side } from "../../src/rules/side";
import { GREEN_SETUP, placementsOf, RED_SETUP, WINNING_MOVE } from "../referee/fixtures";
import { JsonSocket, socketUrl } from "./json-socket";

type PlayerSocket = JsonSocket<RefereeReply>;

interface PairedSeat {
	readonly gameId: string;
	readonly seatToken: string;
	readonly opponent: string;
}

describe("the Referee Worker", () => {
	let harness: TestHarness;
	let base: URL;

	beforeAll(async () => {
		harness = createTestHarness({ workers: [{ configPath: "./wrangler.jsonc" }] });
		await harness.listen();
	});

	beforeEach(async () => {
		await harness.reset();
		base = (await harness.listen()).url;
	});

	afterAll(async () => {
		await harness.close();
	});

	/** Pairs two Guests through Quick Match and returns each side's seat. */
	async function pairTwoGuests(): Promise<Record<Side, PairedSeat>> {
		const guests = await Promise.all(
			["Ada", "Bob"].map(async (nickname) => {
				const guest = await JsonSocket.open<QuickMatchReply>(socketUrl(base, "/quick-match"));
				guest.send({ type: "join", nickname });
				return guest;
			}),
		);
		const seats: Partial<Record<Side, PairedSeat>> = {};
		for (const guest of guests) {
			const paired = await guest.replyWhere((reply) => reply.type !== "waiting");
			guest.leave();
			if (paired?.type !== "paired") {
				throw new Error(`a Guest was not paired: ${JSON.stringify(guest.replies)}`);
			}
			seats[paired.side] = { gameId: paired.gameId, seatToken: paired.seatToken, opponent: paired.opponent };
		}
		const { red, green } = seats;
		if (red === undefined || green === undefined) {
			throw new Error("both sides should be seated");
		}
		return { red, green };
	}

	async function takeSeat(seat: PairedSeat): Promise<PlayerSocket> {
		const player = await JsonSocket.open<RefereeReply>(socketUrl(base, `/games/${seat.gameId}`));
		player.send({ type: "take_seat", seatToken: seat.seatToken });
		await player.replyCount(2);
		return player;
	}

	async function startGame(): Promise<{ seats: Record<Side, PairedSeat>; red: PlayerSocket; green: PlayerSocket }> {
		const seats = await pairTwoGuests();
		const red = await takeSeat(seats.red);
		const green = await takeSeat(seats.green);
		red.send({ type: "setup", placements: placementsOf("red", RED_SETUP) });
		await Promise.all([red.replyCount(3), green.replyCount(3)]);
		green.send({ type: "setup", placements: placementsOf("green", GREEN_SETUP) });
		await Promise.all([red.replyCount(4), green.replyCount(4)]);
		return { seats, red, green };
	}

	it("seats both Guests and plays a game from Setup to Victory", async () => {
		const seats = await pairTwoGuests();
		const red = await takeSeat(seats.red);
		expect(red.replies).toEqual([
			{ type: "seated", side: "red", opponent: seats.red.opponent },
			{ type: "setup_status", ownSetupDone: false, opponentSetupDone: false },
		]);
		const green = await takeSeat(seats.green);

		red.send({ type: "setup", placements: placementsOf("red", RED_SETUP) });
		expect(await green.reply(2)).toEqual({ type: "setup_status", ownSetupDone: false, opponentSetupDone: true });

		green.send({ type: "setup", placements: placementsOf("green", GREEN_SETUP) });
		const redStart = await red.reply(3);
		const greenStart = await green.reply(3);
		expect(redStart).toMatchObject({ type: "game_state", history: [], view: { side: "red", sideToMove: "red" } });
		expect(greenStart).toMatchObject({ type: "game_state", history: [], view: { side: "green", sideToMove: "red" } });

		red.send({ type: "move", move: WINNING_MOVE });
		const redEnd = await red.reply(4);
		const greenEnd = await green.reply(4);
		for (const end of [redEnd, greenEnd]) {
			expect(end).toMatchObject({
				type: "moved",
				event: { moverSide: "red", fight: { attackerType: "buffoon", defenderType: "princess" } },
				view: { result: { status: "red_wins", reason: "princess_captured" } },
			});
			expect(end.type === "moved" ? end.finalBoard : undefined).toHaveLength(35);
		}
	});

	it("shows each player only their own Piece Types while the game goes on", async () => {
		const { red, green } = await startGame();
		red.send({ type: "move", move: parseMove("c3-c4") });
		await green.replyCount(5);

		const greenSaw = JSON.stringify(green.replies);
		expect(greenSaw).not.toMatch(/finalBoard/);
		for (const reply of green.replies) {
			if (reply.type === "game_state" || reply.type === "moved") {
				expect(reply.view.ownPieces).toHaveLength(18);
				expect(reply.view.side).toBe("green");
			}
		}
	});

	it("gives a Guest who reconnects the game so far", async () => {
		const { seats, red, green } = await startGame();
		red.send({ type: "move", move: parseMove("c3-c4") });
		await green.replyCount(5);
		green.leave();
		await green.closed;

		const back = await takeSeat(seats.green);
		expect(back.replies[1]).toMatchObject({
			type: "game_state",
			view: { side: "green", sideToMove: "green" },
			history: [{ moverSide: "red", move: parseMove("c3-c4") }],
		});
	});

	it("refuses an illegal Move and keeps the game going", async () => {
		const { red, green } = await startGame();
		red.send({ type: "move", move: parseMove("b3-b4") });
		expect(await red.reply(4)).toEqual({ type: "refused", reason: "illegal_move" });

		red.send({ type: "move", move: parseMove("c3-c4") });
		expect(await green.reply(4)).toMatchObject({ type: "moved", event: { moverSide: "red" } });
	});

	it("shows out a socket with a wrong Seat Token", async () => {
		const seats = await pairTwoGuests();
		const intruder = await JsonSocket.open<RefereeReply>(socketUrl(base, `/games/${seats.red.gameId}`));
		intruder.send({ type: "take_seat", seatToken: "0".repeat(64) });

		expect(await intruder.reply(0)).toEqual({ type: "refused", reason: "unknown_seat" });
		expect(await intruder.closed).toBe("unknown_seat");
	});

	it("answers 404 for a game id no game was opened with", async () => {
		const response = await harness.fetch(`/games/${"0".repeat(64)}`, { headers: { Upgrade: "websocket" } });
		expect(response.status).toBe(404);
	});
});
