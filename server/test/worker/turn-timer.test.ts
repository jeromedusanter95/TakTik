import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { RefereeReply } from "../../src/referee/protocol";
import { GREEN_SETUP, placementsOf, RED_SETUP } from "../referee/fixtures";
import { pairTwoGuests, takeSeat } from "./paired-guests";

/** Short, so a turn runs out within one test. */
const TURN_TIMER_SECONDS = 1;

function isOver(reply: RefereeReply): boolean {
	return reply.type === "game_state" && reply.view.result.status !== "in_progress";
}

describe("the Referee Worker's Turn Timer", () => {
	let harness: TestHarness;
	let base: URL;

	beforeAll(async () => {
		harness = createTestHarness({ workers: [{ configPath: "./wrangler.jsonc", vars: { TURN_TIMER_SECONDS } }] });
		await harness.listen();
	});

	beforeEach(async () => {
		await harness.reset();
		base = (await harness.listen()).url;
	});

	afterAll(async () => {
		await harness.close();
	});

	it("tells both Guests how long Red has, then Forfeits Red who never moves", async () => {
		const seats = await pairTwoGuests(base);
		const red = await takeSeat(base, seats.red);
		const green = await takeSeat(base, seats.green);
		red.send({ type: "setup", placements: placementsOf("red", RED_SETUP) });
		green.send({ type: "setup", placements: placementsOf("green", GREEN_SETUP) });

		const start = await green.replyWhere((reply) => reply.type === "game_state");
		const timeLeft = start.type === "game_state" ? start.turnTimeLeftMs : undefined;
		expect(timeLeft).toBeGreaterThanOrEqual(0);
		expect(timeLeft).toBeLessThanOrEqual(TURN_TIMER_SECONDS * 1_000);

		const end = await green.replyWhere(isOver);
		expect(end).toMatchObject({ view: { result: { status: "green_wins", reason: "out_of_time" } } });
		expect(end.type === "game_state" ? end.finalBoard : undefined).toHaveLength(36);
	});
});
