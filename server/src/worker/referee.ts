import { DurableObject } from "cloudflare:workers";
import { OnlineGame } from "../referee/online-game";
import { RefereeSession } from "../referee/referee-session";
import type { Seating } from "../referee/seating";
import { DurableObjectGameStore } from "./durable-object-game-store";
import { WebSocketSeatConnections } from "./websocket-seat-connections";

/**
 * The referee of one online game. Its record is reloaded whenever the object
 * wakes, since hibernation wipes memory; the sockets survive it.
 */
export class Referee extends DurableObject<Env> {
	private readonly store: DurableObjectGameStore;
	private session: RefereeSession<WebSocket> | undefined;

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		this.store = new DurableObjectGameStore(ctx.storage);
		void ctx.blockConcurrencyWhile(async () => {
			const record = await this.store.load();
			if (record !== undefined) {
				this.startSession(OnlineGame.fromRecord(record));
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
		this.startSession(game);
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

	private startSession(game: OnlineGame): void {
		this.session = new RefereeSession(game, new WebSocketSeatConnections(this.ctx), this.store);
	}
}
