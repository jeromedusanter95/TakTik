import { beforeEach, describe, expect, it } from "vitest";
import { parseMove } from "../../src/rules/board-notation";
import type { Side } from "../../src/rules/side";
import type { Clock } from "../../src/referee/clock";
import { ForfeitWatch, type AbsenceRecord, type AbsenceStore } from "../../src/referee/forfeit-watch";
import { OnlineGame, type GameRecord } from "../../src/referee/online-game";
import type { RefereeRefusal, RefereeReply } from "../../src/referee/protocol";
import type { RefereeAlarm } from "../../src/referee/referee-alarm";
import { RefereeSession, type GameStore, type SeatConnections } from "../../src/referee/referee-session";
import type { OpenedRematch, RematchMaker } from "../../src/referee/rematch-maker";
import { SetupTimer } from "../../src/referee/setup-timer";
import { TurnTimer, type TurnDeadlineStore } from "../../src/referee/turn-timer";
import type { SetupDraws } from "../../src/rules/setup";
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

class FakeTurnDeadlines implements TurnDeadlineStore {
	saved: number | undefined;

	async saveTurnDeadline(deadline: number): Promise<void> {
		this.saved = deadline;
	}
}

class FakeAlarm implements RefereeAlarm {
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
const SETUP_TIMER_MS = 180_000;
/** Longer than the Forfeit delay, so a Forfeit comes first unless a test moves time on. */
const TURN_TIMER_MS = 90_000;
const SETUP_DEADLINE = 1_000 + SETUP_TIMER_MS;

/** Always draws the first Square left, so a Random Setup follows the order of the Army. */
const FIRST_SQUARE: SetupDraws = { below: () => 0 };

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("a Referee session", () => {
	let game: OnlineGame;
	let seats: FakeSeats;
	let store: FakeStore;
	let absences: FakeAbsences;
	let alarm: FakeAlarm;
	let turnDeadlines: FakeTurnDeadlines;
	let clock: FakeClock;
	let session: RefereeSession<string>;
	let rematches: FakeRematchMaker;

	function sessionOf(onlineGame: OnlineGame, absent: AbsenceRecord, turnDeadline?: number): RefereeSession<string> {
		const forfeitWatch = new ForfeitWatch(absent, { forfeitAfterMs: FORFEIT_AFTER_MS, clock, store: absences });
		const setupTimer = new SetupTimer(SETUP_DEADLINE, clock);
		const turnTimer = new TurnTimer(turnDeadline, { turnMs: TURN_TIMER_MS, clock, store: turnDeadlines });
		const deadlines = { setupTimer, turnTimer, forfeitWatch, alarm };
		return new RefereeSession(onlineGame, seats, store, deadlines, FIRST_SQUARE, rematches);
	}

	beforeEach(() => {
		game = OnlineGame.open(SEATING);
		seats = new FakeSeats();
		store = new FakeStore();
		absences = new FakeAbsences();
		alarm = new FakeAlarm();
		turnDeadlines = new FakeTurnDeadlines();
		clock = new FakeClock();
		rematches = new FakeRematchMaker();
		session = sessionOf(game, {});
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
				{ type: "setup_status", ownSetupDone: false, opponentSetupDone: false, setupTimeLeftMs: SETUP_TIMER_MS },
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

			expect(seats.lastReplyTo("ada")).toMatchObject({ type: "setup_status", ownSetupDone: false, opponentSetupDone: true });
			expect(seats.lastReplyTo("bob")).toMatchObject({ type: "setup_status", ownSetupDone: true, opponentSetupDone: false });
			expect(store.saved.at(-1)?.setups.green).toEqual(placementsOf("green", GREEN_SETUP));
		});

		it("sends each player only their own view once both are in", async () => {
			await startPlay();

			expect(seats.lastReplyTo("ada")).toEqual({ type: "game_state", view: game.viewOf("red"), history: [], turnTimeLeftMs: TURN_TIMER_MS });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "game_state", view: game.viewOf("green"), history: [], turnTimeLeftMs: TURN_TIMER_MS });
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
			expect(seats.lastReplyTo("ada")).toEqual({ type: "moved", event, view: game.viewOf("red"), turnTimeLeftMs: TURN_TIMER_MS });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "moved", event, view: game.viewOf("green"), turnTimeLeftMs: TURN_TIMER_MS });
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
				{ type: "game_state", view: game.viewOf("green"), history: game.history(), turnTimeLeftMs: TURN_TIMER_MS },
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

		it("sets the alarm back to the Turn Timer when the player comes back", async () => {
			await startPlay();
			await drop("bob");
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));
			expect(alarm.time).toBe(1_000 + TURN_TIMER_MS);
		});

		it("gives Victory to the Opponent of a player who stayed away too long", async () => {
			await startPlay();
			await drop("bob");
			clock.time += FORFEIT_AFTER_MS;
			await session.alarmRang();

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
			await session.alarmRang();

			expect(game.phase()).toBe("playing");
			expect(alarm.time).toBe(1_000 + FORFEIT_AFTER_MS);
		});

		it("Forfeits the player who left first when both are away", async () => {
			await startPlay();
			await drop("ada");
			clock.time += 10;
			await drop("bob");
			clock.time += FORFEIT_AFTER_MS;
			await session.alarmRang();

			expect(game.viewOf("green").result).toEqual({ status: "green_wins", reason: "forfeited" });
		});

		it("waits for play to start before Forfeiting a player who left during Setup", async () => {
			await seatBoth();
			await session.receive("bob", text({ type: "setup", placements: placementsOf("green", GREEN_SETUP) }));
			await drop("bob");
			expect(alarm.time).toBe(SETUP_DEADLINE);

			await session.receive("ada", text({ type: "setup", placements: placementsOf("red", RED_SETUP) }));
			expect(alarm.time).toBe(1_000 + FORFEIT_AFTER_MS);
		});

		it("still Forfeits a player once the referee was rebuilt from storage", async () => {
			await startPlay();
			await drop("bob");
			const rebuilt = OnlineGame.fromRecord(game.toRecord());
			const restarted = sessionOf(rebuilt, absences.saved);
			clock.time += FORFEIT_AFTER_MS;
			await restarted.alarmRang();

			expect(rebuilt.viewOf("red").result).toEqual({ status: "red_wins", reason: "forfeited" });
		});

		it("cancels the alarm when a Resign ends the game", async () => {
			await startPlay();
			await drop("bob");
			await session.receive("ada", text({ type: "resign" }));
			expect(alarm.time).toBeUndefined();
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

	describe("the Setup Timer", () => {
		it("tells each player how long it still runs", async () => {
			await session.receive("ada", text({ type: "take_seat", seatToken: "red-token" }));
			clock.time += 30_000;
			await session.receive("bob", text({ type: "take_seat", seatToken: "green-token" }));

			expect(seats.lastReplyTo("bob")).toMatchObject({ type: "setup_status", setupTimeLeftMs: SETUP_TIMER_MS - 30_000 });
		});

		it("is what the alarm rings for during Setup", async () => {
			await session.scheduleAlarm();
			expect(alarm.time).toBe(SETUP_DEADLINE);
		});

		it("changes nothing when the alarm rings before it runs out", async () => {
			await seatBoth();
			clock.time = SETUP_DEADLINE - 1;
			await session.alarmRang();

			expect(game.phase()).toBe("setup");
			expect(store.saved).toEqual([]);
			expect(alarm.time).toBe(SETUP_DEADLINE);
		});

		it("gives a Random Setup to a side still without one, keeps the other and starts play", async () => {
			await seatBoth();
			await session.receive("ada", text({ type: "setup", placements: placementsOf("red", RED_SETUP) }));
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			const record = store.saved.at(-1);
			expect(game.phase()).toBe("playing");
			expect(record?.setups.red).toEqual(placementsOf("red", RED_SETUP));
			expect(record?.setups.green).toHaveLength(18);
			expect(seats.lastReplyTo("ada")).toEqual({ type: "game_state", view: game.viewOf("red"), history: [], turnTimeLeftMs: TURN_TIMER_MS });
			expect(seats.lastReplyTo("bob")).toEqual({ type: "game_state", view: game.viewOf("green"), history: [], turnTimeLeftMs: TURN_TIMER_MS });
		});

		it("gives both sides a Random Setup when neither handed one in", async () => {
			await seatBoth();
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			expect(game.phase()).toBe("playing");
			expect(game.viewOf("red").ownPieces).toHaveLength(18);
			expect(game.viewOf("green").ownPieces).toHaveLength(18);
		});

		it("leaves a game it started replayable from its record", async () => {
			await seatBoth();
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			expect(OnlineGame.fromRecord(game.toRecord()).viewOf("green")).toEqual(game.viewOf("green"));
		});

		it("hands a player who left during Setup over to the Forfeit deadline", async () => {
			await seatBoth();
			clock.time = SETUP_DEADLINE - 10_000;
			await drop("bob");
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			expect(game.phase()).toBe("playing");
			expect(alarm.time).toBe(SETUP_DEADLINE - 10_000 + FORFEIT_AFTER_MS);
		});

		it("Forfeits at once a player who has already been away longer than the Forfeit delay", async () => {
			await seatBoth();
			await drop("bob");
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			expect(game.viewOf("red").result).toEqual({ status: "red_wins", reason: "forfeited" });
			expect(seats.lastReplyTo("ada")).toMatchObject({ view: { result: { reason: "forfeited" } } });
		});
	});

	describe("the Turn Timer", () => {
		it("starts when play starts and is what the alarm rings for", async () => {
			await startPlay();

			expect(turnDeadlines.saved).toBe(1_000 + TURN_TIMER_MS);
			expect(alarm.time).toBe(1_000 + TURN_TIMER_MS);
		});

		it("starts again with each Move and tells both players how long the next player has", async () => {
			await startPlay();
			clock.time += 20_000;
			await session.receive("ada", text({ type: "move", move: parseMove("c3-c4") }));

			expect(turnDeadlines.saved).toBe(21_000 + TURN_TIMER_MS);
			expect(seats.lastReplyTo("bob")).toMatchObject({ type: "moved", turnTimeLeftMs: TURN_TIMER_MS });
		});

		it("tells a Guest who comes back how long the player to move still has", async () => {
			await startPlay();
			clock.time += 30_000;
			await session.receive("bob-again", text({ type: "take_seat", seatToken: "green-token" }));

			expect(seats.lastReplyTo("bob-again")).toMatchObject({ type: "game_state", turnTimeLeftMs: TURN_TIMER_MS - 30_000 });
		});

		it("Forfeits the player to move when it runs out", async () => {
			await startPlay();
			clock.time += TURN_TIMER_MS;
			await session.alarmRang();

			expect(game.viewOf("green").result).toEqual({ status: "green_wins", reason: "out_of_time" });
			expect(store.saved.at(-1)?.concession).toEqual({ loser: "red", reason: "out_of_time" });
			expect(seats.lastReplyTo("bob")).toMatchObject({ type: "game_state", view: { result: { reason: "out_of_time" } } });
			expect(seats.lastReplyTo("bob")).not.toHaveProperty("turnTimeLeftMs");
			expect(alarm.time).toBeUndefined();
		});

		it("Forfeits no one before it runs out", async () => {
			await startPlay();
			clock.time += TURN_TIMER_MS - 1;
			await session.alarmRang();

			expect(game.phase()).toBe("playing");
			expect(alarm.time).toBe(1_000 + TURN_TIMER_MS);
		});

		it("gives way to an absence that passed its Forfeit delay first", async () => {
			await startPlay();
			await drop("bob");
			clock.time += TURN_TIMER_MS;
			await session.alarmRang();

			expect(game.viewOf("red").result).toEqual({ status: "red_wins", reason: "forfeited" });
		});

		it("Forfeits the player to move when it ran out before the absent Opponent's delay", async () => {
			await startPlay();
			clock.time += TURN_TIMER_MS - 10_000;
			await drop("bob");
			clock.time += 10_000;
			await session.alarmRang();

			expect(game.viewOf("red").result).toEqual({ status: "green_wins", reason: "out_of_time" });
		});

		it("starts when the Setup Timer starts play", async () => {
			await seatBoth();
			clock.time = SETUP_DEADLINE;
			await session.alarmRang();

			expect(alarm.time).toBe(SETUP_DEADLINE + TURN_TIMER_MS);
			expect(seats.lastReplyTo("ada")).toMatchObject({ type: "game_state", turnTimeLeftMs: TURN_TIMER_MS });
		});

		it("still Forfeits the player to move once the referee was rebuilt from storage", async () => {
			await startPlay();
			const rebuilt = OnlineGame.fromRecord(game.toRecord());
			const restarted = sessionOf(rebuilt, {}, turnDeadlines.saved);
			clock.time += TURN_TIMER_MS;
			await restarted.alarmRang();

			expect(rebuilt.viewOf("red").result).toEqual({ status: "green_wins", reason: "out_of_time" });
		});
	});
});
