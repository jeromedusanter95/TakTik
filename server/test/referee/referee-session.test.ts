import { beforeEach, describe, expect, it } from "vitest";
import { parseMove } from "../../src/rules/board-notation";
import type { Side } from "../../src/rules/side";
import { ForfeitWatch, type AbsenceRecord, type AbsenceStore, type Clock, type ForfeitAlarm } from "../../src/referee/forfeit-watch";
import { OnlineGame, type GameRecord } from "../../src/referee/online-game";
import type { RefereeRefusal, RefereeReply } from "../../src/referee/protocol";
import { RefereeSession, type GameStore, type SeatConnections } from "../../src/referee/referee-session";
import type { OpenedRematch, RematchMaker } from "../../src/referee/rematch-maker";
import { GREEN_SETUP, placementsOf, RED_SETUP, SEATING, WINNING_MOVE } from "./fixtures";

/** Sockets held in memory, seated in the order they take their seats. */
class FakeSeats implements SeatConnections<string> {
	readonly closed = new Set<string>();
	private readonly rematchWishes = new Set<string>();
	readonly closeReasons = new Map<string, RefereeRefusal>();
	private readonly sides = new Map<string, Side>();
	private readonly sent = new Map<string, RefereeReply[]>();

	sideOf(connection: string): Side | undefined {
		return this.sides.get(connection);
	}

	markWantsRematch(connection: string): void {
		this.rematchWishes.add(connection);
	}

	wantsRematch(side: Side): boolean {
		return this.connectionsOf(side).some((connection) => this.rematchWishes.has(connection));
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

	refuseAndClose(connection: string, reason: RefereeRefusal): void {
		this.closed.add(connection);
		this.closeReasons.set(connection, reason);
	}

	repliesTo(connection: string): RefereeReply[] {
		return this.sent.get(connection) ?? [];
	}

	lastReplyTo(connection: string): RefereeReply | undefined {
		return this.repliesTo(connection).at(-1);
	}
}

/** Hands out game-1, game-2... with seat tokens named after the new side. */
class FakeRematchMaker implements RematchMaker {
	readonly opened: Readonly<Record<Side, string>>[] = [];
	failing = false;

	async open(nicknames: Readonly<Record<Side, string>>): Promise<OpenedRematch> {
		if (this.failing) {
			throw new Error("no referee");
		}
		this.opened.push(nicknames);
		const gameId = `game-${this.opened.length}`;
		return {
			gameId,
			seating: {
				red: { nickname: nicknames.red, seatToken: `${gameId}-red` },
				green: { nickname: nicknames.green, seatToken: `${gameId}-green` },
			},
		};
	}
}

class FakeStore implements GameStore {
	readonly saved: GameRecord[] = [];

	async save(record: GameRecord): Promise<void> {
		this.saved.push(record);
	}
}

class FakeAbsences implements AbsenceStore {
	saved: AbsenceRecord = {};

	async saveAbsences(record: AbsenceRecord): Promise<void> {
		this.saved = record;
	}
}

class FakeAlarm implements ForfeitAlarm {
	time: number | undefined;

	async setFor(time: number | undefined): Promise<void> {
		this.time = time;
	}
}

class FakeClock implements Clock {
	time = 1_000;

	now(): number {
		return this.time;
	}
}

const FORFEIT_AFTER_MS = 60_000;

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("a Referee session", () => {
	let game: OnlineGame;
	let seats: FakeSeats;
	let store: FakeStore;
	let absences: FakeAbsences;
	let alarm: FakeAlarm;
	let clock: FakeClock;
	let session: RefereeSession<string>;
	let rematches: FakeRematchMaker;

	function watchFrom(record: AbsenceRecord): ForfeitWatch {
		return new ForfeitWatch(record, { forfeitAfterMs: FORFEIT_AFTER_MS, clock, store: absences, alarm });
	}

	beforeEach(() => {
		game = OnlineGame.open(SEATING);
		seats = new FakeSeats();
		store = new FakeStore();
		absences = new FakeAbsences();
		alarm = new FakeAlarm();
		clock = new FakeClock();
		rematches = new FakeRematchMaker();
		session = new RefereeSession(game, seats, store, watchFrom({}), rematches);
	});

	/** The socket closing, as the server sees it. */
	async function drop(connection: string): Promise<void> {
		seats.closed.add(connection);
		await session.disconnect(connection);
	}

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
			expect(seats.closeReasons.get("eve")).toBe("unknown_seat");
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

	describe("Resign", () => {
		it("gives Victory to the Opponent and shows both players the whole Board", async () => {
			await startPlay();
			await session.receive("bob", text({ type: "resign" }));

			for (const player of ["ada", "bob"]) {
				expect(seats.lastReplyTo(player)).toMatchObject({
					type: "game_state",
					view: { result: { status: "red_wins", reason: "resigned" } },
					finalBoard: game.finalBoard(),
				});
			}
			expect(store.saved.at(-1)?.concession).toEqual({ loser: "green", reason: "resigned" });
		});

		it("is refused during Setup", async () => {
			await seatBoth();
			await session.receive("ada", text({ type: "resign" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "game_not_started" });
			expect(store.saved).toEqual([]);
		});

		it("is refused once the game is over", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: WINNING_MOVE }));
			await session.receive("bob", text({ type: "resign" }));

			expect(seats.lastReplyTo("bob")).toEqual({ type: "refused", reason: "game_over" });
		});

		it("shows out a socket that Resigns before taking a seat", async () => {
			await session.receive("eve", text({ type: "resign" }));
			expect(seats.closeReasons.get("eve")).toBe("not_seated");
		});
	});

	describe("the Opponent's presence", () => {
		it("tells a player when their Opponent's last socket closes", async () => {
			await startPlay();
			await drop("bob");

			expect(seats.lastReplyTo("ada")).toEqual({ type: "opponent_presence", connected: false });
			expect(absences.saved).toEqual({ green: 1_000 });
		});

		it("tells a player when their Opponent takes their seat again", async () => {
			await startPlay();
			await drop("bob");
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "opponent_presence", connected: true });
			expect(absences.saved).toEqual({});
		});

		it("tells a player taking their seat that their Opponent is away", async () => {
			await startPlay();
			await drop("bob");
			await drop("ada");
			await session.receive("ada-again", text({ type: "take_seat", seatToken: "red-token" }));

			expect(seats.repliesTo("ada-again").map((reply) => reply.type)).toEqual([
				"seated",
				"game_state",
				"opponent_presence",
			]);
			expect(seats.lastReplyTo("ada-again")).toEqual({ type: "opponent_presence", connected: false });
		});

		it("says nothing when a socket replaced by a newer one closes", async () => {
			await startPlay();
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));
			const redRepliesBefore = seats.repliesTo("ada").length;
			await drop("bob");

			expect(seats.repliesTo("ada")).toHaveLength(redRepliesBefore);
			expect(absences.saved).toEqual({});
		});

		it("ignores a socket that closes before taking a seat", async () => {
			await startPlay();
			await drop("eve");
			expect(absences.saved).toEqual({});
		});
	});

	describe("Forfeit", () => {
		it("sets the alarm for when a player who left during play would Forfeit", async () => {
			await startPlay();
			await drop("bob");
			expect(alarm.time).toBe(1_000 + FORFEIT_AFTER_MS);
		});

		it("cancels the alarm when the player comes back", async () => {
			await startPlay();
			await drop("bob");
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));
			expect(alarm.time).toBeUndefined();
		});

		it("gives Victory to the Opponent of a player who stayed away too long", async () => {
			await startPlay();
			await drop("bob");
			clock.time += FORFEIT_AFTER_MS;
			await session.forfeitOverdue();

			expect(seats.lastReplyTo("ada")).toMatchObject({
				type: "game_state",
				view: { result: { status: "red_wins", reason: "forfeited" } },
				finalBoard: game.finalBoard(),
			});
			expect(store.saved.at(-1)?.concession).toEqual({ loser: "green", reason: "forfeited" });
			expect(alarm.time).toBeUndefined();
		});

		it("Forfeits no one before the delay is up", async () => {
			await startPlay();
			await drop("bob");
			clock.time += FORFEIT_AFTER_MS - 1;
			await session.forfeitOverdue();

			expect(game.phase()).toBe("playing");
			expect(alarm.time).toBe(1_000 + FORFEIT_AFTER_MS);
		});

		it("Forfeits the player who left first when both are away", async () => {
			await startPlay();
			await drop("ada");
			clock.time += 10;
			await drop("bob");
			clock.time += FORFEIT_AFTER_MS;
			await session.forfeitOverdue();

			expect(game.viewOf("green").result).toEqual({ status: "green_wins", reason: "forfeited" });
		});

		it("waits for play to start before setting the alarm", async () => {
			await seatBoth();
			await session.receive("bob", text({ type: "setup", placements: placementsOf("green", GREEN_SETUP) }));
			await drop("bob");
			expect(alarm.time).toBeUndefined();

			await session.receive("ada", text({ type: "setup", placements: placementsOf("red", RED_SETUP) }));
			expect(alarm.time).toBe(1_000 + FORFEIT_AFTER_MS);
		});

		it("still Forfeits a player once the referee was rebuilt from storage", async () => {
			await startPlay();
			await drop("bob");
			const rebuilt = OnlineGame.fromRecord(game.toRecord());
			const restarted = new RefereeSession(rebuilt, seats, store, watchFrom(absences.saved), rematches);
			clock.time += FORFEIT_AFTER_MS;
			await restarted.forfeitOverdue();

			expect(rebuilt.viewOf("red").result).toEqual({ status: "red_wins", reason: "forfeited" });
		});

		it("cancels the alarm when a Move ends the game", async () => {
			await startPlay();
			await drop("bob");
			await session.receive("ada", text({ type: "move", move: WINNING_MOVE }));
			expect(alarm.time).toBeUndefined();
		});
	});
	describe("Quick Chat", () => {
		it("relays a Quick Chat to both players with its sender", async () => {
			await seatBoth();
			await session.receive("bob", text({ type: "quick_chat", message: "good_luck" }));

			for (const connection of ["ada", "bob"]) {
				expect(seats.lastReplyTo(connection)).toEqual({ type: "quick_chat", side: "green", message: "good_luck" });
			}
		});

		it("refuses a message outside the fixed set", async () => {
			await seatBoth();
			await session.receive("bob", text({ type: "quick_chat", message: "you are bad" }));

			expect(seats.lastReplyTo("bob")).toEqual({ type: "refused", reason: "malformed_message" });
			expect(seats.lastReplyTo("ada")?.type).not.toBe("quick_chat");
		});
	});

	describe("Rematch", () => {
		async function finishGame(): Promise<void> {
			await startPlay();
			await session.receive("ada", text({ type: "move", move: WINNING_MOVE }));
		}

		it("is refused while the game goes on", async () => {
			await startPlay();
			await session.receive("ada", text({ type: "rematch" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "game_not_over" });
		});

		it("tells the Opponent when one player asks for it", async () => {
			await finishGame();
			await session.receive("ada", text({ type: "rematch" }));

			expect(seats.lastReplyTo("bob")).toEqual({ type: "rematch_offered" });
			expect(rematches.opened).toEqual([]);
		});

		it("opens a new game with the sides swapped once both ask", async () => {
			await finishGame();
			await session.receive("ada", text({ type: "rematch" }));
			await session.receive("bob", text({ type: "rematch" }));

			expect(rematches.opened).toEqual([{ red: "Bob", green: "Ada" }]);
			expect(seats.lastReplyTo("ada")).toEqual({
				type: "rematch_ready",
				gameId: "game-1",
				side: "green",
				seatToken: "game-1-green",
				opponent: "Bob",
			});
			expect(seats.lastReplyTo("bob")).toEqual({
				type: "rematch_ready",
				gameId: "game-1",
				side: "red",
				seatToken: "game-1-red",
				opponent: "Ada",
			});
		});

		it("gives the same seat again to a player who asks twice", async () => {
			await finishGame();
			await session.receive("ada", text({ type: "rematch" }));
			await session.receive("bob", text({ type: "rematch" }));
			await session.receive("ada", text({ type: "rematch" }));

			expect(rematches.opened).toHaveLength(1);
			expect(seats.lastReplyTo("ada")).toMatchObject({ type: "rematch_ready", side: "green", gameId: "game-1" });
		});

		it("forgets the wish of a player whose socket closed", async () => {
			await finishGame();
			await session.receive("ada", text({ type: "rematch" }));
			await drop("ada");
			await session.receive("bob", text({ type: "rematch" }));

			expect(rematches.opened).toEqual([]);
		});

		it("tells both players when no Rematch could be opened", async () => {
			rematches.failing = true;
			await finishGame();
			await session.receive("ada", text({ type: "rematch" }));
			await session.receive("bob", text({ type: "rematch" }));

			expect(seats.lastReplyTo("ada")).toEqual({ type: "refused", reason: "rematch_unavailable" });
		});
	});
});
