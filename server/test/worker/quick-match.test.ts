import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { QuickMatchReply } from "../../src/quick-match/protocol";

/** A Guest's Quick Match socket, recording every reply until the server closes it. */
class GuestSocket {
	readonly replies: QuickMatchReply[] = [];
	readonly closed: Promise<void>;
	private readonly socket: WebSocket;
	private waiters: (() => void)[] = [];

	private constructor(socket: WebSocket) {
		this.socket = socket;
		socket.addEventListener("message", (event) => {
			this.replies.push(JSON.parse(String(event.data)) as QuickMatchReply);
			this.waiters.forEach((wake) => wake());
			this.waiters = [];
		});
		this.closed = new Promise((resolve) => socket.addEventListener("close", () => resolve()));
	}

	static async open(url: URL): Promise<GuestSocket> {
		const socket = new WebSocket(url);
		await new Promise<void>((resolve, reject) => {
			socket.addEventListener("open", () => resolve());
			socket.addEventListener("error", () => reject(new Error("the socket could not open")));
		});
		return new GuestSocket(socket);
	}

	join(nickname: string): void {
		this.socket.send(JSON.stringify({ type: "join", nickname }));
	}

	leave(): void {
		this.socket.close();
	}

	async nextReplyCount(count: number): Promise<QuickMatchReply[]> {
		while (this.replies.length < count) {
			await new Promise<void>((wake) => this.waiters.push(wake));
		}
		return this.replies;
	}
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
		quickMatchUrl = new URL("/quick-match", url.href.replace(/^http/, "ws"));
	});

	afterAll(async () => {
		await harness.close();
	});

	it("pairs two Guests into one game on opposite sides and closes their sockets", async () => {
		const ada = await GuestSocket.open(quickMatchUrl);
		ada.join("Ada");
		expect(await ada.nextReplyCount(1)).toEqual([{ type: "waiting" }]);

		const bob = await GuestSocket.open(quickMatchUrl);
		bob.join("Bob");
		const [adaPaired] = (await ada.nextReplyCount(2)).slice(1);
		const [bobPaired] = await bob.nextReplyCount(1);
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
		const ada = await GuestSocket.open(quickMatchUrl);
		ada.join("Ada");
		await ada.nextReplyCount(1);
		ada.leave();
		await ada.closed;

		const bob = await GuestSocket.open(quickMatchUrl);
		bob.join("Bob");
		expect(await bob.nextReplyCount(1)).toEqual([{ type: "waiting" }]);
	});

	it("refuses an invalid nickname and closes the socket", async () => {
		const guest = await GuestSocket.open(quickMatchUrl);
		guest.join("   ");
		expect(await guest.nextReplyCount(1)).toEqual([{ type: "refused", reason: "invalid_nickname" }]);
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
