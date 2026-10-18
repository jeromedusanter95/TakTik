import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { QuickMatchReply } from "../../src/quick-match/protocol";
import { JsonSocket, socketUrl } from "./json-socket";

type GuestSocket = JsonSocket<QuickMatchReply>;

async function openGuest(url: URL): Promise<GuestSocket> {
	return JsonSocket.open<QuickMatchReply>(url);
}

function join(guest: GuestSocket, nickname: string): void {
	guest.send({ type: "join", nickname });
}

describe("the Quick Match Worker", () => {
	let harness: TestHarness;
	let quickMatchUrl: URL;

	beforeAll(async () => {
		harness = createTestHarness({ workers: [{ configPath: "./wrangler.jsonc" }] });
		await harness.listen();
	});

	beforeEach(async () => {
		await harness.reset();
		const { url } = await harness.listen();
		quickMatchUrl = socketUrl(url, "/quick-match");
	});

	afterAll(async () => {
		await harness.close();
	});

	it("pairs two Guests into one game on opposite sides and closes their sockets", async () => {
		const ada = await openGuest(quickMatchUrl);
		join(ada, "Ada");
		expect(await ada.replyCount(1)).toEqual([{ type: "waiting" }]);

		const bob = await openGuest(quickMatchUrl);
		join(bob, "Bob");
		const [adaPaired] = (await ada.replyCount(2)).slice(1);
		const [bobPaired] = await bob.replyCount(1);
		await Promise.all([ada.closed, bob.closed]);

		if (adaPaired?.type !== "paired" || bobPaired?.type !== "paired") {
			throw new Error(`expected both Guests to be paired, got ${JSON.stringify([adaPaired, bobPaired])}`);
		}
		expect(adaPaired.gameId).toBe(bobPaired.gameId);
		expect([adaPaired.side, bobPaired.side].sort()).toEqual(["green", "red"]);
		expect(adaPaired.opponent).toBe("Bob");
		expect(bobPaired.opponent).toBe("Ada");
		expect(adaPaired.seatToken).toMatch(/^[0-9a-f]{64}$/);
		expect(adaPaired.seatToken).not.toBe(bobPaired.seatToken);
	});

	it("never pairs a Guest with one who left while waiting", async () => {
		const ada = await openGuest(quickMatchUrl);
		join(ada, "Ada");
		await ada.replyCount(1);
		ada.leave();
		await ada.closed;

		const bob = await openGuest(quickMatchUrl);
		join(bob, "Bob");
		expect(await bob.replyCount(1)).toEqual([{ type: "waiting" }]);
	});

	it("refuses an invalid nickname and closes the socket", async () => {
		const guest = await openGuest(quickMatchUrl);
		join(guest, "   ");
		expect(await guest.replyCount(1)).toEqual([{ type: "refused", reason: "invalid_nickname" }]);
		await guest.closed;
	});

	it("answers anything but a WebSocket upgrade with 426", async () => {
		const response = await harness.fetch("/quick-match");
		expect(response.status).toBe(426);
	});

	it("answers an unknown path with 404", async () => {
		const response = await harness.fetch("/nothing-here");
		expect(response.status).toBe(404);
	});
});
