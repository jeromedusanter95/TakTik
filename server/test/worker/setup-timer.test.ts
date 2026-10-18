import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { RefereeReply } from "../../src/referee/protocol";
import { placementsOf, RED_SETUP } from "../referee/fixtures";
import { pairTwoGuests, takeSeat } from "./paired-guests";

/** Short, so Setup ends within one test; the Forfeit delay stays long enough not to interfere. */
const SETUP_TIMER_SECONDS = 1;
const FORFEIT_AFTER_SECONDS = 60;

function startsPlay(reply: RefereeReply): boolean {
	return reply.type === "game_state";
}

describe("the Referee Worker's Setup Timer", () => {
	let harness: TestHarness;
	let base: URL;

	beforeAll(async () => {
		harness = createTestHarness({
			workers: [{ configPath: "./wrangler.jsonc", vars: { SETUP_TIMER_SECONDS, FORFEIT_AFTER_SECONDS } }],
		});
		await harness.listen();
	});

	beforeEach(async () => {
		await harness.reset();
		base = (await harness.listen()).url;
	});

	afterAll(async () => {
		await harness.close();
	});

	it("tells a Guest taking their seat how long Setup still runs", async () => {
		const seats = await pairTwoGuests(base);
		const red = await takeSeat(base, seats.red);

		const status = red.replies[1];
		expect(status?.type).toBe("setup_status");
		const timeLeft = status?.type === "setup_status" ? status.setupTimeLeftMs : -1;
		expect(timeLeft).toBeGreaterThanOrEqual(0);
		expect(timeLeft).toBeLessThanOrEqual(SETUP_TIMER_SECONDS * 1_000);
	});

	it("starts play with a Random Setup for a Guest who left during Setup", async () => {
		const seats = await pairTwoGuests(base);
		const red = await takeSeat(base, seats.red);
		const green = await takeSeat(base, seats.green);
		red.send({ type: "setup", placements: placementsOf("red", RED_SETUP) });
		green.leave();

		const start = await red.replyWhere(startsPlay);
		expect(start).toMatchObject({ type: "game_state", history: [], view: { side: "red", sideToMove: "red" } });

		const back = await takeSeat(base, seats.green);
		expect(back.replies[1]).toMatchObject({ type: "game_state", view: { side: "green", result: { status: "in_progress" } } });
		expect(back.replies[1]?.type === "game_state" ? back.replies[1].view.ownPieces : []).toHaveLength(18);
	});
});
