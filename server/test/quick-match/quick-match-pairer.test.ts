import { beforeEach, describe, expect, it } from "vitest";
import type { QuickMatchReply } from "../../src/quick-match/protocol";
import {
	QuickMatchPairer,
	type GameOpener,
	type GuestConnections,
	type PairingDraws,
	type WaitingGuest,
} from "../../src/quick-match/quick-match-pairer";
import type { Seating } from "../../src/referee/seating";

/** Connections held in memory, joined in the order they arrive. */
class FakeConnections implements GuestConnections<string> {
	readonly sent = new Map<string, QuickMatchReply[]>();
	readonly closed = new Set<string>();
	private readonly waiting: WaitingGuest<string>[] = [];
	private readonly joined = new Set<string>();

	waitingGuests(): readonly WaitingGuest<string>[] {
		return this.waiting.filter((guest) => !this.closed.has(guest.connection));
	}

	hasJoined(connection: string): boolean {
		return this.joined.has(connection);
	}

	markWaiting(connection: string, nickname: string): void {
		this.joined.add(connection);
		this.waiting.push({ connection, nickname });
	}

	markPaired(connection: string): void {
		this.joined.add(connection);
		const index = this.waiting.findIndex((guest) => guest.connection === connection);
		if (index >= 0) {
			this.waiting.splice(index, 1);
		}
	}

	send(connection: string, reply: QuickMatchReply): void {
		this.sent.set(connection, [...this.repliesTo(connection), reply]);
	}

	close(connection: string): void {
		this.closed.add(connection);
	}

	repliesTo(connection: string): QuickMatchReply[] {
		return this.sent.get(connection) ?? [];
	}
}

class FakeOpener implements GameOpener {
	readonly opened: Seating[] = [];
	failing = false;

	async open(seating: Seating): Promise<string> {
		if (this.failing) {
			throw new Error("the referee is unreachable");
		}
		this.opened.push(seating);
		return `game-${this.opened.length}`;
	}
}

/** Hands out seat-1, seat-2... and gives Red to the newcomer when told to. */
class FixedDraws implements PairingDraws {
	newcomerIsRed = true;
	private issued = 0;

	seatToken(): string {
		this.issued += 1;
		return `seat-${this.issued}`;
	}

	newcomerPlaysRed(): boolean {
		return this.newcomerIsRed;
	}
}

function join(nickname: string): string {
	return JSON.stringify({ type: "join", nickname });
}

describe("the Quick Match pairer", () => {
	let connections: FakeConnections;
	let opener: FakeOpener;
	let draws: FixedDraws;
	let pairer: QuickMatchPairer<string>;

	beforeEach(() => {
		connections = new FakeConnections();
		opener = new FakeOpener();
		draws = new FixedDraws();
		pairer = new QuickMatchPairer(connections, opener, draws);
	});

	it("keeps the first Guest waiting", async () => {
		await pairer.receive("ada", join("Ada"));

		expect(connections.repliesTo("ada")).toEqual([{ type: "waiting" }]);
		expect(connections.closed.has("ada")).toBe(false);
		expect(opener.opened).toEqual([]);
	});

	it("pairs the second Guest with the one waiting and opens their game", async () => {
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));

		expect(opener.opened).toEqual([
			{ red: { nickname: "Bob", seatToken: "seat-1" }, green: { nickname: "Ada", seatToken: "seat-2" } },
		]);
		expect(connections.repliesTo("ada")).toEqual([
			{ type: "waiting" },
			{ type: "paired", gameId: "game-1", side: "green", seatToken: "seat-2", opponent: "Bob" },
		]);
		expect(connections.repliesTo("bob")).toEqual([
			{ type: "paired", gameId: "game-1", side: "red", seatToken: "seat-1", opponent: "Ada" },
		]);
	});

	it("gives Red to the Guest who was waiting when the draw says so", async () => {
		draws.newcomerIsRed = false;
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));

		expect(opener.opened[0]?.red.nickname).toBe("Ada");
		expect(opener.opened[0]?.green.nickname).toBe("Bob");
	});

	it("closes both sockets once paired", async () => {
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));

		expect([...connections.closed].sort()).toEqual(["ada", "bob"]);
	});

	it("pairs the Guest who has waited longest", async () => {
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));
		await pairer.receive("cyd", join("Cyd"));
		await pairer.receive("dee", join("Dee"));

		expect(opener.opened.map((seating) => [seating.red.nickname, seating.green.nickname])).toEqual([
			["Bob", "Ada"],
			["Dee", "Cyd"],
		]);
	});

	it("never pairs a Guest whose socket has closed", async () => {
		await pairer.receive("ada", join("Ada"));
		connections.close("ada");
		await pairer.receive("bob", join("Bob"));

		expect(connections.repliesTo("bob")).toEqual([{ type: "waiting" }]);
		expect(opener.opened).toEqual([]);
	});

	it("lets two Guests use the same nickname", async () => {
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("ada-too", join("Ada"));

		expect(opener.opened).toHaveLength(1);
	});

	it("refuses a second join on the same socket and keeps the Guest waiting", async () => {
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("ada", join("Ada"));

		expect(connections.repliesTo("ada")).toEqual([{ type: "waiting" }, { type: "refused", reason: "already_joined" }]);
		expect(connections.waitingGuests()).toEqual([{ connection: "ada", nickname: "Ada" }]);
		expect(connections.closed.has("ada")).toBe(false);
	});

	it("refuses an invalid nickname and closes the socket", async () => {
		await pairer.receive("ada", join(""));

		expect(connections.repliesTo("ada")).toEqual([{ type: "refused", reason: "invalid_nickname" }]);
		expect(connections.closed.has("ada")).toBe(true);
		expect(connections.waitingGuests()).toEqual([]);
	});

	it("refuses a malformed message and closes the socket", async () => {
		await pairer.receive("ada", "hello");

		expect(connections.repliesTo("ada")).toEqual([{ type: "refused", reason: "malformed_message" }]);
		expect(connections.closed.has("ada")).toBe(true);
	});

	it("tells both Guests when their game cannot be opened", async () => {
		opener.failing = true;
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));

		expect(connections.repliesTo("ada").at(-1)).toEqual({ type: "refused", reason: "game_unavailable" });
		expect(connections.repliesTo("bob")).toEqual([{ type: "refused", reason: "game_unavailable" }]);
		expect([...connections.closed].sort()).toEqual(["ada", "bob"]);
	});

	it("takes a paired Guest out of the waiting list before the game is opened", async () => {
		const slowOpener: GameOpener = {
			open: async () => {
				expect(connections.waitingGuests()).toEqual([]);
				return "game-slow";
			},
		};
		pairer = new QuickMatchPairer(connections, slowOpener, draws);
		await pairer.receive("ada", join("Ada"));
		await pairer.receive("bob", join("Bob"));

		expect(connections.repliesTo("bob")[0]).toMatchObject({ type: "paired", gameId: "game-slow" });
	});
});
