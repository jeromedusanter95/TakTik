import { DurableObject } from "cloudflare:workers";
import { ForfeitWatch, type AbsenceRecord } from "../referee/forfeit-watch";
import { OnlineGame } from "../referee/online-game";
import { RefereeSession } from "../referee/referee-session";
import type { Seating } from "../referee/seating";
import { DurableObjectAbsenceStore } from "./durable-object-absence-store";
import { DurableObjectForfeitAlarm } from "./durable-object-forfeit-alarm";
import { DurableObjectGameStore } from "./durable-object-game-store";
import { WebSocketSeatConnections } from "./websocket-seat-connections";

const SYSTEM_CLOCK = { now: (): number => Date.now() };

/**
 * The referee of one online game. Its record and who is away are reloaded
 * whenever the object wakes, since hibernation wipes memory; the sockets and
 * the forfeit alarm survive it.
 */
export class Referee extends DurableObject<Env> {
	private readonly store: DurableObjectGameStore;
	private readonly absences: DurableObjectAbsenceStore;
	private session: RefereeSession<WebSocket> | undefined;

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		this.store = new DurableObjectGameStore(ctx.storage);
		this.absences = new DurableObjectAbsenceStore(ctx.storage);
		void ctx.blockConcurrencyWhile(async () => {
			const record = await this.store.load();
			if (record !== undefined) {
				this.startSession(OnlineGame.fromRecord(record), await this.absences.load());
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
		this.startSession(game, {});
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
		await this.session?.forfeitOverdue();
	}

	private startSession(game: OnlineGame, absences: AbsenceRecord): void {
		const forfeitWatch = new ForfeitWatch(absences, {
			forfeitAfterMs: Number(this.env.FORFEIT_AFTER_SECONDS) * 1_000,
			clock: SYSTEM_CLOCK,
			store: this.absences,
			alarm: new DurableObjectForfeitAlarm(this.ctx.storage),
		});
		this.session = new RefereeSession(game, new WebSocketSeatConnections(this.ctx), this.store, forfeitWatch);
	}
}
