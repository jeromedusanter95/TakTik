import { beforeEach, describe, expect, it } from "vitest";
import { parseMove } from "../../src/rules/board-notation";
import type { Side } from "../../src/rules/side";
import { OnlineGame, type GameRecord } from "../../src/referee/online-game";
import type { RefereeReply } from "../../src/referee/protocol";
import { RefereeSession, type GameStore, type SeatConnections } from "../../src/referee/referee-session";
import { GREEN_SETUP, placementsOf, RED_SETUP, SEATING, WINNING_MOVE } from "./fixtures";

/** Sockets held in memory, seated in the order they take their seats. */
class FakeSeats implements SeatConnections<string> {
	readonly closed = new Set<string>();
	private readonly sides = new Map<string, Side>();
	private readonly sent = new Map<string, RefereeReply[]>();

	sideOf(connection: string): Side | undefined {
		return this.sides.get(connection);
	}

	seat(connection: string, side: Side): void {
		this.sides.set(connection, side);
	}

	connectionsOf(side: Side): readonly string[] {
		return [...this.sides].filter(([connection, seated]) => seated === side && !this.closed.has(connection)).map(([c]) => c);
	}

	send(connection: string, reply: RefereeReply): void {
		this.sent.set(connection, [...this.repliesTo(connection), reply]);
	}

	close(connection: string): void {
		this.closed.add(connection);
	}

	repliesTo(connection: string): RefereeReply[] {
		return this.sent.get(connection) ?? [];
	}

	lastReplyTo(connection: string): RefereeReply | undefined {
		return this.repliesTo(connection).at(-1);
	}
}

class FakeStore implements GameStore {
	readonly saved: GameRecord[] = [];

	async save(record: GameRecord): Promise<void> {
		this.saved.push(record);
	}
}

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("a Referee session", () => {
	let game: OnlineGame;
	let seats: FakeSeats;
	let store: FakeStore;
	let session: RefereeSession<string>;

	beforeEach(() => {
		game = OnlineGame.open(SEATING);
		seats = new FakeSeats();
		store = new FakeStore();
		session = new RefereeSession(game, seats, store);
	});

	async function seatBoth(): Promise<void> {
		await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));
		await session.receive("bob", text({ type: "take_seat", seatToken: "green-token" }));
	}

	async function startPlay(): Promise<void> {
		await seatBoth();
		await session.receive("ada", text({ type: "setup", placements: placementsOf("red", RED_SETUP) }));
		await session.receive("bob", text({ type: "setup", placements: placementsOf("green", GREEN_SETUP) }));
	}

	describe("seating", () => {
		it("seats a Guest by their Seat Token and tells them where Setup stands", async () => {
			await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));

			expect(seats.sideOf("ada")).toBe("red");
			expect(seats.repliesTo("ada")).toEqual([
				{ type: "seated", side: "red", opponent: "Bob" },
				{ type: "setup_status", ownSetupDone: false, opponentSetupDone: false },
			]);
		});

		it("shows out a Guest with an unknown Seat Token", async () => {
			await session.receive("eve", text({ type: "take_seat", seatToken: "guess" }));

			expect(seats.repliesTo("eve")).toEqual([{ type: "refused", reason: "unknown_seat" }]);
			expect(seats.closed.has("eve")).toBe(true);
			expect(seats.sideOf("eve")).toBeUndefined();
		});

		it("moves a seat to the newest socket and closes the old one", async () => {
			await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));
			await session.receive("ada-again", text({ type: "take_seat", seatToken: "red-token" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "seat_taken_elsewhere" });
			expect(seats.closed.has("ada")).toBe(true);
			expect(seats.connectionsOf("red")).toEqual(["ada-again"]);
		});

		it("refuses a second seat on the same socket", async () => {
			await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));
			await session.receive("ada", text({ type: "take_seat", seatToken: "green-token" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "already_seated" });
			expect(seats.sideOf("ada")).toBe("red");
		});

		it("shows out a socket that plays before taking a seat", async () => {
			await session.receive("eve", text({ type: "move", move: parseMove("a3-a4") }));

			expect(seats.repliesTo("eve")).toEqual([{ type: "refused", reason: "not_seated" }]);
			expect(seats.closed.has("eve")).toBe(true);
		});

		it("shows out an unseated socket that sends a malformed message", async () => {
			await session.receive("eve", "hello");

			expect(seats.repliesTo("eve")).toEqual([{ type: "refused", reason: "malformed_message" }]);
			expect(seats.closed.has("eve")).toBe(true);
		});

		it("keeps a seated Guest connected after a malformed message", async () => {
			await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));
			await session.receive("ada", "hello");

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "malformed_message" });
			expect(seats.closed.has("ada")).toBe(false);
		});
	});

	describe("Setup", () => {
		it("tells both players when one finishes and saves the game", async () => {
			await seatBoth();
			await session.receive("bob", text({ type: "setup", placements: placementsOf("green", GREEN_SETUP) }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "setup_status", ownSetupDone: false, opponentSetupDone: true });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "setup_status", ownSetupDone: true, opponentSetupDone: false });
			expect(store.saved.at(-1)?.setups.green).toEqual(placementsOf("green", GREEN_SETUP));
		});

		it("sends each player only their own view once both are in", async () => {
			await startPlay();

			expect(seats.lastReplyTo("ada")).toEqual({ type: "game_state", view: game.viewOf("red"), history: [] });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "game_state", view: game.viewOf("green"), history: [] });
		});

		it("refuses an invalid Setup without saving", async () => {
			await seatBoth();
			await session.receive("ada", text({ type: "setup", placements: placementsOf("green", GREEN_SETUP) }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "invalid_setup" });
			expect(store.saved).toEqual([]);
		});
	});

	describe("play", () => {
		it("sends both players the public event and their own view after a Move", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: parseMove("c3-c4") }));

			const event = { moverSide: "red", move: parseMove("c3-c4") };
			expect(seats.lastReplyTo("ada")).toEqual({ type: "moved", event, view: game.viewOf("red") });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "moved", event, view: game.viewOf("green") });
			expect(store.saved.at(-1)?.moves).toEqual([parseMove("c3-c4")]);
		});

		it("never sends a player a Piece Type of the other side while the game goes on", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: parseMove("c3-c4") }));

			const greenReplies = JSON.stringify(seats.repliesTo("bob"));
			expect(greenReplies).not.toMatch(/"finalBoard"/);
			expect(seats.lastReplyTo("bob")).toMatchObject({ view: { side: "green" } });
		});

		it("refuses a Move out of turn to that player only", async () => {
			await startPlay();
			const greenRepliesBefore = seats.repliesTo("bob").length;
			await session.receive("bob", text({ type: "move", move: parseMove("c6-c5") }));

			expect(seats.lastReplyTo("bob")).toEqual({ type: "refused", reason: "not_your_turn" });
			expect(seats.repliesTo("ada").at(-1)?.type).toBe("game_state");
			expect(seats.repliesTo("bob")).toHaveLength(greenRepliesBefore + 1);
		});

		it("reveals the whole Board to both players with the deciding Move", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: WINNING_MOVE }));

			expect(seats.lastReplyTo("bob")).toMatchObject({
				type: "moved",
				view: { result: { status: "red_wins", reason: "princess_captured" } },
				finalBoard: game.finalBoard(),
			});
		});

		it("gives a Guest who comes back the whole game so far", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: parseMove("c3-c4") }));
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));

			expect(seats.repliesTo("bob-again")).toEqual([
				{ type: "seated", side: "green", opponent: "Ada" },
				{ type: "game_state", view: game.viewOf("green"), history: game.history() },
			]);
		});
	});
});
