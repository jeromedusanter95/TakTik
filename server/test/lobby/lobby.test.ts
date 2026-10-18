import { beforeEach, describe, expect, it } from "vitest";
import type { GameOpener } from "../../src/lobby/game-opener";
import {
	Lobby,
	MAX_LISTED_GUESTS,
	type Clock,
	type GuestState,
	type LobbyConnections,
	type LobbyDraws,
	type LobbyGuest,
} from "../../src/lobby/lobby";
import type { LobbyRefusal, LobbyReply } from "../../src/lobby/protocol";
import type { Seating } from "../../src/referee/seating";

/** Lobby sockets held in memory. */
class FakeConnections implements LobbyConnections<string> {
	readonly closed = new Set<string>();
	readonly closeReasons = new Map<string, LobbyRefusal>();
	private readonly states = new Map<string, GuestState>();
	private readonly paired = new Set<string>();
	private readonly sent = new Map<string, LobbyReply[]>();

	guests(): readonly LobbyGuest<string>[] {
		return [...this.states]
			.filter(([connection]) => !this.closed.has(connection) && !this.paired.has(connection))
			.map(([connection, state]) => ({ ...state, connection }))
			.sort((first, second) => first.enteredAt - second.enteredAt);
	}

	stateOf(connection: string): GuestState | undefined {
		return this.paired.has(connection) ? undefined : this.states.get(connection);
	}

	hasEntered(connection: string): boolean {
		return this.states.has(connection);
	}

	setState(connection: string, state: GuestState): void {
		this.states.set(connection, state);
	}

	markPaired(connection: string): void {
		this.paired.add(connection);
	}

	send(connection: string, reply: LobbyReply): void {
		if (!this.closed.has(connection)) {
			this.sent.set(connection, [...this.repliesTo(connection), reply]);
		}
	}

	refuseAndClose(connection: string, reason: LobbyRefusal): void {
		this.closed.add(connection);
		this.closeReasons.set(connection, reason);
	}

	/** The Guest closing their own socket. */
	leave(connection: string): void {
		this.closed.add(connection);
	}

	repliesTo(connection: string): LobbyReply[] {
		return this.sent.get(connection) ?? [];
	}

	lastReplyTo(connection: string): LobbyReply | undefined {
		return this.repliesTo(connection).at(-1);
	}

	/** The replies of [type] sent to [connection]. */
	repliesOfType<Type extends LobbyReply["type"]>(connection: string, type: Type): Extract<LobbyReply, { type: Type }>[] {
		return this.repliesTo(connection).filter((reply): reply is Extract<LobbyReply, { type: Type }> => reply.type === type);
	}

	clearReplies(): void {
		this.sent.clear();
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

/** Names Guests after their connection's order of arrival: guest-1, guest-2... */
class FixedDraws implements LobbyDraws {
	firstIsRed = true;
	private guests = 0;
	private seats = 0;

	guestId(): string {
		this.guests += 1;
		return `guest-${this.guests}`;
	}

	seatToken(): string {
		this.seats += 1;
		return `seat-${this.seats}`;
	}

	firstPlaysRed(): boolean {
		return this.firstIsRed;
	}
}

class TickingClock implements Clock {
	private time = 0;

	now(): number {
		this.time += 1;
		return this.time;
	}
}

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("the Lobby", () => {
	let connections: FakeConnections;
	let opener: FakeOpener;
	let draws: FixedDraws;
	let lobby: Lobby<string>;

	beforeEach(() => {
		connections = new FakeConnections();
		opener = new FakeOpener();
		draws = new FixedDraws();
		lobby = new Lobby(connections, opener, draws, new TickingClock());
	});

	/** Enters [connection] with the nickname of the same name; Guest ids follow the order of entry. */
	async function enter(...names: string[]): Promise<void> {
		for (const name of names) {
			await lobby.receive(name, text({ type: "enter", nickname: name }));
		}
	}

	async function send(connection: string, message: unknown): Promise<void> {
		await lobby.receive(connection, text(message));
	}

	describe("Guests playing a game", () => {
		it("lists them as in a game", async () => {
			await enter("Ada");
			await send("Bob", { type: "enter", nickname: "Bob", inGame: true });

			expect(connections.lastReplyTo("Ada")).toEqual({
				type: "guests",
				guests: [{ guestId: "guest-2", nickname: "Bob", waiting: false, inGame: true }],
			});
		});

		it("answers a Challenge to them that they are busy", async () => {
			await enter("Ada");
			await send("Bob", { type: "enter", nickname: "Bob", inGame: true });
			await send("Ada", { type: "challenge", guestId: "guest-2" });

			expect(connections.lastReplyTo("Ada")).toEqual({ type: "challenge_ended", guestId: "guest-2", reason: "busy" });
			expect(connections.repliesOfType("Bob", "challenged")).toEqual([]);
		});

		it("never pairs them by Quick Match", async () => {
			await send("Bob", { type: "enter", nickname: "Bob", inGame: true });
			await send("Bob", { type: "quick_match" });
			await enter("Ada");
			await send("Ada", { type: "quick_match" });

			expect(connections.lastReplyTo("Bob")).not.toMatchObject({ type: "paired" });
			expect(connections.repliesOfType("Bob", "refused")).toEqual([{ type: "refused", reason: "in_game" }]);
			expect(connections.repliesOfType("Ada", "quick_match")).toEqual([{ type: "quick_match", waiting: true }]);
		});
	});

	describe("entering", () => {
		it("gives the Guest an id and lists the Guests already there", async () => {
			await enter("Ada", "Bob");

			expect(connections.repliesTo("Bob")[0]).toEqual({ type: "entered", guestId: "guest-2" });
			expect(connections.lastReplyTo("Bob")).toEqual({
				type: "guests",
				guests: [{ guestId: "guest-1", nickname: "Ada", waiting: false, inGame: false }],
			});
		});

		it("tells the Guests already there about the newcomer", async () => {
			await enter("Ada", "Bob");

			expect(connections.lastReplyTo("Ada")).toEqual({
				type: "guests",
				guests: [{ guestId: "guest-2", nickname: "Bob", waiting: false, inGame: false }],
			});
		});

		it("lists at most the Guests there longest", async () => {
			const names = Array.from({ length: MAX_LISTED_GUESTS + 2 }, (_, index) => `g${index}`);
			await enter(...names);

			const listing = connections.repliesOfType("g0", "guests").at(-1);
			expect(listing?.guests).toHaveLength(MAX_LISTED_GUESTS);
			expect(listing?.guests[0]?.nickname).toBe("g1");
		});

		it("refuses an invalid nickname and shows the socket out", async () => {
			await send("eve", { type: "enter", nickname: "   " });

			expect(connections.repliesTo("eve")).toEqual([{ type: "refused", reason: "invalid_nickname" }]);
			expect(connections.closeReasons.get("eve")).toBe("invalid_nickname");
		});

		it("refuses entering twice and keeps the Guest in", async () => {
			await enter("Ada");
			await send("Ada", { type: "enter", nickname: "Ada" });

			expect(connections.lastReplyTo("Ada")).toEqual({ type: "refused", reason: "already_entered" });
			expect(connections.closed.has("Ada")).toBe(false);
		});

		it("shows out a socket that acts before entering", async () => {
			await send("eve", { type: "quick_match" });

			expect(connections.closeReasons.get("eve")).toBe("not_entered");
		});

		it("keeps an entered Guest who sends a malformed message", async () => {
			await enter("Ada");
			await lobby.receive("Ada", "hello");

			expect(connections.lastReplyTo("Ada")).toEqual({ type: "refused", reason: "malformed_message" });
			expect(connections.closed.has("Ada")).toBe(false);
		});
	});

	describe("Quick Match", () => {
		it("keeps the first Guest waiting and shows them waiting to the others", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "quick_match" });

			expect(connections.repliesOfType("Ada", "quick_match")).toEqual([{ type: "quick_match", waiting: true }]);
			expect(connections.lastReplyTo("Bob")).toEqual({
				type: "guests",
				guests: [{ guestId: "guest-1", nickname: "Ada", waiting: true, inGame: false }],
			});
		});

		it("pairs the next Guest with the one waiting and opens their game", async () => {
			await enter("Ada", "Bob", "Cyd");
			await send("Ada", { type: "quick_match" });
			await send("Bob", { type: "quick_match" });
			await send("Cyd", { type: "quick_match" });

			expect(opener.opened).toEqual([
				{ red: { nickname: "Ada", seatToken: "seat-1" }, green: { nickname: "Bob", seatToken: "seat-2" } },
			]);
			expect(connections.lastReplyTo("Ada")).toEqual({
				type: "paired",
				gameId: "game-1",
				side: "red",
				seatToken: "seat-1",
				opponent: "Bob",
			});
			expect(connections.lastReplyTo("Bob")).toMatchObject({ type: "paired", side: "green", opponent: "Ada" });
			expect(connections.repliesOfType("Cyd", "quick_match")).toEqual([{ type: "quick_match", waiting: true }]);
		});

		it("draws lots for the sides", async () => {
			draws.firstIsRed = false;
			await enter("Ada", "Bob");
			await send("Ada", { type: "quick_match" });
			await send("Bob", { type: "quick_match" });

			expect(opener.opened[0]?.red.nickname).toBe("Bob");
		});

		it("takes paired Guests out of the Lobby and leaves their sockets to them", async () => {
			await enter("Ada", "Bob", "Cyd");
			await send("Ada", { type: "quick_match" });
			await send("Bob", { type: "quick_match" });

			expect(connections.lastReplyTo("Cyd")).toEqual({ type: "guests", guests: [] });
			expect(connections.closed.size).toBe(0);
		});

		it("lets a Guest stop waiting", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "quick_match" });
			await send("Ada", { type: "stop_waiting" });
			await send("Bob", { type: "quick_match" });

			expect(connections.lastReplyTo("Ada")).toMatchObject({ type: "guests" });
			expect(opener.opened).toEqual([]);
		});

		it("never pairs a Guest who left", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "quick_match" });
			connections.leave("Ada");
			lobby.leave("Ada");
			await send("Bob", { type: "quick_match" });

			expect(opener.opened).toEqual([]);
			expect(connections.repliesOfType("Bob", "quick_match")).toEqual([{ type: "quick_match", waiting: true }]);
		});

		it("tells both Guests when their game cannot be opened", async () => {
			opener.failing = true;
			await enter("Ada", "Bob");
			await send("Ada", { type: "quick_match" });
			await send("Bob", { type: "quick_match" });

			expect(connections.closeReasons.get("Ada")).toBe("game_unavailable");
			expect(connections.closeReasons.get("Bob")).toBe("game_unavailable");
		});
	});

	describe("Challenges", () => {
		it("delivers a Challenge to the Guest named", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "challenge", guestId: "guest-2" });

			expect(connections.repliesOfType("Ada", "challenge_sent")).toEqual([{ type: "challenge_sent", guestId: "guest-2" }]);
			expect(connections.repliesOfType("Bob", "challenged")).toEqual([
				{ type: "challenged", guestId: "guest-1", nickname: "Ada" },
			]);
		});

		it("pairs the two Guests when the Challenge is accepted", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Bob", { type: "answer_challenge", guestId: "guest-1", accept: true });

			expect(opener.opened).toEqual([
				{ red: { nickname: "Ada", seatToken: "seat-1" }, green: { nickname: "Bob", seatToken: "seat-2" } },
			]);
			expect(connections.lastReplyTo("Bob")).toMatchObject({ type: "paired", side: "green", opponent: "Ada" });
		});

		it("tells the sender when the Challenge is declined", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Bob", { type: "answer_challenge", guestId: "guest-1", accept: false });

			expect(connections.repliesOfType("Ada", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-2", reason: "declined" },
			]);
			expect(opener.opened).toEqual([]);
		});

		it("tells the Guest challenged when the sender withdraws", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Ada", { type: "withdraw_challenge" });

			expect(connections.repliesOfType("Bob", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-1", reason: "withdrawn" },
			]);
			await send("Bob", { type: "answer_challenge", guestId: "guest-1", accept: true });
			expect(connections.lastReplyTo("Bob")).toEqual({ type: "refused", reason: "no_such_challenge" });
		});

		it("withdraws the previous Challenge when the sender challenges someone else", async () => {
			await enter("Ada", "Bob", "Cyd");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Ada", { type: "challenge", guestId: "guest-3" });

			expect(connections.repliesOfType("Bob", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-1", reason: "withdrawn" },
			]);
			expect(connections.repliesOfType("Cyd", "challenged")).toHaveLength(1);
		});

		it("withdraws a Challenge when its sender joins Quick Match", async () => {
			await enter("Ada", "Bob");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Ada", { type: "quick_match" });

			expect(connections.repliesOfType("Bob", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-1", reason: "withdrawn" },
			]);
		});

		it("ends the Challenges of a Guest who leaves", async () => {
			await enter("Ada", "Bob", "Cyd");
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Cyd", { type: "challenge", guestId: "guest-1" });
			connections.leave("Ada");
			lobby.leave("Ada");

			expect(connections.repliesOfType("Bob", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-1", reason: "gone" },
			]);
			expect(connections.repliesOfType("Cyd", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-1", reason: "gone" },
			]);
		});

		it("ends the other Challenges of two Guests once they are paired", async () => {
			await enter("Ada", "Bob", "Cyd");
			await send("Cyd", { type: "challenge", guestId: "guest-2" });
			await send("Ada", { type: "challenge", guestId: "guest-2" });
			await send("Bob", { type: "answer_challenge", guestId: "guest-1", accept: true });

			expect(connections.repliesOfType("Cyd", "challenge_ended")).toEqual([
				{ type: "challenge_ended", guestId: "guest-2", reason: "gone" },
			]);
			await send("Cyd", { type: "challenge", guestId: "guest-2" });
			expect(connections.lastReplyTo("Cyd")).toEqual({ type: "refused", reason: "unknown_guest" });
		});

		it("refuses a Challenge to a Guest who is not in the Lobby, or to oneself", async () => {
			await enter("Ada");
			await send("Ada", { type: "challenge", guestId: "guest-9" });
			expect(connections.lastReplyTo("Ada")).toEqual({ type: "refused", reason: "unknown_guest" });
			await send("Ada", { type: "challenge", guestId: "guest-1" });
			expect(connections.lastReplyTo("Ada")).toEqual({ type: "refused", reason: "unknown_guest" });
		});

		it("refuses answering a Challenge never sent", async () => {
			await enter("Ada", "Bob");
			await send("Bob", { type: "answer_challenge", guestId: "guest-1", accept: true });

			expect(connections.lastReplyTo("Bob")).toEqual({ type: "refused", reason: "no_such_challenge" });
		});
	});
});
