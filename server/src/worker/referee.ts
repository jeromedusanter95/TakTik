import { DurableObject } from "cloudflare:workers";
import { ForfeitWatch, type AbsenceRecord } from "../referee/forfeit-watch";
import { OnlineGame } from "../referee/online-game";
import { RefereeSession } from "../referee/referee-session";
import type { Seating } from "../referee/seating";
import { SetupTimer } from "../referee/setup-timer";
import { TurnTimer } from "../referee/turn-timer";
import { DurableObjectAbsenceStore } from "./durable-object-absence-store";
import { DurableObjectGameStore } from "./durable-object-game-store";
import { DurableObjectRefereeAlarm } from "./durable-object-referee-alarm";
import { DurableObjectSetupDeadlineStore } from "./durable-object-setup-deadline-store";
import { DurableObjectTurnDeadlineStore } from "./durable-object-turn-deadline-store";
import { RandomLobbyDraws } from "./random-lobby-draws";
import { RandomSetupDraws } from "./random-setup-draws";
import { RefereeGameOpener } from "./referee-game-opener";
import { RefereeRematchMaker } from "./referee-rematch-maker";
import { WebSocketSeatConnections } from "./websocket-seat-connections";

const SYSTEM_CLOCK = { now: (): number => Date.now() };

/**
 * The referee of one online game. Its record, when its Setup Timer and the
 * current turn run out and who is away are reloaded whenever the object wakes,
 * since hibernation wipes memory; the sockets and the alarm survive it.
 */
export class Referee extends DurableObject<Env> {
	private readonly store: DurableObjectGameStore;
	private readonly absences: DurableObjectAbsenceStore;
	private readonly setupDeadlines: DurableObjectSetupDeadlineStore;
	private readonly turnDeadlines: DurableObjectTurnDeadlineStore;
	private session: RefereeSession<WebSocket> | undefined;

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		this.store = new DurableObjectGameStore(ctx.storage);
		this.absences = new DurableObjectAbsenceStore(ctx.storage);
		this.setupDeadlines = new DurableObjectSetupDeadlineStore(ctx.storage);
		this.turnDeadlines = new DurableObjectTurnDeadlineStore(ctx.storage);
		void ctx.blockConcurrencyWhile(async () => {
			const record = await this.store.load();
			if (record === undefined) {
				return;
			}
			const game = OnlineGame.fromRecord(record);
			const storedSetupDeadline = await this.setupDeadlines.load();
			const turnTimer = this.turnTimerFrom(await this.turnDeadlines.load());
			const turnTimerMissing = game.phase() === "playing" && turnTimer.deadline() === undefined;
			if (turnTimerMissing) {
				await turnTimer.restart();
			}
			const setupDeadline = storedSetupDeadline ?? (await this.startSetupTimer());
			const session = this.startSession(game, await this.absences.load(), setupDeadline, turnTimer);
			if (storedSetupDeadline === undefined || turnTimerMissing) {
				await session.scheduleAlarm();
			}
		});
	}

	/** Rejects when this game is already open. */
	async open(seating: Seating): Promise<void> {
		if (this.session !== undefined) {
			throw new Error("This game is already open");
		}
		const game = OnlineGame.open(seating);
		await this.store.save(game.toRecord());
		const session = this.startSession(game, {}, await this.startSetupTimer(), this.turnTimerFrom(undefined));
		await session.scheduleAlarm();
	}

	override async fetch(): Promise<Response> {
		if (this.session === undefined) {
			return new Response("No such game", { status: 404 });
		}
		const [client, server] = Object.values(new WebSocketPair()) as [WebSocket, WebSocket];
		this.ctx.acceptWebSocket(server);
		return new Response(null, { status: 101, webSocket: client });
	}

	override async webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): Promise<void> {
		const text = typeof message === "string" ? message : new TextDecoder().decode(message);
		await this.session?.receive(socket, text);
	}

	/** The runtime has already answered the close frame (web_socket_auto_reply_to_close). */
	override async webSocketClose(socket: WebSocket): Promise<void> {
		await this.session?.disconnect(socket);
	}

	override async alarm(): Promise<void> {
		await this.session?.alarmRang();
	}

	/** Starts the Setup Timer now and returns when it runs out. */
	private async startSetupTimer(): Promise<number> {
		const deadline = SYSTEM_CLOCK.now() + Number(this.env.SETUP_TIMER_SECONDS) * 1_000;
		await this.setupDeadlines.save(deadline);
		return deadline;
	}

	/** The Turn Timer of a turn that runs out at [deadline], or of a game whose first turn has not started. */
	private turnTimerFrom(deadline: number | undefined): TurnTimer {
		return new TurnTimer(deadline, {
			turnMs: Number(this.env.TURN_TIMER_SECONDS) * 1_000,
			clock: SYSTEM_CLOCK,
			store: this.turnDeadlines,
		});
	}

	private startSession(
		game: OnlineGame,
		absences: AbsenceRecord,
		setupDeadline: number,
		turnTimer: TurnTimer,
	): RefereeSession<WebSocket> {
		const forfeitWatch = new ForfeitWatch(absences, {
			forfeitAfterMs: Number(this.env.FORFEIT_AFTER_SECONDS) * 1_000,
			clock: SYSTEM_CLOCK,
			store: this.absences,
		});
		const deadlines = {
			setupTimer: new SetupTimer(setupDeadline, SYSTEM_CLOCK),
			turnTimer,
			forfeitWatch,
			alarm: new DurableObjectRefereeAlarm(this.ctx.storage),
		};
		const connections = new WebSocketSeatConnections(this.ctx);
		const rematchMaker = new RefereeRematchMaker(new RefereeGameOpener(this.env.REFEREE), new RandomLobbyDraws());
		const draws = new RandomSetupDraws();
		this.session = new RefereeSession(game, connections, this.store, deadlines, draws, rematchMaker);
		return this.session;
	}
}
